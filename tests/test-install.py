import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
M = json.loads((ROOT / 'install/sets.json').read_text())

def install_list():
    return [n for n in (ROOT / 'third_party/pstack/INSTALL').read_text().splitlines()
            if n and not n.startswith('#')]


class Manifest(unittest.TestCase):
    """INSTALL is the pstack allowlist; sets.json must not drift from it."""

    def test_full_set_is_core_plus_install(self):
        core = sorted(p.name for p in (ROOT / 'skills').iterdir() if (p / 'SKILL.md').is_file())
        full = M['sets']['full']
        self.assertEqual(len(full), len(set(full)), 'duplicate names in the full set')
        self.assertEqual(set(full), set(core) | set(install_list()))

    def test_worker_set_is_a_subset_of_full(self):
        worker = M['sets']['worker']
        self.assertEqual(len(worker), len(set(worker)), 'duplicate names in the worker set')
        self.assertLessEqual(set(worker), set(M['sets']['full']))

    def test_every_harness_names_a_known_set(self):
        for name, harness in M['harnesses'].items():
            self.assertIn(harness['set'], M['sets'], name)


class Install(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)

    def run_install(self, *args, ok=True):
        r = subprocess.run([str(ROOT / 'install.sh'), *args], env={**os.environ, 'HOME': str(self.home)}, text=True, capture_output=True)
        self.assertEqual(r.returncode == 0, ok, r.stderr)
        return r

    def test_catalogs_and_idempotence(self):
        self.run_install('--dry-run')
        self.assertEqual(list(self.home.iterdir()), [])
        self.run_install()
        r = subprocess.run([str(ROOT / 'scripts/check-harness-skills.sh')], env={**os.environ, 'HOME': str(self.home)}, text=True, capture_output=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        for h in M['harnesses'].values():
            self.assertEqual({p.name for p in (self.home / h['install_dir']).iterdir()}, set(M['sets'][h['set']]))
        self.assertFalse((self.home / '.agents/skills').exists())
        self.assertEqual(self.run_install().stdout, '')
        self.assertTrue((self.home / '.local/bin/fleet-rev').is_symlink())
        self.assertFalse((self.home / '.local/bin/arbiter').is_symlink())

    def test_foreign_link_refusal_and_force(self):
        link = self.home / '.codex/skills/wake'
        link.parent.mkdir(parents=True)
        link.symlink_to('/foreign/missing')
        r = self.run_install(ok=False)
        self.assertIn('/foreign/missing', r.stderr)
        self.assertFalse((self.home / '.claude').exists())
        self.run_install('--force')
        self.assertEqual(link.resolve(), ROOT / 'skills/wake')

    def test_prune_old_checkout_and_links(self):
        old = self.home / '.agents/skills'
        old.mkdir(parents=True)
        subprocess.run(['git', 'init', '-q', str(old)], check=True)
        subprocess.run(['git', '-C', str(old), 'remote', 'add', 'origin', 'https://github.com/example/agent-skills.git'], check=True)
        (old / 'third_party/pstack/skills/poteto-mode').mkdir(parents=True)
        (old / 'third_party/pstack/skills/poteto-mode/SKILL.md').write_text('---\nname: poteto-mode\n---\n')
        link = self.home / '.codex/skills/poteto-mode'
        link.parent.mkdir(parents=True)
        link.symlink_to(old / 'third_party/pstack/skills/poteto-mode')
        before = subprocess.run([str(ROOT / 'scripts/check-harness-skills.sh'), '--list'], env={**os.environ, 'HOME': str(self.home)}, text=True, capture_output=True)
        self.assertIn('poteto-mode', before.stdout)
        self.run_install(ok=False)
        self.run_install('--prune-old', '--dry-run')
        self.assertTrue(old.exists())
        self.run_install('--prune-old')
        self.assertFalse(old.exists())
        self.assertFalse(link.is_symlink())
        self.assertTrue((self.home / '.agents/agent-skills-backup/.git').exists())
        after = subprocess.run([str(ROOT / 'scripts/check-harness-skills.sh'), '--list'], env={**os.environ, 'HOME': str(self.home)}, text=True, capture_output=True)
        self.assertEqual(after.returncode, 0, after.stderr)
        self.assertNotIn('poteto-mode', after.stdout)

    def test_regular_content_never_overwritten(self):
        link = self.home / '.codex/skills/wake'
        link.mkdir(parents=True)
        self.run_install('--force', ok=False)
        self.assertTrue(link.is_dir())

    def test_catalog_detects_duplicate_and_excluded(self):
        self.run_install()
        duplicate = self.home / '.agents/skills/wake'
        duplicate.mkdir(parents=True)
        (duplicate / 'SKILL.md').write_text('---\nname: wake\n---\n')
        excluded = self.home / '.agents/skills/arena'
        excluded.mkdir()
        (excluded / 'SKILL.md').write_text('---\nname: arena\n---\n')
        r = subprocess.run([str(ROOT / 'scripts/check-harness-skills.sh')], env={**os.environ, 'HOME': str(self.home)}, capture_output=True)
        self.assertNotEqual(r.returncode, 0)

if __name__ == '__main__':
    unittest.main()
