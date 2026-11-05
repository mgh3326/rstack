#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

check_workflows() {
  python3 - "$1" <<'PY'
from pathlib import Path
import re
import sys

gate = "github.event_name == 'push' && github.ref == 'refs/heads/main' &&"
failed = False
for path in sorted((Path(sys.argv[1]) / '.github/workflows').glob('*.yml')):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not re.match(r'^\s*runs-on\s*:', line):
            continue
        value = line.split(':', 1)[1]
        positions = [match.start() for match in re.finditer(r'vars\.', value)]
        if 'self-hosted' in value or any(not value[:pos].rstrip().endswith(gate) for pos in positions):
            print(f'{path}:{number}: runner must be hosted or gated to a main push')
            failed = True
sys.exit(1 if failed else 0)
PY
}

mkdir -p "$tmp/.github/workflows"
fixture="$tmp/.github/workflows/fixture.yml"
for value in \
  "\${{ vars.PANEWIRE_POST_LINUX_RUNNER || 'ubuntu-latest' }}" \
  'self-hosted' \
  "\${{ (github.ref == 'refs/heads/main' && vars.PANEWIRE_POST_LINUX_RUNNER) || 'ubuntu-latest' }}" \
  "\${{ (github.event_name == 'push' && github.ref == 'refs/heads/main' && vars.A) || vars.B }}" \
  "\${{ (github.event_name == 'push' && github.ref == 'refs/heads/main' && vars.A) || (github.ref == 'refs/heads/main' && vars.B) }}"; do
  printf 'runs-on: %s\n' "$value" > "$fixture"
  if check_workflows "$tmp"; then
    printf 'RED fixture unexpectedly passed: %s\n' "$value" >&2
    exit 1
  fi
done
check_workflows "$root"
