# PR #<M> — <short title>

**Issue:** [#<N>](…) · **PR:** [#<M>](…) · **Branch:** `<branch>` · **Date:** YYYY-MM-DD

<One-paragraph framing: what kind of change this is (feature / refactor / bugfix / refactor+guards) and the single most important thing about its risk profile.>[^history]

[^history]: <Background the reviewer may want but need not read: how long the old code has been there, the issue comment where this was agreed, the commit that introduced the thing being replaced.>

## TL;DR — what to know before approving

- **Size.** N files, +X / −Y. Which ones are substantive vs trivial.
- **The guarantee.** The one safety property that holds (e.g. "outputs byte-stable", "no API change", "fully covered by tests") and that it was checked.
- **The discovery / the catch**, if any — one line.[^how-found]
- **Where to look.** Point at the 🔍 section.

[^how-found]: <The exact command and output that establishes the catch, e.g. `rg -c '"[^"]*,[^"]*"' data/raw/2022.csv → 3`.>

## The safety contract (and how it was verified)

<What promise underpins this PR, and the exact commands/evidence that prove it — tests, a diff-of-outputs, CI. Be concrete.>

```bash
<the verification command(s) and their passing result>
```

> **Why this matters for your review:** you do **not** need to re-derive <X>; it's proven. Spend your attention on the judgment call(s) below.

## The nuance to scrutinize 🔍

<For each thing that required a human judgment call. This is the heart of the doc.>

### <what is decided here, ≤ 8 words>

```julia
# BEFORE
<real hunk from `git diff main...<branch>`>
```
```julia
# AFTER
<real hunk>
```

**What to confirm:** <state plainly what the reviewer should sanity-check or push back on, and why the choice was made this way.>[^why-not]

[^why-not]: <The alternative that was rejected and the one-line reason, or the doc/codebook page that justifies the rule.>

## The discovery: <one line>

<Anything the PR surfaced but does NOT fix. A small table or example, then why it's out of scope (e.g. "fixing it would change output; belongs in its own PR"). Link the issue comment that records it.>

| col | col | col |
|---|---|---|
| … | … | … |

## The rest of the changes (lower-risk, by theme)

### <theme>
<one tight snippet + one or two sentences of why>

### <theme>
…

## Suggested approval checklist

- [ ] <judgment call 1 from the 🔍 section>
- [ ] <judgment call 2>
- [ ] Comfortable deferring the items below.

<One sentence: if all sit right, this is a clean merge because <the proven property>.>

## Deferred (recorded, not in this PR)

- **<item>** — <why it's separate / which issue tracks it>.
