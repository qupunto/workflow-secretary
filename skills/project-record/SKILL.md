---
name: project-record
description: "The project's record of work and why. `--todo` parks what is not being built now: task to the backlog, reasoning to the decision log. `--log` records a decision already made. Also trigger on \"leave this for later\", \"we've decided\", \"park this\", \"here are my notes\", \"notes from the standup\", a pasted block of decisions, or when you judge something premature yourself."
---

# The project record

This skill owns the project's task and decision records, and one idea:
**nothing that was decided should survive only in a chat log.**

| Flag | Means | Writes |
|---|---|---|
| `--todo` | park this; we are not building it now | `record.todo` **and** `record.decisions` — a deferral is a decision |
| `--log` | we decided this; record the reasoning | `record.decisions` only |

Both go through the same routing table, the same file rules, and the same index
regeneration. Two flags rather than one because the skill does two jobs that feel
different to whoever is typing, not because the logic differs.

**Project facts come from `.claude/workflow.json`**: `record.todo`,
`record.decisions`, `record.decisionsIndex`, `record.openDecisions`, and
`commands.indexRegen`. The fallbacks when a key is absent are
[`manifest.md`](../../workflow/manifest.md)'s, not this file's — say which ones
you used. `record.decisionsIndex` is the one with no fallback: without it, append
to the decision log and say the index was not regenerated.

This skill is the **sole writer** of every one of them. Who owns everything else is
[`~/.claude/workflow/ownership.md`](../../workflow/ownership.md); what each
record may and may not hold is
[`record-contract.md`](../../workflow/record-contract.md), which is the authority
if this file and that one ever disagree.

## Routing: which file, and why it matters

```
Is it settled?
├─ No — we cannot start until someone chooses  → record.openDecisions
│                                                (options, tradeoffs, a
│                                                recommendation if there is one,
│                                                and WHAT IT BLOCKS)
└─ Yes
   ├─ and it produces work         → record.todo + record.decisions
   └─ and it produces no work      → record.decisions
```

**The first branch is the one to get right.** "Not now, because the project does
not need it" is a **decision** → `decisions`. "We cannot start because nobody has
chosen between A and B" is an **open decision** → `openDecisions`. Logging the
second as the first is how a blocking choice quietly becomes invisible: it reads
as settled, so nobody revisits it, and the first person to write code past it
makes the call by accident.

**An entry never lives in both.** Settling one means deleting it from
`openDecisions` and appending the outcome — including the options rejected — to
`decisions`. An entry in both is the specific failure this split exists to
prevent.

## Intake: a block of notes, rather than one item

**Trigger on "here are my notes", "notes from the standup", "we discussed X, Y
and Z", "minutes from the call", or a pasted block of unstructured decisions and
actions.** The user is handing over a conversation they had somewhere else, and
the job is to route every line in it through the table above.

This is the one place the skill takes input it did not shape. Notes arrive
mixed: a decision, an action, a thing someone will "look into", a complaint, and
a date. Route each independently — **one note does not produce one entry**, and
the commonest mistake is filing the whole block as a single decision because it
arrived as a single paragraph.

**Three passes, in this order:**

1. **Split into claims.** One decision, action or question per line. A sentence
   containing "and we should also" is two.
2. **Route each** through the table above: settled + work → `record.todo` and
   `record.decisions`; settled + no work → `record.decisions`; unsettled and
   blocking → `record.openDecisions`.
3. **Report what you dropped, and why.** Status updates, restated context and
   anything already in a record are not entries. Say which lines produced
   nothing — silently discarding half of someone's notes is how they stop
   handing them over.

**What does not survive intake:**

- **Attribution.** "Sam thinks we should…" becomes the proposal, not the person.
  These records are read months later by someone who does not know who Sam is,
  and `record-contract.md` gives them decisions rather than a transcript.
- **"We should probably…"** is not settled. It is either an open decision with
  what it blocks, or it is nothing — and asking which is cheaper than guessing.
- **A date with no decision attached.** A deadline belongs to `--plan`.

**Ask before writing when the block is large or the routing is genuinely
ambiguous** — list what you propose to file where, in one message, and let the
user correct it. A batch of ten misrouted entries costs far more to unpick than
one round trip, and the user has the meeting in their head right now.

**Everything here is still the flags' work underneath.** Intake decides the
routing; the writing is `--todo` and `--log` exactly as above, under whatever
grant the caller arrived with. Intake confers nothing of its own.

## Writing to `record.todo`

**Read the value first: it may not be a file.** Where `record.todo` is an object
carrying a `provider` key, the backlog lives somewhere else and the procedure is
that provider's — currently only
[`providers/github-issues.md`](../../workflow/providers/github-issues.md).
Everything below about *what an entry says* still applies; only where it is
written changes.

