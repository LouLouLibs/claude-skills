#!/usr/bin/env bash
# Install all claude-skills into ~/.claude/skills/
set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "$0")" && pwd)/skills"
TARGET_DIR="$HOME/.claude/skills"

mkdir -p "$TARGET_DIR"

for skill in "$SKILLS_DIR"/*/; do
  name="$(basename "$skill")"
  target="$TARGET_DIR/$name"
  if [ -L "$target" ]; then
    rm "$target"
  elif [ -e "$target" ]; then
    echo "skip: $target exists and is not a symlink"
    continue
  fi
  ln -s "$skill" "$target"
  echo "installed: $name"
done
