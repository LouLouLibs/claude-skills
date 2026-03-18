---
name: xldiff
description: Use when the user asks to compare, diff, or find differences between two Excel spreadsheets or sheets within a spreadsheet. Also use when the user mentions xlsx diff, spreadsheet comparison, or wants to know what changed between two Excel files.
---

# xldiff — Excel Sheet Comparison

Compare two Excel sheets and report added, removed, and modified rows.

## Quick Reference

```bash
# Compare two files (first sheet, positional mode)
xldiff old.xlsx new.xlsx

# Compare by key column
xldiff old.xlsx new.xlsx --key ID

# Composite key
xldiff old.xlsx new.xlsx --key Date,Ticker

# Compare specific sheets in the same file
xldiff data.xlsx:Sheet1 data.xlsx:Sheet2

# Select sheet by name or 0-based index
xldiff file.xlsx:Sales other.xlsx:Revenue

# Skip metadata rows (3 in file1, 5 in file2)
xldiff file1.xlsx file2.xlsx --skip 3,5

# Float tolerance (differences <= 0.01 treated as equal)
xldiff old.xlsx new.xlsx --key ID --tolerance 0.01

# Only compare specific columns
xldiff old.xlsx new.xlsx --key ID --cols Name,Score

# Output formats
xldiff old.xlsx new.xlsx --format markdown
xldiff old.xlsx new.xlsx --key ID --format json
xldiff old.xlsx new.xlsx --format csv
```

## Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `--key <cols>` | *(none)* | Row identity columns (name or column letter), comma-separated |
| `--cols <cols>` | all | Columns to compare (key columns always included) |
| `--skip <n>[,m]` | `0` | Rows to skip before header row |
| `--tolerance <f>` | *(none)* | Numeric tolerance for float comparisons |
| `--format` | `text` | `text`, `markdown`, `json`, or `csv` |
| `--no-color` | false | Force-disable ANSI colors (auto-detected) |

## Diff Modes

**Positional (default, no `--key`):** Every column defines identity. Rows match exactly or differ. Reports added/removed only.

**Key-based (`--key` specified):** Match rows by key columns, compare remaining columns cell by cell. Reports added, removed, and modified with per-cell old/new values. Tolerance applies only in this mode.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No differences |
| 1 | Differences found |
| 2 | Error |

## Workflow

1. Identify the two files (or file + two sheets) to compare
2. Use `--key` if rows have a natural identity column (ID, date, etc.)
3. Use `--tolerance` for financial/scientific data with float rounding
4. Use `--cols` to ignore noisy columns (timestamps, audit fields)
5. Use `--format json` for structured output, `--format markdown` for LLM consumption

## Common Patterns

**What changed between these files:**
```bash
xldiff old.xlsx new.xlsx --key ID
```

**Compare two tabs in the same workbook:**
```bash
xldiff file.xlsx:Q1 file.xlsx:Q2
```

**Ignore small rounding differences:**
```bash
xldiff old.xlsx new.xlsx --key ID --tolerance 0.001
```

**Pipe structured results for further processing:**
```bash
xldiff a.xlsx b.xlsx --key ID --format json | jq '.modified'
```
