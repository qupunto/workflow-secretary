# Claude tooling

Every skill, agent and script in this repository, and what each one is for. This
repo is *only* tooling, so this doubles as the overview of what the project is.

`ws-tools` (`--ws-tools`) owns this file and is its sole writer.
`--ws-full-check` hands it back here at the end of every health check, which is what
keeps it from becoming the stale inventory this workflow warns about everywhere
else.

**Where a project has a documentation site**, `--ws-tools` hands this file to
`--ws-docs`, which adapts it into a Claude-tooling annex page and owns that page.
This repository now has one: `docs/annex/claude-tooling.md` is that derived
page. This file stays the source — when the two disagree, this one is right.

**What this file deliberately does not carry**: which record each skill may
write, or what any grant permits in detail. That is
[`ownership.md`](../workflow/ownership.md), and a second copy here would drift
from it. The diagram below shows the two tiers and the direction authorization
flows, because that is the shape nobody can reconstruct from a single file — but
where it and `ownership.md` disagree, `ownership.md` is right. This answers
*what does this thing do*, and *what calls what*.

Nor does it say which skills a session actually loads in full. A skill can be set
to `name-only` — still invocable, but with its description kept out of the
session's context — and which ones are is `skillOverrides` in `settings.json`.
**The harness half of that lever is the checkout form's only.** `skillOverrides`
does not reach plugin skills, and `settings.json` is the user's rather than the
plugin's, so an install loads every description in this file regardless. Every
skill below exists and can be called whether or not it is listed there.

**But `shorthand-flags.sh` checks the overrides itself**, so under a plugin
install `off` still stops that skill's *flag* firing while the skill stays
callable. Half a disabled skill; `README.md` carries the detail.

---

## How the pieces fit

The rows below describe each skill alone. What none of them shows — and what
nobody can reconstruct from any single file — is the direction work and
authorization flow. `--ws-tools` maintains this picture itself, under the three
rules in its own file — check the renderer, draw only what you read, stop before
it stops being readable.

```
                 a flag the user types
                          │
                          │  confers the grant. A skill never widens
                          │  its own, and an invoked skill inherits
                          │  its CALLER's grant, never its own flag's.
                          ▼
   ┌──────────────────────────────────────────────────────────────┐
   │  ORCHESTRATORS — own the session, write no record            │
   │                                                              │
   │    --ws-start    --ws-check    --ws-full-check   --ws-release│
   │    --ws-wrap     --ws-pr       --ws-stocktake    --ws-report │
   │    --ws-docs     --ws-adopt    --ws-overview                 │
   └───────────────────────────┬──────────────────────────────────┘
                               │
                               │  invokes, passing its grant down
                               ▼
   ┌──────────────────────────────────────────────────────────────┐
   │  PRIMITIVES — a record, the history, or a rule               │
   │                                                              │
   │    with a flag:  --ws-track    --ws-todo / --ws-log          │
   │                  --ws-plan     --ws-tools     --ws-scout     │
   │                  --ws-describe                               │
   │                                                              │
   │    flagless:     ws-contracts  (a skill)                     │
   │                                                              │
   │    procedures    sweep-tracker     handoff-writer            │
   │    under         changelog-writer  git-writer                │
   │    workflow/     manifest-writer   behaviour-writer          │
   │    writers/:     reference-writer  audit-writer              │
   └───────────────────────────┬──────────────────────────────────┘
                               │  the ones that write
                               ▼
              the record files, and the git history
```

**Every orchestrator writes no record**, and the box needs only one row to say
so. The diagram draws the current state, never an intended one — a map that
shows the destination is read as showing the territory.

The picture shows tier and grant direction only. **Who invokes whom is the table
below**, deliberately not drawn here: the two would fight for the same arrows.

**Not every primitive writes**, which is why the bottom arrow is labelled.
`ws-contracts` only states how the suite is wired — the "rule" in the box
label. It is a primitive on the same test as the rest: one job, no session of
its own, no authorization it did not inherit.

