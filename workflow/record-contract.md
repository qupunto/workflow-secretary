# The record contract

**What each record file holds, and what it must never hold.** One copy. Before
this file existed the same table lived in four places — a full version in one
skill, a shortened one in a project's `CLAUDE.md`, and partial versions in two
more — with one of them declaring itself the authority and nothing enforcing it.

Who may *write* each file is [`ownership.md`](ownership.md). Which path plays
which role in a given project is that project's `.claude/workflow.json`, whose
keys are [`manifest.md`](manifest.md). This file is about **content**: what
belongs where, and why putting it elsewhere breaks something.

## The split

| Role | Holds | Does **not** hold |
|---|---|---|
| `record.todo` | What to build and how. Checkboxes, technical detail, file references. Forward-looking only. | Reasoning about *whether* to build something. Completed items — they are removed, not struck through. |
| `record.decisions` | The **why**, chronological, append-only. What was chosen, and what was rejected. | Anything undecided. Rewrites of past entries. Statements of current behaviour. |
| `record.decisionsIndex` | **Generated.** One row per decision. The cheap way in. | Anything hand-written. |
| `record.openDecisions` | Decisions **pending**: options, tradeoffs, a recommendation where one exists, and what each one blocks. | Anything settled — it moves out when decided. |
| `record.behaviour` | What the system **currently does** at runtime, by topic. | Why it does it. Decided-but-unbuilt behaviour. |
| `record.reference` | Current state — stack, architecture, data model, conventions. | Decision history. |
| `record.audits` | What was examined, when, against which commit, and what was found. Each entry carries an [`audit-coverage`](audit-coverage.md) block. | The resulting tasks — those go to `record.todo`. |
| `record.roadmap` | Milestones and the blocks inside them, their order and dependencies, the version each milestone intends to ship as, and which milestones are completed. | Design arguments. The claim that a version *shipped* — a tag is the only proof of that. |
| `record.changelog` | What someone *using* the project would notice, per released version. | Unreleased work. |
| `record.handoff` | What a fresh session must know **before it touches code**, compressed, plus pointers to everything else. | Anything it can look up when the topic comes up. |
| `record.tooling.catalog` | What skills and agents exist, what each is for in one human sentence, and a diagram of who invokes whom. It is the **source** for the docs site's Claude-tooling annex page, which `--docs` derives and owns. | Anything that changes as the project changes — see the mutable-claim rule below, and the carve-out under this table, which is narrow and applies to this row only. |

**The catalog row contradicts itself unless this carve-out is read with it.** Its
"Holds" column requires an inventory of what skills and agents exist; its "Does
not hold" column bars anything that changes as the project changes — and an
inventory is exactly that. The reconciliation lived only in one repo-scoped skill
file that no other project loads, which meant every adopter read a row that
forbids the thing the row is for.

So, stated here where every project reads it: **the inventory itself is
permitted in `record.tooling.catalog`, and nothing else mutable is.** Rows for
what exists, yes. Counts of them, "currently", a status, a health verdict, a
line about what some skill is in the middle of — no; those are ordinary mutable
claims and get deleted rather than corrected.

The carve-out holds only because something re-derives this file on a schedule:
`--tools` rebuilds it whenever a skill or agent changes, and a repo whose
maintenance skill refreshes it on every run keeps it honest. An inventory nothing
re-derives drifts silently and is worse than no inventory, because it reads as
current.

## Four rules that are easy to get wrong

**1. A decision is recorded when it is *made*, not when it is built.** The
opposite rule fails concretely: a batch of real design commitments sits in the
backlog mixed in with unbuilt sketches, with no way to tell one from the other.
If something is settled in conversation it gets an entry that day, even if no
code follows for months. What *exists* is `record.reference`'s job.

**2. A decision not to build something is still a decision.** It gets an entry.
The task stays in `record.todo` as an unchecked item pointing at it.

**3. An entry never lives in both `openDecisions` and `decisions`.** Settling one
means deleting it from the first and appending the outcome — including the
options rejected — to the second. Never both. An entry in both is the specific
failure the split exists to prevent.

**4. History is not staleness.** An old entry in `record.decisions` describing a
decision later reversed is **correct as written**. The *later* entry is what makes
the record accurate. Do not rewrite it. This is the one file exempt from "fix what
is stale", and the exemption is the whole reason the file can be trusted as a log.

## Two write modes, and why they do not share an owner

| Mode | Files | Failure if done badly |
|---|---|---|
| **Append-only** | `decisions`, `audits`, `changelog` | Additive. A wrong entry is a wrong entry; nothing true was lost. |
| **Rewritten in place** | `behaviour`, `reference`, `handoff`, `todo`, `roadmap` | Destroys the previous true statement. |

Appending a dated entry and rewriting a topic section have different blast radii.
That is why `record.decisions` belongs to the append-record primitive and
`record.behaviour` belongs to `behaviour-writer`, rather than one owner holding
both.

### Status fields

**Append-only constrains the entry, not every character in it.** An entry's
**body** — what was decided, what was examined and found, what shipped — is never
rewritten once written. A **status field** records the entry's current
disposition rather than a claim about the past, and updating one destroys nothing
that was true. A field is mutable only if this table names it:

| File | Status field | Updated when |
|---|---|---|
| `record.decisions` | **none** | — |
| `record.audits` | `Outcome` | remediation lands. Starts as `logged` |
| `record.changelog` | an entry's released / unreleased status | drift against `git tag` is settled by declaring the work unreleased |

`record.decisions` has none, deliberately, and that is what rule 4 above
protects: alone of the three, its entries are claims about the past and nothing
else. An audit's `Outcome` and a changelog entry's release status are statements
about *now* that happen to live in a dated entry — leaving them stale does not
preserve history, it just makes the file wrong.

The distinction is what keeps this checkable. "Append-only with exceptions" is a
rule nobody can apply confidently; "bodies never change, and these three cells
are the only mutable ones" is a rule you can verify by reading. **Widening the
set is a decision to record, not an edit to make** — and rewriting a body under
cover of updating its status is the failure this table exists to name.

## The mutable-claim rule

**A skill or agent file may carry conventions, decisions and pointers — never
counts, inventories, or "not yet built".**

Anything that changes as the project changes goes in a record file that something
keeps current, or in a command the skill runs. This is not a style preference: a
stale claim in one of these files makes the agent re-derive the real state on
every run, paying for it every time — and it recurs, because nothing ever
triggers a re-read of the file that misled it.

So when a stale claim is found in one of these files, **delete the claim rather
than correcting it.** A corrected count is a claim that will go stale again; a
deleted one cannot.

The same risk applies to `record.handoff`, which is loaded every session and
therefore costs tokens forever. Prefer a one-line warning plus a pointer over a
paragraph, and **delete a resolved warning the moment it is fixed** — a stale
warning teaches the reader that the warnings in that file are unreliable, which
costs you the real ones.

## Negative claims

**"Nothing does X" is the highest-risk sentence in any record file.** Run the grep
that would *disprove* it — not one that confirms it — before writing it, every
time. This holds for any absolute claim about state that moves, including counts.

The failure mode is a grep written against the wrong call shape: search for a
bare framework method in a codebase that wraps it, and the absence of results
"proves" a capability is missing when every instance is right there under another
name. A negative claim is then used to retire work, which is what makes it
expensive rather than merely wrong.

## When nothing fits

Say so. Do not invent structure — ask which existing file should stretch, or
whether a new one is warranted, and once decided keep using that same place for
the same kind of content instead of re-deciding it each time.
