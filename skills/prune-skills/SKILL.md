---
name: prune-skills
description: "Find prose in a project's skill and agent files that does not change what Claude does — flavour, anecdote, reasoning that belongs in a commit message — and dispatch the cuts to `--tools`. SHORTHAND: `--prune`. Also trigger on \"prune the skills\", \"trim the skill files\", \"these files are getting long\"."
---

# Pruning the skill files

`--tools` deletes claims that have gone *false*; it is silent on prose that is
verbose and true. That prose is this skill's job.

## The `--prune` shorthand

`--prune` invokes this immediately, with no confirmation. It grants **COMMIT, not
push** — which this skill never exercises itself, because it writes nothing: the
grant is what `--tools` inherits when the cuts are dispatched to it, so the cuts
land in a commit rather than only in the working tree.

Where a flag counts, and the authorization it confers, live in
`shorthand-flags.sh` and [`README.md`](../../README.md) — one copy,
not restated per skill.

## Scope

The files are **`record.tooling.sources`** in the project's
`.claude/workflow.json` — the same set `--tools` owns, so the two skills can
never disagree about what a tooling file is. Without a manifest, fall back to
`.claude/skills/*/SKILL.md` and `.claude/agents/*.md` and say in one line that
you did.

Both scopes count where a project has both.

## It writes nothing. It dispatches to `--tools`.

`--tools` is the sole writer of these files. This skill reads, classifies,
measures and reports; the owner re-verifies and makes the cut, exactly as
`--check` dispatches rather than fixing — a proposed cut is a hypothesis, and a
wrong one fails silently.

Ownership, and why the second look is load-bearing, are
[`ownership.md`](../../workflow/ownership.md#the-inspector-writes-nothing).

## The test

**A line stays if removing it would change what Claude does.**

Apply it literally, paragraph by paragraph. Three things pass:

1. **Behaviour** — a rule, threshold, ordering, boundary, path, command, or the
   name of a file or skill to hand something to.
2. **Defence of a counterintuitive rule.** A rule that looks wrong gets reverted
   by the next session that reads it. The sentence explaining *why it is not
   wrong* is load-bearing, because without it the rule does not survive. Keep it
   — but as **one clause**, not a paragraph and not a story.
3. **Routing** — the frontmatter `description`. It is the only part loaded in
   every session, so it is both the most expensive text here and the one whose
   removal breaks the skill outright.

Everything else is a candidate: the second illustration of a point already made,
the history of how a rule was arrived at, the reassurance that a rule is
sensible, the paragraph restating the section above it.

**Nothing is destroyed, only relocated.** Reasoning with durable value goes to
`record.decisions` through `--log`, or into the commit message that makes the
cut. A skill file is the wrong home for it either way.

## What is never cut

Four hazards, each of which fails silently:

- **A heading another skill cites by name.** Delete or rename that heading and
  the citation resolves to nothing while still reading as live. The suite's
  `doctor.sh` checks these; run it before proposing and after cutting.
- **The last statement of a rule.** Before cutting a restatement, confirm the
  rule is actually stated elsewhere and say where. Two copies is duplication;
  zero is a behaviour change disguised as tidying.
- **A link to a `workflow/*.md` authority.** Those pointers are what keep the
  contract in one place instead of copied into every skill.
- **Text inside a fenced block.** Scripts, JSON and command sequences are
  executed or copied verbatim. Comments in them are not flavour.

**An agent file adds a fifth: its `tools:` list and its frontmatter
`description`.** The description is what the orchestrator matches a task
against, so cutting it narrows what the agent is ever chosen for — a failure
that shows up as the agent never running, not as anything reporting an error.

## Procedure

1. **Resolve scope** through `sweep-tracker`, entry `prune`. A file unchanged
   since the last prune was already judged; re-reading it produces the same
   answer. Voided for any file `--tools` has edited since, and for all of them if
   the test above changes.
2. **Read each file in scope and classify every paragraph** against the test.
   Delegate the reading — a subagent per file, returning candidate cuts with the
   test each one fails. Only the verdicts need to reach this context.
3. **Re-check each candidate yourself** against the hazards. This is the step
   that makes the report worth acting on; skipping it turns the skill into a
   generator of plausible deletions.
4. **Measure.** Bytes before, bytes proposed, and the share of the file. A cut
   worth less than a percent or two is not worth the churn or the risk.
5. **Report and dispatch** to `--tools`, grouped by file, each cut quoted with
   the test it fails and where its content survives if it survives anywhere.
6. **Verify after the cuts land**: the suite's `doctor.sh`, then the project's
   `commands.test` where it declares one. Both must pass, and section citations
   in particular must still resolve.
7. **Stamp `prune` through `sweep-tracker`** — one scope, `prose` — with the
   baseline and, per file, what was covered and what was not. Offering only a
   commit id claims the whole scope by omission, and that stamp is refused.
   **A file whose candidates were refused or deferred is `not-covered`.** It was
   judged and still carries cuts; stamping it `covered` asserts it was found
   clean and hides that work from every later prune. Only a file whose
   candidates were all either cut or judged lean is `covered`.
   **Take the baseline after the cuts land, not before.** Step 1 voids the
   narrowing for any file `--tools` has edited since — and `--tools` is what
   applies these cuts, so a baseline taken earlier marks every pruned file
   edited-since and voids the whole entry. Taken after, "edited since" means
   edited for some *other* reason, which is the case that does warrant a
   re-read.

## Report the negative result too

A file that is already lean is a finding. Say so rather than proposing marginal
cuts to justify the run — a pruner that always finds something teaches you to
stop reading its output, and this is a skill whose whole value is that its
proposals get taken seriously.
