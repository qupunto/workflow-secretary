---
name: ws-overview
description: "Report where a project stands at a glance — record counts per lane, sweep freshness, pending warnings, the nearest milestones, branch and lane — read fresh at invocation, writing nothing. SHORTHAND: `--ws-overview`. Also trigger on \"where does the project stand\", \"state of the repo\", \"project status at a glance\"."
---

# The project at a glance

**Project facts come from `.claude/workflow.json`** — `record.*`, `lanes.*`,
`sweeps`, `commands.ci`. Without a manifest, fall back to conventional names,
and report every key that does not resolve as **undeclared** rather than
skipping its line. Where a `.claude/lane` selector names a lane,
`lanes.named.<lane>.records.X` overrides `record.X` for `todo`,
`openDecisions` and `handoff` — [`manifest.md`](../../workflow/manifest.md)'s
resolution rule.

**This skill writes nothing.** No record, no checkpoint, no commit, no sweep.
It is the read-only sibling of `--ws-check`: that flag asks *what has
drifted*; this one asks *where do we stand*. Anything that looks wrong is
reported with the flag that owns fixing it, in one line, and left alone.

## The report

One block in the reply, every number read at invocation time — never carried
forward from a handoff card, memory, or an earlier session. A count is a
mutable claim, so it lives in this reply and never lands in a file
([`record-contract.md`](../../workflow/record-contract.md#the-mutable-claim-rule)).

- **Tree** — current branch, short HEAD, dirty or clean, and the active lane
  from `.claude/lane` ("no lane" where absent). One `git status --porcelain`
  and one `rev-parse`; cheap and always first, because every other line is a
  claim about this tree.
- **Records** — the open-item count per record the manifest declares: `- [ ]`
  entries in `record.todo`, `## ` entries in `record.openDecisions`, open
  blocks per milestone in `record.roadmap`. Under `lanes.named`, count each
  lane's `todo` and `openDecisions` separately and give the total. Where
  `record.todo` is a provider object, count through the provider's contract
  ([`providers/github-issues.md`](../../workflow/providers/github-issues.md))
  and mind its read-after-write rule.
- **Warnings pending** — `doctor.sh` FAILURES (it is read-only; run it), open
  entries in the machine-local bug-report inbox, and `!important` blocks in
  `record.handoff`.
- **Sweeps** — for each entry in the `sweeps` checkpoint file (check,
  full-check, stocktake, docs, tooling, test-run): its baseline commit and how
  many commits HEAD is ahead of it — the same computation the session hook
  makes, reused rather than reinvented. No checkpoint file means "no sweep has
  ever run here", which is a line, not an omission.
- **Roadmap** — the current milestone (the first not marked completed), its
  next unchecked block, and the nearest milestone after it. Where versions
  name the milestones, say which is the nearest minor and which the nearest
  major.

Three rules carry the whole contract:

- **Undeclared is not zero.** "No backlog is declared" and "the backlog is
  empty" are different facts; a bare `0` renders them identically.
- **Not checked is not zero either.** A read that needs an unreachable tool —
  `gh`, the network, a provider — is reported as *not checked*, never
  dropped; an absent line reads as clean.
- **Report, never repair.** Stale sweep → name `--ws-check`. Untriaged inbox →
  name `--ws-full-check`. A milestone that looks complete → name `--ws-plan`.
  One line each; acting on them is those flags' work, under their grants.

## What this skill does not do

- **It does not stamp anything.** Reading records is not a sweep and earns no
  checkpoint — `sweep-tracker` never hears from it.
- **It does not verify claims.** Drift detection is `--ws-check`'s method;
  this skill counts what the records say, not whether they are right.
- **It does not rebuild or reorder anything** — backlog is `--ws-todo`'s,
  roadmap is `--ws-plan`'s, and a full reckoning is `--ws-stocktake`'s.
