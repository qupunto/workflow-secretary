#!/usr/bin/env bash
# Contract tests for the two hooks and the doctor — shorthand-flags.sh,
# session-check.sh and doctor.sh.
#
#   ~/.claude/tests/hook-contract.sh
#
# Runs anywhere, needs only bash and jq, touches nothing outside a temp dir.
#
# Why this exists: a syntax error or a bad case label in that hook breaks EVERY
# flag at once, silently — the hook exits non-zero, Claude Code carries on, and
# each flag quietly degrades to being matched from a skill description. There is
# no symptom to notice. The hook was also edited several times with no way to
# check it beyond firing flags by hand and reading the output.
#
# Every test sets HOME to an empty directory. Without that, skill_exists() finds
# the real ~/.claude/skills and the gating tests pass for the wrong reason on a
# machine where this repo is installed — which is every machine that matters.

set -u

# The hooks moved to `hooks/` on 2026-08-01. CHECK below derives from this path's
# dirname, so both follow from this one line; the root fallback keeps a checkout
# made before the move testable rather than silently skipping every hook test.
#
# The probe fills the DEFAULT only. An explicitly passed HOOK must survive even
# when it does not exist, so a wrong override fails loudly here instead of
# silently retargeting the suite at the repo's own hook and passing.
_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
_default="$_root/hooks/shorthand-flags.sh"
[ -f "$_default" ] || _default="$_root/shorthand-flags.sh"
HOOK="${HOOK:-$_default}"
pass=0 fail=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/project/.claude/skills" "$TMP/bare"

ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail + 1)); }
head_(){ printf '\n\033[1m%s\033[0m\n' "$1"; }

command -v jq  >/dev/null 2>&1 || { echo "needs jq"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "needs git"; exit 1; }
[ -f "$HOOK" ] || { echo "no hook at $HOOK"; exit 1; }

# Run the hook with a given prompt, from a given directory, with an empty HOME.
# Prints the injected context, or nothing.
run() {
  local prompt=$1 dir=${2:-$TMP/project}
  (cd "$dir" && printf '%s' "$(jq -nc --arg p "$prompt" '{prompt:$p}')" \
    | HOME="$TMP/home" bash "$HOOK" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
}

fires() { # prompt, expected-flag, [dir]
  local out; out=$(run "$1" "${3:-$TMP/project}")
  if printf '%s' "$out" | grep -q -- "included the \`$2\` flag\|flags: .*$2"; then
    ok "[$1] fires $2"
  else
    bad "[$1] should fire $2 but did not"
  fi
}

silent() { # prompt, why
  local out; out=$(run "$1")
  if [ -z "$out" ]; then ok "[$1] silent — $2"
  else bad "[$1] should be silent ($2) but injected $(printf '%s' "$out" | wc -c) bytes"
  fi
}

# ---------------------------------------------------------------- structure

head_ "Structure"

if bash -n "$HOOK" 2>/dev/null; then ok "parses"
else bad "SYNTAX ERROR — this breaks every flag, not one"; fi

FLAGS=$(sed -n 's/^FLAGS=(\(.*\))$/\1/p' "$HOOK")
[ -n "$FLAGS" ] && ok "FLAGS array parses ($(printf '%s' "$FLAGS" | wc -w) flags)" \
                || bad "cannot parse the FLAGS array"

# Every flag needs a skill mapping, a block, and a stated authorization. A flag
# in FLAGS with no block is worse than an absent flag: it is claimed and then
# injects nothing.
for f in $FLAGS; do
  skill=$(awk -v flag="$f" '
    /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*echo/ {
      alts=$0; sub(/\).*/,"",alts); gsub(/[[:space:]]/,"",alts)
      n=split(alts,a,"|"); for(i=1;i<=n;i++) if(a[i]==flag){
        t=$0; sub(/.*echo[[:space:]]+/,"",t); sub(/[[:space:]]*;;.*/,"",t); print t; exit }
    }' "$HOOK")
  [ -n "$skill" ] || { bad "$f has no skill_for() mapping"; continue; }
  # A block_for() label may be an alternation — `--flags | --help)` covers both —
  # so test membership of the alternatives rather than pattern-matching the
  # start of the line. Matching only `^  FLAG)` reported --help as having no
  # block when it was the second alternative of one, which is the same defect
  # the skill_for() reader above already had to fix.
  awk -v flag="$f" '
    /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*$/ {
      alts=$0; sub(/\).*/,"",alts); gsub(/[[:space:]]/,"",alts)
      n=split(alts,a,"|"); for(i=1;i<=n;i++) if(a[i]==flag){ found=1; exit }
    } END { exit !found }' "$HOOK" ||
    { bad "$f has no block_for() case"; continue; }
  # `-` means the hook serves the flag itself; there is no skill to plant.
  if [ "$skill" != "-" ]; then
    mkdir -p "$TMP/project/.claude/skills/$skill" && : > "$TMP/project/.claude/skills/$skill/SKILL.md"
  fi
  ok "$f -> $skill, block present"
done

head_ "Every block states an authorization"

for f in $FLAGS; do
  out=$(run "$f")
  case $out in
    *"Authorization:"*) ok "$f states its grant" ;;
    "") bad "$f injected nothing even with its skill present" ;;
    *) bad "$f injects a block with no Authorization line" ;;
  esac
done

# ------------------------------------------------------------------ position

head_ "Position is the whole signal"

fires  "--wrap" "--wrap"
fires  "--wrap the purge work is done" "--wrap"
fires  "that is everything for today --wrap" "--wrap"
silent "remind me what --wrap does" "mid-sentence: discussed, not invoked"
silent "should --wrap also update the changelog?" "a question about the flag"
silent "git branch --track origin/dev" "pasted command"
silent "see the --wrapper module" "glued to a word"
silent "no flags here at all" "nothing to fire"

head_ "Runs fire every flag they name, in typed order"

out=$(run "--stocktake--release--wrap")
case $out in
  *"--stocktake --release --wrap"*) ok "glued run keeps typed order" ;;
  *) bad "glued run lost order or flags: $(printf '%s' "$out" | head -1)" ;;
esac

out=$(run "--wrap --stocktake")
case $out in
  *"--wrap --stocktake"*) ok "spaced run keeps typed order" ;;
  *) bad "spaced run did not preserve order" ;;
esac

head_ "Audit scope is mutually exclusive, wider wins"

out=$(run "--full-stocktake --stocktake")
if printf '%s' "$out" | grep -q -- "--full-stocktake" && \
   ! printf '%s' "$out" | grep -qE 'flags: .*--stocktake( |$)'; then
  ok "--full-stocktake suppresses --stocktake"
else
  bad "--stocktake was not suppressed by --full-stocktake"
fi

head_ "A record sweep does not run twice"

# project-stocktake runs --check's method over --check's files as its record
# dimension: "invoke one or the other, never both". Firing both sweeps the
# record twice, and the second reports the first one's writes as fresh drift.
for wide in --stocktake --full-stocktake; do
  out=$(run "$wide --check")
  if printf '%s' "$out" | grep -q -- "included the \`$wide\` flag" && \
     ! printf '%s' "$out" | grep -q -- "included the \`--check\` flag"; then
    ok "$wide absorbs --check"
  else
    bad "--check was not absorbed by $wide"
  fi
done

# The half with no symptom. --full-check is a different SKILL rather than a
# wider scope — it also sweeps the docs site and the tooling files, which no
# stocktake touches — so absorbing it would silently narrow the request.
out=$(run "--stocktake --full-check")
if printf '%s' "$out" | grep -q -- "flags: --stocktake --full-check"; then
  ok "--stocktake leaves --full-check standing"
else
  bad "--full-check was wrongly absorbed by --stocktake"
fi

# Suppressed since the pair was introduced, never covered until now.
out=$(run "--full-check --check")
if printf '%s' "$out" | grep -q -- "included the \`--full-check\` flag" && \
   ! printf '%s' "$out" | grep -q -- "included the \`--check\` flag"; then
  ok "--full-check absorbs --check"
