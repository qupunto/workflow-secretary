# The record contract

**What each record file holds, and what it must never hold.** One copy. A
second copy of this table anywhere declares an authority nothing enforces, and
the copies drift apart silently — partial versions in individual skills and
project files are how that happens.

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
| `record.openDecisions` | Decisions **pending**, one `## <the choice>` heading per entry: options, tradeoffs, a recommendation where one exists, and what each one blocks. The heading is contractual — machinery counts entries by `## ` line, and an entry shaped any other way is invisible to the staleness nudge. | Anything settled — it moves out when decided. |
| `record.behaviour` | What the system **currently does** at runtime, by topic. | Why it does it. Decided-but-unbuilt behaviour. |
| `record.reference` | Current state — stack, architecture, data model, conventions. | Decision history. |
| `record.audits` | What was examined, when, against which commit, and what was found. Each entry carries an [`audit-coverage`](audit-coverage.md) block. | The resulting tasks — those go to `record.todo`. |
| `record.roadmap` | Milestones and the blocks inside them, their order and dependencies, the version each milestone intends to ship as, and which milestones are completed. | Design arguments. The claim that a version *shipped* — a tag is the only proof of that. |
| `record.changelog` | What someone *using* the project would notice, per released version. | Unreleased work. |
| `record.handoff` | What a fresh session must know **before it touches code**, compressed, plus pointers to everything else. | Anything it can look up when the topic comes up. |
| `record.toolbelt` | One row per **adopted capability**: task shape → package → pointer into the `record.decisions` entry that adopted it. Consulted before building any capability. | The reasoning — that goes to `record.decisions` via `--ws-log` at the moment of adoption, so the registry stays a lookup table rather than a second decision log. |
| `record.tooling.catalog` | What skills and agents exist, what each is for in one human sentence, and a diagram of who invokes whom. It is the **source** for the docs site's Claude-tooling annex page, which `--ws-docs` derives and owns. | Anything that changes as the project changes — see the mutable-claim rule below, and the carve-out under this table, which is narrow and applies to this row only. |

**The catalog row contradicts itself unless this carve-out is read with it.** Its
"Holds" column requires an inventory of what skills and agents exist; its "Does
not hold" column bars anything that changes as the project changes — and an
inventory is exactly that. So, stated here where every project reads it: **the inventory itself is
permitted in `record.tooling.catalog`, and nothing else mutable is.** Rows for
what exists, yes. Counts of them, "currently", a status, a health verdict, a
line about what some skill is in the middle of — no; those are ordinary mutable
claims and get deleted rather than corrected.

The carve-out holds only because something re-derives this file on a schedule:
`--ws-tools` rebuilds it whenever a skill or agent changes, and a repo whose
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
The task stays in `record.todo` as an unchecked item pointing at it. **And the
entry names whose call the deferral was** — the owner's words, or the session's
own judgment, which stands only until the owner's next gate. A parking written
without attribution reads as settled while hiding who settled it, and "I don't
recall ordering this" must be answerable from the record rather than by forensic
reading of which entries *do* carry an owner's name.

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
| **Rewritten in place** | `behaviour`, `reference`, `handoff`, `todo`, `roadmap`, `toolbelt` | Destroys the previous true statement. |

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

## Lane-scoped records — which may split, and which must never

A project worked on from several git worktrees at once may split a record into
per-lane files, declared under the manifest's `lanes.named` and resolved by
[`manifest.md`](manifest.md)'s resolution rule. **Splittable: `todo`,
`openDecisions`, `handoff`** — forward-looking records, lane-scoped by nature,
and the three every concurrent session wants to write, which is exactly where
the merge conflicts were. **Never: `decisions`, `audits`, `changelog`** — the
append-only single timelines; three branches appending at EOF conflict
trivially and resolve as "keep both" — **nor `roadmap`, `behaviour`,
`reference`**, which describe one system, **nor `toolbelt`** — which tool does a
job is a property of the project, not of a worktree. A lane-local decision log is the
failure this rule exists to prevent: the why of a choice fragments across
files nobody reads together.

Under lanes the decision log is fed by promotion, not by lane writes: a lane
appends *candidate* entries to its own openDecisions file, and the merge to
the integration branch is what promotes settled ones into `record.decisions`.
One writer per file still holds — each lane file has the same owner its
unsplit record has, per [`ownership.md`](ownership.md).

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

**The pattern rule — this rule's general form: a rule file states behavior; the
log explains it.** A skill, agent, procedure, check or contract file carries
explicit behavioral patterns — trigger, action, boundary — plus at most one
clause of *mechanism* per counterintuitive rule. History never appears: no
dates, no incident citations, no what-a-file-used-to-say, no who-found-what.
All of that belongs in `record.decisions` or the audit log, which exist to
explain the pattern without being loaded beside it. The test is robustness: a
rule a reader must infer from an anecdote is inferred differently by each
reader, and variance in reading becomes variance in behavior — where stating
the rule explicitly costs more words, the words are the cheaper side of that
trade. `doctor.sh` polices the greppable proxy: a date-shaped string in prose,
outside a fenced block, in any rule file.

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

## A record holds one project, and only its own

**A finding about another project never enters this project's records.** Not
`todo`, not `roadmap`, not `openDecisions`, and **not `decisions`** — which is
otherwise the file that takes everything settled, and is the one most likely to
be reached for on the grounds that a real decision was made. Hand it to that
project's own record, in that project's lane, and stop there.

This is not the lane split one level up. Lanes divide one project among
worktrees; this divides projects. A lane's records still describe the system all
its lanes build.

The suite is installed once and serves every project on the machine, so another
project reaches a session routinely — through a shared inbox, a question asked
mid-batch, a checkout in the next directory. **Reaching a session confers no
ownership.** What goes wrong is not exposure: it is that an entry filed in the
wrong project is read by sessions that cannot act on it, missed by the ones that
can, and counted in a status report describing a tree it does not describe.

Where this project's own machinery must change *because* of what another project
showed, that item is legitimate and belongs here — **written from this project's
facts**. State what is true here; never name the other project, quote its
configuration, or cite its records as the evidence. A reader of this record must
be able to act on the entry without access to anything outside this tree.

### The one exception: a name that is load-bearing

**Another project's name may be written where the name itself is the operative
detail of a fact about *this* tree.** Both halves are required:

- **It is a fact about this project.** This repository's history contains the
  string; this repository's gate trips on it; this repository's file was copied
  from there. Not a fact about the other project's state, plans or adoption.
- **The name does the work.** Redacting it breaks the entry — it is the needle a
  grep is run with, the literal a check matches on, the value that has to be
  typed. A name that could be replaced by "another project" without loss is not
  load-bearing, and the rule above applies unchanged.

The canonical case is a hazard whose own command embeds the string: abstracting
the name leaves a warning nobody can act on, which is a worse record than the
one that names it. The canonical *non*-case is a condition on the other project
— "once they adopt this", "when their migration lands" — which names it for
state a reader of this tree cannot observe, and fails whether or not the name is
spelled out.

Provenance on already-completed work qualifies where the name is what makes the
provenance checkable, and not otherwise. Append-only records get no separate
allowance, and no licence to rewrite either: `record.decisions` takes no rewrites
of past entries (the table at the top of this file), so an entry that violated
the rule when written stays as written and the correction is a later entry.

Telling the user what was noticed is always right. **Filing is what routes**, and
it routes outward.

## When nothing fits

Say so. Do not invent structure — ask which existing file should stretch, or
whether a new one is warranted, and once decided keep using that same place for
the same kind of content instead of re-deciding it each time.
