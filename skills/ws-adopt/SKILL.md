---
name: ws-adopt
description: "Bring a project under this workflow — map what already exists to the records the skills expect, and write its `.claude/workflow.json`. SHORTHAND: `--ws-adopt`. Also trigger on \"set up the workflow here\", \"create the manifest\", \"declare <key> in the manifest\", or when a skill reports falling back to conventional filenames."
---

# Adopting a project

Every skill in this workflow reads `.claude/workflow.json`, and only this skill
— through `manifest-writer`, which does the writing — ever creates one; without
it each skill degrades to conventional filenames and stays there. This skill is
the way out, and the **only** one that runs before the project is under the
contract at all.

**It writes the `permissions.ask` entries of step 5 and nothing else with content
in it.** The manifest itself goes through
[`manifest-writer`](../../workflow/writers/manifest-writer.md), which is its sole writer — this
skill decides what the values should be and hands them over. The keys it may ask
for are [`manifest.md`](../../workflow/manifest.md); who owns each record
afterwards is [`ownership.md`](../../workflow/ownership.md).

## What it is not

**Not a rewrite.** If a manifest already exists this is an *amendment*: read it,
report what it declares, fill only the gaps, and never overwrite a key the
project already chose.

**Not a documentation pass.** It creates record files *empty*, with their
heading and nothing else. Content is the owning skill's, always — an adopted
project with an empty backlog is correct; one with a backlog this skill invented
is a lie on day one.

**Not a judgement about the project.** It reports what it found and what it could
not resolve, and an unresolvable key is left **out** of the manifest: a missing
key degrades gracefully and says so, while a key pointing at the wrong file
misdirects every skill that reads it, silently.

## 1. Establish which mode you are in

`.claude/workflow.json` present → amendment. Absent → adoption. `--lane <name>`
in the request → worktree setup for a declared lane, which skips to its own
section below. Say which in one line before doing anything, because the modes
have different blast radii.

Also pin the tree — `git rev-parse --short HEAD` and `git status --porcelain`.
If the tree is dirty, say so and continue.

## 2. Detect the shape

Per [`project-shape.md`](../../workflow/project-shape.md). Report each signal
with the evidence that established it, not just the conclusion — the user is the
one who knows whether an inferred `service` is real or a stray dependency.

## 3. Find what already exists — search, do not assume

Conventional names are a starting guess, not an answer. A project that has been
running for a year has a backlog somewhere, and it is as likely to be
`docs/TODO.md` or `PLANNING.md` as `TODO.md`.

For each record in [`record-contract.md`](../../workflow/record-contract.md),
look for a file that already plays that role — by name, then by content. Report
the mapping as a table before writing anything, and mark each row **found**,
**ambiguous**, or **absent**. Ambiguous means two candidates; ask rather than
picking.

**A file that already holds the right content is the answer, whatever it is
called.** Renaming a project's files to suit the workflow is backwards — the
manifest exists precisely so that it does not have to.

**The backlog row is the one that may not be a file at all.** A team already
running on GitHub Issues has no `TODO.md` and never will, and the row comes back
**absent** for a project whose backlog is in fact busy. Before recording it as
absent, look: `gh issue list --limit 5` against the origin repo, and the labels
that come back. Open issues here mean the row is a **provider** question rather
than a missing file — carry it to step 7 rather than proposing an empty
`TODO.md`. The mapping is
[`providers/github-issues.md`](../../workflow/providers/github-issues.md).

## 4. Read the commands out of the project's own tooling

Never invent a command. Look in whatever declares them — the package manifest's
scripts, a Makefile, a task runner's config, CI workflow steps — and propose:

- `commands.typecheck`, `commands.test` (the **full** suite with coverage where
  one exists; a bare test run is not the same key)
- `commands.indexRegen` where anything generates an index
- `commands.ci` where a pipeline is configured

If the project has no test command, say so plainly and leave the key out.
`--ws-stocktake` treats an absent suite as a standing finding; that is the correct
outcome and it depends on the key being genuinely absent rather than wrong.

## 5. Propose `permissions.ask` for the commands that destroy state

Gating is deliberately not a manifest key — a stack's destructive commands
belong in the project's own `.claude/settings.json`, per
[`manifest.md`](../../workflow/manifest.md). `--ws-stocktake` checks for that gate
under `safety-nets`, so a project adopted without it starts life owing a
finding this step can settle while the tooling is already open.

Same sources as step 4, different question: which of the commands this project
*actually declares* destroy something expensive to rebuild — migration resets
and force-syncs, history rewrites, deploys against a shared environment, bulk
deletes against real data. Propose each with the line that declares it, in the
form settings uses:

```json
{ "permissions": { "ask": ["Bash(pnpm db:reset*)", "Bash(git push --force*)"] } }
```