else
  bad "--check was not absorbed by --full-check"
fi

# -------------------------------------------------------------------- gating

head_ "A flag whose skill resolves nowhere is inert, not broken"

for f in $FLAGS; do
  # The flags the hook serves ITSELF are exempt, and must be: gating the flag
  # list on a skill existing would silence it in exactly the configuration
  # where a user most needs to ask what is available. Test the opposite for
  # those — they must still fire from a bare directory.
  fskill=$(awk -v flag="$f" '
    /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*echo/ {
      alts=$0; sub(/\).*/,"",alts); gsub(/[[:space:]]/,"",alts)
      n=split(alts,a,"|"); for(i=1;i<=n;i++) if(a[i]==flag){
        t=$0; sub(/.*echo[[:space:]]+/,"",t); sub(/[[:space:]]*;;.*/,"",t); print t; exit }
    }' "$HOOK")
  out=$(run "$f" "$TMP/bare")
  if [ "$fskill" = "-" ]; then
    [ -n "$out" ] && ok "$f still fires where no skill exists — it needs none" \
                  || bad "$f went inert in a bare project, which is where it is most needed"
    continue
  fi
  [ -z "$out" ] && ok "$f inert where its skill is absent" \
                || bad "$f fired with no skill to carry it out"
done

head_ "The flag list is computed, not written down"

# The whole value of --flags is that it cannot go stale. It is built from the
# FLAGS array and skill_for() at run time, so a flag added without touching it
# still appears. A hand-written list would pass every other test in this file
# while being wrong, which is the failure this asserts against: every flag in
# FLAGS must have a row.
out=$(run "--flags" "$TMP/bare")
missing=""
for f in $FLAGS; do
  printf '%s' "$out" | grep -qF "| \`$f\`" || missing="$missing $f"
done
[ -z "$missing" ] && ok "--flags lists every flag in FLAGS ($(printf '%s' "$FLAGS" | wc -w) rows)" \
                  || bad "--flags omitted:$missing — the list is not computed from FLAGS"

# And it must be honest about what does not resolve, which is most of its value
# in a project that has not adopted the suite.
case $out in
  *'**no**'*) ok "--flags marks a flag whose skill is absent as inert" ;;
  *) bad "--flags reported nothing as inert from a bare project — it cannot be reading the disk" ;;
esac

head_ "A settings-disabled skill does not get its flag block either"

# Absent and disabled look identical from the hook's side only if it looks. An
# override leaves SKILL.md exactly where it was, so the gate above passes and
# the block gets injected for a skill the harness then refuses — an instruction
# and a refusal in the same turn.
#
# Two of the four levels block model invocation and two do not, so both
# directions are asserted here. Treating `name-only` as disabled would lose a
# flag that works, which is the same silent loss the gate exists to prevent.

overrides() { # scope, level — write one entry, or remove the file when level is empty
  local dir
  case $1 in
    project) dir="$TMP/project/.claude" ;;
    user)    dir="$TMP/home/.claude" ;;
  esac
  mkdir -p "$dir"
  if [ -z "$2" ]; then
    rm -f "$dir/settings.json"
  else
    jq -nc --arg l "$2" '{skillOverrides:{"wrap-task":$l}}' > "$dir/settings.json"
  fi
}

for level in off user-invocable-only; do
  overrides user "$level"
  out=$(run "--wrap")
  [ -z "$out" ] && ok "--wrap inert while wrap-task is \"$level\"" \
                || bad "--wrap fired for a skill the harness will refuse (\"$level\")"
done

for level in on name-only; do
  overrides user "$level"
  out=$(run "--wrap")
  printf '%s' "$out" | grep -q -- 'included the `--wrap` flag' \
    && ok "--wrap still fires while wrap-task is \"$level\"" \
    || bad "--wrap lost to an override that does not block model invocation (\"$level\")"
done

# Project outranks user for this key. That is why the lookup stops at the first
# file naming the skill rather than merging the two.
overrides user off
overrides project on
out=$(run "--wrap")
printf '%s' "$out" | grep -q -- 'included the `--wrap` flag' \
  && ok "project settings outrank user settings" \
  || bad "a user-level off beat a project-level on"

overrides user ""
overrides project ""

# ------------------------------------------------------------- session-check

head_ "SessionStart check is silent when there is nothing to say"

# The whole design rests on this one property. It fires in every session of
# every project and its output goes into the model's context, so a version that
# speaks on a clean tree is a permanent token cost AND a warning nobody reads.
# It is also the property most easily lost by a later edit, and losing it has no
# symptom beyond a slightly noisier session.
# Overridable for the same reason $HOOK is: the swallowed-output assertions at
# the end of this section are only meaningful if they can be pointed at a
# deliberately broken copy and seen to fail. A guard nobody has watched fail is
# a guard nobody has tested.
CHECK="${CHECK:-$(dirname "$HOOK")/session-check.sh}"
if [ ! -x "$CHECK" ]; then
  bad "session-check.sh is missing or not executable — SessionStart fires nothing"
