#!/usr/bin/env bash
#
# Blank every record this project declares, back to its canonical heading —
# a fresh start, with the structure kept and the content gone.
#
#   ./reset-records.sh            # show what would be blanked, change nothing
#   ./reset-records.sh --write    # do it
#   ./reset-records.sh --write --dir /path/to/project
#
# WHY THIS EXISTS. A record's structure is the workflow; its content is one
# project's history. Someone adopting this suite wants the first, never the
# second — a session reading an inherited backlog will pick work off it and
# believe it. `publish.sh` calls this so the published tree ships agnostic, and
# an adopter can run it directly after cloning or forking.
#
# WHAT IT WILL NOT DO. It refuses to touch a record that is not declared in the
# manifest, and it never invents files. `record.reference` (README.md) and
# `record.tooling.catalog` (.claude/TOOLING.md) are records that describe the
# TOOLING rather than the project, so blanking them would destroy the landing
# page — they are deliberately not in the table below, and deriving this list
# from the manifest instead of naming it is the mistake that would.
#
# It is read-only unless you pass --write, and it prints what it is about to do
# either way, because a script that empties files should be boring to run by
# accident.
set -euo pipefail

DIR="$PWD"
WRITE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --write) WRITE=1 ;;
    --dir)   shift; DIR="${1:?--dir needs a path}" ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

MANIFEST="$DIR/.claude/workflow.json"
[ -f "$MANIFEST" ] || { echo "no .claude/workflow.json in $DIR — nothing declares a record here" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "reset-records.sh needs jq" >&2; exit 1; }

# manifest key | canonical heading. The heading is what `--adopt` would create,
# and nothing more: the owning skill writes the first real line, so that the
# first real line is a true one.
RECORDS='
todo|# Backlog
roadmap|# Roadmap
changelog|# Changelog
handoff|# Handoff
decisions|# Decision log
openDecisions|# Open decisions
audits|# Audit log
'

DIR_ABS="$(cd "$DIR" && pwd -P)"

# A manifest is data, and this script writes. `record.todo: "../../notes.md"`
# was followed and blanked — outside the project, so outside its git, so
# unrecoverable. A record that is a SYMLINK was written through onto its target
# for the same reason. Neither needs malice: a hand-edited manifest and a
# symlinked record are both things people do.
#
# So every path is resolved and must land inside the project, and a symlinked
# record is refused rather than resolved — a record that points somewhere else
# is a question for a person, not something to guess at while truncating a file.
# Refusal is loud AND fatal: publish.sh depends on this script, and a partial
# reset that exits 0 would publish a tree carrying somebody's content.
refused=0
contained() { # relative-path -> prints the absolute path, or refuses
  local rel=$1 target tdir abs
  target="$DIR/$rel"
  if [ -L "$target" ]; then
    printf '  REFUSE %-14s %s is a symlink — resolve it yourself\n' "$2" "$rel" >&2
    refused=1; return 1
  fi
  tdir="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || {
    printf '  REFUSE %-14s %s has no reachable directory\n' "$2" "$rel" >&2
    refused=1; return 1
  }
  abs="$tdir/$(basename "$target")"
  case "$abs/" in
    "$DIR_ABS"/*) printf '%s' "$abs" ;;
    *) printf '  REFUSE %-14s %s resolves outside the project (%s)\n' "$2" "$rel" "$abs" >&2
       refused=1; return 1 ;;
  esac
}

changed=0 skipped=0
while IFS='|' read -r key heading; do
  [ -n "$key" ] || continue
  rel=$(jq -r --arg k "$key" '.record[$k] // empty | if type == "string" then . else empty end' "$MANIFEST")
  # `if type == "string"` is not defensive noise: record.todo may be a PROVIDER
  # object naming a GitHub label, and there is no file to blank in that case.
  # Emptying a backlog that lives in someone's issue tracker is not this
  # script's business, and could not be undone from here.
  if [ -z "$rel" ]; then
    printf '  skip   %-14s not declared as a file\n' "$key"; skipped=$((skipped + 1)); continue
  fi
  if [ ! -f "$DIR/$rel" ]; then
    printf '  skip   %-14s %s does not exist\n' "$key" "$rel"; skipped=$((skipped + 1)); continue
  fi
  abs=$(contained "$rel" "$key") || { skipped=$((skipped + 1)); continue; }
  before=$(wc -c < "$abs" | tr -d ' ')
  if [ "$WRITE" -eq 1 ]; then
    printf '%s\n' "$heading" > "$abs"
    printf '  blank  %-14s %s (was %s bytes)\n' "$key" "$rel" "$before"
  else
    printf '  would  %-14s %s (%s bytes -> %s)\n' "$key" "$rel" "$before" "${#heading}"
  fi
  changed=$((changed + 1))
done <<EOF
$RECORDS
EOF

# The hazards file is not a record and no manifest key names it, but it carries
# standing warnings about whichever repository wrote them — which is exactly the
# content an adopter must not inherit. Handled by name, and only where the
# handoff's own directory says this project uses that split.
haz="$DIR/.claude/HAZARDS.md"
if [ -f "$haz" ]; then
  if [ "$WRITE" -eq 1 ]; then
    printf '# Standing hazards\n' > "$haz"
    printf '  blank  %-14s .claude/HAZARDS.md\n' "hazards"
  else
    printf '  would  %-14s .claude/HAZARDS.md\n' "hazards"
  fi
  changed=$((changed + 1))
fi

echo
if [ "$WRITE" -eq 1 ]; then
  echo "blanked $changed, skipped $skipped"
else
  echo "$changed would be blanked, $skipped skipped — nothing was written. Pass --write to do it."
fi
[ "$refused" -eq 0 ] || {
  echo "REFUSED at least one record — see above. Nothing outside the project was touched." >&2
  exit 1
}