**Only commands the project has.** A pattern matching nothing is noise; one
matching too much teaches the user to approve without reading, which is worse
than no gate.

Merge the approved entries into the **project's** `.claude/settings.json` —
never the user's global one — preserving every key already there, and say what
you added. Where the project already gates them, say so and change nothing.
Where nothing it declares destroys state, say *that*, so the answer is on the
record as considered rather than as an empty list.

## 6. Read the roles out of `.claude/agents/`

Where agent files exist, propose the `agents.*` mapping from what they actually
are — an agent named for reviewing infrastructure is `agents.infra`. Where none
exist, **leave `agents` out entirely.** Every skill already handles undeclared
roles by working inline or with a general-purpose subagent and saying so; a
guessed mapping sends work to an agent that was never written for it.

## 7. Ask only what cannot be inferred

Batch these with `AskUserQuestion` — four at a time, recommended option first.
Everything answerable from the repo should already be answered by now.

- **`record.todo` as a file or a provider** — ask only where step 3 found open
  issues. "Your backlog: a `TODO.md` in the repo, or the issues you already
  have?" Choosing issues needs the `repo` slug and a **label** — press for the
  label, because without one the backlog is every open issue including user bug
  reports, which is almost never meant. Say plainly that the file form is the
  battle-tested path and the provider is newer, so the choice is informed.
  Where step 3 found no issues, do not raise it: a project with one backlog does
  not need to be told it could have a different one.
- **`branch.integration` and `branch.publish`** — inferable from the current
  branch and the remote's default, but worth confirming; `--ws-wrap` pushes one of
  them.
- **`gate.coverage`** — only where a coverage tool is configured. Ask for the
  thresholds CI actually enforces, not aspirations.
- **`commitTrailer`** — offer `Claude-Session`; it is what `--ws-wrap` stamps and
  what makes concurrent sessions distinguishable.
- **`commands.testConsentEnv`** — only if the suite is gated behind a token.
- **`lanes.*`** — the paths where two concurrent edits collide. Worth asking
  only for projects that will use `--ws-start`; skip it otherwise and say so.
- **`lanes.named`** — only where the project is worked on from **several git
  worktrees at once**, or the user says it will be. One entry per lane with its
  `scope` globs, and the three splittable records redirected to lane files for
  **all** lanes or none — the resolution rule and the all-or-none constraint
  are [`manifest.md`](../../workflow/manifest.md)'s. A single-worktree project
  never needs this; do not raise it unprompted.
- **`hazards.*`** — where the project's known traps are already written, as
  `file#anchor`. Do not write the traps themselves; the manifest holds pointers.

**Do not ask about `audit.*`.** Both keys exist to override defaults that are
correct for a new adopter, and a question nobody can answer well on day one is a
question that produces a wrong answer.

## 8. Hand the manifest to `manifest-writer`

Everything above settled *what the values are*. Writing them is
[`manifest-writer`](../../workflow/writers/manifest-writer.md)'s, which validates each key
against [`manifest.md`](../../workflow/manifest.md), writes, and runs the doctor.

Hand it only keys with real, verified values. A key whose file you are about to
create in step 9 is fine; a key pointing at something aspirational is not, and
`manifest-writer` will refuse it rather than write it.

**Amendment mode reaches this step directly.** Adding or correcting one key in an
existing manifest needs no detection, no search and no questions — steps 2
through 7 are an adoption's work, not an amendment's.

## 9. Create the missing records — empty

For each record the project needs and does not have, create the file with its
canonical heading and nothing else. Say which you created.

**Nothing else goes in them.** Not a placeholder task, not an example decision,
not a "TODO: fill this in". The owning skill writes the first real line, and it
should be a true one.

Where the project genuinely does not need a record — no roadmap because it is a
library with no planned blocks — do not create it, and leave the key out.

**A record under a provider has no file to create.** Where `record.todo` is a
provider object, creating an empty `TODO.md` here would hand the project the two
backlogs the provider exists to prevent — the same fallback
[`providers/github-issues.md`](../../workflow/providers/github-issues.md)
refuses. Skip the row and say the backlog is provider-managed.

## `--lane <name>` — set up a worktree for a declared lane