else
  ok "session-check.sh is executable"
  bash -n "$CHECK" 2>/dev/null && ok "session-check.sh parses" \
    || bad "session-check.sh has a syntax error"

  # A config directory with no doctor at all: nothing to report, so nothing said.
  out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "silent when there is no doctor to run" \
                || bad "spoke with nothing to report: $out"

  # A failing doctor MUST be surfaced — that is the one case it exists for.
  mkdir -p "$TMP/failconf"
  printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$TMP/failconf/doctor.sh"
  chmod +x "$TMP/failconf/doctor.sh"
  out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$TMP/failconf" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *FAIL*) ok "surfaces a failing doctor" ;;
                 *) bad "a FAILING doctor produced no output — the hook's only job" ;;
  esac

  # It must never break a session, whatever it finds.
  (cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$TMP/failconf" bash "$CHECK" </dev/null >/dev/null 2>&1)
  [ $? -eq 0 ] && ok "exits 0 even when the doctor fails" \
               || bad "exited non-zero — a hook that can block startup on its own finding"

  # The handoff exception. A project that maps record.handoff away from
  # CLAUDE.md has a handoff the harness never loads; this hook is what loads it.
  # Both halves matter: injecting it where it was moved, and NOT injecting it
  # where CLAUDE.md already carries it — that second one has no symptom beyond
  # paying for the same file twice, so nothing else would ever catch it.
  hoproj="$TMP/handoff-proj"
  mkdir -p "$hoproj/.claude"
  printf '# Handoff\n\nSENTINEL-HANDOFF-BODY\n' > "$hoproj/.claude/HANDOFF.md"

  printf '{"record":{"handoff":".claude/HANDOFF.md"}}\n' > "$hoproj/.claude/workflow.json"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-HANDOFF-BODY*) ok "injects a handoff mapped away from CLAUDE.md" ;;
                 *) bad "handoff mapped off CLAUDE.md was not injected — nothing else loads it" ;;
  esac

  printf '{"record":{"handoff":"CLAUDE.md"}}\n' > "$hoproj/.claude/workflow.json"
  printf '# Handoff\n' > "$hoproj/CLAUDE.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "silent where CLAUDE.md is the handoff — the harness loads it" \
                || bad "injected a handoff the harness already loads: $out"

  printf '{"record":{"handoff":".claude/GONE.md"}}\n' > "$hoproj/.claude/workflow.json"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "silent where the declared handoff does not exist" \
                || bad "spoke about a handoff file that is not there: $out"

  # The card cut. Injecting the whole handoff is what made this repo's own cost
  # 23 KB a session. The marker is the budget, and BOTH halves are load-bearing:
  # a cut that silently dropped the card would be caught by any test above, but
  # a cut that silently stopped cutting would not be caught by any of them — the
  # output stays correct and merely costs five times as much, forever.
  printf '{"record":{"handoff":".claude/HANDOFF.md"}}\n' > "$hoproj/.claude/workflow.json"
  printf 'SENTINEL-CARD\n<!-- handoff:card-ends -->\nSENTINEL-BELOW-THE-LINE\n' \
    > "$hoproj/.claude/HANDOFF.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-CARD*) ok "injects the card above the marker" ;;
                 *) bad "the card above handoff:card-ends was not injected" ;;
  esac
  case "$out" in *SENTINEL-BELOW-THE-LINE*)
        bad "injected the body below handoff:card-ends — the cut is not cutting" ;;
                 *) ok "stops at the marker, leaving the body on disk" ;;
  esac
  case "$out" in *"deliberately NOT loaded"*)
        ok "says where the rest went, so it is read rather than assumed absent" ;;
                 *) bad "cut the handoff without telling the session the rest exists" ;;
  esac

  # A project that has not split its handoff is not broken, and must not be
  # silently truncated to nothing by a marker it never wrote.
  printf 'SENTINEL-UNMARKED-WHOLE\nSTILL-HERE\n' > "$hoproj/.claude/HANDOFF.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-UNMARKED-WHOLE*STILL-HERE*)
        ok "a handoff with no marker is injected whole" ;;
                 *) bad "an unmarked handoff lost content — back-compat broken" ;;
  esac

  # ------------------------------------------------------------- record age
  head_ "Record age nudges, and the far larger set of cases where it must not"

  # Nothing else in the suite resurfaces deferred work, so this is the only
  # thing that will ever say an open decision has been blocking for a while.
  # It counts COMMITS, not dates — asserted below by building distance out of
  # commits alone, since a wall-clock version would be a design decision nobody
  # made and would pass none of these.
  #
  # The silence cases outnumber the firing ones deliberately. This fires on
  # every session of every project; the failure that matters is not "it missed
  # one", it is "it spoke about a file that was fine", because that is what
  # trains the reader to skip the doctor failures printed alongside it.

  recfix() { # dir, manifest-json, open-decisions-body, todo-body, [roadmap-body]
    local d=$1
    rm -rf "$d"; mkdir -p "$d/.claude" "$d/docs"
    git init -q "$d" 2>/dev/null
    git -C "$d" config user.email t@test; git -C "$d" config user.name t
    # These fixtures make ~80 commits each in a tight loop. Auto-gc can fire
    # part-way through that and has no business running inside a fixture, and a
    # signing hook belongs to whoever's machine this is, not to the test.
    git -C "$d" config gc.auto 0
    git -C "$d" config commit.gpgsign false
    printf '%s\n' "$2" > "$d/.claude/workflow.json"
    printf '%s\n' "$3" > "$d/docs/open-decisions.md"
    printf '%s\n' "$4" > "$d/TODO.md"
    [ -n "${5:-}" ] && printf '%s\n' "$5" > "$d/ROADMAP.md"
    git -C "$d" add -A >/dev/null 2>&1
    git -C "$d" commit -q -m "records" >/dev/null 2>&1 \
      || bad "recfix: the records commit failed in $d — every nudge assertion below is meaningless"
  }
  # The nudges count COMMITS SINCE THE RECORD LAST CHANGED, so a single lost
  # commit here shifts every threshold by one and the fixture then tests the
  # wrong distance — silently, and in the direction that reads as "the nudge did
  # not fire". That is exactly what the 2026-08-02 CI flake looked like: silent
  # at the 79 check, silent again at the 80 check. Discarding git's output made
  # a lost commit invisible, so the failure surfaced as a mystery two steps later.
  advance() { # dir, n — distance measured purely in commits
    local i err
    for i in $(seq 1 "$2"); do
      err=$(git -C "$1" commit -q --allow-empty -m c 2>&1) || {
        bad "advance: commit $i of $2 failed in $1 — $(printf '%s' "$err" | head -1)"
        return 1
      }
    done
  }
  # Assert the distance the next assertion depends on. A fixture that has drifted
  # now fails AS a fixture fault, naming the number it actually had, instead of
  # being reported as the hook staying quiet.
  at_distance() { # dir, file, expected
    local last n
    last=$(git -C "$1" log -1 --format=%H -- "$2" 2>/dev/null)
    [ -n "$last" ] || { bad "at_distance: nothing in $1 ever touched $2"; return 1; }
    n=$(git -C "$1" rev-list --count "$last"..HEAD 2>/dev/null)
    [ "$n" = "$3" ] || { bad "at_distance: $2 is $n commits behind, expected $3"; return 1; }
  }
  recrun() { # dir
    local err_f out
    err_f=$(mktemp)
    out=$(cd "$1" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>"$err_f" \
      | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
    # Discarding stderr hid the other candidate explanation for the same flake:
    # the hook dying mid-pipeline looks identical to the hook deciding to stay
    # quiet. Empty output plus something on stderr is now reported, not swallowed.
    if [ -z "$out" ] && [ -s "$err_f" ]; then
      bad "recrun: the hook wrote to stderr and produced nothing — $(head -1 "$err_f")"
    fi
    rm -f "$err_f"
    printf '%s' "$out"
  }

  BOTH='{"record":{"todo":"TODO.md","openDecisions":"docs/open-decisions.md"}}'
  ENTRY='# Open decisions

## Whether to do X

**Blocks:** everything downstream.'
  ITEM='# Backlog

- [ ] **Thing.**
      Do the thing.'

  rec="$TMP/rec"
  recfix "$rec" "$BOTH" "$ENTRY" "$ITEM"

  out=$(recrun "$rec")
  [ -z "$out" ] && ok "silent while both records are current" \
                || bad "nudged about records that just changed: $out"

  advance "$rec" 24
  out=$(recrun "$rec")
  [ -z "$out" ] && ok "silent one commit short of the open-decision threshold" \
                || bad "open-decision nudge fired early: $out"

  # An open decision blocks work and gets settled by accident by whoever writes
  # the first line depending on it, so it nudges before the backlog does.
  advance "$rec" 1
  out=$(recrun "$rec")
  case "$out" in
    *"open decision"*"docs/open-decisions.md"*) ok "nudges on a stale open decision" ;;
    *) bad "an open decision blocked for 25 commits and nothing was said: $out" ;;
  esac
  printf '%s' "$out" | grep -q -- '--start' \
    && ok "the open-decision nudge names --start" \
    || bad "nudge with no flag to act on — the reader is told a fact and no move"
  printf '%s' "$out" | grep -q 'TODO.md' \
    && bad "backlog nudged at 25 commits; the two thresholds are not separate" \
    || ok "backlog stays quiet while only the open decision is stale"

  advance "$rec" 54          # 79 behind
  out=$(recrun "$rec")
  printf '%s' "$out" | grep -q 'TODO.md' \
    && bad "backlog nudge fired one commit short of its threshold" \
    || ok "silent on the backlog one commit short of its threshold"

  advance "$rec" 1           # 80 behind
  out=$(recrun "$rec")
  case "$out" in
    *"TODO.md"*) ok "nudges on a backlog untouched for 80 commits" ;;
    *) bad "backlog untouched through 80 commits of work and nothing was said" ;;
  esac
  printf '%s' "$out" | grep -q -- '--stocktake' \
    && ok "the backlog nudge names --stocktake" \
    || bad "backlog nudge names no flag"

  (cd "$rec" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null >/dev/null 2>&1)
  [ $? -eq 0 ] && ok "exits 0 while both record nudges fire" \
               || bad "exited non-zero with something to say"

  # The roadmap is the third nudge and the last one. record.decisions and
  # record.audits are deliberately uncovered — the decision log is append-only
  # so its age carries no signal, and the sweep nudge above already fires on a
  # stale --stocktake baseline at 40. Asserting the roadmap ALONE here is the
  # point of the fixture: the open-decisions file is empty by design and the
  # backlog is finished, so anything else in the output is a nudge that should
  # not have fired.
  QUIET_OD='# Open decisions

**Nothing is open.** That is a state, not a gap.'
  DONE_TD='# Backlog

- [x] **Shipped.**'
  PLAN='# Roadmap

## M1 — the first milestone

