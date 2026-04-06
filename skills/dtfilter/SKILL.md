---
name: dtfilter
description: Use when the user asks to filter, query, search, or extract specific rows or columns from a tabular data file (CSV, TSV, Parquet, Arrow, JSON, NDJSON, Excel). Also use when the user wants to sort data, find rows matching conditions, or select specific columns from any supported format.
---

# dtfilter — Tabular Data Filter

Filter, sort, and select data from any supported tabular file format. Outputs markdown tables or CSV.

## Quick Reference

```bash
# Filter rows where State equals CA
dtfilter data.csv --filter State=CA

# Multiple filters (AND logic)
dtfilter data.parquet --filter State=CA --filter Amount>1000

# Select specific columns
dtfilter data.csv --columns State,City,Amount

# Sort by column (ascending by default)
dtfilter data.csv --sort Amount
dtfilter data.csv --sort Amount:desc

# Limit output rows
dtfilter data.csv --filter Status=Active --limit 10

# First/last N rows (before filtering)
dtfilter data.csv --head 20
dtfilter data.csv --tail 10

# Target a specific sheet (Excel)
dtfilter report.xlsx --sheet Revenue --filter Region=East

# Skip metadata rows above header
dtfilter data.csv --skip 2 --filter Name~alice

# CSV output for piping
dtfilter data.parquet --filter Amount>500 --csv

# Override format detection
dtfilter data.txt --format csv --filter value>100
```

## Filter Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `=` | Equals | `State=CA` |
| `!=` | Not equals | `Status!=Draft` |
| `>` | Greater than | `Amount>1000` |
| `<` | Less than | `Year<2024` |
| `>=` | Greater or equal | `Score>=90` |
| `<=` | Less or equal | `Price<=50` |
| `~` | Contains (case-insensitive) | `Name~john` |
| `!~` | Not contains | `Name!~test` |

Numeric columns compare numerically. String columns compare lexicographically.

## Flags

| Flag | Purpose |
|------|---------|
| `--format <fmt>` | Override format detection |
| `--sheet <name\|idx>` | Select sheet (Excel only) |
| `--skip <n>` | Skip metadata rows above header |
| `--filter <expr>` | Filter rows (repeatable, AND logic) |
| `--sort <spec>` | Sort by column (`col` or `col:desc`) |
| `--columns <cols>` | Select columns by name (comma-separated) |
| `--head <n>` | First N rows (before filtering) |
| `--tail <n>` | Last N rows (before filtering) |
| `--limit <n>` | Max rows in output (after filtering) |
| `--csv` | Output as CSV instead of markdown |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error |
| 2 | Invalid arguments |

## Workflow

1. Use `dtcat file` first to see schema and sample data
2. Use `--filter` to filter rows by conditions
3. Use `--columns` to narrow to relevant columns
4. Use `--sort` to order results
5. Use `--csv` when piping to other tools
