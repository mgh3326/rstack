#!/bin/bash
# rstack install: link every skills/<name> into the agent skill directories.
# Usage: ./install.sh [--dry-run]
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
dry=false
[ "${1:-}" = "--dry-run" ] && dry=true
targets=("$HOME/.claude/skills" "$HOME/.codex/skills")
for dir in "$root"/skills/*/; do
	name=$(basename "$dir")
	for target in "${targets[@]}"; do
		link="$target/$name"
		if $dry; then
			echo "would link $link -> ${dir%/}"
			continue
		fi
		mkdir -p "$target"
		if [ -e "$link" ] && [ ! -L "$link" ]; then
			echo "skip $link (exists and is not a link)" >&2
			continue
		fi
		ln -sfn "${dir%/}" "$link"
		echo "linked $link"
	done
done
