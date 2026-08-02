# Writing the reference record

> **A procedure, not a skill** — see [`README.md`](README.md). Sole writer of `record.reference`, per [`ownership.md`](../ownership.md).

**Sole writer of `record.reference`.** Everything else in this workflow that
needs it changed calls this skill; who owns what is
[`~/.claude/workflow/ownership.md`](../ownership.md), and what this
file may and may not hold is
[`record-contract.md`](../record-contract.md), which is the
authority when this file and that one disagree.

Resolve the path from `.claude/workflow.json`. Without a manifest the fallback is
in [`manifest.md`](../manifest.md) — **say which you used.**

**`record.reference` is often a list of paths rather than one**, and frequently
includes the project's `README.md`. That mapping is the manifest saying the
README *is* the project's reference material, which makes it this skill's — not
an ordinary file anyone may edit, and not `--docs`' to place by tier.

## What this record holds

**Current state.** The stack and its versions, how the pieces fit together, the
data model, directory layout, and the conventions the project has actually
adopted.

Two things it never holds:

- **Decision history.** Why the stack is this stack belongs in
  `record.decisions`, written by `--log`. This file says what is true now; a
  reader wanting the argument has somewhere else to go.
- **Runtime rules.** Auth, ownership, state transitions, error statuses — those
  are `record.behaviour`'s, written by
  [`behaviour-writer`](behaviour-writer.md). The line between the two is
  *what the system is* against *what the system does*, and when a subject sits on
  it, put it where a reader would look for it and leave a pointer in the other.

## Two kinds of caller, and they want different amounts

This is why the record has its own primitive rather than living inside `--docs` —
[`ownership.md`](../ownership.md)'s split test.

### A dispatched one-line correction

From `--check`, `--full-check`, `--start` or `--stocktake`. Scope is **the section
the finding names, and nothing else.**

1. **Re-verify against source before writing.** A dispatched finding is a
   hypothesis, not an instruction —
   [`ownership.md`](../ownership.md#the-inspector-writes-nothing).
   Hand the disagreement back rather than writing a correction that is itself
   wrong.
2. **Fix what was asked**, and report anything else you noticed rather than
   widening the job.

### A structural change

From `--start` Phase 6 after a schema or architecture change, or from `--adopt`
when a project's shape was established for the first time.

1. **Read the source of truth.** For a data model that is the schema and its
   migrations, not a summary of them.
2. **Rewrite only the affected sections**, re-reading the source for each.
3. **Count nothing from memory.** "N seeded locales", "three services", "the four
   entry points" — every such figure is a claim that decays silently. Run the
   command that produces it, or write the command instead of the number.

## Negative claims need the grep that would disprove them

"Nothing else reads this key", "no endpoint enforces X" — run the search first
and, where it is cheap, leave the command in the file rather than the verdict.
[`record-contract.md`](../record-contract.md#negative-claims) is the
rule; this record is where it bites hardest, because a reference is exactly what
a later reader trusts instead of checking.

## Where the code disagrees, the code is right

Fix the record and **report the drift you found**.

## Authorization

**None of its own.** Its grant is whatever the caller was granted, and it confers
nothing — [`ownership.md`](../ownership.md) has the rule. It does not
commit; the caller does that when its own flag allows.
