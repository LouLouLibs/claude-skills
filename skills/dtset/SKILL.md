---
name: dtset
description: Modify cells in Excel (.xlsx/.xlsm) files using dtset. Use when the user asks to edit, update, change, or write values to an Excel spreadsheet, or when you need to programmatically update cells in an xlsx file.
---

# dtset — Excel Cell Writer (alpha)

Modify cells in existing .xlsx/.xlsm files. Preserves formatting, formulas,
and all structure it doesn't touch. Saves atomically, so a failed write never
corrupts the original.

**Only .xlsx and .xlsm.** Other formats (CSV, Parquet, JSON, `.xls`, `.ods`)
are rejected with exit code 2; there is no dt tool that edits them in place.

**Alpha build.** dtset is not in the dt-cli-tools release binaries. If
`command -v dtset` finds nothing, install it from a dt-cli-tools checkout:
`cargo install --path . --features alpha`.

## Quick Reference

```bash
# Set a single cell
dtset file.xlsx A1=42

# Set multiple cells
dtset file.xlsx A1=42 B2="hello world" C3=true

# Force type with tag (e.g., preserve leading zero)
dtset file.xlsx A1:str=07401

# Target a specific sheet (name or 0-based index)
dtset file.xlsx --sheet Revenue A1=42

# Write to a new file (don't modify original)
dtset file.xlsx -o new.xlsx A1=42

# Bulk update from CSV
dtset file.xlsx --from updates.csv

# Bulk from stdin
echo "A1,42" | dtset file.xlsx --from -
```

## Type Inference

Values are auto-detected:
- `42` → integer, `3.5` → float
- `true`/`false` → boolean
- `2024-01-15` → date
- Everything else → string

Override with tags: `:str`, `:num`, `:bool`, `:date`

## CSV Format

```csv
cell,value
A1,42
B2,hello
C3:str,07401
```

The header row is optional. Standard RFC 4180 quoting for values with commas: `A1,"hello, world"`

## Exit Codes

| Code | Meaning                                         |
|------|-------------------------------------------------|
| 0    | Success                                         |
| 1    | Runtime error (file not found, unreadable, ...) |
| 2    | Invalid arguments (bad cell ref, non-xlsx file) |

## Workflow

1. Use `dtcat file.xlsx` first to see current content (`--sheet` for other sheets)
2. Use `dtset` to modify cells
3. Use `dtcat` again to verify changes
