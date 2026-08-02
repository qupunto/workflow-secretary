#!/usr/bin/env bash
# UserPromptSubmit hook: turns a `--flag` shorthand into a deterministic skill
# invocation. The FLAGS array below is the list — deliberately not restated
# here, because a second copy is a stale inventory waiting to happen, and this
# one had already fallen a flag behind.
#
# Every flag here maps to a GLOBAL skill. A flag whose skill is project-scoped
# belongs in that project's own hook, not this one — a global block guarding a
# skill only one project has is a standing warning here and a set of rules that
# project cannot edit.
#
# Skills are model-invoked — Claude decides whether a request matches the
# skill's description, so a shorthand written only into a description is
# reliable in practice but not guaranteed. This hook is the deterministic
# path: the instruction is injected whether or not Claude would have noticed.
#
# WHERE A FLAG COUNTS. Flags are read from a *run* at the very START or the
# very END of the message. A run is one or more whitespace-separated tokens,
# each of which decomposes entirely into flags — so `--stocktake --release`,
# `--stocktake--release` and `--stocktake --release --wrap` all fire every flag they
# name, and a message made of nothing but flags is covered end to end by the
# two runs meeting in the middle.
#
# Matching anywhere in the message would fire on a pasted command that happens
# to contain a flag (`git branch --track origin/dev` being the realistic case)
# and on any message that merely *discusses* a flag. A token must decompose
# with nothing left over, so `--wrapper` and `origin/dev` end a run rather than
# extending it.
#
# Wired up from ~/.claude/settings.json. Silent (exit 0, no output) when no
# flag is present, so it costs nothing on ordinary turns.

# Two hard dependencies, both of which fail SILENTLY without a guard, and both
# of which degrade exactly the way this hook exists to prevent: every flag goes
# inert, the hook exits 0, and nothing says so for weeks.
#
#   jq  — without it the prompt parses empty, no token decomposes, and the
#         `${#ordered[@]} -eq 0` exit below looks like an ordinary flagless turn.
#   bash 4 — `declare -A` below needs bash 4, and /bin/bash on stock macOS is
#         still 3.2. CI only ever runs ubuntu-latest, so no pipeline covers it.
#         It fails at RUNTIME ("declare: -A: invalid option") rather than at
#         parse time, which is the only reason a guard ABOVE it gets to run at
#         all — leaving `seen` an indexed array, so the next subscript evaluates
#         `--wrap` as arithmetic. Keep this check above line ~103.
#
# Both write to stderr and exit 0: a non-zero exit here would block the user's
# turn outright, and a broken shorthand must never cost someone their prompt.
if ! command -v jq >/dev/null 2>&1; then
  echo "shorthand-flags.sh: jq not found — every --flag is inert until it is installed" >&2
  exit 0
fi
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "shorthand-flags.sh: needs bash 4+ (found ${BASH_VERSION:-unknown}) — every --flag is inert" >&2
  exit 0
fi

payload=$(cat 2>/dev/null)
prompt=$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null)

# The invariant this list must keep: NO FLAG IS A PREFIX OF ANOTHER. Where that
# holds, a token can never be split into a shorter flag plus junk and the order
# below does not matter. `--stocktake` and `--full-stocktake` look like they collide and
# do not — the latter has its own leading dashes. doctor.sh checks the invariant
# rather than trusting this comment; add a flag that violates it and it fails.
FLAGS=(--full-stocktake --pullrequest --full-check --release --stocktake --adopt --prune --flags --start --track --docs --check --tools --todo --wrap --plan --help --log)