Three rules that survive the medium, and are the ones most easily lost:

- **An explicit deferral must be marked, because there is no section to put it
  in.** Where you would have filed the item under a `## Later` heading — the
  decision was "not now, revisit when X" rather than "do this in due course" —
  the issue body opens with `[later → X]`, exactly as a blocked item opens with
  `[blocked → …]`. This is not optional bookkeeping: `--start` reads issues
  newest-first, so an item parked seconds ago is the *first* thing it reaches
  for, and an unmarked deferral is reversed by the next session that runs it.
  Ordinary backlog items, the ones simply not scheduled yet, carry no marker.

- **The reasoning still goes to `record.decisions`, never into the item.** An
  issue body is not a decision log. Link to the decision from the item — and
  note that the file form's closing line, "Deferred — see the decision log",
  stops being a pointer the moment it is read on github.com rather than three
  files away. Give a URL or a repo-relative path that resolves from there.
- **Never fall back to a local file when the provider cannot be reached.** Say
  the item was not filed and name it, so it can be filed by hand. A project that
  declared a provider and finds a stray `TODO.md` appearing now has two
  backlogs, which is the failure the provider exists to prevent.

The rest of this section is the file form.

Pick the section it belongs to, or add one if none fits — don't force it
somewhere wrong. Check for an equivalent entry first and update rather than
duplicate.

A checkbox, a bold name, then the **technical** detail someone needs to actually
do it: file paths, table names, the shape of the fix, and the constraints that
would bite the implementer. **Not the argument for or against.**

```
- [ ] **Short name.**
      What it is, concretely. Which files/tables/endpoints.
      Constraints or gotchas that would bite the implementer.
      Deferred — see the decision log.
```

If a decision blocks it, mark it `[blocked → <what's undecided>]` pointing at
`record.openDecisions`.

**Never write the reasoning here.** That is the whole point of the split. A
backlog that carries its own arguments grows into a mixture of checklist and
essay that can no longer be scanned for what to do next, and the only fix at
that point is a full restructure.

## Writing to `record.decisions`

Append-only, chronological. Lead with a `**Decided:** …` line stating the
outcome, then what was proposed, what was chosen instead, and *why now is or is
not the time* — what complexity it avoids, or what it depends on to make sense.

Three rules that are not stylistic:

- **Record when the decision is made, not when it is built.** The opposite rule
  fails concretely: real design commitments end up in the backlog mixed with
  unbuilt sketches, and nothing distinguishes them.
- **Never rewrite a past entry.** An old entry describing a decision later
  reversed is *correct as written*; the later entry is what makes the record
  accurate. This is the one file exempt from "fix what is stale", and that
  exemption is why it can be trusted as a log at all.
- **Group a batch.** Several deferrals in one pass make one dated entry with a
  bullet each, not a dozen tiny ones.

**Then regenerate the index** with `commands.indexRegen`. It is generated, never
hand-edited, and a later `--check` fails if you skip it. Where the manifest
declares no index command, say the index was not regenerated rather than leaving
it silently stale.

## When a deferred item is later done

**Delete it from `record.todo`.** Don't strike it through — that record is
forward-looking only, and strike-through is what made one project's backlog
unreadable. What was built is recorded in `record.decisions`, `record.changelog`
and `record.reference`.

## What this skill does not do

- **It does not decide.** It records what the user decided. If you find yourself
  writing an entry for a choice nobody actually made, that belongs in
  `record.openDecisions` instead.
- **It does not touch `record.roadmap`** — that is `--plan`'s — or
  `record.changelog`, which is `changelog-writer`'s, or tags, which are
  `git-writer`'s and only ever on `--release`'s say-so. A task *about* releasing
  something is fine; a task that *is* a release is not.
- **`record.changelog` is the neighbour worth keeping straight.** `--log` records
  *why a choice was made*, for whoever maintains the project; a changelog records
  *what a user of the software notices*, keyed to a version. A refactor with no
  user-visible effect earns an entry here and no changelog line; a dependency
  bump users feel earns the reverse.
- **It does not judge whether the work is worth doing.** A known bug that will
  not be fixed now still gets logged — as a defect with reproduction steps
  rather than as a deferred idea. Those read very differently to whoever picks it
  up.
- **It is not the session task list.** That is `--track`: ephemeral, gone when
  the session ends. If something must outlive the session, it belongs here.

## Being invoked by something else

Orchestrators call this skill rather than writing the record themselves —
`--start` when it settles an open decision or removes a shipped item, `--stocktake`
when it dispositions a finding, `--check` when it dispatches one. That is not
politeness: a record file with several writers is how one table ends up copied
across several skills and one file ends up with several writers, which is the
problem this workflow was restructured to remove.

When called that way, the caller supplies the content and you own the placement,
the format, and the index.
