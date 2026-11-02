#!/usr/bin/env python3
"""Filesystem discovery audit. This is not proof of a harness session's loaded catalog."""
import json
import os
from pathlib import Path
import re
import sys
ROOT = Path(__file__).resolve().parent.parent
manifest = json.loads((ROOT / 'install/sets.json').read_text())
excluded = re.compile(r'^(poteto-mode|babysit|swarm|arena|setup-pstack|thermos|thermo-nuclear-.*|deslop|fix-ci|fix-merge-conflicts|get-pr-comments|make-pr-easy-to-review|automate-me|bro|ketchup.*|poteto-help|what-did-i-get-done)$')
print('| harness | set | scanned dirs | support/evidence | visible | excluded | duplicate names |')
print('|---|---|---|---|---:|---:|---:|')
failed = False
for name, harness in manifest['harnesses'].items():
    found = {}
    for directory in harness['scan_dirs']:
        base = Path.home() / directory
        if not base.is_dir():
            continue
        # Follow installed skill symlinks, but never recurse through a cycle.
        def visit(path, ancestors):
            real = path.resolve()
            if real in ancestors:
                return
            if path.name in {'.git', 'node_modules'}:
                return
            if path.is_file() and path.name.lower() == 'skill.md':
                match = re.search(r'^name:\s*[\'\"]?([^\n\'\"]+)', path.read_text(), re.M)
                if match:
                    found.setdefault(match[1].strip(), set()).add(str(real.parent))
            elif path.is_dir():
                for child in path.iterdir():
                    visit(child, ancestors | {real})
        visit(base, set())
    bad = sum(bool(excluded.fullmatch(n)) for n in found)
    duplicates = sum(len(paths) > 1 for paths in found.values())
    missing = set(manifest['sets'][harness['set']]) - found.keys()
    extra = set(found) - set(manifest['sets'][harness['set']])
    failed |= bool(bad or duplicates or missing or extra)
    print(f"| {name} | {harness['set']} | {', '.join('~/'+d for d in harness['scan_dirs'])} | {harness['evidence']} | {len(found)} | {bad} | {duplicates} |")
    if '--list' in sys.argv:
        print('<!-- ' + name + ': ' + ', '.join(sorted(found)) + ' -->')
    if missing:
        print(f'{name}: missing {sorted(missing)}', file=sys.stderr)
    if extra:
        print(f'{name}: additional skills {sorted(extra)}', file=sys.stderr)
sys.exit(int(failed))