**These procedures are not skills.** They live at `workflow/writers/*.md`
and a caller reaches one by reading the file, not by invoking anything — a
skill's description loads into every session whether the skill is used or not,
and each of these is invoked only by other skills, a trigger a description
cannot serve. They are drawn in this box because the tier is the same: one
record each, sole writer, no grant of their own. `workflow/writers/README.md` is their index.

**The flagless row cannot be entered from the top**, and that is the point
rather than an omission: a primitive with no flag has no grant of its own to
inherit from, so a caller can never acquire authorization the user did not give
it. Arrows also run the other way — the primitive `--ws-tools` invokes `--ws-docs` —
because the tier says what a skill owns, not who may call it.

### Who invokes whom

| Caller | Invokes | For |
|---|---|---|
| `--ws-adopt` | `manifest-writer`, `--ws-docs`, `git-writer` | writing the manifest it decided on; scaffolding a project that has no documentation; committing. Amendment mode — one key in an existing manifest — reaches `manifest-writer` without the detection phase |
| `--ws-start` | `--ws-track`, `--ws-todo` / `--ws-log`, `--ws-plan`, `--ws-tools`, `--ws-docs`, `behaviour-writer`, `reference-writer`, `handoff-writer`, `git-writer`, `sweep-tracker` | building the task list before the batch; recording what the batch produced, committing it, and stamping the suite run so the next audit need not repeat it. `--ws-docs` only where a change also earns a page. Its Phase 6 handoffs run **serialized**, never concurrently — every record writer re-verifies against the other records, so each one's read set is all of them |
| `--ws-check` | the owner of each finding, and `sweep-tracker` | it writes nothing itself — dispatch is the whole design. Every row in its table is a primitive, so a one-line staleness fix never has to run a whole orchestrator procedure to get written |
| `--ws-full-check` | the same owners at full scope, plus `--ws-tools` (claims and prune), `sweep-tracker`, `doctor.sh` and the project's own test command | ignoring every checkpoint. It resolves the suite carry-forward at the start and deliberately never stamps it at the end, because its later steps always run against a tree it has already edited |
| `--ws-stocktake` | `--ws-todo` / `--ws-log`, `--ws-plan`, `--ws-tools`, `--ws-wrap`, `audit-writer`, `handoff-writer`, `git-writer`, `sweep-tracker`, and the project's own code-analysis skill where one exists | the dispositions, its own audit entry, and a dispatched close-out. It runs the record dimension itself from `workflow/checks/record-drift.md` — the hook drops `--ws-check` when either stocktake flag is typed |
| `--ws-release` | `--ws-full-check`, `changelog-writer`, `git-writer` | everything being in order before a tag — drift included, since that is one of its dimensions — then the entry and the tag. It reads `--ws-plan`'s mark and never writes it |
| `--ws-wrap` | `handoff-writer`, `--ws-plan`, `git-writer` | the handoff, the milestone question, the commits. It *names* `--ws-pr` where the pushed branch is ahead of `branch.publish`, and never invokes it — a session ending and work being ready to merge are two different facts |
| `--ws-pr` | `git-writer`, `--ws-todo` | the merge, once the user confirms in that turn; and the review threads nobody resolved, which the merge is about to hide — proposed to the user, never filed automatically, because a meaningful share of unresolved threads is chatter. It drafts the body and holds the gate, and writes nothing itself |
| `--ws-tools` | `--ws-docs`, `--ws-todo`, `sweep-tracker`, `git-writer` | handing the catalog over, stamping the sweep. It draws the diagram above itself. A tooling *task* it uncovers goes to `--ws-todo` rather than being written here |
| `--ws-docs` | `--ws-todo`, `--ws-track`, `sweep-tracker`, `behaviour-writer`, `reference-writer` | parking a page set larger than one session, since this skill stores no state of its own; narrowing its next audit; and handing over a subject that turns out to be a runtime rule or reference material rather than a page, which it never writes itself |
| `--ws-scout` | `--ws-log` | the reasoning entry an adoption earns, at the moment the user adopts — the registry row stays lean and points at it |

