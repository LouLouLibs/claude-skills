---
name: xlset
description: Modify cells in Excel (.xlsx) files using xlset. Use when the user asks to edit, update, change, or write values to an Excel spreadsheet, or when you need to programmatically update cells in an xlsx file.
---

# xlset — Excel Cell Writer

Modify cells in existing .xlsx files. Preserves formatting, formulas,
and all structure it doesn't touch.

## Quick Reference

```bash
# Set a single cell
xlset file.xlsx A1=42

# Set multiple cells
xlset file.xlsx A1=42 B2="hello world" C3=true

# Force type with tag (e.g., preserve leading zero)
xlset file.xlsx A1:str=07401

# Target a specific sheet
xlset file.xlsx --sheet Revenue A1=42

# Write to a new file (don't modify original)
xlset file.xlsx --output new.xlsx A1=42

# Bulk update from CSV
xlset file.xlsx --from updates.csv

# Bulk from stdin
echo "A1,42" | xlset file.xlsx --from -
```

## Type Inference

Values are auto-detected:
- `42` → integer, `3.14` → float
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

Standard RFC 4180 quoting for values with commas: `A1,"hello, world"`

## Exit Codes

| Code | Meaning           |
|------|-------------------|
| 0    | Success           |
| 1    | Runtime error     |
| 2    | Invalid arguments |

## Workflow

1. Use `xlcat file.xlsx` first to see current content
2. Use `xlset` to modify cells
3. Use `xlcat` again to verify changes
