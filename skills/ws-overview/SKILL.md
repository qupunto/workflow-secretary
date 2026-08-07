---
name: ws-overview
description: "Report where a project stands at a glance — record counts per lane, sweep freshness, pending warnings, the nearest milestones, branch and lane — read fresh at invocation, writing nothing. SHORTHAND: `--ws-overview`. Also trigger on \"where does the project stand\", \"state of the repo\", \"project status at a glance\"."
---

# The project at a glance

**This skill writes nothing.** No record, no checkpoint, no commit, no sweep.
Anything that looks wrong is reported with the flag that owns fixing it, in
one line, and left alone.

## Run the probe first

Every mechanical number in the report comes from one script, run from the
project directory:

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/workflow-secretary/*/ 2>/dev/null | tail -1)
bash "$S"/skills/ws-overview/assets/probe.sh
```

The two resolution lines are [`ws-contracts`](../ws-contracts/SKILL.md)'
canonical form.

The probe is read-only and offline. It resolves `.claude/workflow.json`
itself — conventional fallbacks, the `.claude/lane` selector, `lanes.named`
overrides, all per [`manifest.md`](../../workflow/manifest.md) — counts every
record, runs `doctor.sh`, computes each sweep baseline's distance from HEAD,
locates the roadmap's first goal with open blocks, and locates the release
list's first milestone not marked completed. **The roadmap is lane-resolved
and the release list never is** — one release checkpoint per project, however
many lanes it runs, per
[`record-contract.md`](../../workflow/record-contract.md). **Quote its
block rather than re-rendering it**: paste the probe's output as the report,
then append the judgment lines below — one line each. Every number
was read at this invocation: never carried forward from a handoff card,
memory, or an earlier session. A count is a mutable claim, so it lives in
the reply and never lands in a file
([`record-contract.md`](../../workflow/record-contract.md#the-mutable-claim-rule)).

Where the probe cannot run at all, read and count by hand to the same
contract, and say so in one line.

## What the model adds — the judgment lines

The probe stops where mechanics stop. On top of its output:

- **Finish the lines it marks "not counted here" or "not checked".** A
  provider-backed backlog is counted through
  [`providers/github-issues.md`](../../workflow/providers/github-issues.md)
  — mind its read-after-write rule — or reported *not checked* when `gh`,
  the network, or the provider is unreachable. Never dropped: an absent line
  reads as clean.
- **Interpret both positions, and keep them apart.** The roadmap's is *what
  this area is working toward* — in a lane worktree, that lane's, and say
  which lane. The release list's is *what ships next*: name the first
  milestone not marked completed, whether it is a real milestone or a
  maintenance coda, and which of its versions is the nearest minor and which
  the nearest major. **A goal being met is not a milestone being complete**,
  and nothing derives one from the other.
- **Say when the probe warns that a roadmap heading carries a version or a
  completion mark.** That is a release checkpoint in the wrong file — under
  lanes, one worktree's — and it goes to `--ws-plan`.
- **Keep the probe's distinct states distinct.** "Undeclared", "missing" and
  "0 open" are three different facts — "no backlog is declared" and "the
  backlog is empty" must never render as the same bare `0`.
- **Report, never repair.** Stale sweep → name `--ws-check`. Untriaged inbox
  → name `--ws-full-check`. A milestone that looks complete → name
  `--ws-plan`. One line each; acting on them is those flags' work, under
  their grants.

## What this skill does not do

- **It does not stamp anything.** Reading records is not a sweep and earns no
  checkpoint — `sweep-tracker` never hears from it, and the probe is as
  read-only as the skill.
- **It does not verify claims.** Drift detection is `--ws-check`'s method;
  this skill counts what the records say, not whether they are right.
- **It does not rebuild or reorder anything** — backlog is `--ws-todo`'s,
  roadmap is `--ws-plan`'s, and a full reckoning is `--ws-stocktake`'s.
