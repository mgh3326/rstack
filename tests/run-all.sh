#!/usr/bin/env bash
# The one test entry point: CI (both workflows) and local runs call this.
# Every tests/test-*.py and tests/test-*.sh runs; a new test needs no CI edit.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
for test in tests/test-*.py; do
  echo "== $test"
  python3 "$test"
done
for test in tests/test-*.sh; do
  echo "== $test"
  bash "$test"
done