# Split into whitespace-separated tokens. `set -f` because an unquoted
# expansion would otherwise glob `*` in the prompt against the filesystem.
set -f
tokens=($prompt)
set +f
n=${#tokens[@]}

# Print every flag a token is built from, or fail if any part of it is not a
# flag. `continue 2` restarts the while loop after a successful match.
decompose() {
  local s=$1 f out=()
  while [ -n "$s" ]; do
    for f in "${FLAGS[@]}"; do
      if [[ $s == "$f"* ]]; then
        out+=("$f")
        s=${s#"$f"}
        continue 2
      fi
    done
    return 1
  done
  [ ${#out[@]} -gt 0 ] || return 1
  printf '%s\n' "${out[@]}"
}

# The leading run, then the trailing run — the second never reaching back past
# where the first stopped, so an all-flags message counts each flag once.
lead_end=0
while [ $lead_end -lt $n ] && decompose "${tokens[$lead_end]}" >/dev/null; do
  lead_end=$((lead_end + 1))
done
tail_start=$n
while [ $tail_start -gt $lead_end ] && decompose "${tokens[$((tail_start - 1))]}" >/dev/null; do
  tail_start=$((tail_start - 1))
done

# Collect in the order the user typed them, deduplicated: multiple flags now
# fire together, and the order they run in should be the order they were asked
# for.
declare -A seen=()
ordered=()
collect() {
  local f
  while IFS= read -r f; do
    [ -n "${seen[$f]:-}" ] && continue
    seen[$f]=1
    ordered+=("$f")
  done < <(decompose "$1")
}
for ((i = 0; i < lead_end; i++)); do collect "${tokens[$i]}"; done
for ((i = tail_start; i < n; i++)); do collect "${tokens[$i]}"; done

[ ${#ordered[@]} -eq 0 ] && exit 0

# `--stocktake` and `--full-stocktake` are the same skill at two scopes, so they are
# mutually exclusive and the wider one wins.
if [ -n "${seen[--full-stocktake]:-}" ]; then
  unset 'seen[--stocktake]'
fi

# `--full-check` is a different SKILL from `--check` rather than a wider scope of
# it, but it runs --check's method over --check's files as one of its three
# areas, so firing both sweeps the record twice. The wider one wins.
#
# `--docs` and `--tools` are deliberately NOT dropped, even though --full-check
# subsumes their SWEEPS. Both of those flags have a second, unrelated job —
# writing a page, syncing the catalog — and `--full-check --docs auth` is a
# health check followed by a request to document something. This hook cannot
# tell that apart from a redundant sweep, and dropping a write request to save
# one read is the wrong way to be wrong. The multi-flag preamble already tells
# Claude to do a shared step once.
if [ -n "${seen[--full-check]:-}" ]; then
  unset 'seen[--check]'
fi

# Either stocktake flag absorbs `--check`. project-stocktake runs --check's
# method over --check's files as its record dimension and says so — "invoke one
# or the other, never both" — so firing both sweeps the record twice, and the
# second sweep reports the first one's writes as fresh drift.
#
# `--full-check` is deliberately NOT dropped here, on the same reasoning that
# spares --docs and --tools above. It is a different skill, not a wider scope:
# it also covers the docs site and the tooling files, neither of which a
# stocktake touches. Dropping it would silently narrow what the user asked for.
if [ -n "${seen[--stocktake]:-}" ] || [ -n "${seen[--full-stocktake]:-}" ]; then
  unset 'seen[--check]'
fi

# Only claim a flag whose skill actually resolves here — at user level, or in
# this project. Injecting "follow the X skill" where X does not exist is an
# instruction Claude cannot carry out, so an unresolvable flag is left INERT
# rather than fired. That gate is what lets global and project-specific skills
# share one hook: a project simply does not get the flags it has no skill for.
# The third root is what makes this hook work when the configuration ships as a
# plugin rather than as ~/.claude. Without it every flag is INERT for a plugin
# install — the gate that makes an unresolvable flag safe becomes the thing that
# disables the whole feature, and it does so silently, which is the worst way to
# find out.
#
# The user root is CLAUDE_CONFIG_DIR when it is set, NOT $HOME/.claude. doctor.sh
# and session-check.sh both resolve it that way; this hook did not, so under a
# custom config dir it gated flags against a skills/ tree the harness was not
# loading — firing a flag for a skill that will not be there, or leaving one
# inert that will. Same variable, same precedence, all three scripts.
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

skill_exists() {
  [ -f "$PWD/.claude/skills/$1/SKILL.md" ] ||
    [ -f "$CONFIG_DIR/skills/$1/SKILL.md" ] ||
    { [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/skills/$1/SKILL.md" ]; }
}

# Existing on disk is not the same as runnable. Settings can disable a skill by
# name under `skillOverrides`, and an override leaves SKILL.md exactly where it
# was — so the check above passes, this hook injects "invoke the X skill now",
# and the harness then refuses. The user sees an instruction and a refusal in
# the same turn, which is worse than the flag having done nothing.
#
# The key, its four levels, and the precedence below are read off the CLI
# (2.1.220), not assumed:
#
#   - the schema is a map of skill name to one of on / name-only /
#     user-invocable-only / off;
#   - two of those block MODEL invocation, which is the only kind this hook can
#     ask for: `off`, and `user-invocable-only` — the latter is also what a
#     skill author's own `disableModelInvocation` resolves to. `name-only` trims
#     what is loaded into context and still runs, so it fires normally;
#   - project settings outrank user settings, and nothing else participates.
#     `settings.local.json` is a real settings scope but this key's resolver
#     does not read it, so neither does this. Reading it anyway would make a
#     flag inert for a skill that does in fact run — the same silent loss, in
#     the other direction.
#
# First file that names the skill wins. A file that does not mention it is not
# an answer, so the search continues rather than concluding "enabled".
skill_disabled() {
  local file level
  for file in "$PWD/.claude/settings.json" "$CONFIG_DIR/settings.json"; do
    [ -f "$file" ] || continue
    level=$(jq -r --arg s "$1" '.skillOverrides[$s] // empty' "$file" 2>/dev/null)
    [ -n "$level" ] || continue
    case $level in
      off | user-invocable-only) return 0 ;;
      *) return 1 ;;
    esac
  done
  return 1
}

# `-` means "served by this hook itself, not by a skill" — `--flags` is the only
# one. It is a real mapping rather than a missing arm on purpose: doctor.sh and
# the contract suite both FAIL on a flag whose skill_for() arm is absent, and
# that check is worth keeping sharp. A silent empty string would have made the
# one flag with no skill indistinguishable from a flag someone forgot to wire.
skill_for() {
  case $1 in
    --flags | --help) echo - ;;
    --track) echo track-complex-tasks ;;
    --todo | --log) echo project-record ;;
    --wrap) echo wrap-task ;;
    --start) echo start-work ;;
    --release) echo release ;;
    --pullrequest) echo pr-flow ;;
    --stocktake | --full-stocktake) echo project-stocktake ;;
    --adopt) echo adopt-workflow ;;
    --docs) echo docs ;;
    --tools) echo tooling-catalog-sync ;;
    --check) echo record-inspector ;;
    --full-check) echo full-health-check ;;
    --plan) echo roadmap ;;
    --prune) echo prune-skills ;;
  esac
}

