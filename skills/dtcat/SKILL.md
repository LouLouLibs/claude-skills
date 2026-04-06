---
name: dtcat
description: View and analyze tabular data files (CSV, TSV, Parquet, Arrow/Feather, JSON, NDJSON, Excel) using dtcat. Use when the user asks to open, view, inspect, read, or analyze a data file in any of these formats, or when you encounter such a file that needs to be examined. Also use when converting between formats.
---

# dtcat — Tabular Data File Viewer

View and analyze tabular data files at the command line. Supports CSV, TSV, Parquet, Arrow/Feather, JSON, NDJSON, and Excel. Outputs structured, LLM-friendly markdown.

## Quick Reference

```bash
# Auto-detect format and show overview
dtcat data.csv
dtcat data.parquet
dtcat data.arrow
dtcat data.json
dtcat report.xlsx

# Column names and types only
dtcat data.parquet --schema

# Summary statistics per column
dtcat data.csv --describe

# File metadata (size, format, shape, sheets)
dtcat report.xlsx --info

# View a specific sheet (Excel only)
dtcat report.xlsx --sheet Revenue

# First/last N rows
dtcat data.csv --head 10
dtcat data.csv --tail 10

# Show all rows (override adaptive limit)
dtcat data.csv --all

# Random sample of rows
dtcat huge.parquet --sample 20
dtcat huge.parquet --sample 50 --csv

# Raw CSV output for piping
dtcat data.parquet --csv

# Convert between formats
dtcat data.csv --convert parquet -o data.parquet
dtcat report.xlsx --sheet Revenue --convert csv -o revenue.csv
dtcat data.parquet --convert ndjson              # text formats go to stdout

# Override format detection
dtcat data.txt --format csv

# Skip metadata rows above header
dtcat data.csv --skip 2
```

## Supported Formats

| Format | Extensions | Auto-detected |
|--------|-----------|---------------|
| CSV | .csv | Yes (magic + extension) |
| TSV | .tsv, .tab | Yes |
| Parquet | .parquet, .pq | Yes (PAR1 magic) |
| Arrow/Feather | .arrow, .feather, .ipc | Yes (ARROW1 magic) |
| JSON | .json | Yes ([ prefix) |
| NDJSON | .ndjson, .jsonl | Yes ({ prefix) |
| Excel | .xlsx, .xls, .xlsb, .ods | Yes (PK/OLE magic) |

Detection priority: `--format` flag > magic bytes > file extension.

## Default Behavior

- **<=50 rows:** shows all data
- **>50 rows:** shows first 25 + last 25 rows
- **Excel, multiple sheets:** lists all sheets with schemas (use `--sheet` to pick one)

## Flags

| Flag | Purpose |
|------|---------|
| `--format <fmt>` | Override format detection (csv, tsv, parquet, arrow, json, ndjson, excel) |
| `--sheet <name\|index>` | Select sheet by name or 0-based index (Excel only) |
| `--skip <n>` | Skip first N rows before header |
| `--schema` | Column names and types only |
| `--describe` | Summary statistics (count, mean, std, min, max, median, unique) |
| `--head <n>` | First N rows |
| `--tail <n>` | Last N rows |
| `--all` | Show all rows (override adaptive limit) |
| `--sample <n>` | Randomly sample N rows |
| `--csv` | Output as CSV instead of markdown |
| `--info` | File metadata (size, format, shape, sheets) |
| `--convert <fmt>` | Convert to format (csv, tsv, parquet, arrow, json, ndjson) |
| `-o <path>` | Output file path (required for binary formats with --convert) |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error (file not found, corrupt) |
| 2 | Invalid arguments |

## Workflow

1. Run `dtcat <file>` to see the overview (schema + sample data)
2. For Excel multi-sheet files, pick a sheet with `--sheet`
3. Use `--describe` for statistical analysis
4. Use `--head`/`--tail` to zoom into specific regions, `--sample` for random rows
5. Use `--csv` when you need to pipe data to other tools
6. Use `--convert` to transform between formats (e.g., CSV to Parquet)

## Mutual Exclusivity

- `--schema`, `--describe`, `--info`, `--csv`, `--convert` are mutually exclusive with each other
- `--sample` is mutually exclusive with `--head`, `--tail`, `--all`
- `--convert` is mutually exclusive with all display flags
