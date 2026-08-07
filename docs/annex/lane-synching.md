# Lane synching

How work crosses between lanes without any lane writing another's records.

This page documents the **mechanism**. It is not a log of synch runs — each run
records itself in `record.audits`, which is where "what was examined, when,
against which commit, and what was found" belongs. A page carrying one run's
actions would be stale the moment the next run happened, with nothing to
re-derive it.

## The problem lanes create

Worktree lanes divide a project so that concurrent sessions cannot collide.
What they cannot divide is the **dependencies between the work**. A plan in one
lane changes a data shape, an endpoint or a contract another lane builds
against — and nothing in the ordinary flow surfaces that until somebody hits it
at the worst moment.

The naive fix is to let a lane write into the lane it depends on. That breaks
the invariant every record in this suite rests on: one writer per file.

## The transfer queue

Each lane declares an **inbox** — `lanes.named.<lane>.transfer` — that every
*other* lane may append to.

| | A record | A transfer queue |
|---|---|---|
| Writers | exactly one | any lane |
| Holds | state | messages in flight |
| Steady state | whatever it says | **empty** |
| Consumed by | nothing — it is read | the owning lane's `--ws-start` |

**It is declared beside `records`, never inside it**, and the nesting is the
argument: everything under `records` has one writer, and a queue has many.
`doctor.sh` fails on `transfer` appearing under `records`, and on a queue
declared for some lanes but not all — a lane without one is a lane nothing can
file to, so the request goes into its records by hand instead, which is the
second writer the queue exists to prevent.

**Append-only is what makes many writers safe** — an append is additive, so a
wrong entry is merely wrong and nothing true is lost. **One consumer is what
keeps the records' invariant intact**: an entry becomes part of `record.todo`
only when that lane's own session moves it there.

### An entry

```
## [todo] <one-line summary>
From: <originating lane> · <what it came from>
Why: <what makes this the receiving lane's work>
```

`[todo]`, `[openDecisions]` and `[roadmap]` are the only targets — three of the
four splittable records, since a lane's handoff is written by that lane alone
and nothing files into it. One queue serves all three, so the entry names where
it is bound rather than the filename implying it.

**A queue entry is a request, never an instruction.** The receiving lane's
session decides whether it belongs, and declines it with a line saying so rather
than dropping it silently.

## The conflict inbox — the second queue

A transfer queue is addressed to a **lane**. The conflict inbox is addressed to
a **skill**.

`lanes.conflicts` is one file per project — not one per lane, because a
contradiction between two lanes belongs to neither, and filing it to one of them
would pick a side before anyone has ruled. Any session that trips over one while
doing something else appends to it; `/ws-lanes-records-synch` is the only thing
that consumes it.

```
## <one-line statement of the contradiction>
Lanes: <one lane> vs <the other>
Found: <the lane that filed it> · <what it was doing when it noticed>
Claim: <what each side's record says, cited so it can be checked>
```

**A filed entry is a claim, not a conflict.** The skill re-verifies it against
what the records say now before promoting it into mediation — a meaningful share
of filed findings do not reproduce, and one already resolved reads exactly like
one still live. What the reporting session contributes is evidence; the verdict
belongs to the run.

An entry leaves the inbox either way — promoted into mediation, or deleted with
the reason it did not reproduce. **Both movements go in the run's report**, and
the deletions are the half that matters most: they are how a session that filed
something wrong ever finds out, and a run reporting only promotions is
indistinguishable from one that rubber-stamped everything it was handed.

**A lane session files rather than resolves.** One lane cannot mediate between
two, and picking whichever reading unblocks the current batch is how one lane's
assumption quietly becomes the project's.

## Delivery rides the integration branch

A lane appends on its own branch. The entry reaches another worktree only once
the writing lane has landed on `branch.integration` and the receiving lane has
synced forward.

```
lane A appends → --ws-wrap lands A on integration → lane B's --ws-start
                 (fast-forward, or refused)         syncs forward, then drains
```

