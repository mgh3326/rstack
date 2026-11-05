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

green = '''comms-contract: v1 [example]

# Ledger
행 형식: - <action> | root: hk <id> | release: <condition> | status: active | record: hk <ids>
Prose note about the ledger.
## active
- disable action for scope | root: hk 123 | release: fixed | status: active | record: hk 123, 456, deploy/example/123
## released
- old action | root: hk 456 | release: complete | status: released | record: hk 456, 789
'''
result = run(checker, green)
assert result.returncode == 0, f'green fixture failed: {result.stderr} {result.stdout}'
with tempfile.TemporaryDirectory() as tmp:
    ledger = Path(tmp) / 'ledger'
    ledger.write_text(green)
    result = subprocess.run(['python3', str(checker), str(ledger)], text=True, capture_output=True)
    assert result.returncode == 0, f'file fixture failed: {result.stderr}'
print('PASS live-shape ledger accepted')
rows = [
    ('past violation', '- exclude a model profile from a grade | status: active | record: hk 1', ('root', 'release')),
    ('missing root', '- action | release: fixed | status: active | record: hk 1', ('root',)),
    ('empty release', '- action | root: hk 1 | release:  | status: active | record: hk 1', ('release',)),
    ('bad status', '- action | root: hk 1 | release: fixed | status: pending | record: hk 1', ('status',)),
    ('missing record', '- action | root: hk 1 | release: fixed | status: active', ('record',)),
    ('invalid record', '- action | root: hk 1 | release: fixed | status: active | record: other', ('record',)),
    ('duplicate status', '- action | status: active | status: released', ('status',)),
]
for label, row, fields in rows:
    check_red(checker, label, row, fields)
for label, row in [('indented row', '  - x | status: active'),
                   ('asterisk row', '* x'), ('missing space row', '-x'),
                   ('numbered row', '1. x')]:
    result = run(checker, row + '\n')
    assert result.returncode == 1 and result.stdout == f'line 1: malformed row: {row}\n', f'{label}: expected malformed-row diagnostic and exit 1, got {result.returncode}: {result.stdout}'
    print(f'PASS {label} rejected')
result = run(checker, '')
assert result.returncode == 1 and result.stdout == 'no ledger rows read\n', f'empty input: expected no-rows diagnostic and exit 1, got {result.returncode}: {result.stdout}'
print('PASS empty input rejected')
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

needle = "if not re.match(r'hk [0-9]+', fields.get('record', '')):"
assert needle in source, 'record guard changed; update mutation probe'
mutant = source.replace(needle, 'if False:', 1)
with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp) / 'mutant.py'
    path.write_text(mutant)
    try:
        check_red(path, 'record mutant', '- action | root: hk 1 | release: fixed | status: active', ('record',))
    except AssertionError:
        print('PASS record mutant caught')
    else:
        raise AssertionError('record mutant escaped')
