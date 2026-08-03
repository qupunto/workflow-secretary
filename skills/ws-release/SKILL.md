---
name: ws-release
description: "Cut a release once `--ws-plan` has marked a milestone completed — confirm the version, have the changelog written, tag, push. SHORTHAND: `--ws-release`. Always asks before pushing. Also on \"cut a release\", \"tag this version\". TAGS AND PUSHES — not to be inferred from \"ship it\", which is approval, not a request to publish."
---

# Cutting a release

**This skill writes nothing.** It is the only one that may *decide* to tag, but
the tag itself is written by `git-writer`, the changelog by `changelog-writer`,
and the milestone mark by `--ws-plan`. Who owns what is
[`workflow/ownership.md`](../../workflow/ownership.md).

**Project facts come from `.claude/workflow.json`**: `record.roadmap`,
`record.changelog`, `record.audits`, `branch.publish`, and `agents.release` —
the agent that prepares the material. Without a manifest, fall back to
`CHANGELOG.md`, `ROADMAP.md` and the current branch, and say so. Where a
`.claude/lane` selector names a lane, `lanes.named.<lane>.records.todo`
overrides `record.todo` — [`manifest.md`](../../workflow/manifest.md)'s
resolution rule; the changelog and roadmap never split.

## The `--ws-release` shorthand

Invoking without confirmation is safe: everything up to the push is local and
reversible, and the push has its own gate below. Where a flag counts, and the
authorization it confers, is in `shorthand-flags.sh` and
[`README.md`](../../README.md).

## 1. The precondition is a mark, not a word

**A release requires a milestone marked completed in `record.roadmap`.** That is
the entire precondition and it is `--ws-plan`'s to write: checkable by reading one
file, and still true after a `/clear` — which a spoken approval is not.

Three cases:

- **Marked completed, no tag for it** — that is the release. Go.
- **Looks complete but is not marked** — do not tag it. Hand to `--ws-plan`, which
  asks the user and marks it, then come back. Marking it here would be writing
  another skill's record, and it skips the two disqualifier checks `--ws-plan` runs
  (an open blocking decision; unremediated high-severity audit findings).
- **Nothing marked completed** — say so and stop, unless this is a patch on an
  already-tagged version (§4), which needs no milestone.

Never infer the milestone from recent commits.

## 2. Check that everything is in order before releasing on top of it

**Invoke `--ws-full-check`.** A tag is a claim that the tree it names is sound, and
this is the last point at which that claim is cheap to test. It runs the
project's mechanical checks, re-reads every record, docs page and tooling file at
full scope, and dispatches what it finds to the owner of each file.

Release drift is one of the dimensions it covers: what `record.roadmap` and
`record.changelog` claim shipped, against what `git tag` actually resolves,
locally and on the remote. Do not reimplement that comparison here — a second
copy of a check is a second thing to keep true.

`--ws-full-check` rather than `--ws-check`, deliberately. The incremental sweep trusts
whatever `covered` list an earlier run wrote, and a release is exactly the moment
that trust should not be extended: a checkpoint written before the work being
tagged is the one that would license skipping the files it changed. Releases are
rare enough to afford the full run, and it subsumes `--ws-check` — invoking both
pays twice for the same answers.

It does
spend the session's one consented test run where the project gates its suite
behind `commands.testConsentEnv`; that is the right place to spend it.

**Drift is a release decision, not cleanup.** The usual shape is a document
describing a shipped version that no tag resolves, and there are two honest
outcomes — tag the commit that milestone completed at, or record the work as
unreleased. **Ask which.** Retro-tagging a guessed boundary is worse than
recording plainly that a version was never tagged. Whichever the user picks,
the write goes through the file's owner.

**A health check that comes back red stops the release.** Not because a tag
cannot be cut on top of a known failure, but because the decision to do so is the
user's and needs to be made in words rather than by omission. Report what failed
and ask.

## 3. Prepare — delegate this

Hand the manifest's `agents.release` the milestone being released and have it
return: the version bump it proposes and why, the changelog entry text, and any
drift it found. It reads `record.roadmap`, `record.changelog`, `record.todo`,
`record.audits` and the git history; letting it do that in its own context keeps
several thousand tokens of history out of yours.

Where a project declares no release agent, do the reading here and say that you
did — it costs context, and the user should know why this turn was expensive.

Sanity-check what comes back rather than pasting it through — the version
number and the user-visible framing are the two things worth your own eyes.

## 4. Version

Semantic versioning. Below `1.0.0` the leading zero is doing real work:
**deployed** is not **stable**, and a pre-1.0 project may still change its data
model or API incompatibly.

- Completed milestone → **minor** (`0.1.0` → `0.2.0`). The roadmap already names
  the version the milestone intended to ship as — **confirm that number rather
  than deriving a new one**, and if you disagree with it, say so and ask.
- Fix or small adjustment on an already-tagged version → **patch**. No milestone
  needed; this is the one release that does not come from the roadmap.
- `1.0.0` is an explicit decision by the user, never inertia.

Unsure? Ask. A wrong version number is permanent in a way a wrong commit
message is not.

**Where the tree is a plugin — `.claude-plugin/plugin.json` exists — bump its
`version` to the confirmed number in the same change as the changelog entry,
before the tag is cut.** The plugin cache path keys on that field
(`plugins/cache/<marketplace>/<plugin>/<version>/`), so two vintages published
under one version overwrite one directory instead of sitting side by side —
and the Publish action assembles from the tagged commit, so a bump landing
after the tag ships a tree claiming the previous version. `doctor.sh` warns
when the manifest trails the newest tag; audit pass 10 found it two tags
behind with no owner (F2), which is why this step exists.

## 5. Have the entry written, commit, then stop

**Invoke `changelog-writer`** with the version, the date and the material from
§3. It owns `record.changelog`; do not write that file here even when the entry
is one line and the agent already drafted it. Then have `git-writer` commit it —
the history is its record, and this skill does not write one by hand.

`record.roadmap` already marks the milestone completed — that was the
precondition, and it is `--ws-plan`'s file. Do not edit it here either.

Then **stop and show the user exactly what is about to go out**: the commits,
the tag name, and the branch. Wait for an explicit OK **in that turn** — not one
inherited from earlier in the conversation, and never implied by the milestone
mark. Completing a milestone and publishing a tag are two decisions.

Before showing it, run `git log origin/<branch>..<branch>` and say plainly if
it contains commits this session did not make. A push publishes a whole ref,
so another session's work rides along.

## 6. Tag and push, once confirmed

**Hand the tag name, the message and the branch to `git-writer`**, telling it
the OK was given in this turn — it will not tag otherwise, and it holds the
rules against forcing, amending and skipping hooks. This skill obtains the
confirmation; that skill performs the act.

## 7. Close out

Say what shipped, at which tag, and what the next milestone is per
`record.roadmap`. If the release surfaced anything unresolved — drift you
corrected, a milestone that wasn't as complete as its mark claimed — say so
here.

## What this skill does not do

Who owns what is [`ownership.md`](../../workflow/ownership.md); what each record
holds is [`record-contract.md`](../../workflow/record-contract.md).

- **It does not mark a milestone completed.** That mark is this skill's
  precondition, not its output.
- **It does not write the changelog entry.** It supplies the version and the
  material to that file's owner and never edits the file.
- **It does not commit, tag or push by hand.** Those go through the history's
  owner, which will not tag or push without being told the confirmation was
  given in that turn.
- **It does not prepare its own material** where the project declares
  `agents.release`.
