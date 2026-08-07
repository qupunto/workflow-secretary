#!/usr/bin/env bash
# SessionStart hook: surface config drift and stale sweeps, and NOTHING else.
#
# Why this exists. Every safeguard in this workflow is voluntary — doctor.sh
# catches real drift, but only when someone remembers to run it, and the sweeps
# only get cheaper if someone remembers to run them at all. ownership.md is
# candid about this: the invariants "hold because they are simple enough to
# follow, not because they are policed". This is the cheapest available step
# from voluntary toward mechanical.
#
# THE DESIGN RULE, and it is the whole thing: SILENT WHEN CLEAN. This fires in
# every session of every project, and its output is injected into the model's
# context, so a chatty version would be a permanent token cost AND a warning
# nobody reads. It speaks only when doctor.sh actually fails, or when a sweep
# baseline has fallen far enough behind to be worth a nudge.
#
# ONE DELIBERATE EXCEPTION, below: the project handoff. That is not a warning
# and it is not conditional on anything being wrong — it is the file a fresh
# session is supposed to start from. The harness only auto-loads the working
# directory's CLAUDE.md, so a project that maps record.handoff anywhere ELSE has
# a handoff nothing reads. This injects it, and ONLY in that case: where the
# handoff is CLAUDE.md, or undeclared, or absent, this stays silent, because
# then either the harness already loaded it or there is nothing to load.
# It is therefore free in every project that has not deliberately moved it.
#
# It never fails a session. A hook that can block startup on its own bug is
# worse than the drift it detects, so every path exits 0.

exit_clean() { exit 0; }
trap exit_clean ERR

# EXPORTED, and that matters. This resolves which directory to inspect, then
# runs that directory's doctor.sh — but doctor.sh resolves the same question
# again, on its own, from the environment. Unexported, the two disagreed the
# moment CLAUDE_CONFIG_DIR was set: the hook ran /x/doctor.sh and that doctor
# inspected $HOME/.claude, reporting clean on a directory nobody had looked at.
# Exporting makes the child inherit the answer instead of re-deriving it.
export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CLAUDE_DIR="$CLAUDE_CONFIG_DIR"

# The doctor lives with the INSTALLATION, which is not the config directory once
# this ships as a plugin: the script is then ${CLAUDE_PLUGIN_ROOT}/doctor.sh while
# CLAUDE_DIR is still ~/.claude. Resolved the old way the `-x` guard below simply
# went false, so the doctor never ran from SessionStart and said nothing about
# not running — the silent-net failure this hook exists to prevent, in the hook
# itself. The inbox below deliberately stays on CLAUDE_DIR: it is cross-project
# state that must survive an update, so it must NOT follow the plugin root.
doctor="${CLAUDE_PLUGIN_ROOT:-$CLAUDE_DIR}/doctor.sh"

out=""

