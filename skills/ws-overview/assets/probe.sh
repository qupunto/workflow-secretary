#!/usr/bin/env bash
# probe.sh — the mechanical half of --ws-overview, in one read-only call.
#
# Emits every countable line of the overview report: tree, per-record open
# counts, warning counts, sweep freshness, roadmap position. The skill adds
# the judgment lines only. Writes nothing, stamps nothing, never touches the
# network — external state (backlog providers, gh, CI) is reported as not
# counted here, never as zero.
#
# Run it from the project directory. It lives with the installation, which is
# how it finds doctor.sh in both install forms (checkout and plugin cache).

INSTALL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MANIFEST=".claude/workflow.json"

HAVE_JQ=1; command -v jq >/dev/null 2>&1 || HAVE_JQ=0
HAVE_MANIFEST=0; [ -f "$MANIFEST" ] && HAVE_MANIFEST=1

# With a manifest, an undeclared key is reported "undeclared" — no fallback.
# With no manifest at all, the conventional names from workflow/manifest.md
# apply. jq missing while a manifest exists makes it unreadable: every key
# reads as undeclared, and the header says why.
mget() { # mget <jq-path> <fallback-with-no-manifest>
  if [ "$HAVE_MANIFEST" = 1 ]; then
    [ "$HAVE_JQ" = 1 ] && jq -r "$1 // empty" "$MANIFEST" 2>/dev/null || true
  else
    printf '%s\n' "$2"
  fi
}

LANE=""
[ -f .claude/lane ] && LANE="$(head -1 .claude/lane 2>/dev/null | tr -d '[:space:]')"

resolve_record() { # resolve_record <key> <fallback> — lane-aware per manifest.md
  local path override
  path="$(mget ".record.$1" "$2")"
  if [ -n "$LANE" ]; then
    override="$(mget ".lanes.named.\"$LANE\".records.$1" "")"
    [ -n "$override" ] && path="$override"
  fi
  printf '%s\n' "$path"
}

count_line() { # count_line <label> <path-or-empty> <grep-pattern> <unit>
  if [ -z "$2" ]; then
    printf '%s: undeclared\n' "$1"
  elif [ ! -f "$2" ]; then
    printf '%s: %s — missing\n' "$1" "$2"
  else
    printf '%s: %s — %s %s\n' "$1" "$2" "$(grep -c "$3" "$2" 2>/dev/null || true)" "$4"
  fi
}

echo "== probe =="
echo "mechanical block only; judgment lines are the skill's"
[ "$HAVE_MANIFEST" = 0 ] && echo "note: no manifest — conventional fallback names in use"
[ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 0 ] && \
  echo "note: jq unavailable — manifest unreadable, every key reads as undeclared"

echo
echo "== tree =="
if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "branch: $(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo detached)"
  echo "head: $(git rev-parse --short HEAD 2>/dev/null || echo none)"
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$dirty" = 0 ]; then echo "worktree: clean"; else echo "worktree: dirty ($dirty paths)"; fi
else
  echo "not a git repository — every git-derived line below is unavailable"
fi
echo "lane: ${LANE:-none}"

echo
echo "== records =="
TODO_TYPE="file"
if [ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 1 ]; then
  provider="$(jq -r '.record.todo | if type == "object" and has("provider") then .provider else empty end' "$MANIFEST" 2>/dev/null)"
  [ -n "$provider" ] && TODO_TYPE="provider:$provider"
fi
if [ "$TODO_TYPE" = "file" ]; then
  count_line "todo" "$(resolve_record todo TODO.md)" '^[[:space:]]*- \[ \]' "open"
else
  echo "todo: ${TODO_TYPE#provider:} provider — not counted here; count via the provider contract"
fi
count_line "open-decisions" "$(resolve_record openDecisions docs/open-decisions.md)" '^## ' "entries"

