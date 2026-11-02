# fleet-rev (DEPRECATED)

Read-only revision audit for scopefuel, rstack, panewire and handoffkeep.
Remove this tool when mergewake rollout/agent/status is enabled on all hosts.

Run `fleet-rev --json` for the configured fleet, or `fleet-rev --only local`
for a local probe. The canonical configuration is
`~/.config/fleet/hosts.toml`, overridden by `FLEET_HOSTS_CONFIG`. The probe reads
installed revision metadata and the rstack checkout at `~/.agents/rstack`;
it does not reinstall tools or read credentials.

Statuses: current, current+modified, behind N, diverged, unknown, absent or
unreachable. Exit codes: 0 all current; 1 behind/diverged; 3 unknown/absent/
unreachable without a stale result; 2 usage/configuration error. JSON contains
`main`, `hosts`, and `rc`, matching the process exit code.

Reinstallation is desk-owned; fleet-rev never performs it:

- **scopefuel**: `uv tool install --force git+https://github.com/mgh3326/scopefuel@<sha>`
  is fleet-rev's recommended (권장) pinned installation form. The upstream
  scopefuel README documents the revision-less form, not this recommendation.
- **rstack**: update `~/.agents/rstack` to the approved commit and run its installer
  only under the rollout runbook in the PR body.
- **panewire**: follow its [node update runbook](https://github.com/mgh3326/panewire/blob/main/docs/runbooks/node-update.md).
- **handoffkeep**: use its currently approved installation procedure; this
  document grants no deployment authority.

If the canonical configuration is unreadable and only `WRK_HOSTS_CONFIG` or
`wrk/hosts.toml` remains, fleet-rev refuses with exit 2 instead of silently
auditing only the local host. Set `FLEET_HOSTS_CONFIG` to the intended file or
migrate it to `fleet/hosts.toml`. A readable canonical configuration takes
precedence over obsolete settings.
