#!/bin/sh
# See install/sets.json for harness roles and skill discovery roots.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$root/scripts/install-skills.py" "$@"
