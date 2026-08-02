# Overview

What the repository contains, what a Claude Code session loads from it and when,
and how to check that any of it is working.

## The stack, such as it is

There isn't one. No package manager, no dependencies, no build step, no runtime.
The project is markdown instruction files plus a small set of POSIX shell scripts
— `git ls-files '*.sh'` is the list, deliberately, because a count written here
has already gone stale once — and CI runs `bash -n`, `shellcheck`, `jq` and a
hand-written test harness.

That is a deliberate constraint rather than an accident of youth: the artifact is
a *configuration directory* that must be adoptable on a machine that has nothing
installed, and every dependency added is a dependency an adopter has to satisfy
before a single skill runs.

## Layout

```
~/.claude/
│
├── settings.json          hooks and permissions — the file that wires everything
├── CLAUDE.md              loaded into EVERY session of EVERY project
├── README.md              adopting the repo, and what each `--flag` does
├── LICENSE
│
├── doctor.sh              read-only health check — see "Verifying" below
│
├── hooks/                 both hook scripts, and the hooks.json a plugin needs
│   ├── shorthand-flags.sh   UserPromptSubmit — `--flag` to invocation
│   ├── session-check.sh     SessionStart — see "The hooks" below
│   └── hooks.json           read only when installed as a plugin
├── .claude-plugin/        plugin.json — what makes this directory installable
│
├── skills/                the global suite; available in every project
├── workflow/              the contracts every skill links to instead of copying
│
├── .claude/workflow.json  the manifest — which file plays which record role
├── .claude/HANDOFF.md     record.handoff, mapped away from CLAUDE.md
├── .claude/HAZARDS.md     the standing hazards, split out of the handoff
├── .claude/TOOLING.md     record.tooling.catalog — source for the annex page
├── TODO.md                record.todo
├── ROADMAP.md             record.roadmap — milestones, and what authorises a tag
├── CHANGELOG.md           record.changelog
│
├── tests/                 the hook contract tests, whose breakage is silent
├── .github/workflows/     CI
│
└── docs/                  this site — and the decision, open-decision and audit records
```

`workflow/` sits outside `skills/` on purpose. A directory under `skills/` with
no `SKILL.md` is ignored today, but relying on that is a bet on Claude Code's
discovery internals rather than on documented behaviour.

**Every `record.*` path in that tree is named by `.claude/workflow.json` rather
than by convention**, and that manifest is the first file both `--adopt` and
`doctor.sh` resolve against — which is why a repo running the workflow on itself
needs one at all. A project without a manifest still works: skills fall back to
the conventional names in `workflow/manifest.md` and skip what they cannot
resolve. The fallback worth knowing is `record.handoff`'s, which is
`CLAUDE.md` — under it
the handoff is loaded by the harness with no wiring, and then paid for in every
session of that project. This repo maps it to `.claude/HANDOFF.md` instead, and
that mapping is exactly the condition under which `session-check.sh` injects it.

## What a session loads, and when

This is the part that decides what everything costs, because a byte in one place
is paid for far more often than a byte in another.

| Loaded | When | Consequence |
|---|---|---|
| `CLAUDE.md` | every session, every project — **in the checkout form only** | the most expensive file in the repo, and unread entirely as a plugin |
| Each skill's frontmatter `description` | every session | it is what decides whether the skill is ever invoked |
| A skill's **body** | only when that skill is invoked | length here is cheap by comparison |
| `skills/docs/references/*.md` | only when the `docs` skill reads one | reference detail belongs here, not in a body |
| A `shorthand-flags.sh` block | when its flag fires | injected into the prompt |
| The project's `record.handoff` | every session in **any** project whose manifest maps it away from `CLAUDE.md`, via `session-check.sh` | so handoff length is a permanent per-session cost of adopting, not a local quirk |

Two rules follow. **A description must carry every case that should trigger the
skill, and nothing else** — no procedure summary, no inventory of callers, since
routing to a skill happens from the calling skill's body rather than from the
callee's description. And a "not for X" clause is the expensive kind of mistake:
it cannot be caught by using the skill, because its effect is that the skill is
never used, so the body that would correct it never loads.

Measured, the always-loaded floor is `CLAUDE.md` plus the sum of every skill
description — a few thousand tokens in every session of every project, before
anything happens. A skill body is paid only when invoked, which is why detail
belongs there and not in a description.

## What can be switched off, and what cannot

The lever above has a hard limit, and which shape the suite is in decides whether
you have it at all.

**As a checkout**, `skillOverrides` in `settings.json` controls each skill
individually. This repository sets eight dispatch-only primitives to `name-only`,
so their descriptions do not load in sessions that can never invoke them — those
skills are reached only by another skill dispatching to them, so a description is
pure cost. `doctor.sh` guards the arrangement: its dispatch-only check (the
`dispatch-only skills vs overrides` section) warns when a skill no flag maps to
has no override entry, and
its pass line names how many it compared, **so read that line rather than the
summary**. It refuses `off` for these deliberately — `off` blocks *model*
invocation, which is the only kind a dispatched skill ever gets, so it would not
trim the skill but break it.

**As a plugin, none of that reaches the skills.** `skillOverrides` is ignored for
plugin skills at `off` as well as `name-only`, under bare and namespaced keys
alike. The Claude Code documentation states it outright — *"Plugin skills are not
affected by `skillOverrides`. Manage those through `/plugin` instead"* — and what
`/plugin` manages is plugins: `claude plugin disable <name>` takes every skill in
one with it.

**This suite is one plugin**, so once it is distributed that way, installing it
brings every skill and every flag with no way to decline any of them. There is no
in-suite substitute to build instead, because `skillOverrides` was the mechanism
any per-skill selection would have used. **The rejected alternative was shipping
several plugins by dependency group**, which would have made the group the unit of
choice; it was tried, proven to work, and dropped because the suite's skills reach
their shared contracts by relative link and every one of those would have had to
be re-anchored across plugin boundaries. [`docs/decisions.md`](decisions.md)
carries both decisions and what each cost.

