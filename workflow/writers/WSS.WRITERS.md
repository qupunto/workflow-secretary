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
skill already uses to reach [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md) and the other
contracts in this directory.

## Location does not change ownership

**One writer per WSS.record.** A procedure is one file, the sole writer of its
record, and [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)'s matrix is the authority on
which. Where a procedure lives says nothing about who may write what.

**The authorization rule.** A procedure inherits the grant of the flag the
*user* typed, however many hops away. It confers nothing of its own — that is
why none of these ever had a flag, and why a file here cannot be reached by
typing something.

## The files

| Procedure | Sole writer of |
|---|---|
| [`WSS.AUDIT-WRITER.md`](WSS.AUDIT-WRITER.md) | `WSS.record.stocktake`, `WSS.record.audits` |
| [`WSS.BEHAVIOUR-WRITER.md`](WSS.BEHAVIOUR-WRITER.md) | `WSS.record.behaviour` |
| [`WSS.CHANGELOG-WRITER.md`](WSS.CHANGELOG-WRITER.md) | `WSS.record.changelog` |
| [`WSS.GIT-WRITER.md`](WSS.GIT-WRITER.md) | commits and tags |
| [`WSS.HANDOFF-WRITER.md`](WSS.HANDOFF-WRITER.md) | `WSS.record.handoff` and its overflow document |
| [`WSS.MANIFEST-WRITER.md`](WSS.MANIFEST-WRITER.md) | `.claude/WSS.WORKFLOW.json` |
| [`WSS.REFERENCE-WRITER.md`](WSS.REFERENCE-WRITER.md) | `WSS.record.reference` |
| [`WSS.SWEEP-TRACKER.md`](WSS.SWEEP-TRACKER.md) | the sweep checkpoint |

That column is a convenience. Where it and [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)
disagree, the matrix wins — it is the copy `wss-doctor.sh` compares the flag hook
against, and this one is compared against nothing.