Reached directly, like amendment — no detection, no search, no questions beyond
the two below. The manifest is the authority on what the lanes are
([`manifest.md`](../../workflow/manifest.md)'s `lanes.named`); this mode only
builds the checkout that selects one.

1. **The lane must be declared.** If `lanes.named.<name>` is absent, this is an
   amendment first: settle the lane map with the user — every lane, its scope,
   and the record split for all lanes or none — and hand it to
   `manifest-writer` before any worktree exists. A selector naming an
   undeclared lane is a `doctor.sh` failure, so order matters.
2. **Create the worktree** — `git worktree add <path> <branch>`, asking for the
   path and branch rather than inventing them. One lane, one worktree, one
   branch is the shape; the manifest is tracked and identical on every branch,
   which is what makes the lane files merge cleanly.
3. **Write the selector**: the lane name into `.claude/lane` **in the new
   worktree**, and ensure the project's `.gitignore` covers `.claude/lane` —
   it is per-checkout state, like the sweep checkpoint, and committing it
   would select the same lane in every checkout.
4. **Seed the lane records empty** — every `lanes.named.*.records.*` path that
   does not exist yet, heading and nothing else, exactly as step 9 creates the
   unsplit ones. All lanes' files, not just this lane's: a half-split is a
   `doctor.sh` failure.
5. **Honour `worktree.symlinkDirectories`** where the project's
   `.claude/settings.json` sets it — that key lives in settings, not the
   manifest, because it configures the harness rather than the workflow. Say
   which directories it linked, or that the key is absent.
6. **Prove it from inside the worktree**: run the doctor there and show the
   selector line. Then step 12's close-out, scoped to what this mode did.

Project bootstrap beyond that — env files, generated clients, dependency
installs — belongs to the project's own docs behind `hazards.*`, not here.

## 8b. An archive from another machine imports here — before any record is created

Where the user hands over an archive made by `export-records.sh` — the machine
change is the scenario — run its import **before** step 9, so restored records
count as existing and step 9 seeds only what is genuinely absent:

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/export-records.sh" ] || S=$(ls -d "$S"/plugins/cache/*/workflow-secretary/*/ 2>/dev/null | tail -1)
"$S"/export-records.sh --import <archive>
```

The order is load-bearing, not stylistic: import refuses to overwrite any
non-empty file, and a record step 9 has already seeded carries its heading —
so the other order refuses the very files the archive exists to restore. A
refusal therefore means this machine has real content the archive would
replace: show both sides and let the user choose `--force`, never choose it
for them. Do not ask for an archive when none was offered — most adoptions
have no other machine.

## 10. Prove it, do not claim it

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/workflow-secretary/*/ 2>/dev/null | tail -1)
"$S"/doctor.sh
```

Run it and show the output.

**If it fails, fix and re-run.** Adoption is not finished on a failing doctor:
every later skill trusts the manifest without re-verifying it. A failure in the
manifest itself goes back to `manifest-writer` — this skill does not correct that
file directly, however obviously right the one-line fix looks.

## 11. A project with no documentation gets handed to `--ws-docs`

Step 3 already searched for what exists. If it found no documentation — no
`docs/`, no site under another name, no renderer config — **invoke the `ws-docs`
skill** rather than noting the absence and moving on.

Bound it to the scaffold and the overview page.

**The grant it inherits is this skill's, not `--ws-docs`'s.** `--ws-adopt` authorizes
committing what it creates and `--ws-docs` alone authorizes nothing, so the
scaffold may be committed here and nothing may be pushed.

**Absent is not always missing.** A repository that is only tooling, whose
overview genuinely is its README, does not need a site — and `record.reference`
pointing at that README is the manifest saying so. Take the answer and record
it; do not scaffold something nobody will read. Where the project is unclear,
ask rather than deciding on its behalf.

## 12. Close out

Say, briefly:

- what the manifest now declares, and what `manifest-writer` left out and why;
- which files were created empty, and which skill fills each one first;
- what `permissions.ask` now gates, or that nothing the project declares
  needed it;
- the doctor result;
- the one next step — usually `--ws-check` to see what the record already gets
  wrong, or `--ws-plan` if the project has no roadmap yet.

**Then the cadence card, in full.** Say `--ws-flags` lists everything, then:

| When | Flag |
|---|---|
| Starting anything non-trivial | `--ws-track` |
| Deciding *not* to build something | `--ws-todo` |
| A decision with no task attached | `--ws-log` |
| Finishing a unit of work, or before `/clear` | `--ws-wrap` |
| Weekly, or after a refactor | `--ws-check` |
| Before a release, or when you stop trusting the record | `--ws-full-check` |
| Monthly, or when picking the project back up | `--ws-stocktake` |
| After editing any skill or agent file | `--ws-tools` |

**Name the three that pay on day one — `--ws-track`, `--ws-todo`, `--ws-wrap` — and say
the rest pay back over weeks.** An adopter handed a page of equal-looking flags
uses none of them; handed three, they use three.

Say plainly that nothing here nags: the SessionStart hook speaks only when a
sweep checkpoint has fallen far behind, so the cadence is theirs to keep.

Then have `git-writer` commit it. `--ws-adopt` authorizes committing what it
created and nothing more, and that grant is what the primitive inherits;
publishing is the user's call or `--ws-wrap`'s.
