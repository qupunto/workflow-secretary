# The project manifest — `<project>/.claude/workflow.json`

**The one authority on what a manifest may contain.** The skills are global; this
file is how a project tells them its own paths, commands and roles. Before it
existed the shape was implied by whatever each skill happened to read, and the
skills disagreed — two names for the same command, keys depended on but defined
nowhere, one value documented as both a string and an array.

Who may write each record is [`ownership.md`](ownership.md); what each record
holds is [`record-contract.md`](record-contract.md). This file is about **keys**.

**To create one, use `--adopt`** — it detects the project's shape, maps files
that already exist to the records that expect them, and proves the result with
`doctor.sh`. Writing a manifest by hand is fine too; this table is what it must
conform to either way.

## The one rule

**Paths, commands, roles and thresholds only — never prose.**

A manifest that carries explanation becomes a second handoff file that drifts
from the first. Hazards and hard-won lessons stay in the project's own docs, and
the manifest names the *file and anchor* to read. Every value being a path,
command or name is also what lets `doctor.sh` verify a manifest at all.

## Versioning

```json
{ "manifest": "workflow/v1" }
```

`manifest` is required. Without it a global skill cannot tell which shape it is
holding, so a renamed key reads as absent rather than as an error — the failure
that is worst precisely because it is silent.

## Keys

Every key is optional. A skill that cannot resolve one says so and continues.

### `record` — where each record file lives

| Key | Type | Fallback with no manifest |
|---|---|---|
| `record.todo` | path, **or a provider object** | `TODO.md` |
| `record.roadmap` | path | `ROADMAP.md` |
| `record.changelog` | path | `CHANGELOG.md` |
| `record.handoff` | path | `CLAUDE.md` |
| `record.decisions` | path | `docs/decisions.md` |
| `record.decisionsIndex` | path (generated) | — (see below) |
| `record.openDecisions` | path | `docs/open-decisions.md` |
| `record.behaviour` | path | `docs/behaviour.md` |
| `record.reference` | **array of paths** | `README.md` |
| `record.audits` | path | — (see below) |
| `record.tooling.catalog` | path | `.claude/TOOLING.md` |
| `record.tooling.sources` | array of globs | `.claude/skills/*/SKILL.md`, `.claude/agents/*.md` |

**`record.todo` is the one key that accepts something other than a path.** A
project whose backlog already lives somewhere else declares a provider instead:

```json
"record": { "todo": { "provider": "github-issues", "repo": "owner/name", "label": "backlog" } }
```

`provider` is what distinguishes the two forms, and every reader keys on its
presence rather than on the value being an object — `record.tooling` is an
object too and is not a provider. The only provider that exists is
[`providers/github-issues.md`](providers/github-issues.md), which is the
authority on its keys and on what a skill does when the remote cannot be
reached. Declaring one nothing implements is a `doctor.sh` failure, not a
silent fallback to a file.

**Nothing else takes a provider, and that is deliberate.** `record.decisions`
and `record.openDecisions` are prose read months later by someone reconstructing
why a choice was made; an issue thread is a conversation. The task may move; the
reasoning stays in a file.

