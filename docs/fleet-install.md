# fleet-install — fleet tool release installer

`bin/fleet-install` replaces the desk's ad-hoc install script for the tagged
fleet tools (panewire, mergewake, …). One command downloads a GitHub
release, verifies `SHA256SUMS`, installs the right `<tool>-<os>-<arch>` binary
on the operator host and each named remote, then runs the restart hooks from a
local-only config file.

```sh
fleet-install mergewake v1.2.3 --hosts build-a,build-b
fleet-install mergewake v1.2.3 --hosts build-a --dry-run
```

Tool names must begin with an ASCII letter or digit and contain only ASCII
letters, digits, underscores or hyphens. Unsafe names are rejected before any
external call. `--dry-run` previews checksum verification without requiring a
checksum executable; an actual installation always verifies checksums.

What it does, in order:

1. Polls `gh run list -R mgh3326/<tool> --branch <tag>` until the release
   workflow run for headBranch `<tag>` completes (`--wait-timeout`, default
   1800s, bounding each `gh` call too; a fresh tag may not have a run row
   yet, so an empty list keeps polling). A non-success conclusion is an
   error. `--workflow NAME` restricts the wait to one workflow — pass the
   tool repo's release workflow name when a tag branch can trigger others.
2. `gh release download <tag> -R mgh3326/<tool> --clobber` into a temp dir.
3. `shasum -a 256 -c SHA256SUMS` (or `sha256sum -c`). Required, never skipped —
   and every artifact about to be installed must be listed in it.
4. Detects this host's `<os>-<arch>` (`uname`, x86_64→amd64, aarch64→arm64),
   stages `install -m 755` in a unique temporary directory beside the target,
   verifies the staged binary with `--version`, then atomically renames it into
   place. Failed validation removes only this attempt's stage and preserves
   the working install.
5. Per `--hosts` entry: probes `<os>-<arch>` over ssh, creates `~/.local/bin`
   before upload, then uses `scp` to copy the matching binary to
   a unique `.local/bin/<tool>.<token>.new`, validates it with `--version`,
   then uses `mv -f` into place (atomic replace). If the staged binary cannot
   run, the previous install stays untouched.
6. Runs the configured restart hooks for every target that installed.

Overlapping installs stage and validate independently; the last successful
atomic replacement determines the live version. Release tags, including tags
with `/`, are passed unchanged to GitHub and never used as temporary path prefixes.

Exit codes: `0` all targets ok · `1` at least one target (host or local)
failed — other hosts still install · `2` usage · `3` release wait timed
out/failed or download/checksum error.

## Restart hook config

Host names and which daemon runs where are **local config only** — this repo
is public and must never name real hosts. Default path:

```
~/.config/wrk/fleet-install.toml      # override: FLEET_INSTALL_CONFIG
```

Format (TOML subset — bracket sections, `restart = [ "... strings ..." ]`):

```toml
# Example only — no real hosts.
# [tool.<tool>.local]        hooks run on the operator host via `sh -c`
# [tool.<tool>.host.<name>]  hooks run on the --hosts entry <name> over ssh

[tool.mergewake.local]
restart = ["launchctl kickstart -k gui/$(id -u)/com.example.mergewake"]

[tool.mergewake.host.build-b]
restart = ["systemctl --user restart mergewake.service"]
```

Tools or targets without a section get no restart step. A restart failure
marks that target failed (exit 1).

## Environment overrides

`FLEET_INSTALL_GH` / `FLEET_INSTALL_SSH` / `FLEET_INSTALL_SCP` replace the
`gh`/`ssh`/`scp` binaries, `FLEET_INSTALL_BIN_DIR` the install dir,
`FLEET_INSTALL_CONFIG` the config path, `FLEET_INSTALL_WAIT_TIMEOUT` and
`FLEET_INSTALL_POLL_INTERVAL` the release-wait pacing. Used by
`tests/test-fleet-install.sh`.