`--ws-check` and `--ws-full-check` appear as callers and never as callees of a write:
an inspector that writes is a second writer on every file it touches.

---

## Global skills

In `skills/`, loaded in every project. The record procedures are the table
after this one.

| Skill | Flag | What it does |
|---|---|---|
| `ws-adopt` | `--ws-adopt` | Brings a project under this workflow — detects its shape, maps files it already has, decides what its `.claude/workflow.json` should say and hands that to `manifest-writer`, proposes `permissions.ask` gating for the destructive commands it finds, and hands a project with no documentation to `--ws-docs`. The detection and the asking are what stay here: a primitive has no channel to reach the user |
| `ws-docs` | `--ws-docs` | Writes and maintains a project's long-form documentation site, every claim anchored to a real source path |
| `ws-full-check` | `--ws-full-check` | Asks whether a project is in order end to end — runs its mechanical checks, re-verifies its records, docs and tooling files at full scope ignoring every checkpoint, triages the defect inbox filed from other projects, orders the prune, has this catalog refreshed, then leaves fresh checkpoints. `--ws-release` runs it before a tag |
| `ws-pr` | `--ws-pr` | Moves work from the integration branch onto the publish branch through a pull request — drafts the body from the branch range rather than from memory, opens it, watches its CI, and merges behind a fresh confirmation. The only thing in the suite that moves work between the two branches |
| `ws-stocktake` | `--ws-stocktake`, `--ws-full-stocktake` | Where is this project — record, conventions, public surface, safety nets — then rebuilds the backlog around the answer. Invokes the project's own code-analysis skill where one exists |
| `ws-record` | `--ws-todo`, `--ws-log` | Parks work that is not being built now, and records decisions already made |
| `ws-describe` | `--ws-describe` | Gets a runtime rule settled in conversation into `record.behaviour`, which every other route reaches only as a side effect of a check or a build. Dispatches to `behaviour-writer` and writes nothing; its own work is turning away the three things handed to it by mistake — reasoning and decided-but-unbuilt behaviour, both `--ws-log`'s, and stack or architecture, which is `record.reference`'s |
| `ws-scout` | `--ws-scout` | Consults the project's toolbelt registry before any capability gets hand-built, searches the stack's public registries when the registry has no answer, and explains the candidates — advises, never implements. Sole writer of `record.toolbelt`; the reasoning behind each row goes through `--ws-log` |
| `ws-check` | `--ws-check` | Asks whether a project's records still match reality — including whether the documents claim a version no tag resolves; reports and dispatches, writes nothing itself |
| `ws-report` | `--ws-report` | Files a finding about this suite upstream — appends it to the machine-local inbox, then opens a GitHub issue on the public repository behind a preview, a redaction of the project context, and a fresh OK. Can bundle every open inbox entry under the same rules; hazards are referenced by group name, never quoted |
| `ws-release` | `--ws-release` | Decides that a version ships — once the roadmap marks a milestone done, or once it has declared an end to milestones and the release is maintenance on evidence — and asks before anything is published. The entry and the tag are written by the two primitives above |
| `ws-plan` | `--ws-plan` | Keeps milestones and blocks in order, and marks a milestone complete |
| `ws-overview` | `--ws-overview` | Reports where a project stands at a glance — branch and lane, per-record counts, sweep freshness, pending warnings, the nearest milestones — read fresh at invocation, writing nothing at all. Every mechanical number comes from its probe script in one call; the model adds only the judgment lines. The read-only sibling of `--ws-check`: it counts what the records say and never verifies them |
| `ws-start` | `--ws-start` | Picks up pending work and does it, in parallel lanes partitioned so they cannot collide |
| `ws-tools` | `--ws-tools` | Keeps this catalog current, hands it to `--ws-docs` where a site exists, deletes stale claims from skill and agent files, and runs the prose prune over the same set |
| `ws-track` | `--ws-track` | Builds the visible task list for multi-step work and keeps it honest as the work moves |
| `ws-contracts` | — | States how the suite is wired — that the skills are global, that project facts come from `.claude/workflow.json`, what a project without a manifest falls back to, and where the three contracts resolve in a checkout versus a plugin install. It exists because a plugin root's `CLAUDE.md` is never loaded, so an adopter who installs rather than clones would otherwise see none of it |
| `ws-wrap` | `--ws-wrap` | Closes out a session — task list, the handoff through `handoff-writer`, the commits and push through `git-writer`, asks `--ws-plan` whether a milestone just finished, reports where the project stands in the reply (backlog left, decisions nobody has made, the next milestone), and says when it is safe to clear |