# Where a skill's SKILL.md actually resolved, in the order skill_exists() tries.
skill_path_() {
  local p
  for p in "$PWD/.claude/skills/$1/SKILL.md" "$CONFIG_DIR/skills/$1/SKILL.md"; do
    [ -f "$p" ] && { printf '%s\n' "$p"; return 0; }
  done
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/skills/$1/SKILL.md" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT/skills/$1/SKILL.md"
    return 0
  fi
  return 1
}

# The leading clause of a skill's own description — what it does, before the
# shorthand and the trigger phrases. Read from the file rather than restated
# here: a second copy of sixteen one-liners is an inventory, and this hook has
# a comment at the top about exactly that failure.
skill_gist_() {
  awk '
    NR == 1 && /^---$/ { f = 1; next }
    f && /^---$/ { exit }
    f && /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      gsub(/\\"/, "\"")
      # cut at the first sentence end, the shorthand, or the trigger list
      if (match($0, / SHORTHAND:| Also trigger| Invoke on| Trigger on| Use whenever/))
        $0 = substr($0, 1, RSTART - 1)
      # Cut to the first sentence, but only while that still says something.
      # project-record opens with one short line about the record, and puts the
      # --todo / --log split in the sentence AFTER it, so cutting
      # unconditionally described both flags with the same nine words.
      # NOTE: no apostrophes in this comment. The whole program is inside a
      # single-quoted shell string, and one here ends it — which is a syntax
      # error in the hook that routes every flag.
      if (match($0, /\. [A-Z`]/) && RSTART >= 60) $0 = substr($0, 1, RSTART)
      sub(/[[:space:]]+$/, "")
      print; exit
    }' "$1"
}

# THE POINT OF THIS BLOCK: it is computed, every time, from the FLAGS array and
# skill_for() cases above and from each skill's own description. Nothing here is
# a second copy of anything, so it cannot drift from what the hook actually
# does — which is the failure mode a hand-written flag list has, and this repo
# has deleted two such inventories already for going stale.
#
# It also reports what resolves HERE, which a static list could never do: a flag
# whose skill is absent in this project is INERT, and saying so is most of the
# value. A user who types a flag and gets silence has no other way to find out.
flags_block_() {
  local f skill path gist state
  printf 'The user asked what flags exist. Present this table to them, as a table,\n'
  printf 'and add nothing to it from memory — it was computed from the hook that\n'
  printf 'actually routes the flags, so it is right by construction and anything\n'
  printf 'recalled alongside it may not be.\n\n'
  printf '| Flag | Runs | Here? | What it does |\n'
  printf '|---|---|---|---|\n'
  while IFS= read -r f; do
    skill=$(skill_for "$f")
    if [ "$skill" = "-" ]; then
      printf '| `%s` | — | yes | Lists these flags. Served by the hook, so it needs no skill. |\n' "$f"
      continue
    fi
    if path=$(skill_path_ "$skill"); then
      gist=$(skill_gist_ "$path")
      if skill_disabled "$skill"; then state='disabled'; else state='yes'; fi
    else
      gist=''
      state='**no**'
    fi
    printf '| `%s` | `%s` | %s | %s |\n' "$f" "$skill" "$state" "${gist:-—}"
  done < <(printf '%s\n' "${FLAGS[@]}" | sort)
  printf '\nA flag marked **no** is INERT here: its skill resolves in neither this\n'
  printf 'project nor the user configuration, so typing it does nothing at all\n'
  printf 'rather than failing. `disabled` means settings block model invocation.\n\n'
  printf 'Flags are read only from a run at the very START or very END of a\n'
  printf 'message, so a pasted command containing one does not fire it. Several\n'
  printf 'may be combined and run in the order typed.\n'
}

block_for() {
  case $1 in
  --flags | --help)
    flags_block_
    # The grant line stays HERE, at column 0 in a heredoc, rather than inside
    # flags_block_. doctor.sh reads this shape out of the hook source to compare
    # against ownership.md, and a grant it cannot extract is counted as blind
    # rather than passed — correctly, since a block whose authorization moved
    # out of reach is exactly how the comparison would go quiet.
    cat <<'EOF'

Authorization: none.
EOF
    ;;
  --track)
    cat <<'EOF'
The user included the `--track` flag. That is an explicit, unconditional
instruction to invoke the `track-complex-tasks` skill now. The usual complexity
threshold does NOT apply — do not skip the list because the work looks small.

Authorization: none.
EOF
    ;;
  --todo)
    cat <<'EOF'
The user included the `--todo` flag. That is an explicit, unconditional
instruction to park an idea rather than build it, using the `project-record`
skill — invoke it now, without asking for confirmation first.

The rest of the message is the idea to defer, not a question to answer.

Authorization: none.

Irreversible, in force before the skill loads: a deferral is a decision, so it
produces TWO entries — the task in the project's backlog record, and the
reasoning in its decision record. Never write the reasoning into the backlog.
If the real blocker is an unmade choice rather than bad timing it belongs in the
open-decisions record instead, and never in both.
EOF
    ;;
  --plan)
    cat <<'EOF'
The user included the `--plan` flag. That is an explicit, unconditional
instruction to invoke the `roadmap` skill now — what the next block is, how the
milestones and their blocks are ordered, or whether one is finished. The rest of
the message is scope, not a question to answer first.

Authorization: none.

Irreversible, in force before the skill loads:
- COMPLETING A MILESTONE IS THE USER'S CALL, NEVER YOURS. Never mark one complete
  on the strength of your own reading or an agent's report. Say what the
  milestone claimed, what landed, and what is still open against it — then ask.
- BUT ASK WHEN THE LAST BLOCK LANDS. Do not wait to be told.
- The mark you write is what authorizes `--release` to tag, so write it into the
  roadmap and not into the conversation: it must survive a `/clear`.
- A milestone with an open blocking decision, or with unremediated high-severity
  audit findings, is disqualified however finished it looks. Name it rather than
  letting a release discover it.
- The roadmap holds milestones, blocks and their order. Not tasks, not design
  arguments. Breaking a block into tasks is `--todo`'s job.
- Run the grep that would DISPROVE any "nothing does X" or count before writing
  it here.
EOF
    ;;
  --adopt)
    cat <<'EOF'
The user included the `--adopt` flag. That is an explicit, unconditional
instruction to run the `adopt-workflow` skill now — bring this project under the
workflow by writing `.claude/workflow.json`.

Authorization: COMMIT what it creates. Not push.

Irreversible, in force before the skill loads:
- If a manifest already exists this is an AMENDMENT, not a rewrite. Fill gaps
  only; never overwrite a key the project already chose.
- NEVER INVENT A PATH OR A COMMAND. Every value must be verified to exist or to
  be declared by the project's own tooling. A key you cannot resolve is LEFT
  OUT: a missing key degrades gracefully and says so; a wrong one misdirects
  every skill that reads it without ever failing.
- Record files are created EMPTY, with their heading and nothing else. The
  owning skill writes the first real line.
- Finish by running ~/.claude/doctor.sh and showing its output. Adoption is not
  complete on a failing doctor; never report success over one.
EOF
    ;;
  --check)
    cat <<'EOF'
The user included the `--check` flag. That is an explicit, unconditional
instruction to invoke the `record-inspector` skill now and health-check the
project's record for claims that no longer match reality and for updates the code
owes but never got.

Authorization: none — and this skill writes NOTHING.

Irreversible, in force before the skill loads:
- Do not fix what you find. Report it, then dispatch each finding to the skill
  that OWNS that file, and let that owner re-verify before writing. Your finding
  is a hypothesis, and a share of findings do not reproduce when re-checked.
- Run the grep that would DISPROVE a negative claim before repeating it. The
  usual way "nothing does X" goes wrong is a grep matching the wrong call shape.
- Chronological decision entries are NOT stale. An entry describing a decision
  later reversed is correct as written. Never dispatch a rewrite of one.
EOF
    ;;
  --full-check)
    cat <<'EOF'
The user included the `--full-check` flag. That is an explicit, unconditional
instruction to invoke the `full-health-check` skill now — re-verify every file
the project keeps for its functional value, at FULL scope: the records, the docs
site, and the tooling files.

Authorization: none — and this skill writes nothing that HAS AN OWNER.

Irreversible, in force before the skill loads:
- IGNORE every sweep checkpoint. Full scope means re-reading files a previous
  sweep listed as covered. Do not narrow to a diff.
- Stamp the checkpoints at the end, through `sweep-tracker`, and stamp ONLY what
  was actually read. An area whose reader died or returned a vague report is
  not-covered; coverage claimed and not earned is inherited by every cheap sweep
  after it and nothing downstream can detect the difference.
- Do not fix what you find IN A FILE THAT HAS AN OWNER. Dispatch each such
  finding to the skill that OWNS that file and let that owner re-verify first —
  your finding is a hypothesis, and a share of them do not reproduce. An owner
  invoked from here inherits THIS flag's grant, which is none: it writes its
  file and does not commit.
- A file with NO owner in the matrix is ordinary work: edit it directly and say
  what changed. Scripts, CI, the harness settings and the `workflow/*.md`
  contracts are the usual instances. Read this rule with the one above it —
  "dispatch everything" is what an earlier version of this block said, and it
  forbids the repair of a broken hook script that ownership.md licenses.
- Run the grep that would DISPROVE a negative claim before repeating it.
- The append-only logs — decisions, audits, changelog — are OUT of scope. An
  entry describing a decision later reversed is correct as written. The only
  thing to check about them is whether a generated index has gone stale.
- Source code and the test suite are OUT of scope. The suite is
  --full-stocktake's. Code analysis proper — correctness, security, the data
  model — is a PROJECT's own skill, which --stocktake invokes where one exists
  and reports as not run where none does. No flag here delivers it on its own.
EOF
    ;;
  --tools)
    cat <<'EOF'
The user included the `--tools` flag. That is an explicit, unconditional
instruction to invoke the `tooling-catalog-sync` skill now — keep the tooling
catalog in step with what skills and agents actually exist, and fix stale claims
inside those files.

Authorization: COMMIT. Not push.

Irreversible, in force before the skill loads:
- DELETE a stale mutable claim rather than correcting it. That one line is the
  part that overrides the instinct to be helpful, so it is here rather than only
  behind a link. Everything else the rule decides — what a skill or agent file
  may carry at all, and why a corrected count goes stale again — is stated once,
  in the "The mutable-claim rule" section of
  ~/.claude/workflow/record-contract.md. READ IT before editing any such file.
- Say in the commit what you removed and why. It is the only audit trail an
  erasure gets.
- NEVER edit a file belonging to THIS SUITE — its own skills, agents, workflow
  contracts and scripts — from a session working in another project. Not even
  the skill currently running, and not even when the defect is obvious. Under a
  plugin install the suite is at ${CLAUDE_PLUGIN_ROOT}; in a checkout it is the
  ~/.claude repository. Editing it under a plugin is not refused — it is
  destroyed at the next plugin update, silently.
- This does NOT restrict the working project's own skills and agents. Those are
  what record.tooling.sources globs, and editing them is this flag's whole job.
  Nor does it cover a personal ~/.claude/skills/ that is not this suite.
- Instead, APPEND the finding to bug-reports.md in the config directory
  ($CLAUDE_CONFIG_DIR, else ~/.claude) — the one file any session in any project
  may write to — then stop. It is gitignored and so ships with no template:

      ## [open] <one-line summary>
      Found: <project worked in> · <config commit, short SHA>
      File: <path within the suite> · Detail: <what is wrong, what you expected>

  Never report only into the conversation — that loses the finding at the next
  /clear. Filing IS the action, not a step on the way to fixing it. Triage
  needs a checkout; from a plugin install, raise it upstream as well.
EOF
    ;;
  --log)
    cat <<'EOF'
The user included the `--log` flag. That is an explicit, unconditional
instruction to invoke the `project-record` skill now and record a decision that
has already been made. The rest of the message is the decision, not a question
to answer first — and it is not a request to re-open it.

Authorization: none.

Irreversible, in force before the skill loads:
- The decision record is APPEND-ONLY. Never rewrite a past entry: one describing
  a decision later reversed is correct as written.
- A decision nobody actually made belongs in the open-decisions record instead,
  with what it blocks. Never write it as settled.
- Regenerate the decisions index afterwards if the manifest names a command for
  it. Never hand-edit one.
EOF
    ;;
  --wrap)
    cat <<'EOF'
The user included the `--wrap` flag. Treat it exactly as "wrap this up, I am
about to clear the session" — invoke the `wrap-task` skill immediately and
unconditionally, with no further confirmation, even mid-task.

The rest of the message is context about what to record, not a question to
answer first.

Authorization: COMMIT and PUSH.

Irreversible, in force before the skill loads:
- A push publishes a REF, not a selection of commits, so another session's work
  rides along with yours. Check what is about to go out and say plainly if it
  includes commits this session did not make.
- Never force-push, and never resolve a rejected push by force. A rejection
  usually means someone else pushed first, which is a merge decision.
- Never rewrite a commit this session did not make unless the user names it.
- Commit half-done work rather than losing it, but say so — in the message and
  in the summary. Never describe unverified work as done, and state plainly
  whether the verification commands actually ran.
- Commits and pushes go through git-writer, which owns the history and holds
  these rules. It inherits this grant; it never decides to push.
- After committing, check whether this session checked off the LAST open block
  of the current milestone. If it did, invoke --plan so the user is ASKED while
  the evidence is in front of them, then name --release if they mark it. Do not
  mark the milestone yourself — that is --plan's, and the mark is what
  authorizes a tag.
EOF
    ;;
  --start)
    cat <<'EOF'
The user included the `--start` flag. That is an explicit, unconditional
instruction to run the `start-work` skill — invoke it now, without asking
what to work on or whether to begin.

The rest of the message is scope or emphasis ("--start, stick to the social
block"), not a question to answer first.

Authorization: COMMIT as the work lands, so a compaction cannot lose a finished
lane. NOT push. Wait for the user to say so, or for the user to type --wrap.
Nothing this skill INVOKES may push on its behalf: an invoked skill inherits this
grant, never its own flag's, so closing out goes through handoff-writer for the
handoff, not through wrap-task for the ritual, and the commits go through
git-writer, which may commit here but not push.

Irreversible, in force before the skill loads:
- Lanes run concurrently in ONE shared working tree, so the unit of parallelism
  is the FILE SET, not the task. Two lanes editing one file do not merge: the
  second write wins and the first lane's work is gone silently. Give every lane
  an explicit list of files it owns, and tell it to stop rather than write
  outside that list.
- At most ONE lane in the whole batch may touch the paths the manifest lists
  under `lanes.exclusive`, and it runs first and alone.
- NO lane writes a record file. The orchestrator records once, at the end.
- Settle the open-decisions record with the user BEFORE selecting work. An open
  decision does not wait — it gets made silently by whoever writes the first
  line of code that depends on it.
- The test suite runs ONCE, at the end. Where the manifest names a consent
  token, no subagent can supply it, so there is one attempt per session. Do not
  spend it early.
EOF
    ;;
  --release)
    cat <<'EOF'
The user included the `--release` flag. That is an explicit, unconditional
instruction to run the `release` skill — invoke it now, without asking whether
to start.

The rest of the message is context about what is being released, not a question
to answer first.

Authorization: COMMIT. The PUSH is NOT covered by this flag.

Irreversible, in force before the skill loads:
- The precondition is a MILESTONE MARKED COMPLETED in the roadmap, written by
  --plan. If it looks complete but is not marked, hand to --plan and come back;
  do not mark it yourself and do not infer the milestone from recent commits.
- Show the commits, the tag name and the branch, then wait for an explicit OK
  IN THAT TURN before pushing either the branch or the tag. Unlike --wrap and
  --stocktake this flag is not standing authorization to publish: a tag another
  checkout has fetched cannot be recalled.
- Local tags and remote tags are different facts. Reconcile both before
  choosing a version.
- This skill WRITES NOTHING ITSELF. The changelog entry goes through
  changelog-writer and the tag through git-writer, which will not tag unless
  told the OK was given in this turn. Obtaining that OK is what this skill
  contributes; a primitive has no channel to ask a user for anything.
- No --force, no --amend, no --no-verify.
EOF
    ;;
  --pullrequest)
    cat <<'EOF'
The user included the `--pullrequest` flag. That is an explicit, unconditional
instruction to run the `pr-flow` skill — invoke it now, without asking whether
to open one.

The rest of the message is context about what is being merged, not a question
to answer first.

Authorization: COMMIT. The PUSH and the MERGE are NOT covered by this flag —
each needs a fresh OK in that turn. Opening the PR is covered.

Irreversible, in force before the skill loads:
- The precondition is that branch.integration is ALREADY PUSHED. A PR opened
  over unpushed commits describes a range the reviewer cannot see. If commits
  are local only, stop and say so — pushing them is not this flag's grant.
- Draft the body from `git log origin/<publish>..origin/<integration>`, NEVER
  from what this session remembers doing. A merge publishes the whole branch, so
  name the commits this session did not make — they are the ones a reviewer most
  needs.
- Check for an already-open PR on the same head before creating one. Two PRs
  for one branch is not recoverable by closing one; the review splits.
- READ the CI result before reporting the PR ready. Where the manifest declares
  no commands.ci, say CI was not checked — that is not the same report as
  saying it passed.
- Never --admin, and never merge past a failing required check.
- Squashing is not a safe default. Where branch.mergeMethod is undeclared, use
  a merge commit and say so: a squash discards the individual commit messages
  that the history is the record of.
- This skill WRITES NOTHING ITSELF. The merge goes through git-writer, which
  will not merge unless told the OK was given in this turn. Obtaining that OK is
  what this skill contributes; a primitive has no channel to ask a user for
  anything.
EOF
    ;;
  --full-stocktake)
    cat <<'EOF'
The user included the `--full-stocktake` flag. That is an explicit,
unconditional instruction to run the `project-stocktake` skill at FULL scope —
invoke it now, without asking for confirmation first.

The rest of the message is scope or emphasis, not a question to answer first.

Authorization: COMMIT and PUSH — but the audit's OWN RECORD ONLY.

Irreversible, in force before the skill loads:
- Full scope means audit history is ignored ENTIRELY. Do not read coverage
  baselines out of the audit record and do not skip anything because a previous
  pass covered it. Everything is in scope, including whatever past passes listed
  as not-covered.
- Full scope does NOT mean attempting code analysis inline. That is a
  project-scoped code-analysis skill's, invoked from Phase 1 where one exists;
  where none does, report "no code analysis ran" rather than implying the code
  was examined.
- The push grant does NOT extend to remediation code written afterwards. That is
  ordinary work: commit it and ask.
- Close out through the `wrap-task` skill rather than pushing by hand, so its
  rails apply — a push publishes a ref, so check what rides along, and never
  force-push or resolve a rejection by force.
EOF
    ;;
  --docs)
    cat <<'EOF'
The user included the `--docs` flag. That is an explicit, unconditional
instruction to invoke the `docs` skill now — do not ask whether to start. Bare,
it means "document what we just worked on": infer the target from the
conversation and say what you picked before writing. With an argument, that is
the target. The rest of the message is scope, not a question to answer first.

Authorization: none. Committing and pushing stay ordinary decisions.

Irreversible, in force before the skill loads:
- Check `.claude/skills/` FIRST. If the project ships its own docs skill, defer
  to it and say so — it encodes conventions this one cannot know. Duplicating a
  project's documentation structure is expensive to unpick.
- Never migrate a project to a different renderer because this skill prefers
  one. Match the setup that exists.
- Never document from inference. Read every file you name; if you cannot find
  why something is the way it is, write "reason unclear" rather than inventing
  a rationale. A plausible-but-wrong doc is worse than no doc, because nobody
  knows which of its claims to distrust.
EOF
    ;;
  --stocktake)
    cat <<'EOF'
The user included the `--stocktake` flag. That is an explicit, unconditional
instruction to run the `project-stocktake` skill incrementally — invoke it now,
without asking for confirmation first.

The rest of the message is scope or emphasis, not a question to answer first.

Authorization: COMMIT and PUSH — but the audit's OWN RECORD ONLY.

Irreversible, in force before the skill loads:
- This skill asks WHERE THE PROJECT IS, not whether its code is correct. Its
  dimensions are the record, the project's consistency against its own stated
  conventions, its public interface, and whether the safety nets a release needs
  actually exist. Deep code analysis — correctness, security, the data model,
  test quality — belongs to a PROJECT-SCOPED code-analysis skill, which this one
  invokes when `.claude/skills/` has one. Do not attempt those dimensions
  inline.
- Where the project has NO such skill, say so in the plan and in the report:
  "no code analysis ran". Never let silence imply the code was examined and
  found clean.
- Incremental means resolving each dimension's slice from the audit record and
  re-reading only what changed since the governing baseline. Apply the
  blast-radius rule strictly, WHETHER OR NOT there is a manifest: a changed
  schema or migration voids the narrowing for every dimension, a changed
  dependency manifest or lockfile voids consistency, and anything touching auth,
  roles or ownership widens rather than narrows. `audit.invalidates` and
  `lanes.*` only ever ADD to that set. The record and safety-net dimensions are
  never incremental. When in doubt, widen.
- The push grant does NOT extend to remediation code written afterwards. That is
  ordinary work: commit it and ask.
- Close out through the `wrap-task` skill rather than pushing by hand, so its
  rails apply — a push publishes a ref, so check what rides along, and never
  force-push or resolve a rejection by force.
EOF
    ;;
  --prune)
    cat <<'EOF'
The user included the `--prune` flag. That is an explicit, unconditional
instruction to invoke the `prune-skills` skill now — find prose in this
project's skill and agent files that does not change what Claude does, and
dispatch the cuts to `--tools`, which owns those files.

Authorization: COMMIT. Not push.

Irreversible, in force before the skill loads:
- This skill WRITES NOTHING. Every cut goes to `--tools`, which owns those files
  and takes its own second look. A proposed cut is a hypothesis about what is
  load-bearing, and this is the one job where being wrong is silent: nothing
  fails when a rule stops being stated, it just stops being followed.
- NEVER cut inside a section another skill hands VERBATIM to a subagent.
  `record-inspector`'s "What to look for" and "What is NOT a finding" are handed
  over by `--stocktake` and `--full-check`, so a cut there silently changes what
  those skills dispatch and nothing detects it — the doctor's citation check
  sees the heading, never the body.
- Removing or renaming a heading another file cites breaks that citation check.
  Grep for the anchor before proposing the cut, and run the doctor after.
- Before cutting a restatement, confirm the rule is genuinely stated elsewhere
  and say where. Two copies is duplication; zero is a behaviour change disguised
  as tidying.
- Prefer DELETING a count to correcting it. "Five" is right until someone adds a
  sixth.
- An agent file's frontmatter `description` and `tools:` list are never cut. The
  description is what the orchestrator matches a task against, so narrowing it
  shows up as the agent never being chosen, never as an error.
- The frontmatter `description` is loaded in every session of every project. If
  you touch one it must get shorter or stay the same, never longer.
EOF
    ;;
  esac
}

blocks=""
claimed=()
for f in "${ordered[@]}"; do
  [ -n "${seen[$f]:-}" ] || continue # dropped by the audit-scope rule above
  flag_skill=$(skill_for "$f")
  # `-` is served by this hook itself, so the two gates below do not apply — and
  # must not: gating the flag list on a skill existing would make it silent in
  # exactly the configuration where a user most needs to ask what is available.
  if [ "$flag_skill" != "-" ]; then
    skill_exists "$flag_skill" || continue
    skill_disabled "$flag_skill" && continue
  fi
  claimed+=("$f")
  blocks="${blocks}${blocks:+

}$(block_for "$f")"
done

[ ${#claimed[@]} -eq 0 ] && exit 0

# More than one flag is a sequence, not a choice — say so, because each block
# below reads as if it were the only instruction in the turn.
preamble=""
if [ ${#claimed[@]} -gt 1 ]; then
  preamble="The user included several flags: ${claimed[*]}. Every one of them is an
unconditional instruction. Carry out ALL of them, in the order listed here —
which is the order they were typed — and treat each as fully in force rather
than letting a later one cancel an earlier one. Where two overlap (an audit and
a wrap both wanting to commit and push, say), do the shared step once, at the
point the last flag that needs it calls for it, and make sure it satisfies
every flag's rules — the strictest constraint wins.

"
fi

CONTEXT="${preamble}${blocks}

The flag tokens themselves are for this hook, not part of the request. Ignore
them when interpreting what the user actually wants."

jq -n --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

exit 0