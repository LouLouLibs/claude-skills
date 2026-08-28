---
name: pr-walkthrough
description: Use when a branch is ready for a pull request and the human wants to review the change before approving/merging — "walkthrough", "review before merge", "PR review doc", "explain this diff for approval". Produces a reviewer-facing HTML walkthrough (portable across repos; only needs pandoc).
---

# PR Walkthrough for Human Review

## Overview

Produce a **reviewer-facing** HTML walkthrough that tells the story behind a diff and steers the human to the decisions only they can make — *not* a changelog and *not* a findings dump. The reader is about to click "approve"; your job is to make that decision fast and well-founded.

**Core principle:** Separate *what is already proven safe* (so they don't re-verify it) from *what needs their judgment* (so they spend attention there). End with a checklist of the actual judgment calls.

## The Iron Rule: author Markdown, render with the bundled script

**ALWAYS write the walkthrough as Markdown, then render it with the renderer bundled next to this file:**

```bash
~/.claude/skills/pr-walkthrough/render-walkthrough.sh <name>.md    # writes <name>.html beside it
```

(Installed elsewhere? Use `<dir of this SKILL.md>/render-walkthrough.sh`.)

Every walkthrough gets the same page: a sticky **contents box top-right** that tracks the section being read, Markdown **footnotes lifted into the margin as sidenotes**, numbered sections, light/dark following the OS, one self-contained `.html`. The only dependency is **pandoc** (`brew install pandoc`). A repo's own generic `render_spec.sh` is not the walkthrough style — use the bundled renderer.

**NEVER hand-author the HTML. NEVER put raw HTML or CSS classes in the Markdown.** Headings, tables, code fences, task lists, blockquotes, footnotes and emoji (🔍 ✅ ⚠️) cover every need; hand-HTML can't be re-rendered and breaks the contents box. "Just two small classes" is still zero classes; severity colors are not what a reviewer needs — decisions are.

## The shape the renderer expects

The page layout is driven by the Markdown's structure (full skeleton in `walkthrough-template.md`):

1. **Line 1 — exactly one `#` heading:** `# PR #<M> — <short title>`. It becomes the page title and the sticky top bar; any later `#` heading is demoted to plain text.
2. **Line 3 — the meta line:** `**Issue:** [#N](…) · **PR:** [#M](…) · **Branch:** \`…\` · **Date:** YYYY-MM-DD`. The first paragraph renders as the meta strip.
3. **Sections `##`, subsections `###`** — both feed the contents box (`####` does not). Headings are the reviewer's navigation: ≤ 8 words naming what is decided there ("Quoted commas are now honoured", not "Changes to ingest.jl"). Don't number them — the renderer does.
4. **Footnotes `[^slug]`** carry the evidence trail (next section).
5. **At most one blockquote per section** — the "why this matters for your review" note, rendered as the green-barred callout.
6. **Task list** (`- [ ]`) for the approval checklist.

## Footnotes: the margin is for evidence, the body is for decisions

At desktop width a footnote sits in the margin beside the sentence that cites it; on narrow screens and in print it is a numbered note at the foot. They keep the body a decision guide without losing anything the reviewer might want to check. Footnote:

- **Provenance** — commit SHA, `git blame` result, the issue comment where a choice was agreed, the codebook/doc page that justifies a rule.
- **How a claim was verified** — the exact command and output (`rg -c '…' file → 3`) when the body only needs the conclusion.
- **Why not the alternative** — the rejected approach and its one-line reason.
- **History** — how long the old code was "temporary", who added it and why.
- **Caveats and edge cases** skippable on a first pass.

Keep in the body everything the reviewer must read to decide: the 🔍 judgment calls, *what to confirm*, the safety guarantee, the size. A footnote is read out of line, so it must stand alone: one to three sentences, no "see above".

Syntax: `…the codebook says yes.[^codebook]` in the text; `[^codebook]: CoG 2022 Technical Documentation §4.2, p. 31.` as its own paragraph right after the paragraph that cites it. Slugs are words; the renderer assigns numbers. Two to six footnotes is typical — none means evidence is cluttering the body, a dozen means decisions have leaked into the margin.

## Output location & naming

Per `docs/PRs/README.md`:
```
docs/PRs/YYYYMMDD-HHMM-issue<N>-pr<M>-<short-kebab-desc>.html   # ≤40-char desc
docs/PRs/YYYYMMDD-HHMM-issues<N1>-<N2>-prs<M1>-<M2>-<desc>.html  # series
```
Timestamp = generation date and time in **local time**. Get it by actually running `date +%Y%m%d-%H%M` (which prints local time) — do **not** infer it from the session date/`currentDate` context, which is UTC and has no local time-of-day. Commit the `.md` **and** `.html` to the branch so the walkthrough travels with the PR and survives the merge.

## Process

1. **Gather the real diff** — don't paraphrase:
   ```bash
   git diff --stat main...<branch>
   git diff main...<branch> -- <file>     # pull exact hunks to quote
   ```
2. **Find the human-judgment spots.** Scan for: intentional behavior choices, anything that trades correctness for compatibility, deletions that *look* load-bearing, downgraded checks (`@assert`→`@warn`), discoveries surfaced but not fixed. For data/quant changes also scan for the silent landmines tests rarely catch: **lookahead / data leakage** (information from the test or future period leaking into training/in-sample, scalers or stats fit on the full sample), a changed **metric, threshold, or acceptance bar**, **hardcoded paths or magic parameters**, **dependency / environment pin** changes that move results, and silent **missing-value / outlier / schema** handling. These become the 🔍 section.
3. **Identify what's already proven** — tests passing, byte-identity checks, CI — so the reviewer can skip re-deriving it.
4. **Write the Markdown** in the shape above; quote real code hunks; move evidence into footnotes.
5. **Render** with the bundled script and confirm the page is self-contained:
   ```bash
   rg -q '<script>' <name>.html && ! rg -q '<link' <name>.html && echo self-contained
   ```
6. **Commit** both files to the branch; **surface the `file://` URL on its own line** (per the render-to-HTML house rule).

## Required section structure

Adapt headings to the change, but keep this spine:

- **Title + meta line** — as above.
- **TL;DR — what to know before approving** — 4–6 bullets: size, the safety guarantee, the one discovery, where to look. State the size honestly: if the diff is large or spans more than one logical change, say so and point to the riskiest slice — oversized PRs get superficial review.
- **The safety contract / verification** — what was checked and how (tests, byte-identity, CI), so the reviewer doesn't re-verify. State plainly: *you don't need to re-derive X*. For data/quant changes, fold in the **reproducibility** facts the reviewer would otherwise have to chase: results reproduce (bit-for-bit or within stated tolerance), environment/dependencies pinned, and the data version/source recorded.
- **The nuance(s) to scrutinize 🔍** — the heart of the doc. For each judgment call: quote the before/after hunk, explain the choice, and say explicitly what the reviewer should confirm or push back on.
- **Discoveries** — anything surfaced (e.g. a pre-existing bug) that the PR does *not* fix, with a table/example and why it's out of scope.
- **The rest, by theme** — lower-risk changes grouped by intent (not file-by-file), one tight code snippet each.
- **Suggested approval checklist** — `- [ ]` items, each a real judgment call from the 🔍 section, not "code compiles."
- **Deferred** — known follow-ups, recorded not done.

## Common mistakes

- **Hand-writing HTML / inventing CSS** — the #1 failure. Author Markdown, render with the script, zero new classes.
- **A second `#` heading, or numbering headings by hand** — a stray `#` silently becomes a paragraph; "1. Theme" renders as "5.1 1. Theme".
- **Findings dump instead of decision guide** — "3 Important, 2 Minor" reads like a linter. Lead with the approve/merge decision and the judgment calls.
- **Footnoting the decision** — if the reviewer must read it to approve, it belongs in the body; the margin is for the evidence behind it.
- **Paraphrasing the diff** — quote real hunks (`git diff main...<branch>`); reviewers trust code, not summaries.
- **Burying the risky bit** — if there's one thing to scrutinize, it goes near the top with 🔍, not in paragraph 9.
- **Treating proven and unproven the same** — explicitly tell them what's already verified so their attention goes to what isn't.
- **Wrong home / lost doc** — `docs/PRs/` with the dated name, committed to the branch (not `/tmp`, not project `.claude/` which is gitignored).