---

## The record procedures

In `workflow/writers/`, **not** in `skills/`. A caller reaches one by reading
the file — there is nothing to invoke, and nothing loads unless a caller opens
it. A description costs every session whether or not the skill is used, and
each of these is invoked only by other skills — so they are procedure files
rather than skills. Ownership is unaffected by the location —
`workflow/ownership.md` is still the authority, and `workflow/writers/README.md`
is their index.

| Procedure | Sole writer of | What it does |
|---|---|---|
| [`audit-writer`](../workflow/writers/audit-writer.md) | `record.audits` | Writes the audit log entry — what a stocktake examined, against which tree, and what it found, with its coverage block. Also the one-field `Outcome` update when remediation lands, which is why it is not part of `--ws-stocktake` |
| [`behaviour-writer`](../workflow/writers/behaviour-writer.md) | `record.behaviour` | Writes the record of what the system does at runtime, by topic. Never *why* it does it, which is `--ws-log`'s. Reached by dispatch from a check or a build, or directly through `--ws-describe` |
| [`changelog-writer`](../workflow/writers/changelog-writer.md) | `record.changelog` | Writes the changelog entry for a version, and marks an entry unreleased when the documents claim more than the tags do |
| [`git-writer`](../workflow/writers/git-writer.md) | commits and tags | Makes the commits, the tags and `--ws-pr`'s merge for every skill that may, so the rules that keep a commit, a merge or a push safe live in one file rather than in whichever caller remembered them |
| [`handoff-writer`](../workflow/writers/handoff-writer.md) | `record.handoff` | Writes the handoff a fresh session inherits, at whatever scope its caller asked for |
| [`manifest-writer`](../workflow/writers/manifest-writer.md) | `.claude/workflow.json` | Writes `.claude/workflow.json` — validates each key against `workflow/manifest.md`, refuses one nothing reads or whose path does not resolve, and runs the doctor. Decides nothing: the caller arrives having settled the values |
| [`reference-writer`](../workflow/writers/reference-writer.md) | `record.reference` | Writes the record of what the system *is* — stack, architecture, data model, stated conventions. Often the project's `README.md`, where the manifest maps it there |
| [`sweep-tracker`](../workflow/writers/sweep-tracker.md) | the sweep checkpoint | Records which commit each sweep last verified and what it covered, so the next one re-reads only what changed. It refuses a stamp claiming a commit with no coverage — except a freshness-only entry, which claims none and licenses nothing |


---

## The shared check methods

In `workflow/checks/`, **not** in the skills that wrote them. Each is one way of
finding inconsistency in something the project has written down; the skill that
runs one supplies the scope and decides what happens to a finding.

Each is single-sourced here because a method borrowed by **citing another
skill's headings** breaks silently on a rename, leaving the borrower reporting
success over checks it never ran; `doctor.sh`'s section-citation check polices
the citations that remain.

| Method | What it finds | Run by |
|---|---|---|
| [`record-drift.md`](../workflow/checks/record-drift.md) | the classes of drift in a record, and the things that look like drift and are not | `--ws-check`, `--ws-full-check`, `--ws-stocktake` |
| [`docs-audit.md`](../workflow/checks/docs-audit.md) | a docs site's internal correctness — paths, links, anchors, enumerations, page-level accuracy against source | `--ws-docs`, `--ws-full-check` |
| [`tooling-claims.md`](../workflow/checks/tooling-claims.md) | mutable claims inside the tooling files, which are deleted rather than corrected | `--ws-tools`, `--ws-full-check` |

