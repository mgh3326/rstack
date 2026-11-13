#!/usr/bin/env python3
"""Install only manifest-selected skills; never replace foreign content implicitly."""
import argparse
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = json.loads((ROOT / 'install/sets.json').read_text())

def within(path, root):
    return path == root or root in path.parents

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()
    home = Path.home().resolve()
    roots ={home / r for h in MANIFEST['harnesses'].values() for r in h['scan_dirs']}
    if any(within(ROOT, r.resolve()) for r in roots):
        parser.error('rstack checkout must be outside every scanned skill root')
    allow = {n for n in (ROOT / 'third_party/pstack/INSTALL').read_text().splitlines()
             if n and not n.startswith('#')}
    core = {p.name for p in (ROOT / 'skills').iterdir() if (p / 'SKILL.md').is_file()}
    desired = {}
    for harness in MANIFEST['harnesses'].values():
        target = home / harness['install_dir']
        for name in MANIFEST['sets'][harness['set']]:
            if name not in core | allow:
                parser.error(f'{name}: not a core skill or INSTALL member')
            source = ROOT / ('skills' if name in core else 'third_party/pstack/skills') / name
            if not (source / 'SKILL.md').is_file():
                parser.error(f'missing skill: {source}')
            desired[target / name] = source
    for tool in (ROOT / 'bin').iterdir():
        if tool.is_file() and os.access(tool, os.X_OK):
            desired[home / '.local/bin' / tool.name] = tool
    removals = []
    # Include shared roots, native roots and old installed bin links. Only owned links.
    for directory in roots | {home / '.local/bin'}:
        if not directory.is_dir():
            continue
        for link in directory.iterdir():
            if not link.is_symlink():
                continue
            old = link.resolve()
            if within(old, ROOT) and link not in desired:
                removals.append(link)
    # Preflight the whole plan before writing anything.
    for link, source in desired.items():
        if link in removals:
            continue
        if link.is_symlink():
            old = link.resolve()
            if old == source:
                continue
            if not within(old, ROOT):
                print(f'{link}: old target {os.readlink(link)}', file=sys.stderr)
                if not args.force:
                    parser.error('foreign symlink refused; use --force to replace it')
        elif link.exists():
            parser.error(f'refusing to replace regular content: {link}')
    for link in removals:
        print(f'prune {link} -> {os.readlink(link)}')
        if not args.dry_run:
            link.unlink()
    for link, source in sorted(desired.items()):
        if link.is_symlink() and link.resolve() == source:
            continue
        print(f'link {link} -> {source}')
        if not args.dry_run:
            link.parent.mkdir(parents=True, exist_ok=True)
            if link.is_symlink():
                link.unlink()
            link.symlink_to(source, target_is_directory=source.is_dir())

if __name__ == '__main__':
    main()
