"""CLI regressions for reviewed installer safety failures; no real host actions."""
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
FIX = ROOT / 'tests/fixtures/fleet-install'

class InstallerReview(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.arch = platform.system().lower() + '-' + {'x86_64': 'amd64', 'aarch64': 'arm64'}.get(platform.machine(), platform.machine())
        (self.base / 'scratch').mkdir()
        self.gh = self.base / 'gh'
        self.gh.mkdir()
        (self.gh / 'panewire.run').write_text(json.dumps([{'status': 'completed', 'conclusion': 'success'}]))
        (self.gh / 'panewire.release').write_text('\n'.join(sorted({'panewire-'+self.arch, 'panewire-linux-arm64'}))+'\n')
        self.env = {**os.environ, 'HOME': str(self.base), 'TMPDIR': str(self.base / 'scratch'),
                    'FLEET_INSTALL_FAKE_DIR': str(self.gh),
                    'FLEET_INSTALL_FAKE_ROOT': str(self.base / 'hosts'),
                    'FLEET_INSTALL_BIN_DIR': str(self.base / 'bin'),
                    'FLEET_INSTALL_CONFIG': str(self.base / 'absent.toml'),
                    'FLEET_INSTALL_WAIT_TIMEOUT': '2'}
        for tool in ['gh', 'ssh', 'scp']:
            self.env['FLEET_INSTALL_'+tool.upper()] = str(FIX / tool)
            self.env['FLEET_INSTALL_'+tool.upper()+'_LOG'] = str(self.base / (tool+'.log'))

    def install(self, tool='panewire', *args, tag='v9'):
        return subprocess.run([sys.executable, str(ROOT / 'bin/fleet-install'), tool, tag, *args],
                              env=self.env, text=True, capture_output=True, timeout=15)

    def test_reject_shell_and_path_tool_names_before_external_calls(self):
        for tool in ['panewire;true', 'a b', '../panewire', str(self.base / 'absolute'), '-option', 'x\ny']:
            with self.subTest(tool=tool):
                r = self.install(tool, '--dry-run', '--hosts', 'a')
                self.assertEqual(r.returncode, 2, r.stdout+r.stderr)
                self.assertFalse((self.base / 'ssh.log').exists())
                self.assertFalse((self.base / 'gh.log').exists())

    def test_fresh_remote_bin_directory_is_created_before_upload(self):
        remote = self.base / 'hosts/a'
        remote.mkdir(parents=True)
        (remote / 'arch').write_text('linux-arm64\n')
        r = self.install('panewire', '--hosts', 'a')
        self.assertEqual(r.returncode, 0, r.stdout+r.stderr)
        binary = remote / '.local/bin/panewire'
        self.assertTrue(binary.is_file())
        self.assertEqual(subprocess.check_output([str(binary), '--version'], text=True).strip(), 'panewire v9 (panewire-linux-arm64)')

    def assert_failed_local_preserves_install(self, flag):
        binary = self.base / 'bin/panewire'
        binary.parent.mkdir()
        binary.write_text('#!/bin/sh\necho old-version\n')
        binary.chmod(0o755)
        self.env[flag] = 'panewire-'+self.arch
        r = self.install()
        self.assertEqual(r.returncode, 1, r.stdout+r.stderr)
        old = subprocess.run([str(binary), '--version'], text=True, capture_output=True)
        self.assertEqual(old.stdout.strip(), 'old-version', 'broken artifact replaced the working local binary')
        self.assertFalse(binary.with_suffix('.new').exists())

    def test_broken_local_artifact_preserves_old_install_and_removes_stage(self):
        self.assert_failed_local_preserves_install('FLEET_INSTALL_FAKE_BROKEN')

    def test_unexecutable_local_artifact_preserves_old_install_and_removes_stage(self):
        self.assert_failed_local_preserves_install('FLEET_INSTALL_FAKE_INVALID_FORMAT')

    def test_slash_tag_works_for_install_and_dry_run(self):
        for args in [(), ('--dry-run',)]:
            with self.subTest(args=args):
                r = self.install('panewire', *args, tag='release/v9')
                self.assertEqual(r.returncode, 0, r.stdout+r.stderr)
                self.assertIn('release/v9', r.stdout)

    def test_dry_run_without_checksum_tools(self):
        empty_path = self.base / 'empty-path'
        empty_path.mkdir()
        self.env['PATH'] = str(empty_path)
        r = self.install('panewire', '--dry-run')
        self.assertEqual(r.returncode, 0, r.stdout+r.stderr)
        self.assertIn('SHA256SUMS', r.stdout)
        self.assertFalse((self.base / 'bin').exists())

if __name__ == '__main__':
    unittest.main()