One thing this is *not*: the overrides and the `doctor.sh` check are **not dead
code**. They are correct for the checkout shape, which stays supported.

**A second, unrelated way the forms differ: a plugin root's `CLAUDE.md` is not
loaded as project context at all.** `claude plugin validate` says so and suggests
a skill instead. So an adopter who installs rather than clones would get no
statement that the workflow is global, that skills read `.claude/workflow.json`,
or where the three contracts are — none of which is inferable from a skill body.
That is what `workflow-contracts` carries, and why `CLAUDE.md` now holds the
contract paths and a pointer rather than the rules themselves: one owner, in the
form that can actually reach both. The warning does not go away, because it fires
on the file existing at the plugin root rather than on what is in it.

Writing that skill turned up a plain defect alongside the two costs. `CLAUDE.md`
named the contracts as `~/.claude/workflow/*.md`, which resolves to nothing under
a plugin install — the suite sits at `${CLAUDE_PLUGIN_ROOT}` while `~/.claude`
holds the adopter's own settings. `doctor.sh` had resolved both forms correctly
since the conversion; the prose had not. The skill links them relatively, as the
rest of the suite does.

**What is and is not built.** The plugin *form* is built —
`.claude-plugin/plugin.json` and `hooks/hooks.json` both exist and
`claude plugin validate` passes. What does not exist is anywhere to install it
*from*: no public repository and no marketplace entry, which is `0.2.0`'s
remaining work. So the checkout is the route for an adopter today. It is not the
only way to *run* one, though — `claude plugin marketplace add` accepts a local
path, so a `git archive HEAD` copy can be installed and measured without
publishing anything, and that is how the cost figures above were taken.

## The hooks

Two events are wired in `settings.json`, and both fail *silently* when
misconfigured — the event fires, nothing happens, and behaviour degrades without
an error.

Both scripts live in `hooks/`. Installed as a plugin the wiring comes from
`hooks/hooks.json` instead, which declares the same two events against
`${CLAUDE_PLUGIN_ROOT}`; plugin hooks **merge** with the user's rather than
replacing them, so an adopter's own hooks keep firing.

- **`UserPromptSubmit` → `hooks/shorthand-flags.sh`.** Turns a `--flag` into an
  explicit instruction to invoke a skill. Without it, every flag falls back to
  being matched from a skill description, which is reliable in practice but not
  guaranteed. Flags are read only from a run at the very start or very end of a
  message, so a pasted `git branch --track origin/dev` does not fire anything.
- **`SessionStart` → `hooks/session-check.sh`.** Silent when there is nothing worth a
  session's attention, because its output is injected into every session's
  context — a chatty version would be both a permanent token cost and a warning
  nobody reads. It speaks on a `doctor.sh` **failure** (warnings are routinely
  benign, and a dirty tree reported every session would train the reader to skip
  the whole block); on a sweep checkpoint 40 commits behind `HEAD`; on open
  decisions unchanged for 25 commits, or a backlog or roadmap unchanged for 80 —
  but only for records the project's manifest actually *declares*, and only
  while the file has entries at all, since an empty open-decisions log is the
  normal state and nudging about it is exactly what would teach a reader to skip
  this block; and never for a backlog that names a provider rather than a file,
  because "unchanged for N commits" cannot be asked of a set of issues that
  leaves no trace in this repository's history; and on an open entry in `bug-reports.md`, which nothing else
  surfaces because the file is gitignored. Age is counted in **commits, not dates** — no date
  semantics exist anywhere else in this workflow, and a hook is the wrong place
  to introduce one. One output is not a warning at all: it injects the project's
  handoff, and only where that project mapped `record.handoff` away from
  `CLAUDE.md`. Where the handoff *is* `CLAUDE.md`, or undeclared, or absent, it
  stays silent — the harness has already loaded it, or there is nothing to load,
  so injecting would put the same file in context twice. Read the script for the
  current thresholds; it is the authority and this page describes it.

Because the failure is silent, `doctor.sh` checks the wiring rather than assuming
it. That state persisted unnoticed on one machine for weeks.

## Verifying

```bash
./doctor.sh                    # read-only; prints every check it performs
bash tests/hook-contract.sh    # the hook's contract
```

**Run these rather than trusting any list written in markdown, including this
page.** The doctor has caught classes of drift that reading did not: an
unadopted checkout, dangling citations that read exactly like live ones, a
manifest key no skill reads, a `.gitignore` silently refusing to track new
files, and bugs in itself twice.

It also checks the invariant this suite rests on that nothing else can: that
each `--flag`'s stated grant matches between the hook that fires it and the
ownership matrix — two hand-written copies of the same fact.

## Key files

- `hooks/shorthand-flags.sh` — the `FLAGS` array is the set of tokens the hook will
  decompose a run into; each flag's *grant* is written into the block it
  injects, not into the array. The list of flags is restated for different
  readers in `README.md`, `workflow/ownership.md`, `.claude/TOOLING.md` and
  [the annex](annex/claude-tooling.md), so treat none of those as the source.
  The grants are restated in exactly one other place — `workflow/ownership.md` —
  which is what makes the pair comparable at all; see "Verifying" above.
- `doctor.sh` — read-only. It never writes, so it is always safe to run.
- `workflow/ownership.md` — the authority on who may write what. It settles any
  disagreement between two skills.
- `workflow/record-contract.md` — what each record file holds and must not hold.
- `workflow/manifest.md` — which keys a project's `.claude/workflow.json` may
  set, and what each falls back to when absent.