**A method says what counts as a finding; a runner decides scope, disposition
and owner.** `workflow/checks/README.md` holds that line and why it matters —
material that drifts to the wrong side of it stops being borrowable.

---

## Backlog providers

In `workflow/providers/`. `record.todo` is normally a path; a project whose
backlog already lives somewhere else declares a provider object instead. Nothing
else in `record.*` takes one.

**Every skill that touches the backlog goes through the provider, not just
`--ws-todo`** — `--ws-adopt` offers the choice and `manifest-writer` validates it,
`--ws-start` and `--ws-check` and `--ws-full-check` read it, `--ws-wrap` counts it. None of
them may read a local file instead when the remote is unreachable; they say so
and write nothing.

| Provider | Declared as | Contract |
|---|---|---|
| GitHub Issues | `{ "provider": "github-issues", "repo": "owner/name", "label": "backlog" }` | [`github-issues.md`](../workflow/providers/github-issues.md) |

**A declared provider is never a silent fallback to a file.** `doctor.sh` fails
on one nothing implements, on a missing `repo`, on a repo that does not
resolve, and on a declared `label` no label on the repo matches; it warns when
`gh` is absent or unauthorized, which is a fault of the machine rather than the
manifest. The reasoning behind an item still goes to
`record.decisions` — a file — because an issue thread is a conversation and a
decision log is read months later.

## Skills scoped to this repo

None. The workflow supports them — a project ships a skill under
`.claude/skills/` and the flag hook resolves it there before the global suite.
Everything here is global.

## Agents

None. Every `agents.*` role in the manifest schema is something an *adopting*
project declares, and this repo's own manifest declares none — so a skill that
would route a lane to an agent does that work inline and says so.

## Scripts

