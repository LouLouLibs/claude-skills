---
name: mint-gh-token
description: Mint a short-lived GitHub App installation access token for HTTPS git/gh authentication. Use when GH_TOKEN is unset inside a VM or sandbox that authenticates via a GitHub App (.pem key in GH_APP_KEY), when git push or gh fails with 401/403 against github.com, or when the user asks to mint or refresh a GitHub token.
---

# mint-gh-token — GitHub App installation tokens

Mints a short-lived (1 hour) GitHub App installation access token and prints
it on stdout. Replaces the per-repo `src/scripts/mint_gh_token.py` copies.

```bash
export GH_TOKEN=$(mint-gh-token)
```

Diagnostics go to stderr; stdout carries the bare token and nothing else.

## Install

Check `command -v mint-gh-token` first. If missing, download the release
binary (the repo is public — no token needed; VMs that allow
`github.com` / `release-assets.githubusercontent.com` egress can fetch it):

```bash
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/mint-gh-token \
  "https://github.com/LouLouLibs/claude-skills/releases/latest/download/mint-gh-token-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
chmod +x ~/.local/bin/mint-gh-token
```

Assets: `mint-gh-token-linux-x86_64` (static musl — runs on any Linux,
including NixOS microVM guests) and `mint-gh-token-darwin-arm64`.
Runtime requirement: `curl` on PATH (HTTPS is delegated to it).

## Environment

| Variable | Meaning |
|----------|---------|
| `GH_APP_KEY` | PEM private key content of the GitHub App (usually injected by the VM launcher) |
| `GH_APP_KEY_FILE` | Path to the `.pem` file (used when `GH_APP_KEY` is unset) |
| `GH_APP_ID` | Numeric App ID (or the App's Client ID) |
| `GH_APP_OWNER` | Owner of a repo the App is installed on |
| `GH_APP_REPO` | Name of that repo (installation lookup target) |
| `GH_TOKEN_CACHE` | Cache file path (default `$TMPDIR/mint_gh_token.cache.json`) |
| `GH_API_URL` | API base URL override (default `https://api.github.com`) |

Flags: `--no-cache` forces a fresh mint; `--help`.

## Caching

Tokens are cached and reused until < 5 minutes of life remain. If the cache
path is unwritable (e.g. read-only `/tmp` in a VM), the token is **still
printed** — you only lose reuse across shells. Set `GH_TOKEN_CACHE` to a
writable path to fix the warning. Recover a cached token in a later shell:

```bash
export GH_TOKEN=$(jq -r .token "$GH_TOKEN_CACHE")
```

## Using the token

```bash
export GH_TOKEN=$(mint-gh-token)        # gh CLI picks up $GH_TOKEN

# git push when the global gitconfig blocks github.com (token-in-URL —
# credential-helper lines in GIT_CONFIG_GLOBAL files can trip config parsing):
git push "https://x-access-token:${GH_TOKEN}@github.com/${GH_APP_OWNER}/${GH_APP_REPO}.git" BRANCH
```

Scope gotchas (App installation tokens, not PATs):

- The token only works on repos the App is installed on; other repos 404.
- Some API endpoints claim to be unavailable to App tokens in their docs —
  that is the user-model view; actual writes work.
- The App cannot approve its own PRs; a human merges by hand.

## Building from source

Source lives in `src/` (single-file OCaml, dune project). CI
(`.github/workflows/mint-gh-token.yml`) builds and releases on tags
matching `mint-gh-token-v*`. Local build:

```bash
# With an opam switch that has the deps (x509, base64, yojson, ptime,
# mirage-crypto-rng), just:
cd src && dune build

# On NixOS, use the committed flake devShell (flake.nix), which pins the
# full library closure — including `logs`, without which
# mirage-crypto-rng.unix fails to link:
nix develop -c dune build --root src
# or, with direnv: `direnv allow` once, then plain `dune build` in src/.

# The test suite additionally needs openssl + python3 (the RSA key and the
# stub GitHub API server); curl is already in the devShell:
nix shell nixpkgs#openssl -c nix develop -c \
  ./test/run_test.sh src/_build/default/mint_gh_token.exe
```