- [ ] **A block nobody has built.**'
  ALL_R='{"record":{"todo":"TODO.md","openDecisions":"docs/open-decisions.md","roadmap":"ROADMAP.md"}}'

  rmd="$TMP/rec-roadmap"
  recfix "$rmd" "$ALL_R" "$QUIET_OD" "$DONE_TD" "$PLAN"

  advance "$rmd" 79
  at_distance "$rmd" ROADMAP.md 79
  out=$(recrun "$rmd")
  [ -z "$out" ] && ok "silent one commit short of the roadmap threshold" \
                || bad "roadmap nudge fired early: $out"

  # It reuses the backlog's 80 rather than the sweeps' 40, because a long
  # focused push through one milestone legitimately does not touch this file —
  # that is the milestone working, and a nudge on correct behaviour is what
  # discredits the whole block.
  advance "$rmd" 1
  at_distance "$rmd" ROADMAP.md 80
  out=$(recrun "$rmd")
  case "$out" in
    *"ROADMAP.md"*) ok "nudges on a roadmap untouched for 80 commits" ;;
    *) bad "roadmap untouched through 80 commits of work and nothing was said: $out" ;;
  esac
  printf '%s' "$out" | grep -q -- '--plan' \
    && ok "the roadmap nudge names --plan" \
    || bad "roadmap nudge names no flag — the reader gets a fact and no move"
  printf '%s' "$out" | grep -q 'TODO.md\|open-decisions' \
    && bad "a record that is correctly empty was nudged alongside the roadmap: $out" \
    || ok "the roadmap nudge fires alone, with both other records quiet"

  # A roadmap whose blocks are all marked completed is FINISHED, not neglected.
  # This is the roadmap's version of the empty-by-design case below, and it is
  # the one that matters most: a completed plan is the normal end state, so a
  # nudge here would fire on every project that ever finished a milestone.
  donep="$TMP/rec-roadmap-done"
  recfix "$donep" "$ALL_R" "$QUIET_OD" "$DONE_TD" '# Roadmap

## M1 — shipped

- [x] **A block that landed.**'
  advance "$donep" 120
  out=$(recrun "$donep")
  [ -z "$out" ] && ok "silent on a roadmap whose blocks are all completed, at 120 commits" \
                || bad "nudged about a finished roadmap: $out"

  # Declared and absent: ordinary in a project that adopted the workflow before
  # it had a roadmap, and it has no age to be behind.
  norm="$TMP/rec-roadmap-absent"
  recfix "$norm" "$ALL_R" "$QUIET_OD" "$DONE_TD"
  advance "$norm" 120
  out=$(recrun "$norm")
  [ -z "$out" ] && ok "silent where the declared roadmap does not exist" \
                || bad "spoke about a roadmap file that is not there: $out"

  # Undeclared is not absent. A project with a ROADMAP.md sitting in the tree
  # and no roadmap key never asked to be nudged towards --plan.
  noplan="$TMP/rec-roadmap-undeclared"
  recfix "$noplan" "$BOTH" "$QUIET_OD" "$DONE_TD" "$PLAN"
  advance "$noplan" 120
  out=$(recrun "$noplan")
  [ -z "$out" ] && ok "silent where a roadmap exists but the manifest omits the key" \
                || bad "nudged about a record the manifest never declared: $out"

  # THE case this must get right. docs/open-decisions.md is empty by design most
  # of the time — "nothing is open" is a state, not a gap — and a backlog with
  # no unchecked item is finished, not neglected. Nudging about either is the
  # noise that would discredit every other line this hook prints.
  emp="$TMP/rec-empty"
  recfix "$emp" "$BOTH" \
    '# Open decisions

**Nothing is open.** That is a state, not a gap.' \
    '# Backlog

## Section

Nothing pending.'
  advance "$emp" 120
  out=$(recrun "$emp")
  [ -z "$out" ] && ok "silent on records that are correctly empty, at 120 commits" \
                || bad "nudged about a file that is empty by design: $out"

  # Declared and absent, and declared and never committed. Both are ordinary in
  # a project mid-adoption, and neither has an age to be behind.
  gone="$TMP/rec-gone"
  recfix "$gone" '{"record":{"todo":"NOPE.md","openDecisions":"docs/nope.md"}}' "$ENTRY" "$ITEM"
  advance "$gone" 120
  out=$(recrun "$gone")
  [ -z "$out" ] && ok "silent where the declared records do not exist" \
                || bad "spoke about record files that are not there: $out"

  printf '%s\n' "$ITEM"  > "$gone/NOPE.md"
  printf '%s\n' "$ENTRY" > "$gone/docs/nope.md"
  out=$(recrun "$gone")
  [ -z "$out" ] && ok "silent where a declared record was never committed" \
                || bad "claimed an age for a file git has never seen: $out"

  # Undeclared is not the same as absent. A project that adopted the workflow
  # without declaring these keys, or never adopted it at all, gets no nudge
  # towards a flag it has not asked for — even with an old TODO.md sitting there.
  und="$TMP/rec-undeclared"
  recfix "$und" '{"record":{"handoff":"CLAUDE.md"}}' "$ENTRY" "$ITEM"
  advance "$und" 120
  out=$(recrun "$und")
  [ -z "$out" ] && ok "silent where the manifest declares neither record" \
                || bad "nudged about a record the manifest never declared: $out"

  rm -f "$und/.claude/workflow.json"
  out=$(recrun "$und")
  [ -z "$out" ] && ok "silent in a project with no manifest at all" \
                || bad "nudged a project that never adopted this workflow: $out"

  # Malformed input must not cost a session, and must not be read as staleness.
  printf 'not json {{{ at all\n' > "$und/.claude/workflow.json"
  out=$(recrun "$und")
  [ -z "$out" ] && ok "silent on a malformed manifest" \
                || bad "read something out of a manifest that is not JSON: $out"

  # Run the hook DIRECTLY, not through recrun's pipeline — a pipe reports jq's
  # status, and jq exits 0 on empty input, so the piped form would report
  # success no matter what the hook did.
  (cd "$und" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null >/dev/null 2>&1)
  [ $? -eq 0 ] && ok "exits 0 on a malformed manifest" \
               || bad "a broken manifest took the session down with it"

  # Exiting 0 is not the same as behaving. jq exits non-zero on a manifest that
  # is not JSON; that failure propagates out of the assignment and the hook's
  # own ERR trap exits 0 — discarding everything already collected. A broken
  # workflow.json would then silently swallow a doctor FAILURE, and the exit
  # code above would still say the hook was fine. Nothing else catches this.
  out=$(cd "$und" && CLAUDE_CONFIG_DIR="$TMP/failconf" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *FAIL*) ok "a malformed manifest does not swallow a doctor FAILURE" ;;
                 *) bad "unreadable workflow.json silently discarded the doctor's failures" ;;
  esac

  # --------------------------------------------------- the swallowed-output class
  head_ "An unreadable file must not swallow what was already collected"

  # The class every exit-code assertion in this file is structurally blind to.
  # `trap exit_clean ERR` exits 0, so a bare `x=$(cmd)` that fails aborts the
  # hook BEFORE it prints — after $out already held a doctor FAILURE. The hook
  # exits 0 whether or not that happened, which is what the trap is for, so only
  # stdout CONTENT separates the broken version from the fixed one.
  #
  # The manifest jq site is covered directly above. The two asserted here are
  # the ones fixed at d7f995c by behavioural repro rather than by a test — the
  # bug-report awk and the handoff cat — which is exactly why they are worth
  # pinning: a repro is not repeated, and the next edit to this file reopens
  # them silently. Prove any NEW guard the same way: chmod 000 the target and
  # check the hook still prints.
  #
  # Skipped rather than passed when the chmod does not bite. Root reads a 000
  # file regardless, and a test that cannot fail is worse than no test — it
  # reports coverage that does not exist.
  probe="$TMP/unreadable-probe"
  : > "$probe"; chmod 000 "$probe"
  if cat "$probe" >/dev/null 2>&1; then
    printf '  \033[33mskip\033[0m  chmod 000 not enforced here (root?) — swallow tests cannot fail\n'
  else
    # The inbox lives in the CONFIG dir, beside the doctor whose failure it
    # would discard.
    sw="$TMP/swallow-inbox"
    rm -rf "$sw"; mkdir -p "$sw"
    printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$sw/doctor.sh"
    chmod +x "$sw/doctor.sh"
    : > "$sw/bug-reports.md"; chmod 000 "$sw/bug-reports.md"
    out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$sw" bash "$CHECK" </dev/null 2>/dev/null \
          | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
    case "$out" in *FAIL*) ok "an unreadable bug-report inbox does not swallow a doctor FAILURE" ;;
                   *) bad "unreadable bug-reports.md discarded the doctor's failures" ;;
    esac
    chmod 644 "$sw/bug-reports.md"

    # The handoff cat is the LAST thing to touch $out, so a failure there loses
    # everything collected before it — the doctor, the sweeps and all three
    # record nudges at once. The worst site of the three, and the one whose
    # symptom is most completely absent.
    swh="$TMP/swallow-handoff"
    rm -rf "$swh"; mkdir -p "$swh/.claude"
    printf '{"record":{"handoff":".claude/HANDOFF.md"}}\n' > "$swh/.claude/workflow.json"
    printf '# Handoff\n' > "$swh/.claude/HANDOFF.md"
    chmod 000 "$swh/.claude/HANDOFF.md"
    out=$(cd "$swh" && CLAUDE_CONFIG_DIR="$TMP/failconf" bash "$CHECK" </dev/null 2>/dev/null \
          | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
    case "$out" in *FAIL*) ok "an unreadable handoff does not swallow a doctor FAILURE" ;;
                   *) bad "unreadable handoff discarded everything collected before it" ;;
    esac
    chmod 644 "$swh/.claude/HANDOFF.md"
  fi
  chmod 644 "$probe"
