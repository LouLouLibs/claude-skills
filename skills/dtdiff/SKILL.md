---
name: dtdiff
description: Use when the user asks to compare, diff, or find differences between two tabular data files (CSV, TSV, Parquet, Arrow, JSON, NDJSON, Excel). Also use when the user mentions data diff, file comparison, or wants to know what changed between two data files of the same format.
---

# dtdiff — Tabular Data Comparison

Compare two tabular data files of the same format and report added, removed, and modified rows.

## Quick Reference

```bash
# Compare two CSV files (positional mode)
dtdiff old.csv new.csv

# Compare by key column
dtdiff old.parquet new.parquet --key ID

# Composite key
dtdiff old.csv new.csv --key Date,Ticker

# Float tolerance (differences <= 0.01 treated as equal)
dtdiff old.csv new.csv --key ID --tolerance 0.01

# JSON output for structured processing
dtdiff old.csv new.csv --key ID --json

# CSV output
dtdiff old.csv new.csv --key ID --csv

# Compare Excel sheets
dtdiff old.xlsx new.xlsx --sheet Revenue --key ID

# Override format (e.g., .txt files that are CSV)
dtdiff a.txt b.txt --format csv

# Disable color
dtdiff old.csv new.csv --no-color
```

## Same-Format Requirement

Both files must be the same format. CSV and TSV are treated as the same family and can be compared. Comparing a CSV to a Parquet will error.

## Diff Modes

**Positional (default, no `--key`):** Every column defines identity. Rows match exactly or differ. Reports added/removed only.

**Key-based (`--key` specified):** Match rows by key columns, compare remaining columns cell by cell. Reports added, removed, and modified with per-cell old/new values.

## Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `--format <fmt>` | auto | Override format detection (applies to both files) |
| `--sheet <name\|idx>` | first | Select sheet (Excel only) |
| `--key <cols>` | *(none)* | Key columns for matching (comma-separated names) |
| `--tolerance <f>` | `1e-10` | Float comparison tolerance |
| `--json` | false | Output as JSON |
| `--csv` | false | Output as CSV |
| `--no-color` | false | Disable ANSI colors |

## Exit Codes (diff convention)

| Code | Meaning |
|------|---------|
| 0 | No differences |
| 1 | Differences found |
| 2 | Error |

## Workflow

1. Identify the two files to compare (must be same format)
2. Use `--key` if rows have a natural identity column (ID, date, etc.)
3. Use `--tolerance` for financial/scientific data with float rounding
4. Use `--json` for structured output, default text for quick review

## Common Patterns

**What changed between versions:**
```bash
dtdiff old.csv new.csv --key ID
```

**Ignore small rounding differences:**
```bash
dtdiff old.parquet new.parquet --key ID --tolerance 0.001
```

**Pipe structured results for processing:**
```bash
dtdiff a.csv b.csv --key ID --json | jq '.modified'
```
