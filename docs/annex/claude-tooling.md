# Claude tooling

Exhaustive reference for every skill and script in this repository: what each
one is for, and — the part no single file shows — which of them invoke each
other.

**Source.** This page is derived from `.claude/TOOLING.md`, which `--tools`
owns and hands over. That file is the source of fact; this page is its
adaptation into the site. If the two disagree, the catalog is right and this
page is stale — which is a finding for `--check`, not something to fix by
editing here. For the guide to *how* the tiers work, see
[overview.md](../overview.md).

**Everything listed here exists and can be invoked**, which is not the same as
everything being described to Claude in every session. A skill can be set to
`name-only` — still fully invocable, but with its description kept out of the
always-loaded context, which is what that description costs in every session of
every project. Which skills are set that way is `skillOverrides` in
`settings.json`, and that file is the authority; this page deliberately does not
list them, because a copy of a settings block is stale the moment it is edited.

The diagram below is ASCII rather than Mermaid because `docs/index.html` loads
only the search plugin; a Mermaid fence would render as raw markup for every
reader.

---

## How the pieces fit

```
                 a flag the user types
                          │
                          │  confers the grant. A skill never widens
                          │  its own, and an invoked skill inherits
                          │  its CALLER's grant, never its own flag's.
                          ▼
   ┌────────────────────────────────────────────────────────┐
   │  ORCHESTRATORS — own the session, write no record      │
   │                                                        │
   │    --start   --check    --full-check   --release       │
   │    --wrap    --prune    --pullrequest  --stocktake     │
   │    --docs    --adopt                                   │
   └───────────────────────────┬────────────────────────────┘
                               │
                               │  invokes, passing its grant down
                               ▼
   ┌────────────────────────────────────────────────────────┐
   │  PRIMITIVES — a record, the history, a craft, or a rule│
   │                                                        │
   │    with a flag:  --track   --todo / --log              │
   │                  --plan    --tools    --draw           │
   │                                                        │
   │    flagless:     sweep-tracker     handoff-writer      │
   │                  changelog-writer  git-writer          │
   │                  manifest-writer   behaviour-writer    │
   │                  reference-writer  audit-writer        │
   │                  workflow-contracts                    │
   └───────────────────────────┬────────────────────────────┘
                               │  the ones that write
                               ▼
              the record files, and the git history
```

**Every orchestrator writes no record**, and the box needs only one row to say
so. It used to need two: `--adopt`, `--docs` and `--stocktake` each still owned
a record under a documented carve-out, and the diagram drew that rather than the
intended state, because a map showing the destination gets read as showing the
territory. Those splits landed on 2026-08-01 — into `manifest-writer`,
`behaviour-writer`, `reference-writer` and `audit-writer` — so the distinction no
longer separates anything, and the sub-row is gone rather than emptied.

That includes `--docs`, which produced this page: it owns the site and nothing
else. The two records it used to write are `behaviour-writer`'s and
`reference-writer`'s, and a one-line staleness correction now reaches them
directly instead of having to run a whole documentation procedure.

**The flagless row cannot be entered from the top of that picture.** A primitive
with no flag has no grant of its own to inherit from, so a caller can never
acquire authorization the user did not give it — which is why they have no flag
rather than merely happening to lack one. Arrows also run upward: the primitive
`--tools` invokes the orchestrator `--docs`, because a tier says what a skill
owns, not who may call it.

**Not every primitive writes**, which is why the arrow leaving that box is
labelled rather than bare. `--draw` returns a block for its caller to place, and
`workflow-contracts` only states how the suite is wired — the "rule" the box
label admits. An unlabelled arrow read as though the whole tier ended at the
record files, which was true when every primitive but one was a writer and stopped
being true once there were two. They are primitives on the same test as the rest:
one job, no session of their own, no authorization they did not inherit.

## Who invokes whom

