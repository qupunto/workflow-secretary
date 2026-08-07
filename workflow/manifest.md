# The project manifest — `<project>/.claude/workflow.json`

**The one authority on what a manifest may contain.** The skills are global; this
file is how a project tells them its own paths, commands and roles. Without a
single authority the shape is implied by whatever each skill happens to read,
and the skills disagree — two names for one command, keys depended on but
defined nowhere, one value read as both a string and an array.

Who may write each record is [`ownership.md`](ownership.md); what each record
holds is [`record-contract.md`](record-contract.md). This file is about **keys**.

**To create one, use `--ws-adopt`** — it detects the project's shape, maps files
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
| `record.releases` | path | `RELEASES.md` |
| `record.changelog` | path | `CHANGELOG.md` |
| `record.handoff` | path | `CLAUDE.md` |
| `record.decisions` | path | `docs/decisions.md` |
| `record.decisionsIndex` | path (generated) | — (see below) |
| `record.openDecisions` | path | `docs/open-decisions.md` |
| `record.behaviour` | path | `docs/behaviour.md` |
| `record.reference` | **array of paths** | `README.md` |
| `record.audits` | path | — (see below) |
| `record.toolbelt` | path | `toolbelt.md` |
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
conventional. `--ws-stocktake` asks once on a first pass and then creates one; see that
skill's no-manifest section.

**`record.toolbelt` is the capability registry** — one row per adopted library
or tool, read before building any capability. `ws-scout` is its sole writer and
[`record-contract.md`](record-contract.md) holds the row shape. An absent file is
an empty registry, not a failure: the file is created when the first adoption is
made. It never appears under a lane's `records` — which tool does a job is a
property of the project, not of a worktree.

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
| `commands.indexCheck` | shell command | **Verifies** the index is current, without writing. For `--ws-check`, which writes nothing — usually the same script with a `--check` flag |
| `commands.testConsentEnv` | env var **name** | Where the suite is gated behind a token only the user can supply |
| `commands.ci` | object | `{ "tool": "gh", "workflow": "<name>" }`, or a shell command returning run status |

### `agents` — which subagent plays which role

Values are agent names resolvable in that project. All optional; **a skill that
finds a role undeclared does that work inline or with a general-purpose subagent,
and says so — it never substitutes a different role's agent.**

`architecture`, `implement`, `infra`, `test`, `exploit`, `audit`, `roadmap`,
`release`.

### `lanes` — concurrent-write collision, and named worktree lanes

Consumed by `--ws-start` when partitioning parallel work — and, for `lanes.named`,
by every reader of the splittable records.

| Key | Rule |
|---|---|
| `lanes.exclusive` | At most one lane in a batch, and it runs first, alone |
| `lanes.serialize` | A lane *modifying* one runs alone or first; lanes merely *calling* it run in parallel |
| `lanes.generated` | No lane writes these; the orchestrator regenerates once |
| `lanes.named` | Map of lane name → `{"scope": [globs], "records": {…}, "transfer": path}`, one entry per lane for a project worked on from several git worktrees at once |
| `lanes.conflicts` | path — **one per project**, the conflict inbox `ws-lanes-records-synch` consumes |

**`record.releases` is the release list and `record.roadmap` is not.** Milestones,
the version each intends to ship as and the completion marks live in the first;
goals and the blocks that reach them live in the second, which may split by lane.
[`record-contract.md`](record-contract.md) holds why, and holds the rule that
makes a split roadmap safe: **no roadmap, lane or unsplit, carries a version
number or a completion mark.** `doctor.sh` fails on one that does.

**`lanes.named` holds the worktree lanes**, nested so lane names cannot collide
with the three reserved keys above. Each entry's `scope` globs are the paths the
lane owns — a `--ws-start` batch running inside that worktree partitions within
them — and its `records` object may redirect a record to a lane-scoped file:

```jsonc
"lanes": {
  "named": {
    "backend": { "scope": ["backend/**"],
                 "records": { "todo": "TODO.backend.md",
                              "openDecisions": "docs/open-decisions.backend.md",
                              "handoff": "docs/handoff/backend.md",
                              "roadmap": "ROADMAP.backend.md" } },
    "frontend": { "scope": ["frontend/**"], "records": {},
                  "transfer": "docs/transfer/frontend.md" }
  }
}
```

