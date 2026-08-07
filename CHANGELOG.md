# Changelog

Release notes for **Workflow Secretary Suite** — what changed for people *using*
the suite, in the terms they use it in.

The suite's own engineering log, with contract names, file paths and the
reasoning behind each change, is `WSS.CHANGELOG.md`. This file is deliberately
free of that: if an entry here only makes sense to someone editing the suite, it
belongs in the other one.

## 0.8.0 — 2026-08-08

**Every file the suite writes now announces itself.** Suite files carry a
`wss-` or `WSS.` prefix, so you can tell at a glance which files in your tree
are yours and which are the suite's. Project configuration nests under one
`WSS` root in the manifest; the health check fails an old flat manifest
loudly instead of misreading it silently.

**There is now a guided way out: `/wss-retire`.** One dialog asks first
whether you want a full snapshot of your records — everything, including what
git already tracks and your docs — then which things should go: the suite's
own machinery, your records, a records wipe, or the plugin itself. The
snapshot can be restored if you ever adopt again, and nothing deletes it.
Retirement can only be invoked by name, never triggered by a phrase in a
sentence.

**A settled fact about what your project is can go straight to your README**
with `--wss-reference` — the counterpart to recording how it behaves.

**Documentation sites can carry workflow pages** — one end-to-end flow per
page, a diagram plus the ordered stages, each stage pointing at the rule and
the code it rides on.

**Audit history is now a log plus an index**, so a list of every independent
audit pass exists in one place.

## 0.7.0 — 2026-08-07

**Roadmaps can now be per-area, and releases are tracked separately.** If your
project has an interface side and a service side that plan in different terms,
each can keep its own roadmap. Milestones and their version numbers moved to a
release list that never splits, so there is still exactly one place that says
what ships next.

**Parallel work sessions can hand each other tasks.** A session working on one
area can file work to another area's queue instead of editing records that
belong to it. The receiving session picks the work up when it next starts.

**Backlog items can be marked critical**, and the marker survives even when the
backlog lives in an issue tracker rather than a file.

## 0.6.0 — 2026-08-06

**Contradictions between areas get a queue of their own**, so a disagreement
found while reconciling two areas is raised for a ruling instead of being fixed
silently by whichever session noticed it.

## 0.5.0 — 2026-08-04

**Work split across several checkouts stays in sync at both ends** — picking up
work syncs forward, and finishing it lands cleanly.

## 0.4.0 — 2026-08-04

**Fewer accidental invocations.** Several commands used to trigger on ordinary
phrases: saying "done" could commit and push, "ship it" could cut a release, and
"where are we" could kick off an expensive review that rewrote your backlog.
They now judge the shape of a request rather than a single word, and the ones
that can push name the phrases they refuse.

**A drawing command was removed** — it cost every session and added nothing the
assistant could not already do.

## 0.3.0 — 2026-08-03

**Installable as a plugin**, so you can use the skills in your own projects
without cloning anything:

```bash
claude plugin marketplace add qupunto/workflow-secretary-suite
claude plugin install workflow-secretary-suite
```

**Every command got a short flag** (`--wss-check`, `--wss-start`, and so on), and
each command's name matches the flag that fires it.

## 0.2.0 — 2026-08-03

**Adopting an existing project maps what it already has** rather than demanding
a fixed layout — your backlog, roadmap and docs keep their current names and
locations.

**Your backlog does not have to be a file.** A project already tracking work in
an issue tracker can point the suite at that instead.

## 0.1.0 — 2026-08-01

First release. A set of skills that keep a project's backlog, decision log,
roadmap, documentation and tooling notes matching what the code actually does —
a secretary to coding, not the coder. Anything needing knowledge of your stack
is deliberately out of scope.
