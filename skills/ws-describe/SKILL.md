---
name: ws-describe
description: "Record what the system does at runtime — a rule settled in conversation, written into the behaviour record. SHORTHAND: `--ws-describe`. Also trigger on \"write that rule down\", \"record how this behaves now\", \"document the new auth rule\". Not on why a rule is the way it is, which is `--ws-log`'s."
---

# Describe the running system

A rule settled in conversation has no way to reach `record.behaviour` on its
own. Every other route into that record is a side effect — an inspecting or
building caller dispatches to the writer when it happens to notice a gap, and
none of them fire because someone decided how the system should behave. This
flag is that route.

**This skill decides nothing and writes nothing itself.** It resolves the record
and hands the work to
[`writers/behaviour-writer.md`](../../workflow/writers/behaviour-writer.md),
which is the sole writer of `record.behaviour` per
[`ownership.md`](../../workflow/ownership.md). The whole of what to write, how
much, and what that record may not hold is that procedure's — read it rather
than restating its rules here.

**Project facts come from `.claude/workflow.json`**: `record.behaviour`, with the
fallback in [`manifest.md`](../../workflow/manifest.md). Say which you used.

## What reaches this flag, and what does not

`record.behaviour` holds **what the system does at runtime** — auth rules,
ownership rules, state transitions, visibility rules, error statuses, ordering
guarantees. Three neighbours are routinely handed here and each belongs
elsewhere:

| Handed here | Actually | Route |
|---|---|---|
| *Why* the rule is that way | reasoning | `--ws-log` |
| A rule decided but not built | a plan, not the running system | `--ws-log` |
| Stack, architecture, data model, conventions | `record.reference` | `reference-writer`, and it has no flag |

The third is the one to watch: `reference-writer` has the same
conversation-shaped trigger this flag exists for and deliberately did not get a
flag of its own — the decision log carries why. Dispatching to it because the
user typed `--ws-describe` at it is the wrong fix; say the record is
`record.reference`, and write it as ordinary work through its owner.

## Procedure

1. **Resolve `record.behaviour`** from the manifest, or the fallback. An absent
   file is an empty record, not an error.
2. **Check the rule is about the running system**, against the table above. If it
   is not, name the right record and stop — routing beats writing to the nearest
   file.
3. **Verify the rule against the code before writing it.** A rule stated in
   conversation is a claim about the tree, and this record is read as though
   every line in it were observed. Where the code disagrees, the code wins and
   the disagreement is what to report.
4. **Hand it to `behaviour-writer`** with the rule, the topic it belongs under,
   and what you verified it against.
5. **If the rule is new rather than a correction**, the reasoning behind it is a
   separate record: offer `--ws-log`. Do not write it yourself, and do not let it
   ride along inside the rule.
