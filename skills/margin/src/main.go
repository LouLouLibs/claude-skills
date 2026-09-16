// margin — a write-only comment receiver for tailnet-served doc sites.
//
// Accepts POST /api/comment behind a tailscale-serve proxy and appends
// one JSON line per comment to <site root>/<doc>.jsonl. It serves no
// reads: the static doc sites deliver the JSONL back to the page, so
// this process has zero read surface.
//
// Security posture (see the 2026-09-16 margin spec in the networking
// workspace): loopback-only bind (refuses anything else — the trust in
// the proxy-injected Tailscale-User-Login header depends on it), 16 KiB
// body cap, strict schema with unknown fields rejected, path-traversal
// containment, per-user token bucket, O_APPEND single-write persistence.
// Stdlib only, by design: the empty go.sum is an invariant.
package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	maxBody     = 16 << 10 // 16 KiB
	maxQuote    = 512
	maxAffix    = 64
	maxText     = 4096
	ratePerMin  = 30
	rateBurst   = 30
)

var docRe = regexp.MustCompile(`^[A-Za-z0-9._/-]+$`)
var idRe = regexp.MustCompile(`^[a-f0-9]{16}$`)

// ---------------------------------------------------------------------------

type anchor struct {
	Quote  string `json:"quote"`
	Prefix string `json:"prefix,omitempty"`
	Suffix string `json:"suffix,omitempty"`
}

type request struct {
	Site    string  `json:"site"`
	Doc     string  `json:"doc"`
	Anchor  *anchor `json:"anchor,omitempty"`
	Text    string  `json:"text"`
	ReplyTo string  `json:"reply_to,omitempty"`
}

type record struct {
	ID      string  `json:"id"`
	TS      string  `json:"ts"`
	User    string  `json:"user"`
	Name    string  `json:"name,omitempty"`
	Doc     string  `json:"doc"`
	Anchor  *anchor `json:"anchor,omitempty"`
	Text    string  `json:"text"`
	ReplyTo string  `json:"reply_to,omitempty"`
}

// ---------------------------------------------------------------------------

type bucket struct {
	tokens float64
	last   time.Time
}

type limiter struct {
	mu sync.Mutex
	m  map[string]*bucket
}

func newLimiter() *limiter { return &limiter{m: make(map[string]*bucket)} }

