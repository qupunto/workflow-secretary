---
name: full-health-check
description: "Verify a project is in order end to end — run its mechanical checks, re-read every record, docs page and tooling file at FULL scope ignoring every checkpoint, triage the defect inbox, prune prose, refresh the catalog. SHORTHAND: `--full-check`. Also trigger on \"check everything\", \"is this config still sound\", \"triage the bug reports\", \"I don't trust the record any more\"."
---

# The full health check

The counterpart to the incremental sweeps. `--check`, `--docs` and `--tools`
each narrow themselves to what has moved since they last ran, which is what makes
them affordable to run often — and which means every one of them is trusting a
`covered` list some earlier run wrote.

**This is the run that trusts nothing.** It re-reads every functional file from
scratch, and the checkpoints it leaves behind are what the next weeks of cheap
sweeps rest on. Run it when a checkpoint might be wrong, when a large refactor has
landed, before a release, or on any tree you have not swept in a long time.

Who owns what is [`ownership.md`](../../workflow/ownership.md); what each record
holds is [`record-contract.md`](../../workflow/record-contract.md); the checkpoint
format is [`sweep-checkpoint.md`](../../workflow/sweep-checkpoint.md).

**Project facts come from `.claude/workflow.json`** — `record.*`,
`commands.typecheck`, `commands.test`, `commands.testConsentEnv`,
`commands.indexCheck`. Without a manifest, fall back to conventional names, skip
what you cannot resolve, and say so in one line rather than guessing.

## What it covers, and what it deliberately does not

**Files with functional value** — ones a reader acts on, and that are therefore
wrong rather than merely old when they stop matching reality:

| Covered | Checked for |
|---|---|
| `record.todo`, `record.roadmap` | items already done, claims about state, ordering that no longer reflects dependencies |
| `record.behaviour`, `record.reference` | claims contradicted by source; updates the code owed and never got |
| `record.handoff` | resolved warnings still present, pointers that no longer resolve |
| the docs site | every check in `--docs` audit mode, including the page-by-page accuracy pass |
| `record.tooling.catalog` and its sources | skills and agents that no longer exist, mutable claims that should be deleted, prose that changes nothing |

**Where `record.todo` names a provider it is still covered, and read in full.**
The questions are the same — items already done, claims about state — but the
backlog is a set of open issues rather than a file, per
[`providers/github-issues.md`](../../workflow/providers/github-issues.md).
There is no narrowing to apply and none is wanted here anyway: this flag ignores
checkpoints by definition. Where `gh` cannot reach it, say the backlog was not
checked and why; never read a local file in its place.

**Append-only logs are out of scope, and this is not an omission.**
`record.decisions`, `record.audits` and `record.changelog` are records of what was
true when written. An old entry describing a decision later reversed is **correct
as written** — the later entry is what makes the record accurate. There is nothing
to re-verify, and "fixing" one destroys the only history there is.

The one thing worth checking about a log is that it is *generated* correctly where
it has an index: run `commands.indexCheck` and dispatch a stale index to `--todo`.

**Code and project position are out of scope.** The public interface, the safety
nets and the backlog rebuild are `--full-stocktake`'s, and correctness, security
and the data model belong to a project's own code-analysis skill, which that flag
invokes. Running both against one request pays twice for the same answers. If the
question is "where is this project", that is the flag to use. This one asks
whether **what we have written down about the project is still true** — and
whether the machinery that would tell you otherwise still runs.

## Procedure

### 1. Pin the tree and say what full scope means

`git rev-parse --short HEAD` and `git status --porcelain`. Dirty paths are audited
as they stand and recorded as `not-covered` — a file verified in a state no sha
addresses cannot license a later skip.

Then state, in three or four lines: which files are in scope, that every checkpoint
is being ignored, and roughly how much there is. This is the expensive run; the
user should be able to stop it before it starts.

### 2. The mechanical half, first

