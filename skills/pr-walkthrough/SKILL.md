---
name: pr-walkthrough
description: Use when a branch is ready for a pull request and the human wants to review the change before approving/merging — "walkthrough", "review before merge", "PR review doc", "explain this diff for approval". Produces a reviewer-facing HTML walkthrough in the house style (portable across repos; only needs pandoc).
---

# PR Walkthrough for Human Review

## Overview

Produce a **reviewer-facing** HTML walkthrough that tells the story behind a diff and steers the human to the decisions only they can make — *not* a changelog and *not* a findings dump. The reader is about to click "approve"; your job is to make that decision fast and well-founded.

**Core principle:** Separate *what is already proven safe* (so they don't re-verify it) from *what needs their judgment* (so they spend attention there). End with a checklist of the actual judgment calls.

## The Iron Rule: author Markdown, render with a script

**ALWAYS write the walkthrough as Markdown, then render it to self-contained HTML with a renderer — pick the first that applies:**

```bash
# 1. In the munis_home repo (preferred there — single source of truth for the CSS):
./utilities/bash/render_spec.sh docs/PRs/<name>.md

# 2. In ANY repo (portable fallback — bundled with this skill, only needs pandoc):
"$(dirname "$(realpath ~/.claude/skills/pr-walkthrough)")/pr-walkthrough/render-walkthrough.sh" <name>.md
# (or just call the script by its path inside the skill dir: .../skills/pr-walkthrough/render-walkthrough.sh)
```

Both emit `<name>.html` with the house CSS (`review.css`) inlined — identical pandoc invocation, identical look. The only external dependency is **pandoc** (`brew install pandoc`); `render_spec.sh` and the house `review.css` live ONLY in munis_home, which is why the skill bundles its own copy for portability.

**NEVER hand-author the HTML. NEVER invent CSS classes** (`.finding`, `.verdict-table`, severity divs, …). The CSS is inlined by the renderer; convey status with prose, tables, and emoji (🔍 ✅ ⚠️), not custom CSS.

| Rationalization | Reality |
|---|---|
| "Custom divs have no Markdown equivalent, so I'll write HTML" | Tables + headings + emoji cover every need. Hand-HTML drifts from house style and can't be re-rendered. |
| "I'll just add two small CSS classes" | "Don't invent fresh CSS per doc" is the house rule. Zero new classes. |
| "Markdown→Pandoc loses my severity colors" | Reviewers need the *decisions*, not a color-coded findings table. Use the structure below. |

## Output location & naming

Per `docs/PRs/README.md`:
```
docs/PRs/YYYYMMDD-HHMM-issue<N>-pr<M>-<short-kebab-desc>.html   # ≤40-char desc
docs/PRs/YYYYMMDD-HHMM-issues<N1>-<N2>-prs<M1>-<M2>-<desc>.html  # series
```
Timestamp = generation date and time (`date +%Y%m%d-%H%M`). Commit the `.md` **and** `.html` to the branch so the walkthrough travels with the PR and survives the merge.

## Process

1. **Gather the real diff** — don't paraphrase:
   ```bash
   git diff --stat main...<branch>
   git diff main...<branch> -- <file>     # pull exact hunks to quote
   ```
2. **Find the human-judgment spots.** Scan for: intentional behavior choices, anything that trades correctness for compatibility, deletions that *look* load-bearing, downgraded checks (`@assert`→`@warn`), discoveries surfaced but not fixed. For data/quant changes also scan for the silent landmines tests rarely catch: **lookahead / data leakage** (information from the test or future period leaking into training/in-sample, scalers or stats fit on the full sample), a changed **metric, threshold, or acceptance bar**, **hardcoded paths or magic parameters**, **dependency / environment pin** changes that move results, and silent **missing-value / outlier / schema** handling. These become the 🔍 section.
3. **Identify what's already proven** — tests passing, byte-identity checks, CI — so the reviewer can skip re-deriving it.
4. **Write the Markdown** using the section structure below; quote real code hunks.
5. **Render** with the appropriate script (see the Iron Rule above); confirm self-contained:
   ```bash
   rg -c '<style' <name>.html && rg -c '<link' <name>.html   # expect ≥1 style, 0 link
   ```
6. **Commit** both files to the branch; **surface the `file://` URL on its own line** (per the render-to-HTML house rule).

## Required section structure

Adapt headings to the change, but keep this spine (full skeleton in `walkthrough-template.md`):

- **Header line** — issue/PR/branch/date links.
- **TL;DR — what to know before approving** — 4–6 bullets: size, the safety guarantee, the one discovery, where to look. State the size honestly: if the diff is large or spans more than one logical change, say so and point to the riskiest slice — oversized PRs get superficial review.
- **The safety contract / verification** — what was checked and how (tests, byte-identity, CI), so the reviewer doesn't re-verify. State plainly: *you don't need to re-derive X*. For data/quant changes, fold in the **reproducibility** facts the reviewer would otherwise have to chase: results reproduce (bit-for-bit or within stated tolerance), environment/dependencies pinned, and the data version/source recorded.
- **The nuance(s) to scrutinize 🔍** — the heart of the doc. For each judgment call: quote the before/after hunk, explain the choice, and say explicitly what the reviewer should confirm or push back on.
- **Discoveries** — anything surfaced (e.g. a pre-existing bug) that the PR does *not* fix, with a table/example and why it's out of scope.
- **The rest, by theme** — lower-risk changes grouped by intent (not file-by-file), one tight code snippet each.
- **Suggested approval checklist** — `- [ ]` items, each a real judgment call from the 🔍 section, not "code compiles."
- **Deferred** — known follow-ups, recorded not done.

## Common mistakes

- **Hand-writing HTML / inventing CSS** — the #1 failure. Author Markdown, render with the script, zero new classes.
- **Findings dump instead of decision guide** — "3 Important, 2 Minor" reads like a linter. Lead with the approve/merge decision and the judgment calls.
- **Paraphrasing the diff** — quote real hunks (`git diff main...<branch>`); reviewers trust code, not summaries.
- **Burying the risky bit** — if there's one thing to scrutinize, it goes near the top with 🔍, not in paragraph 9.
- **Treating proven and unproven the same** — explicitly tell them what's already verified so their attention goes to what isn't.
- **Wrong home / lost doc** — `docs/PRs/` with the dated name, committed to the branch (not `/tmp`, not project `.claude/` which is gitignored).