| Script | What it does |
|---|---|
| `doctor.sh` | Read-only health check of this config and the project in the working directory. Prints what it checks, so the list cannot go stale |
| `hooks/shorthand-flags.sh` | The `UserPromptSubmit` hook that turns a `--flag` into a deterministic skill invocation rather than a judgement call |
| `hooks/session-check.sh` | The `SessionStart` hook, and the only thing here that speaks without being asked — so it is built to stay silent unless it has something worth a session's attention: a doctor failure, a sweep or a record gone stale, a filed bug report, an unread upstream filing (counted only in the suite's own checkout, where triage can act), or a handoff the harness would not otherwise load |
| `hooks/alert.sh` | A sound cue when a session waits for input — permission prompts, option pickers, idle, turn end. Ships silent and opts in per machine: `--ws-alerts on\|off` (served by the flag hook, no skill) toggles a state file in the config directory that this hook gates on. Sound only, cross-platform, one cue per burst |
| `hooks/hooks.json` | Declares the same events for a **plugin** install, where `settings.json` is the user's and a plugin never owns it. Plugin hooks merge with the user's rather than replacing them |
| `.claude-plugin/plugin.json` | The manifest that makes this directory installable. `claude plugin validate` reads it |
| `reset-records.sh` | Blanks every record the manifest declares back to its canonical heading — a fresh start with the structure kept and the content gone. Dry-run unless given `--write`. Skips a `record.todo` that names a provider rather than a file, and never touches `record.reference` or `record.tooling.catalog`, which describe the tooling rather than the project. **This one travels**, and `publish.sh` runs the copy of it rather than keeping a second list |
| `export-records.sh` | Moves machine-local workflow state between machines — untracked record files, the lane selector, and the config directory's bug-reports inbox. Skips tracked records and the sweep checkpoint; import is all-or-nothing, refuses escaping entries, and refuses non-empty collisions without `--force`. **This one travels** |
| `retire-workflow.sh` | The tidy exit: removes the suite's machinery from a project — manifest, sweep cache, lane selector — and, only behind `--write --records`, the workflow-shaped records. Never touches the reference, changelog or tooling files, a CLAUDE.md handoff, or the suite's own tree. Dry-run by default. **This one travels** |
| `publish.sh` | Assembles the public tree from `HEAD` and gates it — copies only what it admits, empties the records on the copy, then asserts no ancestry, no private identifier, a whitelist of tracked paths, the credential rules, and the doctor and tests from inside the result. Never pushes. Does not travel with what it copies |
| `.claude-plugin/marketplace.json` | Makes the same directory its own marketplace, listing one plugin whose `source` is `"./"` — so there is no second repository to keep in step. Handed a directory holding both, `claude plugin validate` checks this one and not the other; name the file to check the other |
| `skills/ws-docs/assets/scaffold.sh` | Creates a docsify site shell and only the shell, never content. Refuses to touch an existing directory, and prints the steps it deliberately leaves to its caller. Invoked by `--ws-docs` in Scaffold mode |
| `skills/ws-record/assets/index-decisions.sh` | Generates `record.decisionsIndex` from the decision log — one row per entry, line number and heading — and verifies it without writing under `--check`. Declared as `commands.indexRegen` / `commands.indexCheck` in this repo's manifest; refuses to run where the index key is undeclared |
| `skills/ws-overview/assets/probe.sh` | Emits `--ws-overview`'s whole mechanical block in one read-only call — tree, record counts, doctor result, sweep freshness, roadmap position — so the report costs seconds instead of a model read of every record. Offline by design: external state is reported as not counted, never as zero. Invoked by `--ws-overview` |
| `tests/hook-contract.sh` | The contract tests for the hook, whose breakage is total and silent |
| `.github/workflows/publish.yml` | Fires on a release-tag push, and on manual dispatch — which is how a publication is staged when the public repo has drifted behind `dev` without a tag. Runs `publish.sh` and stages the gated assembly as a PR on the public repository, never a merge. It asserts the pushed tag against `.claude-plugin/plugin.json` first, and reports rather than refuses on a dispatch run, where there is no tag to assert against. Needs the `PUBLISH_TOKEN` secret; removed from the assembly so it never ships |
| `.github/workflows/verify.yml` | CI. Runs `doctor.sh` (twice, from both scopes) and the hook contract tests, plus shell syntax, Shellcheck, JSON validity, credential scans, skill frontmatter, cross-links and absolute-path checks. Runs on a push to any branch except `main`, on every pull request, and on manual dispatch — `main` is reached only through a PR, and on the published repository `main` additionally requires that PR run to be green before it can be merged |

## Command wrappers

In `commands/`, one file per verb flag of a multi-verb skill — a flag whose
name differs from its skill's for a reason other than a scope-variant prefix
(`--ws-full-stocktake` gets none). The wrapper's filename **is** the flag, so
the `/` menu autocompletes it and its body fires the flag with `$ARGUMENTS`
appended. The `UserPromptSubmit` hook
does not fire on a wrapper's expanded body — routing rides the flag token plus
the owning skill's own rules — which is why only skill-backed flags get
wrappers and the hook-served ones (`--ws-flags`, `--ws-help`, `--ws-alerts`)
never do. `doctor.sh` asserts every wrapper fires the flag its name promises.

| Wrapper | Fires | Routes to |
|---|---|---|
| `commands/ws-todo.md` | `--ws-todo` | `ws-record` |
| `commands/ws-log.md` | `--ws-log` | `ws-record` |

## Files that are not tools

Worth naming, because they are most of what a reader will otherwise open:

| File | What it is |
|---|---|
| `workflow/*.md` | The contracts every skill links to instead of carrying its own copy — ownership, record contract, manifest keys, sweep checkpoint, audit coverage, project shape |
| `CLAUDE.md` | Loaded into every session in every project — the checkout form only, because a plugin root's is never read as project context. The three contract paths, the doctor line and a pointer: what each contract governs is `ws-contracts`', which owns it |
| `README.md` | How the repo is adopted on a new machine, and how the flags work |
| `bug-reports.md` | Gitignored inbox for defects found in these files by sessions working in other projects |