func (l *limiter) allow(user string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := time.Now()
	b, ok := l.m[user]
	if !ok {
		b = &bucket{tokens: rateBurst, last: now}
		l.m[user] = b
	}
	b.tokens += now.Sub(b.last).Minutes() * ratePerMin
	if b.tokens > rateBurst {
		b.tokens = rateBurst
	}
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

// ---------------------------------------------------------------------------

type server struct {
	sites map[string]string // site name -> absolute comments root
	lim   *limiter
	fsync bool
}

func httpError(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

// validate checks everything the client controls; returns the contained
// absolute file path for the append.
func (s *server) validate(req *request) (string, error) {
	root, ok := s.sites[req.Site]
	if !ok {
		return "", errors.New("unknown site")
	}
	if req.Doc == "" || len(req.Doc) > 256 || !docRe.MatchString(req.Doc) ||
		strings.Contains(req.Doc, "..") || strings.HasPrefix(req.Doc, "/") {
		return "", errors.New("bad doc id")
	}
	if req.Text == "" || len(req.Text) > maxText {
		return "", errors.New("text empty or too long")
	}
	if a := req.Anchor; a != nil {
		if len(a.Quote) > maxQuote || len(a.Prefix) > maxAffix || len(a.Suffix) > maxAffix {
			return "", errors.New("anchor field too long")
		}
	}
	if req.ReplyTo != "" && !idRe.MatchString(req.ReplyTo) {
		return "", errors.New("bad reply_to id")
	}
	// Containment: the cleaned path must stay under the site root.
	path := filepath.Join(root, filepath.FromSlash(req.Doc)+".jsonl")
	clean := filepath.Clean(path)
	if clean != path || !strings.HasPrefix(clean, root+string(filepath.Separator)) {
		return "", errors.New("doc id escapes root")
	}
	return clean, nil
}

func (s *server) handleComment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		httpError(w, http.StatusMethodNotAllowed, "POST only")
		return
	}
	if ct := r.Header.Get("Content-Type"); !strings.HasPrefix(ct, "application/json") {
		httpError(w, http.StatusUnsupportedMediaType, "application/json only")
		return
	}
	if r.ContentLength < 0 || r.ContentLength > maxBody {
		httpError(w, http.StatusRequestEntityTooLarge, "body absent or over 16KiB")
		return
	}
	// Identity comes ONLY from the tailscale-serve proxy. Loopback bind is
	// what makes this header trustworthy; both are enforced, not assumed.
	user := r.Header.Get("Tailscale-User-Login")
	if user == "" {
		httpError(w, http.StatusUnauthorized, "no tailnet identity")
		return
	}
	if !s.lim.allow(user) {
		httpError(w, http.StatusTooManyRequests, "rate limit: 30/min")
		return
	}

	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBody))
	dec.DisallowUnknownFields()
	var req request
	if err := dec.Decode(&req); err != nil {
		httpError(w, http.StatusBadRequest, "bad json: "+err.Error())
		return
	}
	if dec.More() {
		httpError(w, http.StatusBadRequest, "trailing data")
		return
	}
	path, err := s.validate(&req)
	if err != nil {
		httpError(w, http.StatusBadRequest, err.Error())
		return
	}

	idb := make([]byte, 8)
	if _, err := rand.Read(idb); err != nil {
		httpError(w, http.StatusInternalServerError, "entropy")
		return
	}
	rec := record{
		ID:      hex.EncodeToString(idb),
		TS:      time.Now().UTC().Format(time.RFC3339),
		User:    user,
		Name:    r.Header.Get("Tailscale-User-Name"),
		Doc:     req.Doc,
		Anchor:  req.Anchor,
		Text:    req.Text,
		ReplyTo: req.ReplyTo,
	}
	line, err := json.Marshal(rec)
	if err != nil {
		httpError(w, http.StatusInternalServerError, "marshal")
		return
	}
	if err := appendLine(path, line, s.fsync); err != nil {
		log.Printf("append %s: %v", path, err)
		httpError(w, http.StatusInternalServerError, "store")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"id": rec.ID})
}

func appendLine(path string, line []byte, doSync bool) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err := f.Write(append(line, '\n')); err != nil {
		return err
	}
	if doSync {
		return f.Sync()
	}
	return nil
}

// ---------------------------------------------------------------------------

func parseSites(spec string) (map[string]string, error) {
	sites := make(map[string]string)
	for _, part := range strings.Split(spec, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		name, root, ok := strings.Cut(part, "=")
		if !ok || name == "" || !filepath.IsAbs(root) {
			return nil, fmt.Errorf("bad site spec %q (want name=/abs/path)", part)
		}
		sites[name] = filepath.Clean(root)
	}
	if len(sites) == 0 {
		return nil, errors.New("no sites configured")
	}
	return sites, nil
}

func requireLoopback(addr string) error {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return err
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("refusing non-loopback listen address %q: the Tailscale-User-Login header is only trustworthy behind the local tailscale-serve proxy", addr)
	}
	return nil
}

func main() {
	listen := flag.String("listen", "127.0.0.1:18090", "loopback listen address")
	sitesSpec := flag.String("sites", "", "comma-separated name=/abs/comments/root pairs")
	noFsync := flag.Bool("no-fsync", false, "skip fsync after each append")
	flag.Parse()

	if err := requireLoopback(*listen); err != nil {
		log.Fatal(err)
	}
	sites, err := parseSites(*sitesSpec)
	if err != nil {
		log.Fatal(err)
	}
	s := &server{sites: sites, lim: newLimiter(), fsync: !*noFsync}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/comment", s.handleComment)

	srv := &http.Server{
		Addr:              *listen,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    8 << 10,
	}
	log.Printf("margin: listening on %s, sites: %v, fsync=%v", *listen, sites, s.fsync)
	log.Fatal(srv.ListenAndServe())
}
