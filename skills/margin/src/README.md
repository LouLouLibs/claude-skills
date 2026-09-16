# margin

A write-only comment receiver for tailnet-served static doc sites: comments in the margin.

Accepts `POST /api/comment` behind a `tailscale serve` proxy and appends one JSON line per
comment to `<site root>/<doc>.jsonl`. It serves **no reads** — the static sites deliver the
JSONL back to the page, so this process has zero read surface.

Design spec: `networking/docs/specs/2026-09-16-margin-doc-comments-service.md` (private
workspace). Deployed on coeus via nixos-coeus (`louloulibs.nix` + `modules/nixos/margin.nix`).

## Security posture

- **Loopback-only**: refuses to start on a non-loopback address. The trust in the
  proxy-injected `Tailscale-User-Login` header depends on it, so it is enforced, not assumed.
- Identity comes only from that header; the JSON schema is closed (`DisallowUnknownFields`),
  so it cannot be smuggled in the body.
- 16 KiB body cap, strict per-field limits, doc-id charset + traversal containment.
- Per-user token bucket (30/min).
- `O_APPEND` single-write persistence, fsync by default.
- **Zero third-party dependencies** — stdlib only; the absence of `go.sum` is CI-enforced.
  The intended maintenance burden of this repository is none.

## Run

    margin -listen 127.0.0.1:18090 \
           -sites "InwardBetas=/home/loulou/WORK/InwardBetas/docs/comments"

## Release

Tag `vX.Y.Z` → CI publishes a static `margin-linux-amd64` asset (`CGO_ENABLED=0`).
