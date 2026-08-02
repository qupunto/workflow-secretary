---
name: tooling-catalog-sync
description: "Owns the project's tooling files — the catalog of what skills and agents exist, the diagram of who invokes whom, and the factual claims inside those files. SHORTHAND: `--tools`. Use whenever a skill or agent file is created, edited or removed, or a stale claim is found in one — immediately, before ending the turn."
---

# Keeping the tooling files honest

Two jobs, both about the files that describe and drive the tooling:

1. **The catalog** — `record.tooling.catalog` is a human-readable index of every
   skill and agent: what exists and what it is for, so the user can see it at a
   glance without opening every file.
2. **The claims inside those files** — `record.tooling.sources`. A skill or agent
   file that states something false about the project is worse than one that
   states nothing, and nothing else in the workflow owns them.

**Project facts come from `.claude/workflow.json`**: `record.tooling.catalog` and
`record.tooling.sources`. Without a manifest, fall back to `.claude/TOOLING.md`,
`.claude/skills/*/SKILL.md` and `.claude/agents/*.md`, and say so.

Who owns what else is
[`~/.claude/workflow/ownership.md`](../../workflow/ownership.md).

## When it triggers

- A skill or agent is created, removed, or has its `description` or purpose
  edited in a way that changes what it does or when it's used.
- **A stale claim is found inside a skill or agent file** — by you, or dispatched
  here by `--check`.

Not needed for internal changes that don't alter purpose, like rewording a
section.

**It does not fire on a file belonging to this suite** — including the very
skill being executed. That is filed and left, per
[`ownership.md`](../../workflow/ownership.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session).
The working project's own skills and agents are this skill's ordinary business
and are not affected.

## Job 1 — the catalog

1. Add, edit or remove the matching row in `record.tooling.catalog`.
2. Write the summary in short, human language, one sentence. **Don't copy the
   frontmatter `description` verbatim** — that is written to be read by Claude as
   a trigger condition, not by a human at a glance.
3. If the new skill overlaps an existing one, check that one's row too: its
   summary may now be wrong, especially if it has started delegating.
4. Refresh the interaction diagram below if what you changed moved an arrow.
5. No confirmation needed. This is low-risk internal documentation.

### Hand it to `--docs` — do not write into the site

Where the project has a documentation site, its annex should carry a **Claude
tooling** page: a catalog is an exhaustive per-item reference over an enumerable
set, which is what an annex is for.

**You do not write that page.** After updating `record.tooling.catalog`, invoke
`--docs` and hand it the catalog as the source, for it to adapt into the site's
annex in the site's own conventions. That skill owns everything under `docs/` —
the page, its index row, its sidebar entry.

**The derived copy is only as current as the handoff**, so invoking `--docs` is
part of this procedure rather than a courtesy — and where the catalog moved but
the site did not, that is a finding for `--check`, not something to fix by
editing the page.

Where the project has no documentation site, there is no second file and nothing
to hand over.

### The interaction diagram

The catalog carries a diagram of how the tooling fits together, because the rows
describe each skill alone and **the thing a newcomer cannot reconstruct from any
single file is who invokes whom.**

**Draw it yourself.** There was a `diagram` skill for this and it was cut: what
it carried is behaviour Claude already has, so it cost every session a
description to buy back nothing.

Three rules survive it, because each is a way to be wrong that is easy to be:

- **Check what will render it before choosing a form.** Mermaid in a display
  that does not support it ships raw markup to every reader; `docsify` needs a
  plugin a default `index.html` does not load. Where you cannot determine the
  renderer, use ASCII — it is never wrong.
- **Every box and arrow is a claim.** Draw from the files you actually read,
  never from inference, and where a relationship's direction cannot be
  established, leave it out and say so.
- **Stop before it stops being readable.** A graph nobody can follow is worse
  than the table above it, and the table is already there.

The diagram travels with the catalog when it goes to `--docs`, which re-renders
it for the site's own renderer under the same three rules.

## Scope, when this runs as a sweep

Fired by a specific change — a skill edited, a finding dispatched here — the scope
*is* that change and there is nothing to resolve. Fired as a sweep over every file
in `record.tooling.sources`, ask `sweep-tracker` to resolve the entry `tooling`
first. One scope, `claims`, covering the files whose contents were actually read.

**A file swept clean once stays clean as the project moves, and that is not an
assumption — it is what Job 2 enforces.** The rule below deletes mutable claims
rather than correcting them, so what survives a sweep is conventions, decisions
and pointers: content that a code change cannot falsify. That is the whole reason
this sweep can be narrowed at all, and it stops being true the moment someone
"fixes" a count instead of removing it.

So re-read a tooling file when **the file itself changed** since the baseline, or
when it was left `not-covered`. Two things void that:

- **A file the previous run corrected rather than deleted.** If you cannot tell
  from the checkpoint, re-read it. One corrected count is enough to break the
  argument above for that file.
- **Dangling pointers**, which do go stale without the file changing. Cheap to
  check and not worth narrowing: run the suite's `doctor.sh` every time.

## Job 2 — stale claims inside the tooling files

**The procedure is [`workflow/checks/tooling-claims.md`](../../workflow/checks/tooling-claims.md).**
This skill is what enforces it; `--full-check` runs the same method over every
file in `record.tooling.sources`, and used to reach it by citing this heading.

In one line, because it overrides the instinct to be helpful: *delete the mutable
claim rather than correcting it.* The rule itself is
[`record-contract.md`](../../workflow/record-contract.md#the-mutable-claim-rule).

**What the method deliberately leaves to this skill**, because scope,
disposition and authorization are a runner's and a method that carried them
could not be borrowed by the next caller:

- **Say what you removed and why**, in the commit — `git-writer` writes it under
  this flag's commit-only grant, but the message is yours to supply. It is the
  only audit trail a markdown file has.
- **After a sweep, hand `sweep-tracker` the baseline and the files you actually
  read.** List a file you deleted a claim from under `covered`, and a file you
  corrected one in under `not-covered` — the narrowing only holds where the
  mutable claim is gone rather than restated.
- **When `--check` dispatches a finding here, re-verify before deleting.** A
  deletion is not recoverable from the file itself, which makes the second look
  in [`ownership.md`](../../workflow/ownership.md#the-inspector-writes-nothing)
  especially load-bearing at this end.

## What this skill does not do

It does not write any other record. If the change resolves or creates a tooling
task, that belongs in `record.todo` and its reasoning in `record.decisions` —
both `--todo`'s, so hand it over rather than editing them here.
