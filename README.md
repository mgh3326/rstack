# rstack

Robin's skill stack for a fleet of coding agents. Inspired by Lauren Tan's [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT) and its Claude Code port [pstack-claude](https://github.com/michael-denyer/pstack-claude).

rstack is how sessions in this fleet work: one session goes deep and proves its result; parallel work is split only into independently mergeable units; review converges because a verdict covers a patch and only critical/high findings block.

## Skills

| Skill | For |
|---|---|
| [`robin-mode`](skills/robin-mode/SKILL.md) | The entry point: openers, playbooks, when to use subagents versus spawning a worker, roles by capability. |

Planned moves into this repo (from `agent-skills`): `wake` (PR loop), `ops` (lane mechanics), `fleet-review` (review triage), and the pinned pstack vendor tree.

## Tools it works with

`runtug` (spawn and placement), `pacelever` (quota), `panewire` (hub and lanes), `mergewake` (review, gate, merge), `handoffkeep` (tasks and docs).

## Install

```sh
git clone https://github.com/mgh3326/rstack ~/.agents/rstack
~/.agents/rstack/install.sh
```

The installer links each skill into the Claude Code and Codex skill directories. It never edits agent config files.

## License

MIT. pstack-derived ideas keep their attribution in the skill text.
