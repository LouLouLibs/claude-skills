# Design: replace the nightly cron with a Snakemake rule

**Status:** draft · **Owner:** data team · **Date:** 2026-09-01

The nightly refresh is a cron job that shells out to three scripts in sequence. This note proposes folding it into the pipeline so it is retried and logged like every other step.[^why]

[^why]: The cron job failed silently twice in August; nobody noticed for a week. See the incident log for 2026-08-12.

## Problem

The cron job has no dependency tracking, so a partial failure leaves stale parquet files behind.

### What breaks today

| Failure | Symptom |
|---|---|
| Script 2 dies | Script 3 runs on yesterday's input |
| Disk full | Empty parquet written, downstream reads zero rows |

## Proposal

One rule per script, chained by file dependencies.

```python
rule refresh_prices:
    input: "raw/prices.csv"
    output: "out/prices.parquet"
    shell: "python scripts/refresh.py {input} {output}"
```

- [ ] Agree on the retry count
- [ ] Decide whether to keep the cron as a fallback