fi

# ------------------------------------------------------------------- doctor.sh

head_ "doctor.sh reports a fault planted where its parsers look"

# doctor.sh is ~770 lines of awk and grep run against files it does not own. Its
# checks are stated as prose ABOUT shorthand-flags.sh, ownership.md and the
# markdown tree, so every one of them stops matching the day one of those files
# is reworded — a renamed `FLAGS=` line, a reworded `Authorization:`, a heading
# that moved. There is no symptom: a parser that matches nothing reports nothing
# to report, and the run ends "all checks passed".
#
# So the shape here is a synthetic config directory the doctor calls entirely
# clean, and then one copy of it per fault, each broken in exactly one way. The
# CLEAN run is the load-bearing half: it is what fails when a parser stops
# matching, because a doctor that can no longer see anything still reports every
# broken fixture as broken by saying nothing about it.
#
# Overridable like $HOOK and $CHECK above, for the same reason: point DOCTOR at a
# deliberately mutated copy and every guard here must go red.

#
# Derived from the REPO ROOT, not from $HOOK's directory. Those were the same
# place until the hooks moved into hooks/ on 2026-08-01, and deriving from the
# hook then pointed this at hooks/doctor.sh — a path that has never existed.
# doctor.sh stays at the root deliberately: it is run by hand as often as by the
# SessionStart hook.
DOCTOR="${DOCTOR:-$_root/doctor.sh}"

if [ ! -f "$DOCTOR" ]; then
  bad "doctor.sh not found at $DOCTOR — nothing below ran"
else
  ok "doctor.sh is present"
  bash -n "$DOCTOR" 2>/dev/null && ok "doctor.sh parses" \
    || bad "doctor.sh has a syntax error — every check in it is dead"

  # A config directory the doctor must report entirely clean, carrying only the
  # SHAPES its parsers look for. The doctor never RUNS the hook, it reads it, so
  # this stand-in does not have to work — but it must be laid out exactly like
  # the real one: `FLAGS=` at column 0, the case arms two spaces in, the
  # heredoc's `Authorization:` and its terminator at column 0. Those positions
  # are the contract every awk program here depends on.
  docfix() { # dir
    local d=$1
    rm -rf "$d"
    mkdir -p "$d/skills/alpha-skill" "$d/skills/beta-skill" "$d/workflow"
    printf '.credentials.json\n' > "$d/.gitignore"
    printf '%s\n' '{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"~/.claude/shorthand-flags.sh"}]}]}}' \
      > "$d/settings.json"

    cat > "$d/shorthand-flags.sh" <<'HOOKFIX'
#!/usr/bin/env bash
FLAGS=(--alpha --beta)

skill_for() {
  case $1 in
    --alpha) echo alpha-skill ;;
    --beta)  echo beta-skill ;;
  esac
}

block_for() {
  case $1 in
  --alpha)
    cat <<'EOF'
The user included the `--alpha` flag.

Authorization: COMMIT. Not push.
EOF
    ;;
  --beta)
    cat <<'EOF'
The user included the `--beta` flag.

Authorization: none.
EOF
    ;;
  esac
}
HOOKFIX
    chmod +x "$d/shorthand-flags.sh"

    cat > "$d/workflow/ownership.md" <<'OWNFIX'
# Ownership

## The matrix

