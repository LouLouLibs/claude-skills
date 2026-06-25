#!/usr/bin/env bash
# Install all claude-skills into ~/.claude/skills/
# Skills are copied (not symlinked) so they get picked up inside VMs/sandboxes
# where this repo checkout isn't mounted.
set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "$0")" && pwd)/skills"
TARGET_DIR="$HOME/.claude/skills"

mkdir -p "$TARGET_DIR"

for skill in "$SKILLS_DIR"/*/; do
  name="$(basename "$skill")"
  target="$TARGET_DIR/$name"
  if [ -L "$target" ]; then
    # Replace a stale symlink from an older install.
    rm "$target"
  elif [ -e "$target" ]; then
    # Remove a previous copy so renamed/deleted files don't linger.
    rm -rf "$target"
  fi
  cp -R "$skill" "$target"
  echo "installed: $name"
done
