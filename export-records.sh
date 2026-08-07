#!/usr/bin/env bash
# Export or import the machine-local workflow state of the project in $PWD.
#
#   export-records.sh [-o <archive>]           # default: records-export.tar.gz
#   export-records.sh --import <archive> [--force]
#
# WHAT TRAVELS: only what a `git clone` on the next machine would NOT bring —
# manifest-declared record files (`record.*` and `lanes.named.*.records.*`)
# that git does not track, the `.claude/lane` selector, and `bug-reports.md`
# when run in the config directory, which is the one file whose loss is
# unrecoverable. A project that keeps its records out of its repository is the
# whole audience; a project whose records are tracked has nothing here to move.
#
# WHAT DOES NOT: tracked records (the clone brings them), and the sweep
# checkpoint (`.claude/sweeps.json`) — a cache whose loss costs one re-sweep
# and can never cost correctness, so moving it buys nothing worth the bytes.
#
# Import is ALL-OR-NOTHING. It refuses absolute and `..` entries outright, and
# refuses to overwrite any existing non-empty file unless --force is given —
# a half-restored record set reads exactly like a complete one, which is the
# same reason doctor.sh fails on a half-split lane map.
#
# The archive is a snapshot, not a record: do not commit it, and treat one from
# another machine as stale the moment either side writes.

set -u

MODE=export
ARCHIVE="records-export.tar.gz"
FORCE=0
while [ $# -gt 0 ]; do
  case $1 in
    -o)       shift; ARCHIVE=${1:?-o needs a path} ;;
    --import) MODE=import; shift; ARCHIVE=${1:?--import needs an archive} ;;
    --force)  FORCE=1 ;;
    -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "export-records.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MANIFEST="$PWD/.claude/workflow.json"

# ---------------------------------------------------------------------- import
if [ "$MODE" = import ]; then
  [ -f "$ARCHIVE" ] || { echo "no archive at $ARCHIVE" >&2; exit 1; }

  # Refuse hostile entries BEFORE anything is written: an absolute path, or
  # `..` as its own segment anywhere in the path — the only way out of the
  # project root.
  bad=$(tar tzf "$ARCHIVE" | grep -E '^/|(^|/)\.\.(/|$)' || true)
  if [ -n "$bad" ]; then
    echo "REFUSED: archive contains entries that escape the project:" >&2
    printf '%s\n' "$bad" | sed 's/^/  /' >&2
    exit 1
  fi

  # All-or-nothing: collect every collision first, then either stop or extract.
  clobber=""
  while IFS= read -r e; do
    case $e in */) continue ;; esac
    [ -s "$PWD/$e" ] && clobber="$clobber  $e
"
  done < <(tar tzf "$ARCHIVE")
  if [ -n "$clobber" ] && [ "$FORCE" -eq 0 ]; then
    echo "REFUSED: these files exist here and are not empty (use --force to overwrite):" >&2
    printf '%s' "$clobber" >&2
    exit 1
  fi

  tar xzf "$ARCHIVE" -C "$PWD" || exit 1
  echo "restored into $PWD:"
  tar tzf "$ARCHIVE" | sed 's/^/  /'
  exit 0
fi

# ---------------------------------------------------------------------- export
list=$(mktemp)
trap 'rm -f "$list"' EXIT

candidates() {
  if [ -f "$MANIFEST" ] && command -v jq >/dev/null 2>&1; then
    # Strings and arrays under record.*; provider objects have no file and
    # record.tooling contributes only its catalog. Lane records are record
    # paths like any other. `sweeps` is deliberately absent — see the header.
    jq -r '
      [ (.record // {} | to_entries[] | .value
          | if type == "string" then .
            elif type == "array" then .[]
            else empty end),
        (.record.tooling // {} | .catalog // empty),
        (.lanes.named // {} | .[]? | (.records // {}) | .[]?),
        (.lanes.named // {} | .[]? | .transfer // empty),
        (.lanes.conflicts // empty)
      ] | .[] | select(type == "string")' "$MANIFEST" 2>/dev/null
  fi
  echo ".claude/lane"
  # The inbox is config-directory state, included only when this IS the config
  # directory — from any other project it belongs to a different export.
  if [ "$PWD" -ef "$CONFIG_DIR" ] && [ -f "$PWD/bug-reports.md" ]; then
    echo "bug-reports.md"
  fi
}

in_git=0
git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1 && in_git=1

while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -f "$PWD/$p" ] || continue
  # Tracked files travel with the repository; only the rest need the archive.
  if [ "$in_git" -eq 1 ] &&
     git -C "$PWD" ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
    continue
  fi
  printf '%s\n' "$p"
done < <(candidates) | sort -u > "$list"

if [ ! -s "$list" ]; then
  echo "nothing to export: every declared record is tracked, and no selector or inbox is here"
  exit 0
fi

tar czf "$ARCHIVE" -C "$PWD" -T "$list" || exit 1
echo "exported to $ARCHIVE:"
sed 's/^/  /' "$list"