Cheap, already written, and never run in part. It goes first because the tree is
still clean at this moment — the one point in this skill where a carry-forward can
fire, and the last point before anything here causes an edit.

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/workflow-secretary/*/ 2>/dev/null | tail -1)
"$S"/doctor.sh          # always; it validates this project's manifest too
<commands.typecheck>
<commands.test>
```

**The doctor is not optional and is not covered by any checkpoint.** It inspects
both the configuration and the project in `$PWD`, and it catches the failures that
read exactly like working config — dangling skill references, section citations
that resolve to nothing, a flag mapped to no skill, a manifest key no skill reads,
a record path that no longer exists, a checkpoint claiming a baseline that is not
a commit.

**Before the suite, ask `sweep-tracker` for the `test-run` entry.** When it
licenses one, skip the run and report the previous result and count, saying
plainly that it was carried forward rather than re-run. The conditions, and the
two things that void them, are
[`sweep-checkpoint.md`](../../workflow/sweep-checkpoint.md)'s. Ask the tracker
rather than reading the checkpoint file: it has exactly one reader and writer.

Where `commands.testConsentEnv` gates the suite behind a token only the user can
supply, there is **one** attempt in a session. Ask for it here, and say what the
run would cost if refused. A refusal is not a blocker — it makes the suite
`not-covered` and everything below still runs.

Fix anything either one reports before going further. A later phase editing files
while the hook or the doctor is broken compounds a failure nobody can see.

### 3. Fan out — one reader per area, concurrently

One subagent per area, all in a single message so they run concurrently:
**records**, **the docs site**, **the tooling files**. Give each its file list
and its brief:

- **Records** — [`workflow/checks/record-drift.md`](../../workflow/checks/record-drift.md),
  at full scope, with every incremental narrowing ignored.
- **Docs site** — [`workflow/checks/docs-audit.md`](../../workflow/checks/docs-audit.md),
  every section, over every page — the incremental narrowing lives in `--docs`
  and is simply not applied here.
- **Tooling** — [`workflow/checks/tooling-claims.md`](../../workflow/checks/tooling-claims.md),
  over every file in `record.tooling.sources`.

Hand each reader the file, not a skill. These three were reached by citing
another skill's headings until 2026-08-02, which broke silently on a rename and
left the borrower reporting success over checks it never ran.

**Delegate reading, keep deciding.** A subagent's context is discarded when it
returns, so only its verdict costs you anything. Readers **report**; they do not
fix, and they do not write.

### 4. Triage the defect inbox

`bug-reports.md` in the config directory — defects in this suite's own skills,
contracts and scripts, found by sessions working in other projects, which were
forbidden to fix them and filed instead, per
[`ownership.md`](../../workflow/ownership.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session).
`doctor.sh` counts the open entries; nothing else reads them, and the session
that wrote one is long cleared.

**In scope only when this project *is* that configuration directory.** From
anywhere else, filing is the whole action a session may take —
[`ownership.md`](../../workflow/ownership.md) is the authority, and triaging
another repository's inbox from this one's session is the same mistake one
indirection along. Say in one line that it was skipped and why.

For every `[open]` entry below the append marker:

1. **Check whether it is stale.** Compare its `Config commit` against the cited
   file now. If the file moved since, the defect may already be fixed — and
   re-reporting a closed finding is how a live instance of the same class one
   file away gets masked.
2. **Re-verify it.** Read the cited lines
   ([`ownership.md`](../../workflow/ownership.md#the-inspector-writes-nothing)).
   Where the claim is negative — "nothing does X" —
   [`record-contract.md`](../../workflow/record-contract.md#negative-claims)
   applies.
3. **Route it** with the rest of this run's findings, in step 6 — it is a finding
   like any other, and its owner is looked up the same way.
4. **Close it.** `[open]` becomes `[done]` when the fix lands, and the commit
   says what it was. Delete the entry outright if it did not reproduce, naming in
   the commit what was claimed and why it is false — a wrong report is
   calibration, and dropping it silently teaches nobody anything.

**An empty inbox is a result worth reporting.** "Nothing was filed" and "I did
not look" are different sentences, and only one of them is ever implied by
silence.

### 5. Verify before anything reaches the user

Re-check each finding against the cited file and line
([`ownership.md`](../../workflow/ownership.md#the-inspector-writes-nothing)), and
settle every negative claim with the grep that would disprove it
([`record-contract.md`](../../workflow/record-contract.md#negative-claims)).

Deduplicate: the same drift found by two readers is one finding with two citations.

### 6. Dispatch — this skill writes nothing

Group by owner and hand each finding to the skill that owns that file, per
[`ownership.md`](../../workflow/ownership.md). The owner re-verifies and writes
under its own rules. `--full-check` grants nothing, so **an owner it invokes writes
its file and does not commit** — the grant a skill inherits is the caller's.

**A file with no owner in the matrix is ordinary work in this project**, not a
claim of ownership: edit it directly and say what changed. Scripts, CI, the
harness settings and the `workflow/*.md` contracts are the usual instances.

**A finding about the shape of the workflow rather than a defect in it is not a
finding.** Say so and leave it for a deliberate change.

### 7. Prune, then refresh the catalog

**Invoke `prune-skills` after the dispatch, not before.** The ordering is written
down because it is the part that would otherwise be got wrong:

- **After the fixes**, because a fix written in step 6 adds its own justification
  in the house style — exactly the prose the prune exists to catch. Run it first
  and it judges the files as they were before this run touched them.
- **After the doctor**, because a prune that deletes a cited heading needs the
  citation check to have been green beforehand, or you cannot tell which run
  broke it.

It reports and dispatches; it does not cut. `--tools` makes the cut after its own
second look.

Then hand `record.tooling.catalog` to `--tools`, which owns it: add, edit or
remove a row for anything this run created, renamed, retired or changed the
purpose of. Refreshing it *here* is what keeps it honest. A catalog is an
inventory, and an inventory is exactly the mutable claim this workflow forbids
everywhere else; it is allowed in that one file only because something
re-derives it on a schedule. Left to fire only when a skill happens to change, it
drifts silently.

### 8. Re-verify mechanically

Every step above may have edited the files that make this project work, so run
step 2's commands again. All must pass. A health check that leaves the hook or
the doctor broken has done more damage than the drift it went looking for.

**Run the suite here unconditionally, including when step 2 carried it forward.**
That carry-forward was licensed by the tree as it stood *before* the edits; it
says nothing about the tree they left. A final verification inherited from before
the edits it exists to verify certifies nothing. Where consent was refused or
already spent, say plainly that the suite did not re-run and that the tree is
therefore unverified by it.

**Do not stamp the test run from here, ever — not even when the tree happens to
be clean.** The steps above edit files and this skill does not commit, so any run
that changed anything reaches this point dirty; `sweep-tracker` would record the
baseline as `<sha>+dirty`, which can never satisfy a carry-forward. The rule is
unconditional so nobody has to judge tree state mid-run, and the only thing a
conditional stamp could buy is a warm cache after a run that changed nothing. The
asymmetry with step 2 — resolve there, no stamp here — is deliberate.

### 9. Stamp the checkpoints — this is the payoff

Hand `sweep-tracker` one entry per sweep — `record`, `docs`, `tooling`, and
`health` for this run as a whole — with this tree's sha, `method: full`, and per
scope what was genuinely covered.

**The `health` entry is what makes this skill visible when it is overdue.** The
session hook nudges on any checkpoint whose baseline has fallen far behind `HEAD`,
so without an entry of its own the one run that verifies everything is the only
one nothing ever asks for. Its scopes are this procedure's own areas —
`mechanical`, `records`, `docs`, `tooling`, `inbox` — and an area that was skipped
or refused is `not-covered`, which is what makes the next nudge honest.

**Only what was read.** An area whose reader died, ran out of context, or returned
a report vague about which files it opened is `not-covered`, and the honest cost of
that is that those files get swept again next time. A full check that stamps
coverage it did not earn is worse than no check at all, because every incremental
sweep after it inherits the lie and nothing downstream can detect it. The rules are
[`sweep-checkpoint.md`](../../workflow/sweep-checkpoint.md).

### 10. Report

What was checked, what was found, what was dispatched to whom, what the inbox
held, what the prune proposed, what changed in the catalog, and **what came back
clean** — clean is a result, and a reader cannot otherwise tell it from "never
looked at".

**Name what you did not cover.** A prune that read four files out of fifteen has
covered four; saying so is the difference between a health check and a claim of
one. Name anything left `not-covered` and why.

## What this skill does not do

- **It changes no code, and writes no record file.** Every write goes through the
  owner, in the owner's own commit.
- **It does not audit source.** Running the project's own checks is not the same
  as reading its code; that is `--full-stocktake`.
- **It does not touch the append-only logs**, beyond checking that a generated
  index is current.
- **It does not commit or push.** Whatever grant the invoking flag carried
  applies; invoked bare, it carries none.
