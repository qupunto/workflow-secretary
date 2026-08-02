# Writing the changelog

> **A procedure, not a skill** — see [`README.md`](README.md). Sole writer of `record.changelog`, per [`ownership.md`](../ownership.md).

**Sole writer of `record.changelog`.** Everything else in this workflow that
needs it changed calls this skill; who owns what is
[`~/.claude/workflow/ownership.md`](../ownership.md), and what this
file may and may not hold is
[`record-contract.md`](../record-contract.md), which is the
authority if the two ever disagree.

**Project facts come from `.claude/workflow.json`**: `record.changelog` is the
file, falling back to `CHANGELOG.md` — say in one line that you used the
fallback. `record.roadmap` is where a version number comes from when a caller
does not supply one. A project that declares neither and has no `CHANGELOG.md`
has no changelog: say so and write nothing rather than creating one, because
which projects keep a changelog is a decision, not a default.

**No flag of its own**, on the same reasoning as `handoff-writer` and
`sweep-tracker`: nobody wants "write a changelog entry", they want a release cut
or a false claim corrected. This is the step inside those.

## Not the decision log

The nearest neighbour is `--log`, and the two are easy to collapse into each
other because both are dated, append-only histories. They have different
readers, and that is the whole test:

| | `record.decisions` (`--log`) | `record.changelog` (this skill) |
|---|---|---|
| Answers | why a choice was made | what a user of the software notices |
| Read by | whoever maintains the project | whoever consumes it |
| Keyed to | a date | a version |

They come apart in both directions, which is why one file cannot serve both. A
refactor with no user-visible effect earns a decision entry and **no changelog
line**. A dependency bump users feel earns a changelog line and **no decision
entry**. Something can earn both — but never for the same reason, so neither
entry is a copy of the other.

The failure to watch for is a changelog entry that starts explaining *why*. That
is a decision entry in the wrong file, and it makes the changelog unscannable
for the one question it exists to answer.

## Form

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/): newest version first,
grouped **Added / Changed / Fixed / Removed**. Omit an empty group rather than
writing "none".

Each line describes the change **from outside** — what a user can now do, or
what stopped happening to them. Not the file that changed, not the mechanism.
If a line cannot be written that way, it is a strong sign the change belongs in
`record.decisions` instead and nowhere here.

## The unreleased status is a real state

`record.changelog` holds released versions, so an entry describing a version
that no tag resolves is a false claim, not a formatting problem. The contract
declares a [status field](../record-contract.md#status-fields) for
exactly this: an entry may be marked unreleased in place, and doing so is
sanctioned rather than a breach of append-only.

**Never invent a tag boundary to make the claim true.** Recording plainly that a
version was never tagged is better than retro-tagging a guessed commit — the
first is honest and reversible, the second is permanent and probably wrong.
Which of the two happens is the user's call, and `--release` is where it gets
asked.

## Scope: do what the caller asked for and stop

| Called by | Write |
|---|---|
| `--release` | The entry for the version being cut, under the version and date the caller supplies |
| `--check` | The one drift finding it dispatched — re-verified first — usually marking an entry unreleased |

**Re-verify a dispatched finding against `git tag -l` before changing anything** —
that is what settles a release-drift claim here. The rule is
[`ownership.md`](../ownership.md#the-inspector-writes-nothing).

**Write what was asked and stop.** No version bump, no tag, no commit — a caller
that wanted a release would have run `--release`.

## What this skill does not do

- **It does not decide the version.** The number comes from the caller, which
  gets it from `record.roadmap` for a milestone or derives a patch. If a caller
  supplies none and the roadmap names none, ask rather than deriving one.
- **It does not tag, commit or push.** Tags are `--release`'s and nothing else
  in this workflow writes one. The caller commits under the caller's grant; this
  skill confers nothing, so dispatched from `--check` it writes the file and
  stops there.
- **It does not write any other record.** Reasoning goes to `record.decisions`
  via `--log`; a milestone's completion is `--plan`'s mark.
