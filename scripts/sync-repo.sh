#!/bin/bash
# Copies the iCloud working copy into the git copy (git is kept out of iCloud Drive), then shows the changes.
# Commit and push from the git copy afterwards. Internal files listed in repo-sync-excludes.txt are not copied.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$HOME/fanfic-pairings}"
brctl download "$SRC" 2>/dev/null || true
mkdir -p "$DEST"
rsync -a --delete --exclude-from="$SRC/scripts/repo-sync-excludes.txt" "$SRC/" "$DEST/"
if [ -d "$DEST/.git" ]; then git -C "$DEST" status --short | head -50; fi
