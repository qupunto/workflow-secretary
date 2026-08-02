# The writers

**Procedures, not skills.** Each file here is the one procedure that writes one
record. A skill that needs a record written **reads the file and follows it** —
there is nothing to invoke.

## Why they are not skills

A skill's `description` loads into every session whether or not the skill is
ever used. These eight always said, in that description, *"Invoked BY other
skills rather than by the user"* — paying a standing per-session cost for a
trigger they explicitly disclaimed. In checkout form `skillOverrides` could
suppress it; in plugin form nothing can, so the cost was unavoidable and
permanent for anyone who installed the suite.

They moved out of `skills/` on 2026-08-02. Together their descriptions were
2,761 B of every session.

**Reading a procedure is more reliable than dispatching to one, not less.** A
skill fires when the model judges a description to match; a link is followed
because the caller was told to follow it. The mechanism is the same one every
skill already uses to reach [`ownership.md`](../ownership.md) and the other
contracts in this directory.

## What did not change

**One writer per record.** The procedure is still one file, still the sole
writer of its record, and [`ownership.md`](../ownership.md)'s matrix is still
the authority on which. Moving a procedure out of `skills/` changed where it
lives and nothing about who may write what.

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