| Caller | Invokes | For |
|---|---|---|
| `--adopt` | `manifest-writer`, `--docs`, `git-writer` | writing the manifest it decided on; scaffolding a project that has no documentation; committing. Amending one key in an existing manifest reaches `manifest-writer` without the detection phase, which is what the split was for |
| `--start` | `--todo` / `--log`, `--plan`, `--tools`, `behaviour-writer`, `reference-writer`, `handoff-writer`, `git-writer`, `sweep-tracker` | recording what a batch produced, committing it, and stamping the suite run so the next audit need not repeat it. Its closing handoffs run **serialized**: every record writer re-verifies against the other records, so each one's read set is all of them |
| `--check` | the owner of each finding, and `sweep-tracker` | it writes nothing itself — dispatch is the whole design |
| `--full-check` | the same owners at full scope, plus `prune-skills`, `--tools`, `sweep-tracker`, `doctor.sh` and the project's own test command | ignoring every checkpoint. It resolves the suite carry-forward at the start and deliberately never stamps it at the end, since its later steps always run against a tree it has already edited |
| `--stocktake` | `--check`, `--todo` / `--log`, `--plan`, `--tools`, `--wrap`, `audit-writer`, `handoff-writer`, `git-writer`, `sweep-tracker`, and the project's own code-analysis skill where one exists | the record dimension, the dispositions, its audit entry, and a dispatched close-out |
| `--release` | `--full-check`, `changelog-writer`, `git-writer` | everything being in order before a tag — drift included, since that is one of its dimensions — then the entry and the tag. It reads `--plan`'s mark and never writes it |
| `--wrap` | `handoff-writer`, `--plan`, `git-writer` | the handoff, the milestone question, the commits. It *names* `--pullrequest` where the pushed branch is ahead of `branch.publish`, and never invokes it — a session ending and work being ready to merge are two different facts |
| `--pullrequest` | `git-writer`, `--todo` | the merge, once the user confirms in that turn; and the review threads nobody resolved, which the merge is about to hide — proposed to the user, never filed automatically, because measured over forty merged PRs two unresolved threads in five were chatter. It drafts the body and holds the gate, and writes nothing itself |
| `--tools` | `--draw`, `--docs`, `sweep-tracker`, `git-writer` | the diagram, handing the catalog over, stamping the sweep |
| `--docs` | `--draw`, `sweep-tracker` | pictures for a page; narrowing its next audit |
| `--draw` | nothing | the leaf — it reads, and returns a block for its caller to place |
| `prune-skills` | `--tools`, `sweep-tracker` | the cuts, since it writes nothing itself; narrowing what it still has to read, and stamping what it covered |

`--check` and `--full-check` appear as callers and never as callees of a write:
an inspector that writes is a second writer on every file it touches.

## Global skills

In `skills/`, loaded in every project.

| Skill | Flag | What it does |
|---|---|---|
| `adopt-workflow` | `--adopt` | Brings a project under this workflow — detects its shape, maps files it already has, decides what its `.claude/workflow.json` should say and hands that to `manifest-writer`, proposes `permissions.ask` gating for the destructive commands it finds, and hands a project with no documentation to `--docs`. The detection and the asking are what stay here: a primitive has no channel to reach the user |
| `diagram` | `--draw` | Draws the picture of a system in whatever form the display can actually render, and hands it back — it writes no file, so a diagram never becomes a second writer on someone's page |
| `docs` | `--docs` | Writes and maintains this documentation site, every claim anchored to a real source path — and nothing else. It decides whether a subject belongs on the site and which tier it lands in; the two records it used to write are `behaviour-writer`'s and `reference-writer`'s |
| `full-health-check` | `--full-check` | Asks whether a project is in order end to end — runs its mechanical checks, re-verifies its records, docs and tooling files at full scope ignoring every checkpoint, triages the defect inbox filed from other projects, orders the prune, has the catalog refreshed, then leaves fresh checkpoints. `--release` runs it before a tag |
| `pr-flow` | `--pullrequest` | Moves work from the integration branch onto the publish branch through a pull request — drafts the body from the branch range rather than from memory, opens it, watches its CI, and merges behind a fresh confirmation. The only thing in the suite that moves work between the two branches |
| `project-record` | `--todo`, `--log` | Parks work that is not being built now, and records decisions already made |
| `project-stocktake` | `--stocktake`, `--full-stocktake` | Where is this project — record, conventions, public surface, safety nets — then rebuilds the backlog around the answer. Invokes the project's own code-analysis skill where one exists |
| `prune-skills` | `--prune` | Finds prose in a project's skill and agent files that does not change what Claude does, and dispatches the cuts to `--tools`. Reads `record.tooling.sources`, so it prunes whatever set the project it runs in declares |
| `record-inspector` | `--check` | Asks whether a project's records still match reality, including whether the documents claim a version no tag resolves; reports and dispatches, writes nothing itself |
| `release` | `--release` | Decides that a version ships, once the roadmap marks a milestone done, and asks before anything is published |
| `roadmap` | `--plan` | Keeps milestones and blocks in order, and marks a milestone complete |
| `start-work` | `--start` | Picks up pending work and does it, in parallel lanes partitioned so they cannot collide |
| `tooling-catalog-sync` | `--tools` | Keeps the catalog current, hands it to `--docs` where a site exists, and deletes stale claims from skill and agent files |
| `track-complex-tasks` | `--track` | Builds the visible task list for multi-step work and keeps it honest as the work moves |
| `workflow-contracts` | — | States how the suite is wired: that the skills are global, that project facts come from `.claude/workflow.json`, what a project without a manifest falls back to, and where the three contracts resolve in a checkout against a plugin install. It exists because a plugin root's `CLAUDE.md` is never loaded as project context, so an adopter who installs rather than clones would otherwise see none of it |
| `wrap-task` | `--wrap` | Closes out a session — task list, handoff, commits, the milestone question, a readout of where the project stands, and whether it is safe to clear |


