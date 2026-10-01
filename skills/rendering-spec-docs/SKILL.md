---
name: rendering-spec-docs
description: Use when asked to render, view in a browser, or share a spec / plan / design / brainstorm / handoff / notes / pre-review markdown file as HTML — including superpowers specs and plans (docs/superpowers/specs, docs/superpowers/plans), any *-design.md / *-plan.md, and referee or AE pre-reviews. Triggers on "show me the doc in html", "render this spec/plan", "make an html version", "use the house style".
---

# Rendering Spec & Plan Docs

## Overview

Render a markdown doc to **one self-contained HTML page in the house style**: a
~42rem reading column, a sticky **contents box** top-right that tracks the section
being read, Markdown **footnotes lifted into the margin as sidenotes**, numbered
sections, light/dark following the OS. The page shell (`walkthrough.css` +
`walkthrough.html`) is owned by the sibling `pr-walkthrough` skill; this skill's
`render-doc.sh` wraps that renderer and labels the page as a doc, not a PR walkthrough.

**Core rule: author Markdown, render with the script.** NEVER hand-roll a pandoc
command, NEVER hand-write HTML or invent CSS, and NEVER use a repo's older
`render_spec.sh` / `review.css` (Times body, Helvetica headings) — that style is
superseded; the page shell here is the only house style.

For PR *review* walkthroughs (a decision-guide narrative), use `pr-walkthrough` —
same page, its own required structure.

## How to render

```bash
~/.claude/skills/rendering-spec-docs/render-doc.sh path/to/doc.md              # writes doc.html beside it
~/.claude/skills/rendering-spec-docs/render-doc.sh path/to/doc.md --open       # …and open it in the browser
~/.claude/skills/rendering-spec-docs/render-doc.sh doc.md --kicker pre-review  # top-bar label (default "doc")
```

Only dependency: pandoc (`brew install pandoc`). Needs `pr-walkthrough` installed
beside it (`install.sh` in the claude-skills repo installs both).

A repo may have its own home for rendered HTML (e.g. `workbench/KEY/output/`) or a
Makefile target that calls this script: move the file there, or use the target.
Before rendering in an unfamiliar repo, look at its newest `.html`
(`rg 'name="generator"' file.html`) and match the convention it shows.

## The shape the renderer expects

1. **Exactly one `#` heading, on line 1** — becomes the page title and the top bar.
   Any later `#` heading is demoted to plain text.
2. **First paragraph = meta strip** (`**Status:** … · **Date:** …`) — optional; keep
   it to one paragraph.
3. **`##` sections and `###` subsections** feed the contents box (`####` does not).
   Don't number headings by hand — the renderer does.
4. **Footnotes `[^slug]`** for evidence, provenance, asides — they render in the margin.
5. Tables, code fences, task lists, blockquotes and emoji (🔍 ✅ ⚠️) cover every
   need — zero raw HTML, zero CSS classes.
6. `$…$` is parsed as TeX math (rendered as MathML). A lone `$5` is safe; escape as
   `\$` when two dollar signs could pair up on one line.

## Verify self-contained

```bash
rg -c '<style'   doc.html   # ≥ 1
rg -c '<script>' doc.html   # ≥ 1  (contents box + sidenotes machinery)
rg -c '<link'    doc.html   # 0
```

Then surface the path **and** a `file://` URL on its own line so the user can click it.

## Common mistakes

| Mistake | Fix |
|---|---|
| Hand-rolled `pandoc … --css`, or a repo's own `render_spec.sh` | Call `render-doc.sh` — that *is* the house style now. |
| Hand-written HTML or invented CSS classes | Prose, tables, emoji, footnotes. Zero new CSS. |
| Two `#` headings | One H1 on line 1; everything else `##`/`###`. |
| Headings numbered by hand ("1. Scope") | Renders as "1 1. Scope". Let the renderer number. |
| Editing `walkthrough.css` for one doc | Shared house style — change it only in the claude-skills repo (`skills/pr-walkthrough/`), then reinstall. |
| Output contains a `<link>` to CSS | Use the script — it passes `--embed-resources`. |

## Keywords

render spec, render plan, design doc to html, view markdown in browser, house style,
walkthrough.css, pandoc, self-contained html, sidenotes, contents box, superpowers
specs, superpowers plans, brainstorm doc, handoff doc, pre-review.