| Verb | Flag | Skill | Tier | Sole writer of | Authorization the flag grants |
|---|---|---|---|---|---|
| alpha | `--alpha` | `alpha-skill` | primitive | nothing | commit, **not** push |
| beta | `--beta` | `beta-skill` | primitive | nothing | — |
OWNFIX

    printf '# alpha-skill\n\nDoes the alpha thing.\n' > "$d/skills/alpha-skill/SKILL.md"
    printf '# beta-skill\n\nDoes the beta thing.\n'   > "$d/skills/beta-skill/SKILL.md"
    printf '# Fixture\n\nSee [the matrix](workflow/ownership.md#the-matrix).\n' > "$d/README.md"

    # A checkout, because three checks below only run in one: the credentials
    # pair, the dirty-tree warn, and the anchor walk, which reads `git ls-files`
    # rather than the whole tree.
    git init -q "$d" 2>/dev/null
    git -C "$d" config user.email t@test; git -C "$d" config user.name t
    docommit "$d"
  }
  docommit() { # dir — leave the tree clean, and every .md visible to ls-files
    git -C "$1" add -A >/dev/null 2>&1
    git -C "$1" commit -q -m fixture >/dev/null 2>&1
  }
  # sed -i is not portable and mv is. Every fault below is one substitution.
  edit_() { # file, sed-expression
    sed "$2" "$1" > "$1.new" && mv "$1.new" "$1"
  }
  doc() { # config-dir, [doctor args] — inspect a config from a project-less PWD,
          # so the $PWD-dependent checks skip rather than report another project's
          # state as this fixture's.
    (cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$1" CLAUDE_DIR="$1" bash "$DOCTOR" "${@:2}" 2>&1)
  }
  says() { # dir, needle, label — the doctor must name this fault
    printf '%s' "$(doc "$1")" | grep -q -- "$2" \
      && ok "$3" || bad "$3 — the doctor said nothing about it"
  }

  clean="$TMP/doc-clean"
  docfix "$clean"
  out=$(doc "$clean"); st=$?

  [ $st -eq 0 ] && ok "clean fixture: exit 0" \
    || bad "clean fixture reported a fault: $(printf '%s' "$out" | grep -aE 'FAIL|warn' | head -2)"
  printf '%s' "$out" | grep -q 'all checks passed' \
    && ok "clean fixture: all checks passed" \
    || bad "clean fixture never reached a clean result"

  # Each of these is a parser reporting that it matched. Without them a doctor
  # whose awk has gone blind passes this whole section: it says nothing about
  # every planted fault below, and saying nothing is what those tests read as
  # the fault being absent.
  printf '%s' "$out" | grep -q -- '--alpha -> alpha-skill' \
    && ok "the flag->skill parser resolved a mapping" \
    || bad "flag->skill parser matched nothing on a hook shaped like the real one"
  printf '%s' "$out" | grep -q "no flag is a prefix of another" \
    && ok "the prefix-clash check ran over a parsed FLAGS array" \
    || bad "prefix-clash check reached no verdict — the FLAGS array parsed as empty"
  # The count is the assertion, not the sentence. "every flag's grant matches"
  # is exactly what a comparison that read NOTHING used to print, so the pass
  # line only means something if it says how many flags it got through.
  printf '%s' "$out" | grep -q "every flag's grant matches between the hook and ownership.md (2 checked)" \
    && ok "the grant comparison reached a verdict on both flags" \
    || bad "grant comparison reached no verdict, or claimed one over fewer than 2 flags"

  # --strict's entire job is an exit code, so nothing but an exit code tests it.
  # Both directions: a clean run must stay 0 under it, or it is just `exit 1`.
  doc "$clean" --bogus >/dev/null 2>&1
  [ $? -eq 2 ] && ok "an unknown argument exits 2 rather than being ignored" \
               || bad "doctor.sh accepted an argument it does not implement"

  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$out" | grep -q 'every link anchor resolves (1 checked)' \
      && ok "the link-anchor walker found the fixture's one link" \
      || bad "link-anchor walker found no links in a fixture that has exactly one"

    doc "$clean" --strict >/dev/null 2>&1
    [ $? -eq 0 ] && ok "--strict leaves a warning-free run at 0" \
                 || bad "--strict failed a run with nothing to warn about"
  else
    printf '  \033[33mskip\033[0m  link anchors need python3 — the doctor warns instead of checking\n'
  fi

  # 1. The FLAGS array. One renamed line and every check below it is computed
  #    from an empty list, which reads as "nothing to check" rather than as an
  #    error — the failure this whole section exists for, in its purest form.
  dfix="$TMP/doc-noflags"; docfix "$dfix"
  edit_ "$dfix/shorthand-flags.sh" 's/^FLAGS=(/SHORTHAND_FLAGS=(/'; docommit "$dfix"
  says "$dfix" 'could not parse the FLAGS array' "a renamed FLAGS= line is a failure, not a quiet pass"

  # 2. A flag claimed in FLAGS and mapped to no skill. Worse than an absent flag:
  #    it is announced and then resolves to nothing.
  dfix="$TMP/doc-nomap"; docfix "$dfix"
  edit_ "$dfix/shorthand-flags.sh" 's/^FLAGS=(--alpha --beta)$/FLAGS=(--alpha --beta --gamma)/'
  docommit "$dfix"
  says "$dfix" 'has no skill_for() mapping' "a flag with no skill_for() arm is reported"

  # 3. Mapped, but with no block to inject. The flag fires and says nothing.
  dfix="$TMP/doc-noblock"; docfix "$dfix"
  edit_ "$dfix/shorthand-flags.sh" 's/^  --beta)$/  --betaX)/'; docommit "$dfix"
  says "$dfix" 'has no block_for() case' "a flag whose block_for() case is gone is reported"

  # 4. The grant comparison, which is the only thing that reads the heredoc's
  #    `Authorization:` line at all. Reword that line's shape in doctor.sh and
  #    the hook side comes back empty, the flag is skipped, and this fixture —
  #    a flag that grants push where the matrix grants nothing — passes.
  dfix="$TMP/doc-grant"; docfix "$dfix"
  edit_ "$dfix/shorthand-flags.sh" 's/^Authorization: none\.$/Authorization: COMMIT and push./'
  docommit "$dfix"
  says "$dfix" 'grants disagree' "a flag that gained push in the hook alone is reported"

  # 5. The other half of the same comparison: the matrix row. A flag stating a
  #    grant that the authority does not list is either an undocumented flag or
  #    one that should not exist, and both need a human.
  dfix="$TMP/doc-norow"; docfix "$dfix"
  edit_ "$dfix/workflow/ownership.md" '/^| beta |/d'; docommit "$dfix"
  says "$dfix" 'no row in' "a flag missing from ownership.md's matrix is reported"

  # 6. Neither half readable. Reword, indent or drop a block's `Authorization:`
  #    line and the hook side comes back empty for every flag at once — which is
  #    indistinguishable from a parser that has gone blind, and used to be
  #    reported as agreement. A check that could not look must say so.
  dfix="$TMP/doc-noauth"; docfix "$dfix"
  edit_ "$dfix/shorthand-flags.sh" 's/^Authorization:/**Authorization**:/'; docommit "$dfix"
  says "$dfix" 'compared against nothing' "a block with no readable Authorization line is reported"
  printf '%s' "$(doc "$dfix")" | grep -q "every flag's grant matches" \
    && bad "the grant check claimed a match while it could read no grant at all" \
    || ok "an unreadable grant withholds the pass line instead of claiming a match"

  # 7. A dangling authority citation — failure (2) in doctor.sh's own header.
  #    The grep that finds these is a fixed alternation of citing phrases, so it
  #    goes blind to a whole class the moment one is edited out.
  dfix="$TMP/doc-dangling"; docfix "$dfix"
  printf 'Dispatch via `ghost-skill`.\n' >> "$dfix/skills/alpha-skill/SKILL.md"
  docommit "$dfix"
  says "$dfix" 'resolves to neither' "a citation of a skill that exists nowhere is reported"

  # 8. A link whose heading moved. It opens the top of the file instead, which
  #    is indistinguishable from a live link to anyone who does not click it.
  if command -v python3 >/dev/null 2>&1; then
    dfix="$TMP/doc-anchor"; docfix "$dfix"
    printf 'Also [gone](workflow/ownership.md#no-such-heading).\n' >> "$dfix/README.md"
    docommit "$dfix"
    says "$dfix" 'no-such-heading' "a link to a heading that does not exist is reported"
  fi

  # 9. --strict, in the direction that matters. The warn class carries the real
  #    drift — "resolves nowhere", "grants disagree" — and only fails set exit 1,
  #    so without this flag all of it lands green in CI.
  dfix="$TMP/doc-warn"; docfix "$dfix"
  rm -rf "$dfix/skills/beta-skill"; docommit "$dfix"
  says "$dfix" 'resolves in neither' "a flag whose skill is absent warns"
  doc "$dfix" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "a warning alone does not fail an ordinary run" \
               || bad "the warn class failed a plain run — --strict then means nothing"
  doc "$dfix" --strict >/dev/null 2>&1
  [ $? -eq 1 ] && ok "--strict turns that same warning into exit 1" \
               || bad "--strict passed a run with warnings — CI's only guard against warn-class drift"

  # 10. "Checked nothing" must not read as "everything resolved". The citing-
  #     phrase alternation is a shape doctor.sh does not own — it is prose,
  #     written by hand in every skill file — so rewording those phrases, or
  #     adding a way of citing an authority the alternation does not list, blinds
  #     the extractor for every file at once. The clean fixture reaches this
  #     without any mutation: its two skills cite nothing, so the extractor
  #     legitimately returns nothing, and the old pass line claimed resolution
  #     over an empty set. Test 7 plants a dangling citation and proves the check
  #     can see; this proves it admits when it saw nothing.
  printf '%s' "$out" | grep -q 'every cited skill/agent/procedure resolves' \
    && bad "the cross-reference check claimed every citation resolves having extracted none" \
    || ok "a fixture with no citations withholds the resolution claim"
  printf '%s' "$out" | grep -q 'no skill/agent/procedure citations to check' \
    && ok "it says it had nothing to check instead" \
    || bad "the cross-reference check said neither that it passed nor that it was empty"

  # 11. The same rule one section up. A citation the extractor CAN see must be
  #     reported with its count, so a drop to zero is visible rather than
  #     indistinguishable from a clean run.
  dfix="$TMP/doc-cites"; docfix "$dfix"
  printf 'Dispatch via `beta-skill`.\n' >> "$dfix/skills/alpha-skill/SKILL.md"
  docommit "$dfix"
  says "$dfix" 'every cited skill/agent/procedure resolves (1 checked)' \
    "a resolvable citation is counted in the pass line"

  # 12. Hook commands, same defect class. The jq selector below walks a layout
  #     this script does not own — settings.json's hook shape is Claude Code's,
  #     and it has changed before. Restructure it and the selector matches
  #     nothing, the loop never runs, and the section prints no failure at all:
  #     silence that is indistinguishable from every hook being fine.
  dfix="$TMP/doc-hookshape"; docfix "$dfix"
  printf '%s\n' '{"hooks":{"UserPromptSubmit":[{"handlers":[{"type":"command","command":"~/.claude/shorthand-flags.sh"}]}]}}' \
    > "$dfix/settings.json"
  docommit "$dfix"
  says "$dfix" 'no command could be read out of them' \
    "a hook layout whose commands cannot be read is reported, not passed over"

  # 13. A dispatch-only skill with no `skillOverrides` entry. Its description
  #     loads in every session of every project while never being used as a
  #     trigger, because no flag maps to it — and nothing about the file says so.
  #     Four primitives were added at once on 2026-08-01 and all four were
  #     forgotten together, which is the case this assertion is written from.
  #     The clean fixture cannot exercise it: both its skills are flag-mapped.
  dfix="$TMP/doc-nooverride"; docfix "$dfix"
  mkdir -p "$dfix/skills/gamma-writer"
  printf '# gamma-writer\n\nReached only by dispatch.\n' > "$dfix/skills/gamma-writer/SKILL.md"
  docommit "$dfix"
  says "$dfix" 'reached only by dispatch' \
    "a dispatch-only skill with no skillOverrides entry is reported"

  # The other half, and the one that catches a check gone blind: the clean
  # fixture must say it looked. A parser that matched nothing reports every
  # fixture as fine by saying nothing at all.
  printf '%s' "$out" | grep -q 'every dispatch-only skill is set to name-only' \
    && ok "the override check reports that it ran on a clean fixture" \
    || bad "the override check said nothing on a clean fixture — it may be blind"

fi

# -------------------------------------------------------------------- result

head_ "A provider-backed backlog is not mistaken for files"

# record.todo may be a provider object instead of a path. Two things must hold,
# and both were broken by the first version: the manifest path walk must not
# treat the provider name, repo slug and label as three declared files, and the
# SessionStart backlog nudge must skip a backlog it cannot measure rather than
# testing `-f` against a blob of JSON and skipping by luck.
provp="$TMP/provider-proj"
mkdir -p "$provp/.claude"
cat > "$provp/.claude/workflow.json" <<'JSON'
{ "manifest": "workflow/v1",
  "record": { "todo": { "provider": "github-issues", "repo": "o/n", "label": "backlog" } } }
JSON
out=$(cd "$provp" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"declared in workflow.json but missing: github-issues"*|\
  *"declared in workflow.json but missing: o/n"*|\
  *"declared in workflow.json but missing: backlog"*)
    bad "the manifest path walk read a provider object as declared file paths" ;;
  *) ok "a provider object is not walked as declared paths" ;;