## The record procedures

In `workflow/writers/`, **not** in `skills/`. A caller reaches one by reading
the file; there is nothing to invoke, and nothing loads unless a caller opens
it. They left `skills/` on 2026-08-02 because a skill description is a
per-session cost paid whether or not the skill is used, and each of these
declared in its own description that only other skills invoked it. Ownership is
unchanged — `workflow/ownership.md` remains the authority.

| Procedure | Sole writer of | What it does |
|---|---|---|
| `audit-writer` | `record.audits` | Writes the audit log entry — what a stocktake examined, against which tree, and what it found, with its coverage block. Also the one-field `Outcome` update when remediation lands, which is why it is not part of `--stocktake` |
| `behaviour-writer` | `record.behaviour` | Writes the record of what the system does at runtime, by topic. Never *why* it does it, which is `--log`'s |
| `changelog-writer` | `record.changelog` | Writes the changelog entry for a version, and marks an entry unreleased when the documents claim more than the tags do |
| `git-writer` | commits and tags | Makes the commits, the tags and `--pullrequest`'s merge for every skill that may, so the rules that keep a commit, a merge or a push safe live in one file rather than in whichever caller remembered them |
| `handoff-writer` | `record.handoff` | Writes the handoff a fresh session inherits, at whatever scope its caller asked for |
| `manifest-writer` | `.claude/workflow.json` | Writes `.claude/workflow.json` — validates each key against `workflow/manifest.md`, refuses one nothing reads or whose path does not resolve, and runs the doctor. Decides nothing: the caller arrives having settled the values |
| `reference-writer` | `record.reference` | Writes the record of what the system *is* — stack, architecture, data model, stated conventions. Often the project's `README.md`, where the manifest maps it there |
| `sweep-tracker` | the sweep checkpoint | Records which commit each sweep last verified and what it covered, so the next one re-reads only what changed |

## The shared check methods

In `workflow/checks/`, not in the skills that wrote them. Each is one way of
finding inconsistency in something the project has written down; the skill that
runs one supplies the scope and decides what happens to a finding.

Extracted on 2026-08-02. All three were already single-sourced, but were reached
by citing another skill's headings — a reference that breaks silently on a rename
and leaves the borrower reporting success over checks it never ran.

| Method | What it finds | Run by |
|---|---|---|
| `record-drift.md` | six classes of drift in a record, and the four things that look like drift and are not | `--check`, `--full-check`, `--stocktake` |
| `docs-audit.md` | a docs site's internal correctness — paths, links, anchors, enumerations, page accuracy against source | `--docs`, `--full-check` |
| `tooling-claims.md` | mutable claims inside the tooling files, deleted rather than corrected | `--tools`, `--full-check` |

A method says what counts as a finding; a runner decides scope, disposition and
owner. Material that drifts to the wrong side of that line stops being borrowable.

## Backlog providers

In `workflow/providers/`. Every record is a markdown file except one:
`record.todo` may name a **provider** object instead of a path, and then the
backlog is a set of open issues. It exists because a team already living in
GitHub Issues cannot adopt a workflow whose backlog is a file — they would be
maintaining two, and the second one loses. Nothing else in `record.*` takes a
provider, deliberately: `record.decisions` and `record.openDecisions` are prose
read months later by someone reconstructing why, and an issue thread is a
conversation rather than a record.

Declared in `.claude/workflow.json`:

```json
"record": { "todo": { "provider": "github-issues", "repo": "owner/name", "label": "backlog" } }
```

| Provider | Contract | Required | Optional |
|---|---|---|---|
| GitHub Issues | `workflow/providers/github-issues.md` | `repo` | `label` — without it the backlog is *every* open issue in the repository, including bug reports filed by users, which is almost never meant |

