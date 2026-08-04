# The writers

**Procedures, not skills.** Each file here is the one procedure that writes one
record. A skill that needs a record written **reads the file and follows it** —
there is nothing to invoke.

## Why they are not skills

A skill's `description` loads into every session whether or not the skill is
ever used. A procedure invoked only by other skills pays that standing
per-session cost for a trigger it explicitly disclaims — and in plugin form
nothing can suppress it, since `skillOverrides` does not reach plugin skills.
So these are files to read, not skills to invoke.

**Reading a procedure is more reliable than dispatching to one, not less.** A
skill fires when the model judges a description to match; a link is followed
because the caller was told to follow it. The mechanism is the same one every
skill already uses to reach [`ownership.md`](../ownership.md) and the other
contracts in this directory.

## Location does not change ownership

**One writer per record.** A procedure is one file, the sole writer of its
record, and [`ownership.md`](../ownership.md)'s matrix is the authority on
which. Where a procedure lives says nothing about who may write what.

**The authorization rule.** A procedure inherits the grant of the flag the
*user* typed, however many hops away. It confers nothing of its own — that is
why none of these ever had a flag, and why a file here cannot be reached by
typing something.

## The files

| Procedure | Sole writer of |
|---|---|
| [`audit-writer.md`](audit-writer.md) | `record.audits` |
| [`behaviour-writer.md`](behaviour-writer.md) | `record.behaviour` |
| [`changelog-writer.md`](changelog-writer.md) | `record.changelog` |
| [`git-writer.md`](git-writer.md) | commits and tags |
| [`handoff-writer.md`](handoff-writer.md) | `record.handoff` and its overflow document |
| [`manifest-writer.md`](manifest-writer.md) | `.claude/workflow.json` |
| [`reference-writer.md`](reference-writer.md) | `record.reference` |
| [`sweep-tracker.md`](sweep-tracker.md) | the sweep checkpoint |

That column is a convenience. Where it and [`ownership.md`](../ownership.md)
disagree, the matrix wins — it is the copy `doctor.sh` compares the flag hook
against, and this one is compared against nothing.
