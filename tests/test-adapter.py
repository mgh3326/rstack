from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
adapter = (root / 'skills/robin-mode/SKILL.md').read_text()
assert '## Work boundary' in adapter
assert '## Fleet adapter for vendored pstack' in adapter
for name in ['skills/wake/SKILL.md', 'skills/fleet-review/SKILL.md', 'third_party/pstack/REVIEW.md', 'third_party/pstack/INSTALL']:
    text = (root / name).read_text()
    assert '§Fleet adapter for vendored pstack' in text, name
    assert '§Precedence' not in text, name
assert '§Work boundary' in (root / 'skills/wake/SKILL.md').read_text()
for term in ['comment-sicko', 'log.sh', 'statechart', 'recall', 'reflect', 'UNVERIFIED', 'AskUserQuestion', 'runtug resolve', 'pstack-models.md', 'independently green', 'scratch', 'migration', 'fleet-review', 'babysit/swarm/arena']:
    assert term in adapter, term
print('PASS adapter headings, pointers and risk carve-outs')
