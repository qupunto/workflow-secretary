---
name: ws-plan
description: "Plan and maintain the project's roadmap — milestones and the blocks inside them, their order, when one splits, and when a milestone is complete enough to mark. Marking one is what authorises `--ws-release` to tag it. SHORTHAND: `--ws-plan`. Also trigger on \"what should we build next\", \"is this milestone done\", \"reorder the roadmap\"."
---

# The roadmap

`record.roadmap` holds **milestones**, and inside each, the **blocks** that make
it up and the order they happen in. This skill is its sole writer.

A **milestone is the unit that ships.** It carries the version it intends to
ship as, and marking one completed is the only thing in this workflow that
authorises a tag. That intended version is a *plan*: `--ws-release` confirms the
number and is the only thing that turns it into a tag or a changelog entry.

It is **not** a task list and **not** a place for design arguments. The
checklist is `record.todo` and the reasoning is `record.decisions`, both
`--ws-todo`/`--ws-log`'s.

**Project facts come from `.claude/workflow.json`**: `record.roadmap`,
`record.todo`, `record.openDecisions`, `record.decisionsIndex`, `record.audits`,
and `agents.roadmap`. Without a manifest, fall back to `ROADMAP.md` and say so.
Where a `.claude/lane` selector names a lane, `lanes.named.<lane>.records.X`
overrides `record.X` for `todo` and `openDecisions` —
[`manifest.md`](../../workflow/manifest.md)'s resolution rule; the roadmap
itself never splits.

Who owns what is [`workflow/ownership.md`](../../workflow/ownership.md);
what each record holds is
[`record-contract.md`](../../workflow/record-contract.md).

## Why this is a skill and not only the agent

Same split as `--ws-release` and for the same reason. The agent named in
`agents.roadmap` does the reading — the roadmap, the backlog, the decision
index, the audit log, the git history — and returns a proposal.

But **completing a milestone requires asking the user, in conversation, and
waiting for the answer.** A subagent has no channel for that; it can only return
a report. So the reading is delegated and the asking stays here.

Where a project declares no roadmap agent, do the reading yourself and say that
you did, since it costs context the user should know about.

## Before proposing anything, check the real state

- `record.roadmap` — what is in progress, next, and completed.
- `record.todo` — so you don't propose as a "next block" something already
  deliberately deferred.
- `record.decisionsIndex` — one line per settled decision. Go through the index,
  never the decision log itself, which can run to tens of thousands of tokens;
  open an entry only when you need its reasoning.
- `record.openDecisions` — **a block whose blocking decision is still open is
  not ready to start.** Say so rather than scheduling it anyway.
- `record.audits` — a milestone carrying unremediated high-severity findings is
  not a candidate for completion.

## Deciding a milestone is done

Checking a block off as it lands is bookkeeping. **A milestone completing is the
decision**, and it is the one this skill exists to get right.

The user decides — but **you ask at the moment the last block lands.** Do not
wait to be told; nobody volunteers the word, and a milestone nobody asks about
is a release that never happens.

So, when the final block of a milestone is checked off:

1. Say what the milestone claimed to cover, what actually landed, and what is
   still open against it.
2. Name either disqualifier if it applies — **an open blocking decision**, or
   **unremediated high-severity audit findings**. Both are worth catching here,
   because the alternative is a release discovering them.
3. Ask, once, in conversation.
4. On yes, **mark it completed in `record.roadmap` with its version**, then hand
   to `--ws-release` and stop.

**The mark is the durable form of the answer** — a spoken "yes" does not survive
a `/clear`.

Versions, the changelog and tags themselves are not yours.

## Keeping the file honest

- Blocks move between in-progress, next-up and completed. A block that has
  quietly stopped being worked on belongs in neither of the first two without a
  note saying why.
- **Every block belongs to a milestone.** A block with no milestone can never
  ship, because nothing will ever mark it complete.
- **A milestone is a version's worth of work**, not a release-day checklist. If
  it has grown to where completing it is implausible, split it — two shipped
  minors beat one milestone that stays open for months.
- When an audit reorders priorities, a finding severe enough to jump the queue
  gets its own block.
- **A roadmap block is a paragraph; a lane needs a file list.** When a block is
  ready to start, do not improvise its task breakdown here — that is
  `--ws-todo`'s, which owns `record.todo` and the format it needs.

## State claims rot, and this file is read to set priorities

`record.roadmap` is read to set priorities, which makes a false claim in it
unusually expensive: it does not just misinform, it redirects work. So "nothing
does X" and any count go through
[`record-contract.md`](../../workflow/record-contract.md#negative-claims) before
they are written here, and a finding dispatched about this file gets the
re-verification in
[`ownership.md`](../../workflow/ownership.md#the-inspector-writes-nothing) before
it is acted on.
