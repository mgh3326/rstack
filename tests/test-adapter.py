from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
adapter = (root / 'skills/robin-mode/SKILL.md').read_text()
assert '## Work boundary' in adapter
assert '## Fleet adapter for vendored pstack' in adapter
for name in ['skills/wake/SKILL.md', 'skills/fleet-review/SKILL.md', 'third_party/pstack/REVIEW.md', 'third_party/pstack/INSTALL']:
    text = (root / name).read_text()
    assert '§Fleet adapter for vendored pstack' in text, name
    assert ('§' + 'Precedence') not in text, name
assert '§Work boundary' in (root / 'skills/wake/SKILL.md').read_text()
for term in ['log.sh', 'UNVERIFIED', 'AskUserQuestion', 'panewire resolve', 'pstack-models.md', 'independently green', 'scratch', 'migration', 'fleet-review', 'babysit/swarm/arena']:
    assert term in adapter, term
print('PASS adapter headings, pointers and risk carve-outs')

reap = (root / 'skills/ops/references/reap.md').read_text()
assert 'panewire jobs list --lane <내 레인> --json' in reap
assert 'arbiter status' not in reap
assert not (root / 'bin/arbiter').exists()
assert not (root / 'tests/test-arbiter.sh').exists()
print('PASS hub job listing replaces retired arbiter')
