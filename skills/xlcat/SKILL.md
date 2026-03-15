---
name: xlcat
description: View and analyze Excel (.xls/.xlsx) files using xlcat. Use when the user asks to open, view, inspect, read, or analyze an Excel spreadsheet, or when you encounter an .xls or .xlsx file that needs to be examined.
---

# xlcat — Excel File Viewer

View and analyze Excel files at the command line. Outputs structured, LLM-friendly markdown.

## Quick Reference

```bash
# Overview: metadata + schema + first/last 25 rows
xlcat file.xlsx

# Column names and types only
xlcat file.xlsx --schema

# Summary statistics per column
xlcat file.xlsx --describe

# View a specific sheet (name or 0-based index)
xlcat file.xlsx --sheet Revenue
xlcat file.xlsx --sheet 0

# First N rows
xlcat file.xlsx --head 10

# Last N rows
xlcat file.xlsx --tail 10

# First N + last M rows
xlcat file.xlsx --head 10 --tail 5

# All rows (overrides size limit)
xlcat file.xlsx --all

# Raw CSV output for piping
xlcat file.xlsx --csv

# Override large-file threshold (default 1MB)
xlcat file.xlsx --max-size 5M
```

## Default Behavior

- **Single sheet, <=50 rows:** shows all data
- **Single sheet, >50 rows:** shows first 25 + last 25 rows
- **Multiple sheets:** lists all sheets with schemas, no data (use `--sheet` to pick one)
- **Large file (>1MB):** shows schema + first 25 rows only

## Flags

| Flag                    | Purpose                                                          |
|-------------------------|------------------------------------------------------------------|
| `--schema`              | Column names and types only                                      |
| `--describe`            | Summary statistics (count, mean, std, min, max, median, unique)  |
| `--head N`              | First N rows                                                     |
| `--tail N`              | Last N rows                                                      |
| `--all`                 | All rows (overrides large-file gate)                             |
| `--sheet <name\|index>` | Select sheet by name or 0-based index                            |
| `--max-size <size>`     | Large-file threshold (default: 1M). Accepts: 500K, 1M, 10M, 1G  |
| `--csv`                 | Output as CSV instead of markdown                                |

## Exit Codes

| Code | Meaning                                 |
|------|-----------------------------------------|
| 0    | Success                                 |
| 1    | Runtime error (file not found, corrupt) |
| 2    | Invalid arguments                       |

## Workflow

1. Start with `xlcat <file>` to get the overview
2. For multi-sheet files, pick a sheet with `--sheet`
3. Use `--describe` for statistical analysis
4. Use `--head`/`--tail` to zoom into specific regions
5. Use `--csv` when you need to pipe data to other tools

## Modes Are Mutually Exclusive

`--schema`, `--describe`, and data mode (default) cannot be combined. Row selection flags (`--head`, `--tail`, `--all`) only work in data mode.

## How to Use This Skill

When the user wants to examine an Excel file:

1. Run `xlcat <file>` to see the overview (sheets, schema, sample data)
2. If multi-sheet, ask which sheet interests them or use `--sheet`
3. For data analysis questions, use `--describe` for statistics
4. For specific rows, use `--head N` / `--tail N`
5. If the user needs the data for further processing, use `--csv`
