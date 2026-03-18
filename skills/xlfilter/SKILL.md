---
name: xlfilter
description: Use when the user asks to filter, query, search, or extract specific rows or columns from an Excel spreadsheet. Also use when the user wants to sort spreadsheet data, find rows matching conditions, or select specific columns from an xlsx file.
---

# xlfilter — Excel Row/Column Filter

Filter, sort, and select data from Excel files. Outputs markdown tables or CSV.

## Quick Reference

```bash
# Filter rows where State equals CA
xlfilter file.xlsx --where State=CA

# Multiple filters (AND logic)
xlfilter file.xlsx --where State=CA --where Amount>1000

# Select specific columns
xlfilter file.xlsx --cols State,City,Amount

# Sort by column (ascending by default)
xlfilter file.xlsx --sort Amount
xlfilter file.xlsx --sort Amount:desc

# Limit output rows
xlfilter file.xlsx --where Status=Active --limit 10

# First/last N rows (before filtering)
xlfilter file.xlsx --head 20
xlfilter file.xlsx --tail 10

# Target a specific sheet
xlfilter file.xlsx --sheet Revenue --where Region=East

# Skip metadata rows above the real header
xlfilter file.xlsx --skip 2 --where Name~alice

# CSV output for piping
xlfilter file.xlsx --where Amount>500 --csv
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
| `--where <expr>` | Filter rows (repeatable, AND logic) |
| `--cols <cols>` | Select columns by name or letter (A,B,D) |
| `--sort <spec>` | Sort by column (`col` or `col:desc`) |
| `--limit <n>` | Max rows in output (after filtering) |
| `--head <n>` | First N rows (before filtering) |
| `--tail <n>` | Last N rows (before filtering) |
| `--sheet <name\|idx>` | Select sheet by name or 0-based index |
| `--skip <n>` | Skip metadata rows above header |
| `--csv` | Output as CSV instead of markdown |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error |
| 2 | Invalid arguments |

## Workflow

1. Use `xlcat file.xlsx` first to see schema and sample data
2. Use `--where` to filter rows by conditions
3. Use `--cols` to narrow to relevant columns
4. Use `--sort` to order results
5. Use `--csv` when piping to other tools
