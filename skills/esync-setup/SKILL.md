---
name: esync-setup
description: Use when setting up file synchronization for a project, when user wants to sync local files to a remote server or backup location, or when configuring esync for a new or existing project directory
---

# esync Setup

Set up [esync](https://github.com/louloulibs/esync) — a lightweight file sync tool that watches for changes and automatically rsyncs them to a local or remote destination.

## Quick Reference

| Command                          | Purpose                                  |
|----------------------------------|------------------------------------------|
| `esync init -r user@host:/path`  | Generate config from current directory   |
| `esync check`                    | Validate config + preview included/excluded files |
| `esync edit`                     | Open config in $EDITOR, validate on save |
| `esync sync`                     | Start watching + syncing (TUI)           |
| `esync sync --daemon`            | Run in background (no TUI)              |
| `esync status`                   | Check if daemon is running               |

## Setup Workflow

1. **Install**: `go install github.com/louloulibs/esync@latest` (or download binary from releases)
2. **Init**: `cd` into the project, run `esync init -r <destination>`
   - Auto-imports `.gitignore` patterns
   - Detects common dirs (`.venv`, `build`, `__pycache__`, `dist`, `.tox`, `.mypy_cache`)
3. **Customize**: Edit `esync.toml` — adjust ignore patterns, SSH, rsync flags
4. **Verify**: `esync check` to see what files will be included/excluded
5. **Sync**: `esync sync` (interactive TUI) or `esync sync --daemon` (background)

## Config Structure

```toml
[sync]
local  = "."
remote = "user@host:/path/to/dest"

[sync.ssh]                          # Optional: explicit SSH control
host             = "myserver.com"
user             = "deploy"
port             = 22
identity_file    = "~/.ssh/id_ed25519"
interactive_auth = false            # true for 2FA servers

[settings]
watcher_debounce = 500              # ms between batched syncs
initial_sync     = false            # full sync on startup
ignore = [".git", "node_modules", ".DS_Store"]

[settings.rsync]
archive    = true
compress   = true
extra_args = ["--delete"]           # pass-through rsync flags
ignore     = ["*.log", "*.tmp"]     # rsync-only excludes

[settings.log]
file   = "/var/log/esync.log"       # optional log file (daemon mode)
format = "text"                     # "text" or "json"
```

## Language-Specific Ignore Patterns

When setting up esync, add project-appropriate ignores:

**Python**: `[".venv", "__pycache__", "*.pyc", ".tox", ".mypy_cache", "*.egg-info", ".pytest_cache"]`

**Node.js**: `["node_modules", "dist", ".next", ".nuxt", "coverage", ".turbo"]`

**Go**: `["vendor"]` (most Go artifacts are in separate GOPATH)

**Rust**: `["target"]`

**R/Data Science**: `[".Rhistory", ".RData", "renv/library", "*.rds"]`

**General**: `[".git", ".DS_Store", "*.swp", "*.swo", ".env", "*.log"]`

## SSH Setup

**Simple** (when `~/.ssh/config` is already set up):
```toml
[sync]
remote = "myserver:/opt/app"    # uses SSH config alias
```

**Explicit** (full control, enables ControlMaster keepalive):
```toml
[sync.ssh]
host          = "192.168.1.50"
user          = "deploy"
port          = 2222
identity_file = "~/.ssh/deploy_key"
```

**2FA servers**: Set `interactive_auth = true` in `[sync.ssh]`.

## Common Customizations

**Delete extraneous remote files**: `extra_args = ["--delete"]`

**Bandwidth limit**: `extra_args = ["--bwlimit=5000"]`

**Set remote permissions**: `extra_args = ["--chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r"]`

**Dry run first**: `esync sync --dry-run`

**Force initial full sync**: `esync sync --initial-sync`