esac
case $out in
  *"nothing implements"*) bad "github-issues reported as unimplemented" ;;
  *) ok "github-issues is recognised as a real provider" ;;
esac

cat > "$provp/.claude/workflow.json" <<'JSON'
{ "manifest": "workflow/v1", "record": { "todo": { "provider": "acme-tracker", "repo": "o/n" } } }
JSON
out=$(cd "$provp" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"nothing implements"*) ok "a provider nothing implements is a FAILURE, not a silent fallback" ;;
  *) bad "an unimplemented provider passed — --todo would write nowhere and say nothing" ;;
esac

# The nudge must be silent here, and for the stated reason rather than by luck.
out=$(cd "$provp" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
      | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
case $out in
  *"open item(s) in"*) bad "the backlog-age nudge fired on a provider it cannot measure" ;;
  *) ok "the backlog-age nudge skips a provider-backed backlog" ;;
esac

head_ "Installation paths in runnable blocks"

# ~/.claude is the config directory in both install forms but the INSTALLATION
# only in a checkout, so a fenced block running ~/.claude/doctor.sh is dead under
# a plugin. The check exists because the class recurred inside the commit that
# claimed to close it: the fix grepped for the inline-backtick form, so every
# surviving instance — all of them in fenced blocks — reported clean.
#
# CLAUDE_CONFIG_DIR redirects CLAUDE_DIR, which is what md_files_ scans, so the
# fault is planted in a scratch suite rather than in the real tree.
instp="$TMP/instpath"
mkdir -p "$instp/skills/demo"
printf '# Demo\n\n```bash\n~/.claude/doctor.sh\n```\n' > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path that only exists in a checkout"*)
    ok "a fenced block hard-coding an installation path FAILS" ;;
  *) bad "a fenced ~/.claude/doctor.sh passed — it is dead under a plugin install" ;;
esac

# The same path in prose must NOT fire. Prose is a wrong label and a judgement
# call; only the runnable form is a fault, and a check that fired on both would
# be ignored for its noise.
printf '# Demo\n\nRun `~/.claude/doctor.sh` when in doubt.\n' > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path that only exists in a checkout"*)
    bad "the check fired on a prose mention, which it must not" ;;
  *) ok "a prose mention of an installation path does not fire the check" ;;
esac

# The one sanctioned exemption, per line so it cannot silently cover a block.
printf '# Demo\n\n```bash\n~/.claude/doctor.sh   # doctor:checkout-only\n```\n' \
  > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path that only exists in a checkout"*)
    bad "the doctor:checkout-only marker did not suppress the check" ;;
  *) ok "the doctor:checkout-only marker suppresses the check, per line" ;;
esac

# $CLAUDE_PLUGIN_ROOT is right for a hook and useless in a fenced block: measured
# 2026-08-02 from a real git-hosted install, it is EMPTY in a model-run Bash
# command, so a block keyed on it silently becomes the adopter's own config dir.
printf '# Demo\n\n```bash\n"$CLAUDE_PLUGIN_ROOT"/doctor.sh\n```\n' > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"EMPTY in a"*) ok "a fenced block keyed on \$CLAUDE_PLUGIN_ROOT FAILS" ;;
  *) bad "a fenced \$CLAUDE_PLUGIN_ROOT passed — it is empty in a model-run Bash command" ;;
esac

# The resolver that replaced it must itself pass, or the fix cannot be applied.
printf '# Demo\n\n```bash\nS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"\n[ -x "$S/doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/workflow-secretary/*/ 2>/dev/null | tail -1)\n"$S"/doctor.sh\n```\n' \
  > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path"*|*"EMPTY in a"*)
    bad "the sanctioned resolver trips the check it was written to satisfy" ;;
  *) ok "the sanctioned root resolver passes both rules" ;;
esac

# A config-directory path is correct in BOTH forms and must never be flagged —
# the bug inbox and the transcript directory genuinely live at ~/.claude.
printf '# Demo\n\n```bash\ncat ~/.claude/bug-reports.md\n```\n' > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path that only exists in a checkout"*)
    bad "the check flagged a config-directory path, which is correct in both forms" ;;
  *) ok "a config-directory path in a fenced block is not flagged" ;;
esac

head_ "The doctor inspects the installation it shipped with"

# The defect this guards was live in the tree published on 2026-08-02, for about
# an hour. CLAUDE_DIR fell back to CONFIG_DIR whenever $CLAUDE_PLUGIN_ROOT was
# absent — and it is absent in every model-run or hand-run Bash command, which is
# how the doctor is normally invoked. So an adopter who installed the plugin and
# ran the command every skill prescribes got three failures and an empty skill
# enumeration, on a correct install, from the check the README tells them not to
# skip.
#
# The fixture must sit OUTSIDE any git checkout: "am I a plugin" is answered
# partly by not being the root of one, and building this under $TMP inside the
# repo would make the answer depend on where the suite happens to run.
# Under the real cache layout, `plugins/cache/<marketplace>/<plugin>/<version>/`,
# because that is what identifies an install now — not the absence of a `.git`,
# which varies by how the marketplace was fetched.
pdir=$(mktemp -d)/plugins/cache/mk/demo-plugin/0.0.1
mkdir -p "$pdir/.claude-plugin" "$pdir/skills/demo" "$pdir/hooks" "$pdir/workflow"
printf '{"name":"x","version":"0.0.1","description":"d"}\n' > "$pdir/.claude-plugin/plugin.json"
printf -- '---\nname: demo\ndescription: d\n---\n\nBody.\n' > "$pdir/skills/demo/SKILL.md"
cp "$HOOK" "$pdir/hooks/shorthand-flags.sh" 2>/dev/null || : > "$pdir/hooks/shorthand-flags.sh"
cp "$CHECK" "$pdir/hooks/session-check.sh" 2>/dev/null || : > "$pdir/hooks/session-check.sh"
printf '.credentials.json\n' > "$pdir/.gitignore"
cp "$DOCTOR" "$pdir/doctor.sh"; chmod +x "$pdir/doctor.sh"

