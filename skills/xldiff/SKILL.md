---
name: xldiff
description: Use when the user asks to compare, diff, or find differences between two Excel spreadsheets or sheets within a spreadsheet. Also use when the user mentions xlsx diff, spreadsheet comparison, or wants to know what changed between two Excel files.
---

# xldiff

Diff two Excel sheets using `go-xldiff`.

## Quick Reference

```bash
# Compare two files (first sheet, positional mode)
go-xldiff old.xlsx new.xlsx

# Compare by key column
go-xldiff old.xlsx new.xlsx --key ID

# Composite key
go-xldiff old.xlsx new.xlsx --key Date,Ticker

# Compare specific sheets in the same file
go-xldiff data.xlsx:Sheet1 data.xlsx:Sheet2

# Select sheet by name or 0-based index
go-xldiff file.xlsx:Sales other.xlsx:Revenue

# Skip metadata rows (3 in file1, 5 in file2)
go-xldiff file1.xlsx file2.xlsx --skip 3,5

# JSON output for further processing
go-xldiff old.xlsx new.xlsx --key ID --format json

# CSV output
go-xldiff old.xlsx new.xlsx --format csv

# No headers in the sheets
go-xldiff old.xlsx new.xlsx --no-header
```

## Flags

| Flag              | Default       | Purpose                                                        |
|-------------------|---------------|----------------------------------------------------------------|
| `--key <cols>`    | all columns   | Row identity columns (name or 0-based index), comma-separated  |
| `--skip <n>[,m]`  | `0`           | Rows to skip before header row                                 |
| `--format`        | `text`        | `text`, `json`, or `csv`                                       |
| `--no-header`     | false         | First row is data, not headers                                 |
| `--no-color`      | false         | Strip ANSI codes                                               |

## Diff Modes

**Positional (default, no `--key`):** Every column defines identity. Rows match exactly or differ. Reports added/removed only.

**Key-based (`--key` specified):** Match rows by key columns, compare remaining columns cell by cell. Reports added, removed, and modified with per-cell old/new values.

## Exit Codes

| Code | Meaning              |
|------|----------------------|
| 0    | No differences       |
| 1    | Differences found    |
| 2    | Error                |

## How to Use This Skill

1. Identify the two files (or file + two sheets) the user wants compared
2. Ask which columns identify a row if not obvious (use `--key`)
3. Ask about skip rows if the user mentions headers/metadata at the top
4. Run the command and present results
5. If the user wants structured output for further processing, use `--format json`

## Common Patterns

**User says "what changed between these files":**
```bash
go-xldiff old.xlsx new.xlsx --key ID --no-color
```

**User says "compare these two tabs":**
```bash
go-xldiff file.xlsx:Tab1 file.xlsx:Tab2 --no-color
```

**User wants to pipe results to jq or another tool:**
```bash
go-xldiff a.xlsx b.xlsx --key ID --format json
```
