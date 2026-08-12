#!/usr/bin/env bash
# Install the team skills where Buzz agents can discover them.
#
# Agents spawned by Buzz Desktop run with cwd ~/.buzz (the "nest"), and the
# Claude Code runtime discovers skills at <cwd>/.claude/skills/<name>/SKILL.md
# — the same path the bundled buzz-cli skill uses. Copying there makes every
# Claude-runtime agent able to load these on demand.
#
# Existing skills with the same name are only replaced with --force, mirroring
# buzz-acp's own collision rule (pack skills never overwrite local ones).
#
# Usage:  ./install.sh          # install / update
#         ./install.sh --force  # overwrite existing copies

set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.buzz/.claude/skills"
FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

[[ -d "$HOME/.buzz" ]] || { echo "No ~/.buzz nest found — start Buzz Desktop once first." >&2; exit 1; }
mkdir -p "$DEST"

installed=0 skipped=0
for dir in "$SRC"/*/; do
  name="$(basename "$dir")"
  [[ -f "$dir/SKILL.md" ]] || continue
  if [[ -e "$DEST/$name" && "$FORCE" == false ]]; then
    echo "skip    $name (exists — use --force to replace)"
    skipped=$((skipped + 1))
    continue
  fi
  rm -rf "$DEST/$name"
  cp -R "$dir" "$DEST/$name"
  echo "install $name"
  installed=$((installed + 1))
done

echo
echo "$installed installed, $skipped skipped → $DEST"
echo "Skills load per-session; agents pick them up on their next spawn."
