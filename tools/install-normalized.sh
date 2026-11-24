#!/bin/bash
# Copy normalize-local.ts output into the shipped tree, dropping the
# ".normalized" suffix: <dir>/cat.normalized.mp3 -> words/cat.mp3
#
# Usage: tools/install-normalized.sh <normalized-dir> <words|arpa|phonemes>
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <normalized-dir> <words|arpa|phonemes>" >&2
  exit 2
fi
SRC="$1"
case "$2" in words|arpa|phonemes) ;; *) echo "target must be words, arpa or phonemes" >&2; exit 2 ;; esac
DEST="$(cd "$(dirname "$0")/.." && pwd)/$2"

shopt -s nullglob
files=("$SRC"/*.normalized.mp3)
if [ ${#files[@]} -eq 0 ]; then
  echo "No *.normalized.mp3 files in $SRC" >&2
  exit 1
fi
for f in "${files[@]}"; do
  name="$(basename "$f" .normalized.mp3).mp3"
  [ -e "$DEST/$name" ] && verb="replaced" || verb="added"
  cp -f "$f" "$DEST/$name"
  echo "$verb $2/$name"
done
