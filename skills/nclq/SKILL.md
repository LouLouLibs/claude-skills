---
name: nclq
description: Query, filter, inspect, and extract data from Nickel (.ncl) files using nclq. Use when the user asks to look at, count, filter, search, or analyze data inside .ncl files, or when you encounter a .ncl file and need to understand its contents.
---

# nclq — Nickel Query Tool

Query nickel files using nickel expressions. Top-level fields are automatically in scope — no import boilerplate needed.

## Quick Reference

```bash
# View a file (auto-detect: no expression needed)
nclq data.ncl
nclq data.ncl --compact

# Single file — fields in scope
nclq '<expr>' file.ncl

# Multi-file — named bindings
nclq '<expr>' -f name1=file1.ncl -f name2=file2.ncl

# Stdin
... | nclq '<expr>'

# Count rows
nclq 'rows' data.ncl --count

# Filter rows (type auto-detected from data)
nclq 'rows' data.ncl --where 'score>10'
nclq 'rows' data.ncl --where agg_level=1 --where 'description~Revenue'

# Sort
nclq 'rows' data.ncl --sort-by score --desc --limit 3

# Unique values of a field
nclq 'rows' data.ncl --unique category

# Inspect structure
nclq data.ncl --list-fields
nclq data.ncl --list-fields --depth 3

# Project fields
nclq 'rows' data.ncl --fields id,name

# Limit output
nclq 'rows' data.ncl --limit 5

# JSON output
nclq 'rows' data.ncl --format json

# Raw string (no quotes)
nclq 'metadata' data.ncl --raw

# Compact single-line output
nclq 'std.array.first rows' data.ncl --compact

# Combined pipeline
nclq 'rows' data.ncl --where agg_level=1 --sort-by cogcs --fields cogcs,description --limit 10

# Cross-reference two files
nclq 'a.rows |> std.array.filter (fun r =>
       std.array.elem r.id (b.codes |> std.array.map (fun c => c.id)))' \
  -f a=data.ncl -f b=codes.ncl
```

## Flags

| Flag                                    | Purpose                                                        |
|-----------------------------------------|----------------------------------------------------------------|
| `--format <nickel\|json\|yaml\|toml>`   | Output format (default: nickel)                                |
| `--fields <f1,f2,...>`                  | Project only named fields from results                         |
| `--limit <N>`                           | Truncate arrays to first N elements                            |
| `--raw`                                 | Strip quotes from string output                                |
| `--compact`                             | Single-line output                                             |
| `-f <NAME>=<FILE>`                      | Bind a file to a name (multi-file mode)                        |
| `--where <CONDITION>`                   | Filter: field=val, field>val, field~substr (repeatable, ANDed) |
| `--sort-by <FIELD>`                     | Sort by field (type auto-detected from data)                   |
| `--desc`                                | Descending sort (use with --sort-by)                           |
| `--unique <FIELD>`                      | Extract unique values of a field                               |
| `--count`                               | Return count instead of data                                   |
| `--list-fields`                         | List field names of the result                                 |
| `--depth <N>`                           | Depth for --list-fields (default: 1)                           |

## Pipeline Order

When multiple flags are combined, they apply in this fixed order regardless of CLI position:

**where → sort-by → unique → fields → limit → count**

`--list-fields` is a separate inspection mode (only `--where` composes with it).

## Exit Codes

| Code | Meaning                                         |
|------|--------------------------------------------------|
| 0    | Success                                          |
| 1    | Nickel evaluation error (stderr passed through)  |
| 2    | Invalid arguments / usage error                  |
| 127  | `nickel` not found on `$PATH`                    |

## Workflow

1. Inspect file structure: `nclq data.ncl --list-fields` or `--list-fields --depth 2`
2. Count rows: `nclq 'rows' data.ncl --count`
3. Filter: `nclq 'rows' data.ncl --where 'score>10'`
4. Project and limit: `--fields id,name --limit 10`
5. Use `--format json` when piping to `jq` or other tools
6. For complex queries, write the nickel expression directly

## Key Notes

- The expression is **standard nickel** — use `std.array.filter`, `std.array.map`, `|>`, etc.
- Use `nclq` instead of `nickel export | jq` — it's shorter and stays in the nickel world
- `nclq file.ncl` with no expression just dumps the file (defaults to `_file`)
- In single-file mode, top-level fields are bound directly (e.g., `rows`, `metadata`)
- In multi-file mode, access fields through the binding name (e.g., `data.rows`)
- `_file` is always available as the raw imported record in single-file mode
- `--where` auto-detects value types from data (numbers, strings, bools, enums)
- `--where` operators: `=` `!=` `>` `<` `>=` `<=` `~` (contains)
- Check for optional fields with `std.record.has_field "field_name" record`