# ---------------------------------------------------------------- doctor
# Only FAILURES are worth interrupting a session for. Warnings are routinely
# benign — a dirty working tree is the usual one, and reporting it every session
# would train the reader to skip the whole block, including the failures.
# The guard is local to this section on purpose. It used to be an early exit at
# the top of the file, which silently gated the handoff below on a doctor being
# present — two unrelated things, and the handoff is the one that would have
# gone missing without a symptom.
if [ -x "$doctor" ] && ! doctor_out=$("$doctor" 2>&1); then
  # Strip ANSI so the injected context is plain text.
  # A FAIL is its own line plus however many continuation lines the message ran
  # to, indented eight spaces by doctor.sh's heredoc-style strings. `grep -A2`
  # took a fixed two and truncated the rest — and the tail is where those
  # messages put what to DO about it, so the reader got the diagnosis without
  # the remedy. Take the whole block instead, however long it is.
  fails=$(printf '%s\n' "$doctor_out" | sed 's/\x1b\[[0-9;]*m//g' |
          awk '/^  FAIL  /  { p = 1; print; next }
               p && /^        / { print; next }
               { p = 0 }' || true)
  [ -n "$fails" ] && out="doctor.sh reports FAILURES in the Claude configuration:

$fails

Fix these before relying on any --flag: a skill that cites something
unresolvable dispatches to nothing, silently."
fi

# ------------------------------------------------------------- sweep age
# A sweep checkpoint that is far behind HEAD means the next --ws-check or --ws-docs
# will re-read a lot. Worth one line so the user can choose to run it; not worth
# a line while it is fresh. 40 commits is a nudge threshold, not a rule.
# The manifest may relocate the checkpoint (`sweeps`, workflow/manifest.md), and
# doctor.sh honours that. Hardcoding the default here meant a project that moved
# it got no nudge at all, silently — or a nudge off an abandoned file still
# sitting at the default path. Same resolution as the doctor's, absolute-safe.
sweeps="$PWD/.claude/sweeps.json"
if [ -f "$PWD/.claude/workflow.json" ] && command -v jq >/dev/null 2>&1; then
  # `|| true` is load-bearing here, exactly as at the manifest reads below: jq
  # exits non-zero on an unreadable or malformed file, that status reaches the
  # ERR trap through the assignment, and the trap exits 0 — discarding the
  # doctor FAILURES already collected in $out. Silent, and the one thing this
  # hook exists to say. tests/hook-contract.sh covers this case and caught it.
  declared=$(jq -r '.sweeps // empty' "$PWD/.claude/workflow.json" 2>/dev/null || true)
  case $declared in
    "") ;;
    /*) sweeps=$declared ;;
    *)  sweeps="$PWD/$declared" ;;
  esac
fi
if [ -f "$sweeps" ] && command -v jq >/dev/null 2>&1 &&
   git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then
  stale=""
  while IFS=$'\t' read -r name base; do
    [ -n "$base" ] || continue
    sha=${base%+dirty}
    git -C "$PWD" cat-file -e "$sha^{commit}" 2>/dev/null || continue
    n=$(git -C "$PWD" rev-list --count "$sha"..HEAD 2>/dev/null || echo 0)
    [ "${n:-0}" -ge 40 ] && stale="${stale}  $name: $n commits behind its baseline
"
  done < <(jq -r '.entries // {} | to_entries[] | "\(.key)\t\(.value.baseline // "")"' \
             "$sweeps" 2>/dev/null)
  [ -n "$stale" ] && out="${out}${out:+

}Sweeps that have not run in a while:

$stale
Running the matching flag now re-reads only what changed since those baselines."
fi

# ------------------------------------------------------------ record age
# Nothing else in the suite resurfaces deferred work. A parked item or a
# blocking choice is re-read only when someone runs a flag that reads it, so an
# open decision can sit for months while code is written past it — and whoever
# writes that code makes the call by accident, without knowing there was a call.
#
# Same mechanism as the sweep nudge above: commits since the file last changed.
# Deliberately NOT wall-clock. No date semantics exist anywhere in this
# workflow, and introducing them in a hook would be a design decision nobody
# made; commits are the unit already proven here and need no new concept.
#
# Three guards keep this quiet, and each matters more than the nudge itself:
#   - only records the manifest DECLARES are considered. A project that never
#     adopted this workflow is never nudged about a TODO.md it happens to have,
#     towards a flag it may not want.
#   - a record with no ENTRIES is not stale. open-decisions.md is empty by
#     design most of the time, and nudging about a file that is correctly empty
#     is exactly what would train the reader to skip this whole block.
#   - a file no commit has ever touched has no age to be behind.
manifest="$PWD/.claude/workflow.json"

# A worktree of a lane-split project carries `.claude/lane` (gitignored), and
# `lanes.named.<lane>.records.X` in the manifest then overrides `record.X` for
# the splittable records — workflow/manifest.md states the rule once.
# Read the selector here so every record read below resolves the same way:
# nudging a lane worktree about the unsplit files would miss the lane's own
# pending decisions, and the handoff injection must serve the lane's card.
#
# `|| true` on both, for the reason every guard in this file exists: a failure
# inside an assignment reaches the ERR trap and exits 0, discarding whatever
# $out already held. An empty selector, an undeclared lane or a missing
# manifest all resolve to the unsplit records — doctor.sh is where a bad
# selector fails LOUDLY; this hook only ever degrades.
lane=""
[ -f "$PWD/.claude/lane" ] &&
  lane=$(tr -d '[:space:]' < "$PWD/.claude/lane" 2>/dev/null || true)

# Resolve record key $1: the selected lane's override, else record.$1. Strings
# only — a provider object under record.todo has no file for this hook to age.
record_path() {
  jq -r --arg lane "$lane" --arg k "$1" \
    '(.lanes.named[$lane].records[$k] // .record[$k])
       | if type == "string" then . else empty end' \
    "$manifest" 2>/dev/null || true
}

if [ -f "$manifest" ] && command -v jq >/dev/null 2>&1 &&
   git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then

  # Commits since $1 last changed; fails when git has no commit touching it.
  behind() {
    local last
    last=$(git -C "$PWD" log -1 --format=%H -- "$1" 2>/dev/null)
    [ -n "$last" ] || return 1
    git -C "$PWD" rev-list --count "$last"..HEAD 2>/dev/null
  }

  # An open decision BLOCKS work and is settled silently by the first person to
  # depend on it — a worse failure than a stale sweep, which only costs a
  # re-read. So it nudges sooner than the sweeps' 40. It can only fire while the
  # file has entries at all, which is the rare state, so it can afford to be
  # the more sensitive of the two.
  #
  # record_path carries the load-bearing `|| true`: jq exits non-zero on a
  # manifest that is not valid JSON, that failure propagates out of the
  # assignment, and the ERR trap at the top then exits 0 — discarding whatever
  # $out already held. A malformed workflow.json would silently swallow a
  # doctor FAILURE, which is the one thing this hook exists to print.
  # Entries are `## ` headings — record-contract.md's format, decided after
  # audit pass 9 found this repo's own record using bold paragraphs, which
  # made this nudge structurally unable to fire on it (F2).
  od=$(record_path openDecisions)
  if [ -n "$od" ] && [ -f "$PWD/$od" ]; then
    n=$(grep -c '^## ' "$PWD/$od" 2>/dev/null || true)
    if [ "${n:-0}" -gt 0 ] && b=$(behind "$od") && [ "${b:-0}" -ge 25 ]; then
      out="${out}${out:+

}$n open decision(s) in $od, unchanged for $b commits of work.
--ws-start settles them before it picks a batch; until then the next commit that
depends on one makes the call by accident."
    fi
  fi

  # A backlog going untouched is far less alarming: it costs a list that has
  # drifted from reality, which is recoverable, and a long focused push through
  # one milestone legitimately does not touch it. At 40 this would fire on
  # correct behaviour, so it sits at twice the sweep threshold.
  # A provider-backed backlog has no file — record_path selects the string
  # form explicitly so the skip is a decision rather than a coincidence: an
  # issue backlog has no baseline in this repository's history, so "unchanged
  # for N commits" is not a question that can be asked of it here.
  # workflow/providers/github-issues.md says the same about why a checkpoint
  # cannot narrow an issue sweep.
  td=$(record_path todo)
  if [ -n "$td" ] && [ -f "$PWD/$td" ]; then
    n=$(grep -c '^[[:space:]]*- \[ \]' "$PWD/$td" 2>/dev/null || true)
    if [ "${n:-0}" -gt 0 ] && b=$(behind "$td") && [ "${b:-0}" -ge 80 ]; then
      out="${out}${out:+

}$n open item(s) in $td, unchanged for $b commits of work.
--ws-stocktake re-checks the backlog against what the code now does, and rebuilds
it around the answer."
    fi
  fi

  # A drifted plan is the same class of loss as a drifted backlog, so it reuses
  # the backlog's 80 rather than getting a number of its own — a long focused
  # push through one milestone legitimately does not touch this file, and at the
  # sweeps' 40 this would fire on correct behaviour. The literal is repeated
  # rather than shared: the two coincide by argument, not by definition, and one
  # constant would make changing either look like changing both.
  #
  # `- [ ]` is the entry test for the same reason it is the backlog's: a roadmap
  # whose blocks are all marked completed is FINISHED, not neglected.
  #
  # record.decisions and record.audits are deliberately absent. The decision log
  # is append-only, so its age carries no signal — a project with nothing to
  # decide correctly never touches it. Audits are already covered by the sweep
  # nudge above, which fires on --ws-stocktake's own checkpoint at 40.
  rd=$(jq -r '.record.roadmap // empty' "$manifest" 2>/dev/null || true)  # see above
  if [ -n "$rd" ] && [ -f "$PWD/$rd" ]; then
    n=$(grep -c '^[[:space:]]*- \[ \]' "$PWD/$rd" 2>/dev/null || true)
    if [ "${n:-0}" -gt 0 ] && b=$(behind "$rd") && [ "${b:-0}" -ge 80 ]; then
      out="${out}${out:+

}$n open block(s) in $rd, unchanged for $b commits of work.
--ws-plan re-orders the roadmap against what has actually landed, and asks whether
a milestone is complete enough to mark."
    fi
  fi
fi

# ------------------------------------------------------------ bug reports
# Filed by sessions in other projects, which may not edit this config and append
# instead. Nothing else surfaces them — the file is gitignored, so it never
# appears in git status either.
inbox="$CLAUDE_DIR/bug-reports.md"
if [ -f "$inbox" ]; then
  # `|| true` is load-bearing: `trap exit_clean ERR` exits 0, so an unreadable
  # inbox would abort the hook here — after the doctor FAILURE was collected and
  # before the handoff is injected — printing nothing at all. The exit-0 tests
  # cannot catch it, because the hook exits 0 either way.
  # Marker present: count below it, so the fenced template above never counts.
  # Marker absent: count everything — a fresh machine's inbox is created bare,
  # and requiring the marker hid every entry on it (audit pass 9, F1). Same
  # rule as doctor.sh's counter; change them together.
  n=$(awk '/<!-- Append new entries below this line. -->/{seen=1;next} /^## \[open\]/{if(seen)c++;else p++} END{print (seen?c:p)+0}' "$inbox" || true)
  [ "${n:-0}" -gt 0 ] && out="${out}${out:+

}$n open bug report(s) filed against the Claude configuration.
Read $inbox; triage them from a session in $CLAUDE_DIR."
fi

# --------------------------------------------------------- upstream issues
# Findings also travel upstream, as issues on the suite's public repository,
# and until this block nothing on this machine ever read them back — an
# adopter's filing sat unseen while the local inbox stayed empty. Gated to a
# session standing in the suite's own checkout: that is the one place triage
# can act, and the gate keeps a network call out of every other project's
# session start. The read degrades to saying the repo was NOT checked — never
# to silence, which would render "unreachable" identical to "zero".
if [ "$PWD" = "$CLAUDE_DIR" ] && [ -f "$CLAUDE_DIR/.claude-plugin/plugin.json" ] &&
   [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  up=""
  if command -v gh >/dev/null 2>&1; then
    up=$(gh issue list -R qupunto/workflow-secretary --state open \
           --json number --jq length 2>/dev/null) || up=""
  fi
  case $up in
    0) : ;;
    ''|*[!0-9]*) out="${out}${out:+

}Upstream issues on qupunto/workflow-secretary were NOT checked (gh missing,
offline, or unauthenticated) — not checked is not zero. Run:
gh issue list -R qupunto/workflow-secretary" ;;
    *) out="${out}${out:+

}$up open issue(s) on qupunto/workflow-secretary await triage — findings filed
upstream by adopters. gh issue list -R qupunto/workflow-secretary;
--ws-full-check's triage reads these alongside the local inbox." ;;
  esac
fi

# --------------------------------------------------------- first session
# A plugin has no channel to speak at install time — measured against the
# docs: no post-install message field or event exists, and SessionStart is
# the documented alternative. So the FIRST session after an install gets one
# orientation block, gated by a marker in the config directory — the same
# resolution argument as the inbox above: cross-project state that must
# survive a plugin update, so never under the plugin root. The marker write
# is `|| true` guarded like everything else here; where the config dir is
# unwritable the notice repeats, which is the safe direction to fail.
# Plugin form only: a checkout user has README.md, and this repo's own
# sessions have the handoff below.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ ! -f "$CLAUDE_DIR/.ws-welcomed" ]; then
  out="${out}${out:+

}The workflow-secretary plugin is installed. One-time orientation, for the user:
type --ws-flags to see everything it provides and what resolves here, and in a
project it should keep records for, type --ws-adopt to set that up. Until a
project is adopted the suite stays quiet — nothing here nags. Relay this to the
user; it will not be shown again."
  : > "$CLAUDE_DIR/.ws-welcomed" 2>/dev/null || true
fi

# --------------------------------------------------------------- handoff
# See the exception in the header. Injected only where the project mapped its
# handoff away from the CLAUDE.md the harness already loads — otherwise this
# would double the cost of a file that is in context twice.
# $manifest is resolved once, in the record-age section above.
if [ -f "$manifest" ] && command -v jq >/dev/null 2>&1; then
  hp=$(record_path handoff)  # lane-aware — a lane worktree gets ITS handoff
  case "$hp" in
    ""|CLAUDE.md|./CLAUDE.md) ;;
    *)
      if [ -f "$PWD/$hp" ]; then
        # THE CARD, not the whole file. A handoff grows without bound — this
        # repo's reached 23 KB, injected into every session of every kind of
        # work, most of it state that only matters once you are already editing
        # a record. Everything above the marker is what must be known BEFORE
        # touching anything; the rest is read on demand. Same test the overflow
        # document applies one level down: unconditionality, not importance.
        #
        # No marker means inject the whole file, which is what every project
        # that has not split its handoff still gets. Silence would be the wrong
        # default here: a project whose handoff predates this is not broken.
        if grep -q '^<!-- handoff:card-ends -->$' "$PWD/$hp"; then
          card=$(awk '/^<!-- handoff:card-ends -->$/{exit} {print}' "$PWD/$hp" || true)
          card="$card

The rest of $hp is deliberately NOT loaded. READ IT before writing to any
record, before trusting anything above about the project's current state, and
whenever this card does not answer the question."
        else
          card=$(cat "$PWD/$hp" || true)
        fi
        out="This project's handoff ($hp). It is mapped away from CLAUDE.md, so
nothing else loads it — this is the file a fresh session starts from.

${card}${out:+

}${out}"
      fi
      ;;
  esac
fi

[ -z "$out" ] && exit 0

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$out" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  printf '%s\n' "$out"
fi
exit 0
