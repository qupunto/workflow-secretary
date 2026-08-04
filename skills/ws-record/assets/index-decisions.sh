#!/usr/bin/env bash
# Regenerates record.decisionsIndex from record.decisions — one row per `## `
# entry: the line it starts at, and its heading. Append-only means old entries
# keep their line numbers, so a row goes stale only when the log's preamble
# changes, and a regen fixes it.
#
# Declared in .claude/workflow.json as commands.indexRegen; `--check` verifies
# without writing, for callers that write nothing (commands.indexCheck).
# Run from the project directory. Both paths resolve from the manifest;
# record.decisionsIndex has deliberately no fallback (workflow/manifest.md), so
# an undeclared index is an error here rather than a guessed filename.
set -euo pipefail

manifest=".claude/workflow.json"
log="docs/decisions.md"
index=""
if [ -f "$manifest" ] && command -v jq >/dev/null 2>&1; then
  log=$(jq -r '.record.decisions // "docs/decisions.md"' "$manifest")
  index=$(jq -r '.record.decisionsIndex // empty' "$manifest")
fi
[ -n "$index" ] || {
  echo "index-decisions.sh: record.decisionsIndex is not declared — nothing to write" >&2
  exit 1
}
[ -f "$log" ] || {
  echo "index-decisions.sh: $log not found" >&2
  exit 1
}

render() {
  printf '# Decisions index\n\n'
  printf 'Generated from `%s` by `commands.indexRegen` — never hand-edit.\n' "$log"
  printf 'One row per entry: the line it starts at, and its heading.\n\n'
  grep -n '^## ' "$log" | sed -E 's|^([0-9]+):## |- L\1 — |'
}

if [ "${1:-}" = "--check" ]; then
  [ -f "$index" ] || {
    echo "index STALE: $index does not exist — run commands.indexRegen" >&2
    exit 1
  }
  if diff <(render) "$index" >/dev/null; then
    echo "index current: $index matches $log"
  else
    echo "index STALE: $index does not match $log — run commands.indexRegen" >&2
    exit 1
  fi
else
  render >"$index"
  echo "wrote $index ($(grep -c '^- ' "$index") entries)"
fi
