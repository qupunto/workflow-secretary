# Writing the behaviour record

> **A procedure, not a skill** — see [`README.md`](README.md). Sole writer of `record.behaviour`, per [`ownership.md`](../ownership.md).

**Sole writer of `record.behaviour`.** Everything else in this workflow that
needs it changed calls this skill; who owns what is
[`ownership.md`](../ownership.md), and what this
file may and may not hold is
[`record-contract.md`](../record-contract.md), which is the
authority when this file and that one disagree.

Resolve the path from `.claude/workflow.json`. Without a manifest the fallback is
in [`manifest.md`](../manifest.md) — **say which you used.** A
manifest that names the file is the authority on placement, so it keeps its path
and skips `--ws-docs`' tier placement and sidebar wiring entirely.

## What this record holds

**What the system does at runtime, by topic.** Auth rules, ownership rules, state
transitions, visibility rules, error statuses, ordering guarantees — the answers
someone needs before they can predict what a request will do.

Three things it never holds, and each has an owner:

- **Why a rule is the way it is.** That is `--ws-log`'s (`record.decisions`). A rule
  with its rationale inline is a decision log growing inside a reference, and it
  goes stale in a way nobody notices because the rule beside it is still true.
- **Decided-but-unbuilt behaviour.** Also `--ws-log`'s. This file describes the
  running system; a rule that does not exist yet is a plan, and a reader who
  cannot tell the two apart has no reason to trust either.
- **Stack, architecture, data model, conventions.** That is `record.reference`'s,
  written by [`reference-writer`](reference-writer.md).

## Two kinds of caller, and they want different amounts

This is why the record has its own primitive rather than living inside `--ws-docs` —
[`ownership.md`](../ownership.md)'s split test.

### A dispatched one-line correction

From `--ws-check`, `--ws-full-check`, `--ws-start` or `--ws-stocktake`. Scope is **the section
the finding names, and nothing else.**

1. **Re-verify against source before writing.** A dispatched finding is a
   hypothesis, not an instruction —
   [`ownership.md`](../ownership.md#the-inspector-writes-nothing). A
   finding that has already been fixed reads exactly like a live one, and acting
   on it can mask a real instance of the same class one file away. Hand the
   disagreement back rather than writing a correction that is itself wrong.
2. **Fix what was asked.** A dispatched one-line correction is not a licence to
   rewrite the page. If the section around it is also wrong, report that; do not
   quietly widen the job.

### A batch of runtime changes

From `--ws-start` Phase 6, or `--ws-docs` when a page it owns turns out to describe
behaviour rather than architecture.

1. **Read the source, not the diff summary.** The caller knows what it changed;
   only the code knows what the rule now is.
2. **Rewrite only the affected topics.** Enumerated tables are the usual
   casualty — a new endpoint invalidates a row, not the page.
3. **Check for consequences.** Does the intro still describe the current
   arrangement? Did a renamed rule break an inbound anchor elsewhere?
   `grep -rn '#the-old-slug'` across the docs tree.

## Where the code disagrees, the code is right

Fix the record and **report the drift you found** — a record that silently
converged on the source has thrown away the one signal that says how far it had
drifted, and the next reader has no reason to check anything.

## Authorization

**None of its own.** Its grant is whatever the caller was granted, and it confers
nothing — [`ownership.md`](../ownership.md) has the rule. It does not
commit; the caller does that when its own flag allows.
