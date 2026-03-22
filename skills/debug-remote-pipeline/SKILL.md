---
name: debug-remote-pipeline
description: Use when the user asks to debug, check, or diagnose a Snakemake pipeline on a remote cluster. Triggers on "why is the pipeline failing", "check the remote", "debug on cluster", "what's erroring on msi", or any request to investigate pipeline errors via SSH.
---

# Debug Remote Pipeline

Diagnose Snakemake pipeline failures on a remote cluster in two read-only SSH calls.
Collects evidence remotely, analyzes locally, presents a structured report.

**Strictly read-only** — no writes, no fixes, no snakemake execution on the remote.

## Assumptions

- `jq` and `bash` available on the remote host
- SSH config set up (host alias works, key auth)
- Remote OS is Linux
- `sacct`/`squeue` optional (gracefully skipped)

## Step 1: Resolve Inputs

Determine from conversation context, CLAUDE.md, or by asking:

1. **SSH host** (e.g., `msi-login`)
2. **Remote project directory** (e.g., `myscratch/munis_home/import_CoG`)

Display before proceeding:

```
Debugging remote pipeline:
  Host: <host>
  Directory: <dir>
```

## Step 2: Phase 1 — Discovery (one SSH call)

Run a single SSH command that collects three things as JSON:

1. **Most recent snakemake orchestrator log** (last 300 lines from `.snakemake/log/`)
2. **Rule log directory listing** (`ls -lt log/*.log`)
3. **SLURM job status** (last 24h via `sacct`, if available)

### Command template

**Single Bash command** — SSH + local jq split chained together so only ONE user
approval is needed. The jq split produces plain text files that Read/Grep can
parse without further Bash calls.

```bash
ssh HOST "cd DIR && bash -c '
  jq -n \
    --rawfile sm_log <({ ls -1t .snakemake/log/*.snakemake.log 2>/dev/null | head -1 | xargs -r tail -300; } || true; echo \"__END__\") \
    --rawfile log_listing <(ls -lt log/*.log 2>/dev/null || echo \"no log directory\") \
    --rawfile slurm <(sacct --format=JobID,JobName,State,ExitCode,Start,End,MaxRSS \
      --starttime \$(date --date=\"24 hours ago\" +%Y-%m-%d) -n 2>/dev/null || echo \"sacct unavailable\") \
    \"{snakemake_log: \\\$sm_log, log_listing: \\\$log_listing, slurm_status: \\\$slurm}\"
'" > /tmp/pipeline_diag_raw.json && \
  jq -r '.snakemake_log' /tmp/pipeline_diag_raw.json > /tmp/pipeline_diag_sm.txt && \
  jq -r '.log_listing' /tmp/pipeline_diag_raw.json > /tmp/pipeline_diag_listing.txt && \
  jq -r '.slurm_status' /tmp/pipeline_diag_raw.json > /tmp/pipeline_diag_slurm.txt
```

### Parse the result locally

**IMPORTANT — minimize user approvals**: The command above produces plain text
files split by field. Use **Read** and **Grep** tools (auto-approved) on these
files. Do NOT run additional Bash commands for parsing.

- `/tmp/pipeline_diag_sm.txt` — snakemake orchestrator log (multi-line text)
- `/tmp/pipeline_diag_listing.txt` — rule log directory listing
- `/tmp/pipeline_diag_slurm.txt` — SLURM job status

```
# Grep for rule status lines (auto-approved, no bash needed)
Grep pattern="Error in rule|Finished jobid" in /tmp/pipeline_diag_sm.txt
```

Parse the snakemake orchestrator log for `Error in rule RULE_NAME:` blocks.
Each block contains a `log:` field with the **exact path(s)** to that rule's
log file(s). Extract:

- Rule name
- Log file path(s) — use these verbatim in Phase 2 (do NOT guess paths from rule names)
- SLURM correlation (best-effort substring match of rule name in sacct JobName)

Also identify:
- Succeeded rules (`Finished jobid: N (Rule: NAME)`)
- Still-running rules (in SLURM queue but not in finished/error lists)

**Run timestamp**: Extract the log filename from the last line
(`Complete log(s): .../.snakemake/log/YYYY-MM-DDTHHMMSS....snakemake.log`)
to report which run is being diagnosed. Include this timestamp in the report header.

### Three log layers

When Snakemake runs via SLURM, there are **three** log locations:

1. **Snakemake orchestrator log** (`.snakemake/log/`) — rule scheduling, status, errors
2. **Rule logs** (from `log:` directive, e.g. `log/RULE_NAME.log`) — script stdout/stderr
3. **SLURM job logs** (`.snakemake/slurm_logs/rule_NAME/JOBID.log`) — SLURM wrapper
   output, useful for OOM kills and timeout diagnostics

The snakemake orchestrator log shows SLURM log paths in lines like:
`Job N has been submitted with SLURM jobid XXXXX (log: .snakemake/slurm_logs/...)`.
For failed rules, Phase 2 should also fetch these SLURM logs when present.

### Control flow

| Scenario                        | Action                                       |
|---------------------------------|----------------------------------------------|
| Failed rules found              | Show intermediate summary, proceed to Phase 2 |
| No failures, jobs still running | Report "pipeline in progress" — done          |
| No failures, all completed      | Report "pipeline succeeded" — done            |
| No snakemake log found          | Report "no recent run found" — done           |

### Intermediate output (show to user)

```
Found N failed rules: RULE_A, RULE_B, ...
M rules still running.
Fetching detailed logs...
```

## Step 3: Phase 2 — Log Collection (one SSH call)