**`transfer` is a sibling of `records`, never a key inside it**, and the nesting
is the point rather than tidiness: everything under `records` has exactly one
writer, and a transfer queue has many. It is the lane's **inbox** — where every
*other* lane files work it believes this lane owns, so that no lane ever writes
another's records. [`record-contract.md`](record-contract.md) holds what it may
contain, why append-only makes many writers safe, and the `[critical → why]`
marker. `doctor.sh` fails on `transfer` appearing under `records`.

Like the splittable records it is **declared for all named lanes or none** — a
lane with no queue is a lane nothing can file to, which reads as "nobody needs
anything from them" and is almost never true. It is tracked, unlike the
`.claude/lane` selector, because an entry has to travel to the worktree it is
addressed to.

**`lanes.conflicts` is the second queue and there is exactly one**, a sibling of
`named` rather than a key inside a lane. It takes a contradiction between two
lanes' records that some session noticed while doing something else, and
`ws-lanes-records-synch` is what consumes it. One per project because a
contradiction belongs to neither lane involved — filing it to one of them would
be picking a side before anyone has ruled.
[`record-contract.md`](record-contract.md) holds the entry shape and the rule
that a filed entry is a claim to be re-verified rather than a conflict to act
on. Declaring it without `lanes.named` is meaningless and `doctor.sh` says so.

Only `todo`, `openDecisions`, `handoff` and `roadmap` may appear under a lane's
`records` — which records may split by lane and which must never is
[`record-contract.md`](record-contract.md)'s rule, and `doctor.sh` fails on any
other key there. **`releases` is not among them**, and that is what keeps a
release checkpoint singular however many lanes a project runs. A splittable record is split for **all** named lanes or none:
a half-split is how two writers land on one file, and `doctor.sh` fails on that
too. Name lane files by **lane**, which is durable (`TODO.backend.md`), never by
worktree, which is litter that outlives the worktree.

**The selector is a file, not a key: `.claude/lane`** — gitignored, one per
worktree, holding the lane name, written once at worktree setup
(`--ws-adopt --lane <name>`). Absence means "unsplit project", the same degradation
as any missing key. It is deliberately **not** derived from the git branch name:
tempting and fragile, where the explicit file is boring and correct. Like
`sweeps`, it is per-checkout state that legitimately does not exist, so it is
not a `record.*` path and its absence is never a failure — but a selector naming
a lane the manifest does not declare **is** a `doctor.sh` failure.

**The resolution rule, stated once, here:** where a lane is selected and
`lanes.named.<lane>.records.X` exists, it overrides `record.X`; in every other
case `record.X` applies exactly as it does today. Cross-lane reads need no
extra key — every lane's paths sit in this shared manifest, which is tracked
and identical on every branch, and that identity is what removes the
record-file merge conflicts worktree lanes otherwise produce.

**Scope globs also bound what a session may act on.** A request that falls
under another lane's `scope` is announced and routed to that lane rather than
executed where it lands — [`ownership.md`](ownership.md)'s rule ("Work scoped
to another lane"), stated there because it is about which session may act,
not about which key resolves.

### `audit` — scope control for `--ws-stocktake`

| Key | Type | Notes |
|---|---|---|
| `audit.dimensions` | array | Strings name a built-in dimension; `{"name": ..., "brief": "path.md#anchor"}` supplies a project's own. Prunes, adds and re-briefs |
| `audit.invalidates` | map of glob → array | Which dimensions a changed path voids. `"*"` means all. **Only ever widens** the built-in blast radius — see the skill's Phase 0 |

### Everything else

| Key | Type | Notes |
|---|---|---|
| `branch.integration` | branch name | What `--ws-wrap` pushes, and what `--ws-pr` opens a PR from |
| `branch.publish` | branch name | What `--ws-release` tags, and what `--ws-pr` merges into |
| `branch.mergeMethod` | `merge` \| `squash` \| `rebase` | How `--ws-pr` merges. Fallback **`merge`** — a squash discards the individual commit messages the history is the record of, so it is a project's explicit choice rather than a default |
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

**Nor is a project name.** A manifest that ships carries its value into
whatever repository it lands in, so a name is worse than useless: it is
confidently wrong. The ban is written down because rule 1 below cannot catch a
key that is already present — nothing reading it looks exactly like something
reading it. A project that needs its own name has `README.md`.

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

