"""Overlapping installs must validate and promote only their own staged artifact."""
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import runpy
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
FIX = ROOT / 'tests/fixtures/fleet-install'

class ConcurrentInstall(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        module = runpy.run_path(str(ROOT / 'bin/fleet-install'))
        self.local = module['install_local']
        self.remote = module['install_host']
        self.run = module['run']

    def releases(self, arch):
        args = []
        for version in ['release-a', 'release-b']:
            directory = self.base / version
            directory.mkdir()
            artifact = directory / ('panewire-'+arch)
            artifact.write_text('#!/bin/sh\necho '+version+'\n')
            args.append(SimpleNamespace(tool='panewire', dir=str(directory),
                        bin_dir=str(self.base / 'bin'), dry_run=False,
                        sums={artifact.name}, ssh=str(FIX / 'ssh'), scp=str(FIX / 'scp')))
        return args

    def overlap(self, function, args, is_copy, is_validate):
        barrier = threading.Barrier(2)
        validated = []
        def run(argv, **kw):
            result = self.run(argv, **kw)
            if is_copy(argv):
                barrier.wait(timeout=10)
            if is_validate(argv):
                validated.append(result.stdout.strip())
            return result
        with patch.dict(function.__globals__, {'run': run}):
            with ThreadPoolExecutor(max_workers=2) as pool:
                outcomes = list(pool.map(function, args))
        return outcomes, validated

    def test_local_overlapping_releases_keep_distinct_stages(self):
        arch = self.local.__globals__['local_arch']()
        args = self.releases(arch)
        outcomes, validated = self.overlap(self.local, args,
                lambda argv: argv[0] == 'install', lambda argv: argv[1:] == ['--version'])
        self.assertEqual(outcomes, [True, True])
        self.assertCountEqual(validated, ['release-a', 'release-b'])
        self.assertEqual({p.name for p in (self.base / 'bin').iterdir()}, {'panewire'})

    def test_remote_overlapping_releases_keep_distinct_stages(self):
        args = self.releases('linux-arm64')
        home = self.base / 'hosts/a'
        home.mkdir(parents=True)
        (home / 'arch').write_text('linux-arm64\n')
        env = {'FLEET_INSTALL_FAKE_ROOT': str(self.base / 'hosts')}
        # Both remote calls use the same host, with a barrier after each upload.
        function = self.remote
        barrier = threading.Barrier(2)
        validated = []
        def run(argv, **kw):
            result = self.run(argv, **kw)
            if argv[0] == str(FIX / 'scp'):
                barrier.wait(timeout=10)
            if argv[0] == str(FIX / 'ssh') and '--version' in argv[-1]:
                validated.append(result.stdout.strip())
            return result
        with patch.dict(os.environ, env), patch.dict(function.__globals__, {'run': run}):
            with ThreadPoolExecutor(max_workers=2) as pool:
                outcomes = list(pool.map(lambda arg: function(arg, 'a')[0], args))
        self.assertEqual(outcomes, [True, True])
        self.assertCountEqual(validated, ['release-a', 'release-b'])
        self.assertEqual({p.name for p in (home / '.local/bin').iterdir()}, {'panewire'})

if __name__ == '__main__':
    unittest.main()