lanes="$(mget '.lanes.named | keys[]?' '')"
if [ -n "$lanes" ]; then
  echo "lanes declared:"
  while IFS= read -r l; do
    lt="$(mget ".lanes.named.\"$l\".records.todo" "")"; lt="${lt:-$(mget '.record.todo' 'TODO.md')}"
    lo="$(mget ".lanes.named.\"$l\".records.openDecisions" "")"; lo="${lo:-$(mget '.record.openDecisions' 'docs/open-decisions.md')}"
    tn="?"; on="?"
    [ -f "$lt" ] && tn="$(grep -c '^[[:space:]]*- \[ \]' "$lt" 2>/dev/null || true)"
    [ -f "$lo" ] && on="$(grep -c '^## ' "$lo" 2>/dev/null || true)"
    printf '  %s: todo %s open (%s), open-decisions %s (%s)\n' "$l" "$tn" "$lt" "$on" "$lo"
  done <<< "$lanes"
fi

echo
echo "== warnings =="
if [ -x "$INSTALL_ROOT/doctor.sh" ]; then
  doctor_out="$("$INSTALL_ROOT/doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
  printf '%s\n' "$doctor_out" | grep '^  FAIL  ' | sed 's/^  FAIL  /doctor FAIL: /' || true
  printf 'doctor result: %s\n' "$(printf '%s\n' "$doctor_out" | tail -1 | sed 's/^  *//')"
else
  echo "doctor: not found at $INSTALL_ROOT — not checked"
fi
count_line "inbox open reports" "$CONFIG_DIR/bug-reports.md" '^## \[open\]' ""
count_line "handoff !important blocks" "$(resolve_record handoff CLAUDE.md)" '!important' ""

echo
echo "== sweeps =="
SWEEPS="$(mget '.sweeps' '.claude/sweeps.json')"
SWEEPS="${SWEEPS:-.claude/sweeps.json}"
if [ ! -f "$SWEEPS" ]; then
  echo "no checkpoint file at $SWEEPS — no sweep has ever run here"
elif [ "$HAVE_JQ" = 0 ]; then
  echo "checkpoint exists at $SWEEPS but jq is unavailable — not read"
else
  jq -r '.entries | to_entries[] | [.key, .value.baseline, (.value.at // "-"), (.value.method // "-"), (.value.result // "")] | @tsv' \
      "$SWEEPS" 2>/dev/null | \
  while IFS=$'\t' read -r name baseline at method result; do
    base="${baseline%+dirty}"
    mark=""; [ "$base" != "$baseline" ] && mark=", dirty at stamp"
    extra=""; [ -n "$result" ] && extra=", result $result"
    ahead="$(git rev-list --count "$base"..HEAD 2>/dev/null)"
    if [ -n "$ahead" ]; then
      printf '%s: baseline %s (%s, %s%s%s) — %s commits behind HEAD\n' \
        "$name" "$base" "$at" "$method" "$mark" "$extra" "$ahead"
    else
      printf '%s: baseline %s is not a commit in this repository — sweep in full\n' "$name" "$baseline"
    fi
  done
  [ -z "$(jq -r '.entries | keys[]?' "$SWEEPS" 2>/dev/null)" ] && echo "checkpoint exists but holds no entries"
fi

echo
echo "== roadmap =="
ROADMAP="$(resolve_record roadmap ROADMAP.md)"
if [ -z "$ROADMAP" ]; then
  echo "roadmap: undeclared"
elif [ ! -f "$ROADMAP" ]; then
  echo "roadmap: $ROADMAP — missing"
else
  awk '
    /^## / {
      m++; title = substr($0, 4)
      comp[m] = (title ~ /\*completed\*/) ? 1 : 0
      miles[m] = title
      next
    }
    /^[[:space:]]*- \[ \]/ {
      if (m > 0) { open[m]++; total++ }
      if (m > 0 && firstblock[m] == "") {
        b = $0; sub(/^[[:space:]]*- \[ \][[:space:]]*/, "", b); firstblock[m] = b
      }
    }
    END {
      printf "milestones (## headings): %d, open blocks total: %d\n", m, total + 0
      cur = 0
      for (i = 1; i <= m; i++) if (!comp[i]) { cur = i; break }
      if (cur == 0 && m > 0) { print "current: none — every heading is marked completed"; exit }
      if (m == 0) { print "current: none — no ## headings"; exit }
      printf "current (first not marked completed): %s\n", miles[cur]
      printf "  open blocks here: %d\n", open[cur] + 0
      if (firstblock[cur] != "") printf "  next unchecked block: %s\n", firstblock[cur]
      if (cur < m) printf "next after it: %s\n", miles[cur + 1]
    }
  ' "$ROADMAP"
fi
