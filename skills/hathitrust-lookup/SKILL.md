---
name: hathitrust-lookup
description: Look up books and serials in the HathiTrust Digital Library by identifier (OCLC, LCCN, ISBN, ISSN, HathiTrust id, or catalog record number) and list each digitized item's reading-room URL and access status. Use when the user has an identifier (or a citation/MARC record containing one) and wants HathiTrust metadata, availability, or a link to read/search a volume. Note: this is identifier lookup, not keyword search.
allowed-tools: Bash(ht-lookup *), Read, Grep
argument-hint: <idtype> <id> [<idtype> <id> ...]
---

# hathitrust-lookup — HathiTrust catalog lookup

Resolve identifiers to HathiTrust catalog records using the `ht-lookup` CLI,
a thin client over the [HathiTrust Bibliographic
API](https://catalog.hathitrust.org/api/volumes/). For each record it prints
the title, identifiers, publish dates, and the list of digitized **items**
(volumes) — each with its HathiTrust id (`htid`), reading-room URL, and US
access status (`Full view` vs `Limited (search-only)`).

```bash
ht-lookup oclc 424023
ht-lookup isbn 9780030110405 lccn 62009520     # batch, up to 20 ids
ht-lookup --json --full recordnumber 000578050  # raw JSON incl. MARC-XML
```

## Scope — read this first

This is **identifier lookup, not keyword/full-text search.** HathiTrust does
not expose its catalog free-text search as an open API (the search pages sit
behind a bot challenge), and the page-content **Data API was retired in July
2024**. So you cannot script "find books about X" here.

To go from a title/author to an identifier: have the user search the catalog
in a browser at <https://catalog.hathitrust.org>, then pass back the OCLC
number or record number. Citations, library catalog entries, and MARC records
usually already carry an OCLC/LCCN/ISBN you can feed straight in.

For bulk text mining (the "research datasets" that replaced the old API), point
the user to the [HathiTrust Research Center](https://www.hathitrust.org/the-htrc/)
(Extracted Features dataset, Data Capsules) — out of scope for this skill.

## Install

Check `command -v ht-lookup` first. If missing, download the release binary
(the repo is public — no token needed):

```bash
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/ht-lookup \
  "https://github.com/LouLouLibs/claude-skills/releases/latest/download/ht-lookup-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
chmod +x ~/.local/bin/ht-lookup
```

Assets: `ht-lookup-linux-x86_64` (static musl — runs on any Linux, including
NixOS microVM guests) and `ht-lookup-darwin-arm64`. Runtime requirement:
`curl` on PATH (HTTPS is delegated to it).

## Usage

```
ht-lookup [--full] [--json] <idtype> <id> [<idtype> <id> ...]
```

| | |
|---|---|
| `idtype` | one of `oclc`, `lccn`, `issn`, `isbn`, `htid`, `recordnumber` |
| `--full` | request full MARC records (adds MARC-XML; pair with `--json`) |
| `--json` | print the raw API JSON instead of the formatted view |

Up to 20 identifiers per call (the API's batch limit). Mixed id types in one
call are fine.

### Reading the output

```
Infinite series (1962)
  record:  https://catalog.hathitrust.org/Record/000578050
  oclc:    424023
  lccn:    62009520
  items (2):
    [Limited (search-only)] mdp.39015025315527  University of Michigan
        https://babel.hathitrust.org/cgi/pt?id=mdp.39015025315527
```

- **`[Full view]`** — the full text is readable online at the item URL.
- **`[Limited (search-only)]`** — in-copyright; only page-level search is
  public. The item URL still opens the (limited) viewer.
- For serials/multi-volume sets each item is tagged with its enumeration in
  brackets, e.g. `[v.2 1881]`. These records can list **many** items — use
  `--json` and pipe through `jq` to filter, e.g. only Full-view volumes:

  ```bash
  ht-lookup --json oclc 6412936 \
    | jq -r '.[].items[] | select(.usRightsString | startswith("Full")) | .htid'
  ```

## Notes

- No API key or authentication is needed; the API is public and unauthenticated.
- An unknown identifier prints `<query>: no record found` and still exits 0.
- `HT_API_BASE` overrides the API base URL (used by the test harness).
