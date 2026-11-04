# rstack

Fleet skills, their tests and the adapter for pinned upstream pstack methods.

Clone outside all scanned skill roots (recommended: `~/.agents/rstack`):

```sh
git clone https://github.com/mgh3326/rstack.git ~/.agents/rstack
cd ~/.agents/rstack
./install.sh --dry-run --prune-old
./install.sh --prune-old
./scripts/check-harness-skills.sh --list
```

Python 3.9+ and Git are required. `--dry-run` writes nothing. The installer refuses
foreign symlinks, prints their old targets, and requires `--force` to replace them.
Regular files and directories are never overwritten. Re-running converges on the
manifest; removed selections lose only rstack-owned links.

`install/sets.json` is the single set and harness manifest. Lead harnesses Claude,
Codex and OMP receive the full core + pstack INSTALL allowlist. CommandCode and
the shared Gemini/Antigravity root receive the worker subset. Devin reads Claude's
root and therefore receives the full set: this is a known scoping limit, covered
by robin-mode's adapter and wake's worker authority rules. No second set is
installed into Devin's native or compatibility roots. OpenCode likewise reuses
the Claude root rather than installing duplicates. Extra user-configured discovery
roots and project skills must be audited separately on each host.

Keep `~/.agents/skills` empty. It is a shared discovery root, not the repository
location. `--prune-old` moves the old agent-skills checkout to
`~/.agents/agent-skills-backup` and removes old checkout links from harness roots
and `~/.local/bin`. The backup is preserved for rollback. Existing unrelated
content is not removed. The checker reports filesystem discovery against the
manifest, including excluded names, distinct source directories for duplicate
names, missing skills and extra names. It does not prove a running session's
loaded catalog; restart and inspect each harness after a rollout.

The retained `bin/` tools are linked into `~/.local/bin`: fleet-install
(release installation) and fleet-rev (revision audit). Both
are DEPRECATED. Remove them when mergewake rollout,
agent and status are enabled on all hosts. rob-lookup is retired: archived issues
now live in handoffkeep docs and the archive job reports the active issue count.
Arbiter is retired, replaced by `panewire jobs list` (hk 2718). Rollout waits for
that panewire release, sequenced by the desk. Installing links does not execute the tools. See [fleet-rev](docs/fleet-rev.md)
and [fleet-install](docs/fleet-install.md) for the retained interfaces.

First-party skills are in `skills/`: robin-mode, wake, ops, fleet-review and desk.
`skills/robin-mode/SKILL.md` owns the work boundary and fleet adapter. Upstream
pstack lives in `third_party/pstack`, outside discovery; only INSTALL names are
linked. The vendor tree is under its own MIT licenses and notices: see PINNED,
NOTICE.md, NOTICE-skills.md and LICENSE* there. It is copied from a pinned commit,
never auto-updated. Excluded skills remain readable as upstream reference files.

Run the changed installer checks with `python3 tests/test-install.py` and
`python3 tests/test-adapter.py`. CI runs the moved contracts and retained tool tests
on Linux and macOS. The macOS job is advisory; the required `ci-ok` check
aggregates the Linux job.
