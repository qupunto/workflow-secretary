#!/usr/bin/env bash
# Retire the workflow from the project in $PWD — the reverse of adoption.
#
#   retire-workflow.sh                     # show what would go, change nothing
#   retire-workflow.sh --write             # remove the suite's MACHINERY
#   retire-workflow.sh --write --records   # ...and the workflow-shaped records
#   retire-workflow.sh --write --dir /path/to/project
#
# Uninstalling the plugin removes the skills and hooks and nothing else — it
# never touches a project, so the manifest, the sweep cache and the records a
# project accumulated all stay behind. This script is the tidy exit.
#
# TWO TIERS, because they are not the same kind of file:
#
#   MACHINERY (--write): .claude/workflow.json, the sweep checkpoint the
#   manifest declares (or .claude/sweeps.json), and the .claude/lane selector.
#   All suite-owned, all regenerable by re-adopting. Losing them costs nothing.
#
#   RECORDS (--write --records): the files the manifest declares for todo,
#   roadmap, releases, decisions, decisionsIndex, openDecisions, audits, the lane record
#   files, and the handoff where it is NOT CLAUDE.md (plus its HAZARDS.md
#   sibling). These hold the PROJECT'S OWN KNOWLEDGE — a backlog, a decision
#   log — which is why they hide behind a second flag and a dry run.
#
# NEVER deleted, whatever the flags: `record.reference` (usually the README),
# `record.changelog` and `record.tooling.*` — files that exist beyond the
# workflow, exactly the set reset-records.sh refuses to blank; a handoff at
# CLAUDE.md (the file also holds the project's standing instructions); the
# project's .claude/settings.json — the permissions.ask entries adoption merged
# there guard the project's own destructive commands and keep doing so without
# the suite; and the docs site. Export first if in doubt: export-records.sh
# archives what git does not track.
set -euo pipefail

DIR="$PWD"
WRITE=0
RECORDS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --write)   WRITE=1 ;;
    --records) RECORDS=1 ;;
    --dir)     shift; DIR="${1:?--dir needs a path}" ;;
    -h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

MANIFEST="$DIR/.claude/workflow.json"
[ -f "$MANIFEST" ] || { echo "no .claude/workflow.json in $DIR — nothing to retire" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "retire-workflow.sh needs jq" >&2; exit 1; }

# Refuse the suite's own tree. Retiring the workflow FROM the workflow deletes
# the records it dogfoods — an unrecoverable slip one wrong --dir away.
if [ -f "$DIR/.claude-plugin/plugin.json" ] &&
   jq -e '.name == "workflow-secretary"' "$DIR/.claude-plugin/plugin.json" >/dev/null 2>&1; then
  echo "REFUSED: $DIR is the workflow-secretary suite itself, not an adopting project" >&2
  exit 1
fi

DIR_ABS="$(cd "$DIR" && pwd -P)"

# Same containment as reset-records.sh: a manifest is data, and this script
# deletes. A path resolving outside the project, or a symlink pointing out of
# it, is refused rather than followed.
contained() { # rel, label -> absolute path on stdout, or failure
  local rel=$1 target tdir
  case "$rel" in /*) target=$rel ;; *) target="$DIR/$rel" ;; esac
  tdir="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || {
    printf '  REFUSE %-14s %s: parent does not resolve\n' "$2" "$rel" >&2; return 1; }
  local abs="$tdir/$(basename "$target")"
  if [ -L "$target" ]; then
    printf '  REFUSE %-14s %s is a symlink\n' "$2" "$rel" >&2; return 1
  fi
  case "$abs/" in
    "$DIR_ABS"/*) printf '%s' "$abs" ;;
    *) printf '  REFUSE %-14s %s resolves outside the project (%s)\n' "$2" "$rel" "$abs" >&2
       return 1 ;;
  esac
}

refused=0
removed=0
act() { # rel, label
  # The existence probe takes the same absolute/relative fork as contained(),
  # or an absolute manifest path is silently kept — probing at "$DIR/$1"
  # never finds it, so the refusal that should be loud never runs.
  local abs target
  case "$1" in /*) target=$1 ;; *) target="$DIR/$1" ;; esac
  [ -f "$target" ] || [ -L "$target" ] || return 0
  abs=$(contained "$1" "$2") || { refused=1; return 0; }
  if [ "$WRITE" -eq 1 ]; then
    rm -f "$abs"
    printf '  remove %-14s %s\n' "$2" "$1"
  else
    printf '  would  %-14s %s\n' "$2" "$1"
  fi
  removed=$((removed + 1))
}

# ------------------------------------------------------------------ records --
# First, while the manifest still exists to be read.
if [ "$RECORDS" -eq 1 ]; then
  while IFS=$'\t' read -r key rel; do
    [ -n "$rel" ] || continue
    case "$key" in
      handoff|lane:*.handoff)
        case "$rel" in CLAUDE.md|./CLAUDE.md)
          printf '  keep   %-14s %s also holds the project'\''s own instructions\n' "$key" "$rel"
          continue ;;
        esac
        act "$rel" "$key"
        # The overflow sibling travels with its record, same as reset-records —
        # and a lane handoff's directory can carry one of its own.
        hz="$(dirname "$rel")/HAZARDS.md"
        act "$hz" "hazards"
        ;;
      *) act "$rel" "$key" ;;
    esac
  done < <(jq -r '
      [ (.record // {} | to_entries[]
          | select(.key | IN("todo","roadmap","releases","decisions","decisionsIndex",
                             "openDecisions","audits","handoff"))
          | select(.value | type == "string")
          | [.key, .value]),
        (.lanes.named // {} | to_entries[] | .key as $l
          | (.value.transfer // empty) | ["lane:" + $l + ".transfer", .]),
        ((.lanes.conflicts // empty) | ["lanes.conflicts", .]),
        (.lanes.named // {} | to_entries[] | .key as $l
          | (.value.records // {}) | to_entries[]
          | ["lane:" + $l + "." + .key, .value])
      ] | .[] | @tsv' "$MANIFEST" 2>/dev/null)
  printf '  keep   %-14s reference, changelog and tooling files exist beyond the workflow\n' "always"
else
  echo "records kept (pass --records with --write to delete the workflow-shaped ones)"
fi

# ---------------------------------------------------------------- machinery --
sweeps=$(jq -r '.sweeps // ".claude/sweeps.json" | if type == "string" then . else ".claude/sweeps.json" end' "$MANIFEST" 2>/dev/null)
act "$sweeps" "sweeps"
act ".claude/lane" "lane"
act ".claude/workflow.json" "manifest"

echo
if [ "$refused" -ne 0 ]; then
  echo "REFUSED at least one path — nothing outside the project was touched. Fix the manifest and re-run."
  exit 1
fi
if [ "$WRITE" -eq 1 ]; then
  echo "retired: $removed file(s) removed. The plugin itself is 'claude plugin uninstall workflow-secretary';"
  echo "permissions.ask entries in .claude/settings.json were kept — they guard the project, not the suite."
else
  echo "$removed file(s) would be removed — nothing was written. Pass --write to do it."
fi
