#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
import tempfile

checker = Path('bin/containment-check')

def run(script, text, *args):
    return subprocess.run(['python3', str(script), *args], input=text, text=True, capture_output=True)

def check_red(script, label, row, fields):
    result = run(script, row + '\n')
    assert result.returncode == 1, f'{label}: expected exit 1, got {result.returncode}: {result.stderr}'
    for field in fields:
        assert f'line 1: missing or invalid {field}:' in result.stdout, f'{label}: missing diagnostic for {field}: {result.stdout}'
    print(f'PASS {label} rejected')

green = '''Ledger
- disable action for scope | root: hk 123 | release: fixed | status: active | record: hk 123
- old action | root: hk 456 | release: complete | status: released | record: hk 456
'''
result = run(checker, green)
assert result.returncode == 0, f'green fixture failed: {result.stderr} {result.stdout}'
with tempfile.TemporaryDirectory() as tmp:
    ledger = Path(tmp) / 'ledger'
    ledger.write_text(green)
    result = subprocess.run(['python3', str(checker), str(ledger)], text=True, capture_output=True)
    assert result.returncode == 0, f'file fixture failed: {result.stderr}'
print('PASS valid active and released rows')
rows = [
    ('past violation', '- exclude a model profile from a grade | status: active | record: hk 1', ('root', 'release')),
    ('missing root', '- action | release: fixed | status: active | record: hk 1', ('root',)),
    ('empty release', '- action | root: hk 1 | release:  | status: active | record: hk 1', ('release',)),
    ('bad status', '- action | root: hk 1 | release: fixed | status: pending | record: hk 1', ('status',)),
    ('duplicate status', '- action | status: active | status: released', ('status',)),
]
for label, row, fields in rows:
    check_red(checker, label, row, fields)
assert run(checker, '', '--help').returncode == 0
source = checker.read_text()
needle = 'if not root_valid:'
assert needle in source, 'root guard changed; update mutation probe'
mutant = source.replace(needle, 'if False:', 1)
with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp) / 'mutant.py'
    path.write_text(mutant)
    try:
        check_red(path, 'root mutant', rows[1][1], rows[1][2])
    except AssertionError:
        print('PASS root mutant caught')
    else:
        raise AssertionError('root mutant escaped')
PY