Readers key on the presence of a `provider` key rather than on the value being an
object, because `record.tooling` is an object too and is not a provider.

The mapping is the markdown one, item for item: an unchecked `- [ ]` becomes an
open issue with the label, its bold short name becomes the title, and **closing
the issue is how an item leaves the backlog** — not a "done" comment, because a
backlog is forward-looking and a closed issue is what that reads like here.
`project-record` is the sole writer of issues carrying the label; an issue
without it belongs to somebody else.

**Every skill that touches the backlog goes through the provider, not just
`--todo`** — `--adopt` offers the choice and `manifest-writer` validates it,
`--start`, `--check` and `--full-check` read it, `--wrap` counts it. None of them
may write a local `TODO.md` when the remote is unreachable: a project that
declared a provider and finds a stray markdown backlog appearing has the two
backlogs this exists to prevent. They say what could not be reached and write
nothing.

`doctor.sh` is where a broken one surfaces. It **fails** on a provider nothing
implements, on a missing `repo`, and on a `repo` that does not resolve — that
last one being a manifest fault rather than a transient one, so it routes to
`--adopt` in amendment mode. It **warns** when `gh` is absent or unauthorized,
because the manifest is correct and only the machine is not.

One cost worth knowing: **a checkpoint cannot narrow an issue sweep the way it
narrows a file sweep.** A file's staleness is a diff against a baseline commit;
an issue's leaves no trace in the repository's history at all, so an issue
backlog is always read in full.

## Skills scoped to this repository

None, and the reason is worth reading before adding one.

The mechanism exists and every project may use it: a skill under
`.claude/skills/` is resolved there before the global suite, which is how a
project ships conventions the global skills cannot know. The argument for
putting one there is cost — a skill in `skills/` loads its description into
every session of every project, so one nothing else can use should not be paid
for everywhere.

This repository had two and now has none. `prune-skills` moved to `skills/`, and
`repo-health` was merged into `--full-check` outright. Both had been written as
though their subject were peculiar to this checkout, and in both cases it was
not: running a project's own checks, triaging the defects other sessions filed,
and keeping a tooling catalog from going stale are things any adopted project
wants. What looked project-scoped was a global concern with this project's paths
hardcoded into it.

The test that follows from that: before scoping a skill to a repository, ask
whether the *concern* is local or only the *paths* are. If it is the paths, the
manifest is the answer and the skill belongs in `skills/`.

## Scripts

| Script | What it does |
|---|---|
| `doctor.sh` | Read-only health check of this config and the project in the working directory. Prints what it checks, so the list cannot go stale |
| `hooks/shorthand-flags.sh` | The `UserPromptSubmit` hook that turns a `--flag` into a deterministic skill invocation rather than a judgement call |
| `hooks/session-check.sh` | The `SessionStart` hook — the only thing here that speaks unasked, so it is built to stay silent unless something is worth a session's attention: a doctor failure, a sweep or a record gone stale, a filed bug report, or a handoff the harness would not otherwise load |
| `hooks/hooks.json` | Declares those same two events when this is installed as a **plugin**, where `settings.json` belongs to the user and a plugin never owns it. Plugin hooks merge with the user's rather than replacing them, so an adopter's own hooks keep firing |
| `.claude-plugin/plugin.json` | The manifest that makes the directory installable, and what `claude plugin validate` reads |
| `.claude-plugin/marketplace.json` | Makes the same directory its own marketplace, listing one plugin whose `source` is `"./"` — so an installer adds this repository as a marketplace and installs from it, with no second repository to keep in step. Handed a directory holding both manifests, `claude plugin validate` checks this one; name the file to check the other |
| `skills/docs/assets/scaffold.sh` | Creates a docsify site shell — and only the shell, never content. Refuses to touch an existing directory, and prints the steps it deliberately leaves to the caller. Invoked by `--docs` in Scaffold mode |
| `tests/hook-contract.sh` | The contract tests for the hook, whose breakage is total and silent |
| `.github/workflows/verify.yml` | CI. Shell syntax, skill frontmatter, cross-links, absolute paths, the hook tests and the doctor. Runs on a push to any branch except `main`, on **every pull request**, and on manual dispatch — `main` is reached only through a PR, and with no branch protection on it that PR run is the only check standing between `dev` and `main` |

## Agents

None. Every `agents.*` role in the manifest schema is something an *adopting*
project declares; this repository declares none, so a skill that would route a
lane to an agent does that work inline and says so.
