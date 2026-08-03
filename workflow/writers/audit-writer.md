# Writing the audit log

> **A procedure, not a skill** — see [`README.md`](README.md). Sole writer of `record.audits`, per [`ownership.md`](../ownership.md).

**Sole writer of `record.audits`.** Everything else in this workflow that needs
an entry written or an `Outcome` updated calls this skill; who owns what is
[`ownership.md`](../ownership.md), and what this
file may and may not hold is
[`record-contract.md`](../record-contract.md).

Resolve the path from `.claude/workflow.json`. **This record has no conventional
filename** — a project that has not declared `record.audits` does not have one,
and inventing a path is how a project ends up with two. Say so and stop.

## Append-only, with one exception

The log is chronological and additive: an old entry describing a tree that has
since changed is **correct as written** and is never corrected.

The single field editable in place is **`Outcome`**, which
[`record-contract.md`](../record-contract.md#status-fields) declares
for this file. It starts as `logged` and moves when remediation lands. Editing it
does not breach append-only, and it is not a reason to re-audit anything.

## Two kinds of caller, and they want very different amounts

This is why the record has its own primitive rather than living inside
`--ws-stocktake` — [`ownership.md`](../ownership.md)'s split test, in its
starkest form:

| Caller | Wants |
|---|---|
| `--ws-stocktake` Phase 4 | A whole new entry: the full field block plus the coverage block |
| Anything landing a remediation | **One field on an existing entry.** `Outcome`, and nothing else |

The second must not have to invoke an audit procedure to get written.

## Writing a new entry

The caller arrives with the material — it ran the audit. This skill lays it out
and enforces what may go in.

**Fields, in order:**

- **Tree** — the commit the audit ran against, and whether the working tree was
  clean. Not a date alone: a date does not resolve to a tree.
- **Scope** — `--ws-stocktake` or `--ws-full-stocktake`, which dimensions, and whether
  checkpoints were honoured or ignored.
- **Method** — how the reading was done, and by what. **Where no code analysis
  ran, say so in those words.** An entry that lists mechanical checks passing
  reads as "the code was reviewed and found clean" unless it explicitly denies it.
- **Verification** — which findings were re-checked by hand and which are
  agent-reported. This distinction is the point of the field: a reader has no
  other way to calibrate how much to trust the rest.
- **Tests** and **CI** — the counts and the commit each ran against, or the
  explicit absence. "No run exists for any commit in this range" is a result.
- **Findings**, then the carry-over counts and any `[missed by <date> audit]`
  annotations.
- **Outcome** — starts as `logged`.

### The coverage block

Its rules are [`audit-coverage.md`](../audit-coverage.md) and they are
followed exactly. **Build `covered` from the auditors' reports, not from the
plan** — the rule that gets bent is *silence is not coverage*, and it gets bent
because a wide `covered` list is what makes the next audit cheap.

That motivation is why the claim and the record are separated at all: the skill
that benefits from broad coverage is not the one that writes it down.

## What never goes in

**The resulting tasks.** Those are `record.todo`'s, written by `--ws-todo`. An audit
entry says what was found; the backlog says what will be done about it, and the
two move on completely different schedules.

## Authorization

**None of its own.** Its grant is whatever the caller was granted, and it confers
nothing. `--ws-stocktake` carries commit-and-push scoped to its own record, and this
file is inside that scope — but the push is still the caller's act through
`git-writer`, never this skill's.