So a queue that looks empty on a lane which has not synced forward proves
nothing. `--ws-start` drains **after** the sync-forward and **before** anything
reads a record, which is why that ordering is stated rather than incidental.

Two lanes appending to different queues never collide. Two appending to the
*same* queue conflict at end-of-file and resolve as "keep both" — the trivial
case the append-only records already accept.

## Priority: one marker

`[critical → why]`, on the first line of an entry's body, the same place and
shape as `[blocked → …]` and `[later → …]`. `--ws-start` takes critical items
before any section ordering applies. Everything else is unmarked.

Two levels rather than four because dependency ordering already outranks
priority when a batch is partitioned, so finer grades mostly lose to it — and
every extra grade is a judgment call paid on every write, with "mid" and
"unmarked" meaning the same thing in practice.

**A lane may not mark its own request critical in another lane's queue.** The
marker is written only where the **user** said so in that turn — a mediated
conflict, or an *accept as critical* ruling. Priority inflation is the standard
failure of every ladder, and here it is worse than usual: a lane marking its own
asks critical is one lane setting another lane's order. The user setting it is
not that, which is why the rule names the writer rather than the route.

## `/ws-lanes-records-synch`

The skill that finds what to file. **Slash-invoked only** — no flag, no
`commands/` wrapper, no dispatch from another skill — because the run is
expensive and it writes into every lane's inbox.

It runs from the **main checkout only**. A lane worktree sees a sibling only as
`branch.integration` last delivered it, so a run from there reads a stale
partial picture while producing findings that look complete.

Four steps:

1. **Analyze** every lane's `todo`, `openDecisions` and `roadmap` together,
   separating **conflicts** (two records that cannot both be right, now) from
   **dependencies** (one lane's plan implying work in another, later).
2. **Mediate the conflicts first**, before anything is integrated — a
   dependency derived from a record that is wrong is a dependency derived
   twice. Resolutions are filed to every affected lane's queue as `critical`.
3. **Present every dependency for an explicit ruling**, lane by lane and within
   each lane by target record, showing which record it was derived from and why
   it is this lane's work.
4. **Record the run** through `audit-writer`, and the declines through
   `--ws-log`.

### The four rulings

| Ruling | Files to the queue | Next run |
|---|---|---|
| **Accept as critical** | yes, with `[critical → why]` | — |
| **Accept** | yes, unmarked | — |
| **Defer** | no | **asks again** |
| **Decline** | no | **does not ask** |

**Defer and Decline file the same thing — nothing — and that is where the
resemblance ends.**

*Defer* means the derivation is right and the timing is wrong, so the next run
finding it again is exactly the behaviour wanted. It is remembered nowhere, and
needs no machinery.

*Decline* means the derivation is **wrong** — not that lane's work, or a
mistaken inference. Re-deriving it every run would ask the same wrong question
forever, and **a gate that asks a wrong question repeatedly stops being a
gate**: the user learns to clear the prompt, which costs the approvals that
matter. So a decline is written to `record.decisions` — one entry per run, since
they were ruled on together — and step 1 reads `record.decisionsIndex` and drops
anything already declined.

A decline is permanent **by record, not by machinery**. Nothing detects that the
source changed and the derivation became valid again; reversing it is a later
decision, logged as one, which is how every other reversal here works.

### Why the approval is mandatory

An item filed without it arrives in a lane's records looking exactly like work
the user asked for, and the receiving session has no way to tell it was derived.
It would then be built, and defended, as though somebody wanted it. **Derived
work is a proposal until a person says otherwise**, and the gate is the only
place a person is present.

Which is also why rulings are never batched into one prompt: the whole risk is
that some items are stale or wrong, and one answer cannot separate them. And why
declining and deferring are offered separately — collapsing them loses the only
distinction that changes what the next run does.

## Eligibility and priority are separate axes

- **Priority** comes from the marker.
- **Eligibility** comes from provenance. An entry that passed the synch approval
  gate was already ruled on, so it is eligible for the receiving lane's batch as
  soon as `--ws-start` drains it. An entry a lane appended outside that gate is
  drained, announced, and waits a run — an inbox is not a gate.
