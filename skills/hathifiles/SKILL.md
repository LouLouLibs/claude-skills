---
name: hathifiles
description: List, download, and query the HathiTrust HathiFiles — tab-separated dumps describing every item in the HathiTrust Digital Library (~18M rows: htid, access/rights, OCLC/ISBN/ISSN/LCCN, title, language, format, provider codes, author). Use when the user wants bulk HathiTrust metadata, to build a local lookup table, or to find all volumes matching attributes (e.g. public-domain English serials). For looking up a single known identifier, use the hathitrust-lookup skill instead.
allowed-tools: Bash(hathifiles *), Bash(zcat *), Bash(gunzip *), Bash(awk *), Bash(dtfilter *), Bash(dtcat *), Read, Grep
argument-hint: list | fetch [--full|--update --date YYYYMMDD] | header | to-ndjson
---

# hathifiles — HathiTrust bulk metadata

The HathiFiles are HathiTrust's bulk metadata distribution: a monthly **full**
file with one row per item in the collection (~18M rows) plus daily **update**
deltas, all gzipped tab-separated values. The `hathifiles` CLI discovers and
downloads them and supplies the column schema (the data files have **no header
row**); querying is then done with the `dt` tools or `awk`.

```bash
hathifiles list                       # what's available (newest first)
hathifiles fetch                      # download the latest monthly full file
hathifiles fetch --date 20260601      # a specific monthly full file
hathifiles fetch --update --date 20260618
hathifiles header                     # the 26 column names (tab-separated)
hathifiles header --describe          # column names + descriptions
```

This is bulk **metadata**, not full text. For one known identifier →
metadata/links, use the **hathitrust-lookup** skill (the `ht_bib_key` and
`oclc_num` columns here feed straight into it). HathiTrust full text is not
openly available (see that skill's notes).

## Install

Check `command -v hathifiles` first. If missing, download the release binary
(the repo is public — no token needed):

```bash
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/hathifiles \
  "https://github.com/LouLouLibs/claude-skills/releases/latest/download/hathifiles-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
chmod +x ~/.local/bin/hathifiles
```

Assets: `hathifiles-linux-x86_64` (static musl) and `hathifiles-darwin-arm64`.
Runtime requirement: `curl` on PATH (HTTPS/download is delegated to it).
Querying additionally uses `zcat`/`gunzip` and, optionally, the
[dt-cli-tools](https://github.com/LouLouLibs/dt-cli-tools) (`dtcat`/`dtfilter`).

## Workflow

### 1. Pick and download a file

Run `hathifiles list` to see the current full and update files with sizes. The
monthly full file is large (~1.2 GB gzipped); downloads **resume** if
interrupted (re-run the same `fetch`). Update files (`hathi_upd_*`) are small
and hold only the last 24h of changes.

```bash
hathifiles fetch                      # -> prints the downloaded path
```

### 2. Query

The `.gz` is tab-separated with **no header** and **no quoting**, and titles
contain raw `"` characters — which breaks readers that infer column types or
honour quotes (including `dtcat`/`dtfilter`). Two reliable paths:

**A. dt tools — convert to NDJSON first** (every field becomes a string, so no
type-inference or quoting surprises). Best for repeated/structured queries:

```bash
zcat hathi_full_20260601.txt.gz | hathifiles to-ndjson > hf.ndjson
dtfilter hf.ndjson --filter 'rights=pd' --filter 'lang=eng' --filter 'bib_fmt=BK' \
  --columns htid,title,oclc_num --limit 20

# For many queries over the full file, convert once to parquet (fast, typed):
dtcat hf.ndjson --convert parquet -o hf.parquet
dtfilter hf.parquet --filter 'access=allow' --columns htid,title
```

**B. awk on the raw TSV** — lightest, streams the gzip, no intermediate file.
Use column *positions* (see `hathifiles header` for the order):

```bash
# public-domain English books -> htid (col 1), title (col 12)
zcat hathi_full_20260601.txt.gz \
  | awk -F'\t' '$3=="pd" && $19=="eng" && $20=="BK" {print $1"\t"$12}'
```

### Column reference

`hathifiles header --describe` prints all 26 columns. The most useful:

| # | Column | Notes |
|---|--------|-------|
| 1 | `htid` | volume id — opens at `babel.hathitrust.org/cgi/pt?id=<htid>` |
| 2 | `access` | `allow` / `deny` (full text viewable in the US) |
| 3 | `rights` | `pd` public domain, `ic` in-copyright, `und` undetermined, … |
| 4 | `ht_bib_key` | catalog record number → `ht-lookup recordnumber <key>` |
| 8 | `oclc_num` | OCLC number(s) → `ht-lookup oclc <num>` |
| 12 | `title` | |
| 16 | `us_gov_doc_flag` | `1` = US federal government document |
| 19 | `lang` | MARC language code (`eng`, `ger`, …) |
| 20 | `bib_fmt` | `BK` book, `SE` serial, … |

## Notes

- No API key or authentication is needed; the files are public.
- Update files are deltas, not cumulative — for a complete snapshot start from a
  monthly full file and apply later `hathi_upd_*` files if you need currency.
- `HATHIFILES_BASE` overrides the download host (used by the test harness).
