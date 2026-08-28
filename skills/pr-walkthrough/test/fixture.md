# PR #42 — Replace ad-hoc CSV parser with `CSV.File`

**Issue:** [#41](https://github.com/example/repo/issues/41) · **PR:** [#42](https://github.com/example/repo/pull/42) · **Branch:** `feat/csv-file` · **Date:** 2026-08-27

A refactor with guards: the hand-rolled line splitter in `ingest.jl` is replaced by `CSV.File`, and a byte-identity check over the 2019–2024 vintages proves the parquet outputs do not move. The one thing that needs a human is the quoting rule for embedded commas.[^why-now]

[^why-now]: The old parser was written before `CSV.jl` handled UTF-8 BOMs correctly (2021). It has been "temporary" for five years; see the discussion on [#41](https://github.com/example/repo/issues/41#issuecomment-1).

## TL;DR — what to know before approving

- **Size.** 6 files, +212 / −340. Only `ingest.jl` and `test/ingest_test.jl` are substantive; the rest is deletion of the old splitter and fixtures.
- **The guarantee.** Parquet outputs for every vintage are byte-identical before and after (`sha256sum`, 12/12 match).
- **The catch.** Rows with an embedded comma inside quotes were previously split wrong; the new parser is *correct*, which changes 3 rows in the 2022 file.[^three-rows]
- **Where to look.** The quoting section below.

[^three-rows]: The 2022 vintage ships 3 municipality names containing a comma (`"Winston-Salem, City of"`). The old splitter produced 27 columns for those rows and dropped the tail silently. Verified with `rg -c '"[^"]*,[^"]*"' data/raw/2022.csv` → `3`.

## The safety contract (and how it was verified)

Byte identity over the full sample, except for the 3 rows discussed below, which were diffed by hand.

```bash
for y in 2019 2020 2021 2022 2023 2024; do
  sha256sum out/main/$y.parquet out/branch/$y.parquet
done
# 12 lines, 6 matching pairs
```

> **Why this matters for your review:** you do **not** need to re-derive output stability; it's proven. Spend your attention on the quoting rule.

## The nuance to scrutinize 🔍

### Quoted commas are now honoured

```julia
# BEFORE
fields = split(line, ',')
```

```julia
# AFTER
rows = CSV.File(path; quotechar='"', escapechar='"')
```

**What to confirm:** that the 3 corrected rows in 2022 are *supposed* to be single municipalities rather than two records. The upstream codebook says yes.[^codebook]

[^codebook]: Census of Governments 2022 Technical Documentation, §4.2: "Names are quoted where they contain the field delimiter." The relevant page is archived in `docs/refs/cog-2022-techdoc.pdf`, p. 31.

### `@assert` downgraded to `@warn` on column count

```diff
@@ -41,3 +41,3 @@ function ingest(path)
-@assert length(fields) == 26
+length(row) == 26 || @warn "unexpected column count" file=path n=length(row)
 push!(out, row)
```

**What to confirm:** that a warning is acceptable here, since the pipeline now fails later (at the schema check) instead of at parse time.

## The discovery: 2021 has a trailing empty column

The 2021 raw file has a trailing comma on every line, so `CSV.File` reads 27 columns. The PR drops the empty column with `select=1:26`; fixing the raw file belongs in the data-refresh PR.

| vintage | raw columns | after select |
|---|---|---|
| 2020 | 26 | 26 |
| 2021 | 27 | 26 |
| 2022 | 26 | 26 |

## The rest of the changes (lower-risk, by theme)

### Delete the old splitter

`src/legacy_split.jl` and its 4 fixtures are removed; nothing else referenced them (`rg legacy_split` → only the deleted files).

### Test coverage

`test/ingest_test.jl` gains a case for quoted commas and one for the 2021 trailing column.

## Suggested approval checklist

- [ ] The 3 corrected 2022 rows are single municipalities (see the codebook note).
- [ ] `@warn` instead of `@assert` on column count is acceptable.
- [ ] Comfortable deferring the raw-file fix for 2021.

If all three sit right, this is a clean merge because outputs are byte-identical everywhere else.

## Deferred (recorded, not in this PR)

- **Fix the 2021 raw file** — tracked in [#43](https://github.com/example/repo/issues/43).
