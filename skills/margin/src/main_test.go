package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testServer(t *testing.T) (*server, string) {
	t.Helper()
	root := t.TempDir()
	return &server{sites: map[string]string{"S": root}, lim: newLimiter(), fsync: false}, root
}

func post(t *testing.T, s *server, body string, hdr map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	r := httptest.NewRequest(http.MethodPost, "/api/comment", bytes.NewBufferString(body))
	r.Header.Set("Content-Type", "application/json")
	r.Header.Set("Tailscale-User-Login", "erik@example.com")
	for k, v := range hdr {
		r.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	s.handleComment(w, r)
	return w
}

func TestHappyPathAppends(t *testing.T) {
	s, root := testServer(t)
	w := post(t, s, `{"site":"S","doc":"notes/x","text":"hello","anchor":{"quote":"q"}}`, nil)
	if w.Code != http.StatusCreated {
		t.Fatalf("code=%d body=%s", w.Code, w.Body)
	}
	b, err := os.ReadFile(filepath.Join(root, "notes", "x.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	var rec record
	if err := json.Unmarshal(bytes.TrimSpace(b), &rec); err != nil {
		t.Fatal(err)
	}
	if rec.User != "erik@example.com" || rec.Text != "hello" || len(rec.ID) != 16 {
		t.Fatalf("bad record: %+v", rec)
	}
}

func TestIdentityCannotComeFromBody(t *testing.T) {
	s, _ := testServer(t)
	w := post(t, s, `{"site":"S","doc":"x","text":"t","user":"spoofed"}`, nil)
	if w.Code != http.StatusBadRequest || !strings.Contains(w.Body.String(), "unknown field") {
		t.Fatalf("unknown field not rejected: %d %s", w.Code, w.Body)
	}
}

func TestNoIdentityHeader(t *testing.T) {
	s, _ := testServer(t)
	r := httptest.NewRequest(http.MethodPost, "/api/comment", bytes.NewBufferString(`{}`))
	r.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	s.handleComment(w, r)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("code=%d", w.Code)
	}
}

func TestTraversalContained(t *testing.T) {
	s, _ := testServer(t)
	for _, doc := range []string{"../etc/passwd", "a/../../b", "/abs", "a//..", ".."} {
		body, _ := json.Marshal(request{Site: "S", Doc: doc, Text: "t"})
		w := post(t, s, string(body), nil)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("doc %q accepted: %d", doc, w.Code)
		}
	}
}

func TestUnknownSite(t *testing.T) {
	s, _ := testServer(t)
	if w := post(t, s, `{"site":"nope","doc":"x","text":"t"}`, nil); w.Code != http.StatusBadRequest {
		t.Fatalf("code=%d", w.Code)
	}
}

func TestOversizeBodyRejected(t *testing.T) {
	s, _ := testServer(t)
	big := `{"site":"S","doc":"x","text":"` + strings.Repeat("a", maxBody) + `"}`
	if w := post(t, s, big, nil); w.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("code=%d", w.Code)
	}
}

func TestTextTooLong(t *testing.T) {
	s, _ := testServer(t)
	body := `{"site":"S","doc":"x","text":"` + strings.Repeat("a", maxText+1) + `"}`
	if w := post(t, s, body, nil); w.Code != http.StatusBadRequest {
		t.Fatalf("code=%d", w.Code)
	}
}

func TestMethodAndContentType(t *testing.T) {
	s, _ := testServer(t)
	r := httptest.NewRequest(http.MethodGet, "/api/comment", nil)
	w := httptest.NewRecorder()
	s.handleComment(w, r)
	if w.Code != http.StatusMethodNotAllowed {
		t.Fatalf("GET: %d", w.Code)
	}
	if w := post(t, s, `x`, map[string]string{"Content-Type": "text/plain"}); w.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("content-type: %d", w.Code)
	}
}

func TestRateLimit(t *testing.T) {
	s, _ := testServer(t)
	var last int
	for i := 0; i < rateBurst+1; i++ {
		last = post(t, s, `{"site":"S","doc":"x","text":"t"}`, nil).Code
	}
	if last != http.StatusTooManyRequests {
		t.Fatalf("burst+1 gave %d, want 429", last)
	}
}

func TestLoopbackGuard(t *testing.T) {
	for addr, ok := range map[string]bool{
		"127.0.0.1:18090": true, "[::1]:18090": true,
		"0.0.0.0:18090": false, "100.64.0.1:18090": false, "coeus:18090": false,
	} {
		err := requireLoopback(addr)
		if (err == nil) != ok {
			t.Fatalf("requireLoopback(%q) = %v, want ok=%v", addr, err, ok)
		}
	}
}

func TestReplyToValidation(t *testing.T) {
	s, _ := testServer(t)
	if w := post(t, s, `{"site":"S","doc":"x","text":"t","reply_to":"zz"}`, nil); w.Code != http.StatusBadRequest {
		t.Fatalf("bad reply_to accepted: %d", w.Code)
	}
	if w := post(t, s, `{"site":"S","doc":"x","text":"t","reply_to":"0123456789abcdef"}`, nil); w.Code != http.StatusCreated {
		t.Fatalf("good reply_to rejected: %d %s", w.Code, w.Body)
	}
}
