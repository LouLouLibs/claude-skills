---
name: julia-release
description: Use when tagging a Julia package version, updating the loulouJL registry, or computing artifact hashes for Artifacts.toml. Triggers on "tag version", "release", "register", "update registry", "artifact hashes".
---

# Julia Package Release & Registry Update

Tag a version, compute artifact hashes, and register in loulouJL.

## Registry Location

`/Users/loulou/Dropbox/projects_code/julia_packages/loulouJL/`

Each package has: `Versions.toml`, `Deps.toml`, `Compat.toml`, `Package.toml`

## Quick Reference

| Step | Command |
|------|---------|
| Get tree SHA | `git rev-parse vX.Y.Z^{tree}` |
| Download release artifact | `curl -sL -o file.tar.gz "URL"` |
| SHA256 of tarball | `shasum -a 256 file.tar.gz` |
| Tree hash of extracted artifact | `julia -e 'using Pkg; println(bytes2hex(Pkg.GitTools.tree_hash(".")))'` |

## Release Checklist

### 1. Version bump (PR required if main is protected)

```julia
# Project.toml
version = "X.Y.Z"
```

### 2. Tag AFTER all changes are merged

**NEVER re-tag a release that has artifacts.** Re-tagging causes GitHub to regenerate tarballs with different SHA256 checksums, breaking all artifact downloads.

```bash
git tag -a vX.Y.Z -m "vX.Y.Z: description"
git push origin vX.Y.Z
```

### 3. Wait for CI + artifact builds

```bash
gh run list --limit 5                    # check status
gh run watch <run-id> --exit-status      # wait for completion
```

### 4. Compute artifact hashes (if package has Artifacts.toml)

```bash
# Download each artifact from the release
curl -sL -o artifact.tar.gz "https://github.com/ORG/REPO/releases/download/vX.Y.Z/artifact-PLATFORM.tar.gz"

# SHA256 (goes in Artifacts.toml [[name.download]] sha256)
shasum -a 256 artifact.tar.gz

# Tree hash (goes in Artifacts.toml [[name]] git-tree-sha1)
mkdir extracted && cd extracted
tar -xzf ../artifact.tar.gz
julia -e 'using Pkg; println(bytes2hex(Pkg.GitTools.tree_hash(".")))'
```

Update `Artifacts.toml` with computed hashes, commit, push. Do this BEFORE tagging if possible to avoid the re-tag problem.

### 5. Update loulouJL registry

```bash
TREE=$(git rev-parse vX.Y.Z^{tree})
```

**Versions.toml** — always update:
```toml
["X.Y.Z"]
git-tree-sha1 = "TREE_SHA"
```

**Deps.toml** — update only if dependencies changed. Use version ranges:
```toml
["X.Y-0"]
SomeDep = "uuid-here"
```
Ranges must not overlap. `"0.6-0"` means 0.6 to end of 0.x.

**Compat.toml** — update only if compat bounds changed:
```toml
["0"]
julia = "1.6-*"
```

Commit and push the registry:
```bash
cd /Users/loulou/Dropbox/projects_code/julia_packages/loulouJL
git add LETTER/PackageName/
git commit -m "Register PackageName vX.Y.Z"
git push
```

### 6. Verify

```julia
using Pkg
Pkg.Registry.update()
Pkg.add("PackageName")  # or Pkg.update("PackageName")
```

## Artifacts.toml Format

```toml
[[artifact_name]]
arch = "aarch64"          # or "x86_64"
git-tree-sha1 = "HASH"
os = "macos"              # or "linux"
lazy = true

    [[artifact_name.download]]
    url = "https://github.com/ORG/REPO/releases/download/vX.Y.Z/file.tar.gz"
    sha256 = "HASH"
```

## Common Mistakes

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Re-tag a release with artifacts | SHA256 changes, downloads break | Tag once, after all changes merged |
| Tag before artifact hashes committed | Need re-tag (see above) | Compute hashes first, commit, then tag |
| Overlapping Deps.toml ranges | Registry resolution errors | `"0.5-0.5"` then `"0.6-0"`, never `"0.5-0"` overlapping `"0.6-0"` |
| Forget `Pkg.Registry.update()` | Old version installed | Always update registry before testing |
| Forget Libdl/stdlib in Deps.toml | Package fails to load | Stdlibs with UUIDs still need Deps.toml entries |
