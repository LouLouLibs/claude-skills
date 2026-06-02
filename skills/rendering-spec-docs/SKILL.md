---
name: rendering-spec-docs
description: Use when asked to render, view in a browser, or share a spec / plan / design / brainstorm / handoff / notes markdown file as HTML — including superpowers specs and plans (docs/superpowers/specs, docs/superpowers/plans), or any *-design.md / *-plan.md. Triggers on "show me the doc in html", "render this spec/plan", "make an html version".
---

# Rendering Spec & Plan Docs

## Overview

Render a markdown design/spec/plan/notes document to **self-contained,
house-style HTML** (Times body, Helvetica headings, warm accent palette, CSS
inlined). One look across every doc the user reads.

**Core rule: author Markdown, render with the script. NEVER hand-roll a pandoc
command, and NEVER hand-write HTML or invent CSS.** Ad-hoc invocations drift
from the house style and can't be re-rendered consistently.

This is the general renderer. For PR *review* walkthroughs (a specific narrative
structure), use `pr-walkthrough` instead — same house CSS.

## How to render

Pick the first that applies:

```bash
# 1. Inside the munis_home repo (source of truth for the CSS):
./utilities/bash/render_spec.sh path/to/doc.md

# 2. Any other repo (portable, bundled with this skill — only needs pandoc):
~/.claude/skills/rendering-spec-docs/render-doc.sh path/to/doc.md
#   add --open to open it in the browser after rendering
```

Both write `doc.html` next to the source, inline the CSS (`--embed-resources`),
and highlight code with pygments. Only dependency: pandoc
(`brew install pandoc`).

## Verify self-contained

```bash
rg -c '<style' doc.html   # expect >= 1
rg -c '<link'  doc.html   # expect 0
```

Then surface the path (and a `file://` URL) on its own line so the user can
click it.

## Common mistakes

| Mistake | Fix |
|---|---|
| Hand-rolled `pandoc … --include-in-header theme.css` with copied CSS | Call the script; the CSS is bundled. |
| Hand-writing HTML or inventing CSS classes | Convey status with prose, tables, emoji (🔍 ✅ ⚠️) — zero new CSS. |
| Editing the bundled `review.css` per-doc | The CSS is shared house style; change it only at the source of truth in munis_home. |
| Output not self-contained (`<link>` to css) | Use the script — it passes `--embed-resources`. |

## Keywords

render spec, render plan, design doc to html, view markdown in browser, house
style, review.css, pandoc, self-contained html, superpowers specs, superpowers
plans, brainstorm doc, handoff doc.