bare=$(mktemp -d)   # the adopter's own config dir: no skills, no hooks, no repo
printf '{"permissions":{"defaultMode":"auto"}}\n' > "$bare/settings.json"

out=$(cd "$bare" && CLAUDE_CONFIG_DIR="$bare" bash "$pdir/doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"not a git checkout"*|*"shorthand-flags.sh missing"*)
    bad "the doctor read the config dir as the installation with CLAUDE_PLUGIN_ROOT unset" ;;
  *) ok "a plugin-root doctor inspects itself, not the adopter's config dir" ;;
esac
case $out in
  *"no skills could be enumerated"*)
    bad "the doctor enumerated no skills while sitting in a tree that has one" ;;
  *) ok "and finds the skills that shipped with it" ;;
esac

# A plugin fetched from a git-hosted marketplace over SSH IS a clone and IS its
# own git toplevel. The first version of this rule asked "am I not a toplevel",
# which is not a property of being a plugin, so that shape regressed straight
# back to the defect above. Build the fixture under a path with the real cache
# layout in it, because that is what the rule keys on now.
gdir=$(mktemp -d)/plugins/cache/mk/demo-plugin/0.0.1
mkdir -p "$gdir"; cp -r "$pdir"/. "$gdir"/
git -C "$gdir" init -q .
out=$(cd "$bare" && CLAUDE_CONFIG_DIR="$bare" bash "$gdir/doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"not a git checkout"*|*"shorthand-flags.sh missing"*)
    bad "a plugin that carries its own .git regressed to reading the config dir" ;;
  *) ok "a plugin cache that is itself a clone is still a plugin" ;;
esac

# And the direction that loses checks rather than adding noise: a checkout
# reached through a symlink reports a LOGICAL path. That made a real checkout
# announce itself as a plugin and silently drop the credentials and settings
# checks — worse than any false failure, because a check that disappears reports
# nothing.
#
# Hermetic: a fixture that is a git checkout root AND carries a plugin manifest,
# which is exactly the source repository's own shape. Pointing this at the real
# tree instead made it depend on $HOME/.claude existing, so it proved nothing on
# a CI runner — and said so, because the third branch below exists.
cdir=$(mktemp -d)/checkout
mkdir -p "$cdir"; cp -r "$pdir"/. "$cdir"/
git -C "$cdir" init -q .
sdir=$(mktemp -d)/link; ln -s "$cdir" "$sdir"
out=$(cd "$sdir" && CLAUDE_CONFIG_DIR="$sdir" bash "$sdir/doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"installed as a plugin"*)
    bad "a symlinked checkout read as a plugin — the credentials check goes off with it" ;;
  *"all checks passed"*|*"failed"*)
    ok "a symlinked checkout is still a checkout" ;;
  *) bad "symlinked checkout: the doctor produced no result, so this proved nothing" ;;
esac

# The other half of the same rule, and the reason self-preference is conditional
# rather than absolute: pointing the doctor at a synthetic installation through
# CLAUDE_CONFIG_DIR is how every fixture above drives it. A doctor that always
# preferred its own location would report those fixtures on a tree it never read.
out=$(CLAUDE_CONFIG_DIR="$TMP/doc-clean" CLAUDE_DIR="$TMP/doc-clean" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"all checks passed"*)
    ok "CLAUDE_CONFIG_DIR still redirects the installation for a checkout doctor" ;;
  *) bad "CLAUDE_CONFIG_DIR no longer reaches the installation: $(printf '%s' "$out" | grep -a FAIL | head -2)" ;;
esac

# A cached doctor pointed at ANOTHER installation must judge that one, not
# itself. Before this, running the shipped tests from a plugin cache failed 21
# of 162 on a healthy install — every fixture said "inspect this directory" and
# the cached doctor preferred itself, so plugin-shaped checks ran against
# checkout-shaped fixtures. A confident wrong answer from the obvious diagnostic
# is worse than shipping no tests at all.
out=$(cd "$bare" && CLAUDE_CONFIG_DIR="$TMP/doc-clean" CLAUDE_DIR="$TMP/doc-clean" \
      bash "$pdir/doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"plugin has no hooks/hooks.json"*|*"installed as a plugin"*)
    bad "a cached doctor applied plugin checks to the checkout it was pointed at" ;;
  *"all checks passed"*)
    ok "an explicit CLAUDE_DIR overrides the doctor's own location" ;;
  *) bad "explicit CLAUDE_DIR: no result line, so this proved nothing" ;;
esac

head_ "reset-records.sh cannot write outside the project"

# It ships, it truncates files, and it reads its list from a manifest — which is
# data. A `../` path was followed and blanked, and a symlinked record was written
# through onto its target. Both landed outside the project, so outside its git,
# so unrecoverable.
RR="$_root/reset-records.sh"
if [ ! -x "$RR" ]; then
  bad "reset-records.sh missing or not executable at $RR"
else
  rr=$(mktemp -d); mkdir -p "$rr/proj/.claude" "$rr/outside"
  printf 'PRECIOUS\n' > "$rr/outside/notes.md"
  printf '{"record":{"todo":"../outside/notes.md"}}\n' > "$rr/proj/.claude/workflow.json"
  bash "$RR" --write --dir "$rr/proj" >/dev/null 2>&1 || :
  [ "$(cat "$rr/outside/notes.md")" = "PRECIOUS" ] \
    && ok "a manifest path escaping the project is refused" \
    || bad "reset-records.sh blanked a file OUTSIDE the project"

  printf 'ALSO PRECIOUS\n' > "$rr/outside/target.md"
  ln -s "$rr/outside/target.md" "$rr/proj/TODO.md"
  printf '{"record":{"todo":"TODO.md"}}\n' > "$rr/proj/.claude/workflow.json"
  bash "$RR" --write --dir "$rr/proj" >/dev/null 2>&1 || :
  [ "$(cat "$rr/outside/target.md")" = "ALSO PRECIOUS" ] \
    && ok "a symlinked record is refused rather than written through" \
    || bad "reset-records.sh wrote through a symlink onto an external file"

  # And it must still do its job, or the guards above are satisfied by a script
  # that refuses everything.
  mkdir -p "$rr/ok/.claude"
  printf '{"record":{"todo":"TODO.md"}}\n' > "$rr/ok/.claude/workflow.json"
  printf '# Backlog\n\nsomeone else content\n' > "$rr/ok/TODO.md"
  bash "$RR" --write --dir "$rr/ok" >/dev/null 2>&1
  [ "$(cat "$rr/ok/TODO.md")" = "# Backlog" ] \
    && ok "a record inside the project is still blanked to its heading" \
    || bad "reset-records.sh refused a legitimate record"

  # Dry run is the default, and a default that writes is a footgun.
  printf '# Backlog\n\nstill here\n' > "$rr/ok/TODO.md"
  bash "$RR" --dir "$rr/ok" >/dev/null 2>&1
  grep -q 'still here' "$rr/ok/TODO.md" \
    && ok "without --write it changes nothing" \
    || bad "reset-records.sh wrote without --write"
fi

head_ "Result"
if [ $fail -gt 0 ]; then
  printf '  \033[31m%d failed\033[0m, %d passed\n\n' "$fail" "$pass"; exit 1
fi
printf '  \033[32mall %d passed\033[0m\n\n' "$pass"