For each failed rule (max 10), fetch:
- **Main log file(s)** — last 100 lines of each path from Phase 1
- **Sub-logs** — `{stem}_error.log` and `{stem}_warn.log` if they exist
  (stem = main log filename without `.log` extension)
- **SLURM job log** — last 50 lines of `.snakemake/slurm_logs/rule_NAME/JOBID.log`
  if the path was found in Phase 1 (useful for OOM/timeout diagnostics)

### Command construction

Build the `jq` command dynamically from Phase 1 results. Use the **exact log
paths** extracted from the snakemake log.

For each failed rule, add four `--rawfile` arguments:
- `rN_main` — `tail -100 <exact_path> 2>/dev/null || echo "log not found"`
- `rN_error` — `cat <stem>_error.log 2>/dev/null || echo ""`
- `rN_warn` — `cat <stem>_warn.log 2>/dev/null || echo ""`
- `rN_slurm` — `tail -50 <slurm_log_path> 2>/dev/null || echo ""` (if SLURM path found in Phase 1)

If a rule has multiple log paths (e.g., `["log/a.log", "log/b.log"]`),
concatenate them into a single main rawfile.

Wrap everything in `bash -c '...'` as in Phase 1.

### Example (2 failed rules)

**Single Bash command** — SSH + local jq split. One approval, then Read/Grep
on the plain text output files.

```bash
ssh HOST "cd DIR && bash -c '
  jq -n \
    --rawfile r1_main <(tail -100 log/STATE_FIN_INDFIN.log 2>/dev/null || echo \"log not found\") \
    --rawfile r1_error <(cat log/state_fin_indfin_error.log 2>/dev/null || echo \"\") \
    --rawfile r1_warn <(cat log/state_fin_indfin_warn.log 2>/dev/null || echo \"\") \
    --rawfile r2_main <(tail -100 log/stable_sample.log 2>/dev/null || echo \"log not found\") \
    --rawfile r2_error <(cat log/stable_sample_error.log 2>/dev/null || echo \"\") \
    --rawfile r2_warn <(cat log/stable_sample_warn.log 2>/dev/null || echo \"\") \
    \"{
      \\\"STATE_FIN_INDFIN\\\": {main: \\\$r1_main, error: \\\$r1_error, warn: \\\$r1_warn},
      \\\"COG_STABLE_SAMPLE\\\": {main: \\\$r2_main, error: \\\$r2_error, warn: \\\$r2_warn}
    }\"
'" > /tmp/pipeline_diag_phase2.json && \
  jq -r '.STATE_FIN_INDFIN.main' /tmp/pipeline_diag_phase2.json > /tmp/pipeline_diag_r1_main.txt && \
  jq -r '.COG_STABLE_SAMPLE.main' /tmp/pipeline_diag_phase2.json > /tmp/pipeline_diag_r2_main.txt
```

Generalize: for each failed rule, extract its `.main` field into a separate
`/tmp/pipeline_diag_rN_main.txt` file. Then use Read/Grep (auto-approved) to
classify errors.

## Step 4: Classify Errors

Parse each rule's log content and classify:

| Error Class      | Detection Pattern                                          |
|------------------|------------------------------------------------------------|
| `shared-library` | `GLIBC_`, `could not load library`, `libdl`                |
| `julia-error`    | `ERROR: LoadError:`, Julia stacktrace frames               |
| `python-error`   | `Traceback (most recent call last)`                        |
| `r-error`        | `Error in `, `Execution halted`                            |
| `oom-killed`     | `Killed`, SLURM `OUT_OF_MEMORY`, `MemoryError`            |
| `timeout`        | SLURM state `TIMEOUT`                                      |
| `missing-file`   | `No such file or directory`, `FileNotFoundError`           |
| `permission`     | `Permission denied`                                        |
| `config-error`   | `NickelError`, `nickel_eval`, `FFI not available`          |
| `unknown`        | No match — include raw log tail                            |

When multiple rules share the same error class and similar messages,
group them as a **common cause**.

## Step 5: Present Report

Format and display the diagnostic report:

```markdown
## Remote Pipeline Diagnostic: {host}:{directory}
**Run**: {YYYY-MM-DD HH:MM:SS} (from snakemake log filename)

### Summary
- {N} rules failed, {M} running, {K} succeeded
- Common cause: {description} (affects {X}/{N} failed rules)

### Failed Rules

| Rule             | Error Class    | Key Message                                          |
|------------------|----------------|------------------------------------------------------|
| RULE_A           | shared-library | GLIBC_2.29 not found (required by libnickel_lang.so) |
| RULE_B           | shared-library | GLIBC_2.29 not found (required by libnickel_lang.so) |

### Running Rules (if any)
- RULE_NAME (running Xm, node nodeXXX)

### Detail: RULE_A
` `` (use triple backtick)
<last 20 lines of log>
` ``
(full 100 lines available on request)

### Suggested Next Steps
- Actionable suggestions based on error class
- The skill suggests but NEVER executes fixes
```

## Guardrails

- **Read-only**: Every remote command must be `ls`, `cat`, `tail`, `head`,
  `sacct`, `squeue`, or `date`. Nothing else.
- **No writes**: No `rm`, `mv`, `touch`, `mkdir`, `>`, `>>`, `snakemake`.
- **No interactive**: No `ssh -t`, no prompts.
- **Cap at 10 rules**: If more than 10 rules failed, fetch the first 10 and
  note the rest in the summary.
- **Fail gracefully**: If any piece of the remote command fails (no logs, no
  sacct, empty directory), the JSON still returns with empty/fallback values.
  Never let one missing log break the whole diagnostic.