**`record.handoff`'s fallback is the one with a running cost.** The harness
auto-loads the working directory's `CLAUDE.md`, so under the fallback the handoff
is read without any wiring — and every line of it is then paid for in every
session of that project, including the ones its subject is irrelevant to. That is
why [`record-contract.md`](record-contract.md#the-mutable-claim-rule) makes
compression, and deleting a resolved warning the moment it is fixed, a rule for
this record and no other. The fallback also merges a rewritten-in-place record
into the file holding the project's standing agent instructions, which have no
owner in the matrix, leaving `handoff-writer` sole writer of a file the user also
edits. **Nothing warns about either**, by design: `session-check.sh` injects a
handoff only where a manifest has mapped it *away* from `CLAUDE.md`, and is
deliberately silent when it is `CLAUDE.md` or undeclared, because in that case
the harness has already loaded it. Declaring a path of its own separates the two
records, at the cost of loading both files.

**`record.reference` is an array, not a sub-object.** Skills describing "the
reference doc (overview)" or "(data model)" are naming *which file in that array*
they mean, not a `record.reference.overview` key. There is no such key.

**`record.audits` has no conventional fallback**, because no filename for it is
conventional. `--stocktake` asks once on a first pass and then creates one; see that
skill's no-manifest section.

**`record.decisionsIndex` has no fallback, and that is not an oversight.** It is
the one generated record, so its filename is only meaningful alongside a
`commands.indexRegen` that writes it. A project with no manifest has no such
command, so a fallback here would name a file nothing can produce — and an owner
appending to the decision log would then report an index it never regenerated.
Where the index is absent, append to `record.decisions` and say the index was not
updated.

### `commands` — what to run

| Key | Type | Notes |
|---|---|---|
| `commands.typecheck` | shell command | — |
| `commands.test` | shell command | The **full** suite with coverage, not a bare test run |
| `commands.indexRegen` | shell command | **Rewrites** `record.decisionsIndex`. For the owners that append to the decision log |
| `commands.indexCheck` | shell command | **Verifies** the index is current, without writing. For `--check`, which writes nothing — usually the same script with a `--check` flag |
| `commands.testConsentEnv` | env var **name** | Where the suite is gated behind a token only the user can supply |
| `commands.ci` | object | `{ "tool": "gh", "workflow": "<name>" }`, or a shell command returning run status |

### `agents` — which subagent plays which role

Values are agent names resolvable in that project. All optional; **a skill that
finds a role undeclared does that work inline or with a general-purpose subagent,
and says so — it never substitutes a different role's agent.**

`architecture`, `implement`, `infra`, `test`, `exploit`, `audit`, `roadmap`,
`release`.

### `lanes` — concurrent-write collision

Globs. Consumed by `--start` when partitioning parallel work.

| Key | Rule |
|---|---|
| `lanes.exclusive` | At most one lane in a batch, and it runs first, alone |
| `lanes.serialize` | A lane *modifying* one runs alone or first; lanes merely *calling* it run in parallel |
| `lanes.generated` | No lane writes these; the orchestrator regenerates once |

### `audit` — scope control for `--stocktake`

| Key | Type | Notes |
|---|---|---|
| `audit.dimensions` | array | Strings name a built-in dimension; `{"name": ..., "brief": "path.md#anchor"}` supplies a project's own. Prunes, adds and re-briefs |
| `audit.invalidates` | map of glob → array | Which dimensions a changed path voids. `"*"` means all. **Only ever widens** the built-in blast radius — see the skill's Phase 0 |

### Everything else

| Key | Type | Notes |
|---|---|---|
| `branch.integration` | branch name | What `--wrap` pushes, and what `--pullrequest` opens a PR from |
| `branch.publish` | branch name | What `--release` tags, and what `--pullrequest` merges into |
| `branch.mergeMethod` | `merge` \| `squash` \| `rebase` | How `--pullrequest` merges. Fallback **`merge`** — a squash discards the individual commit messages the history is the record of, so it is a project's explicit choice rather than a default |
| `gate.coverage` | object of thresholds | e.g. `{"lines": 91, "branches": 79}` — what CI enforces |
| `commitTrailer` | trailer key | e.g. `Claude-Session` |
| `sweeps` | path (generated, **gitignored**) | The sweep checkpoint cache. Fallback `.claude/sweeps.json`; its shape and rules are [`sweep-checkpoint.md`](sweep-checkpoint.md) |
| `onSchemaChange` | **skill name** | The project's mandatory post-schema-edit sequence, and the guard rails around it. A skill rather than a command, because the order matters and because the dangerous operations need prose next to them |
| `hazards.*` | `file#anchor` | Map of phase name → where that phase's known traps are written. Conventional names: `testing`, `lanes`, `migrations`, `generated` |

**`sweeps` is deliberately not under `record.*`.** Every `record.*` path is
expected to exist, and `doctor.sh` fails on one that does not. The checkpoint is
a cache that legitimately has not been created yet — on a fresh clone, in CI, or
before the project's first sweep — and its absence means "sweep in full", which
is the safe answer rather than a fault. Filing it as a record would turn that
into a failure report on every clean checkout.

**Not manifest keys.** `worktree.symlinkDirectories` lives in the project's
`.claude/settings.json`, not here — it configures the harness rather than the
workflow. Skills that read it say so explicitly.

**Nor is a project name.** `project` was a key until 2026-08-01 and no global
skill ever read it, which is rule 1 below failing in the one direction it cannot
catch by itself — the key was already there. It is named here because a manifest
that ships carries its value into whatever repository it lands in, so a name is
worse than useless: it is confidently wrong. A project that needs its own name
has `README.md`.

**Nor are permissions.** A stack's destructive commands — migration resets,
force-syncs, anything that drops state — belong in the project's own
`.claude/settings.json` under `permissions.ask`, beside the `onSchemaChange`
skill that explains them. Shipping them in a shared global config sends one
stack's tooling to every adopter, and worse, it puts the guard somewhere the
project cannot change when its tooling does.

## Adding a key

1. A key earns its place only if a **global** skill reads it. A fact only one
   project uses belongs in that project's docs, with `hazards.*` pointing at it.
2. Add the row here first. This table is the authority; a skill's own file says
   what it does with the value, never what the key is.
3. Use the existing name if one fits. Two names for one concept is the failure
   this file exists to end.
4. Run `doctor.sh`, which checks that paths and `#anchor`s in a manifest resolve.

## When a project has no manifest

Every skill degrades rather than failing: fall back to the conventional names
above, skip what cannot be resolved, and **say in one line which**. A silent
fallback is how a project ends up with two handoff files.

