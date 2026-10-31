# Roles by capability

`runtug` picks the model and host by quota and grade. This table says which **role** a session can take, so a brief asks each model for what it does well. Capabilities are checked per harness, not per model brand. Retired 2026-10-31: Grok (subscription ended), Kimi (not subscribed), Devin GLM.

| Capability | Harnesses (2026-10) | Roles it can take |
|---|---|---|
| In-session subagents | Claude Code (`Agent`/`Task`), Codex (`spawn_agent`, needs `multi_agent = true`) | **Lead**: a whole PR with design comparison, blast-radius and self-verification in one session. **Desk**: coordination, merge gate, small fixes. **Consult**: design and strategy advice. |
| No subagents, strong coder | Devin (SWE-2), Command Code, Antigravity | **Implementer**: one closed-contract unit (acceptance list given, files named, no open design). **Reviewer lane**: one mergewake review pass. |
| Any harness | — | **Verifier**: run the acceptance list against the built artifact, answer PASS / PASS+NOTES / FAIL, no fixing, no free bug hunting. **Reader**: read-only investigation with cited evidence. |

## Rules

- A lead may delegate exploration and verification to its own subagents; it spawns another worker only under the conditions in `robin-mode`.
- An implementer gets a brief whose design is already decided (data shape, files, acceptance). If the brief needs a design choice, it escalates instead of guessing.
- The reviewer of a PR is never the same family as its author (mergewake enforces this).
- A verifier never edits code. Its verdict covers the patch it ran (patch-id), not the commit.
- Model choice stays with `runtug`/`pacelever`; a brief may state the role and a required capability (`--tags`), not a model.

## Enabling subagents

- Claude Code: built in.
- Codex: add `[features]` `multi_agent = true` to `~/.codex/config.toml` (host config change; done by operator-desk per host).

## Models and effort for in-session subagents

The role → model table is **not** kept here. It lives in the fleet's routing policy, which `runtug` reads and enforces for spawned workers. In-session subagents use the same table through one call, so a lead, its subagents and its spawned workers never disagree:

```sh
runtug resolve --role <lead|implementer|explorer|verifier|reviewer|judge> --grade <G> --t <Tn>
# the last line prints:  profile=<name> effort=<rung>
```

- Pass the printed profile's model and effort on the subagent call (Claude Code `Agent` `model`/`effort`; Codex `spawn_agent` `model`/`reasoning_effort`).
- If `resolve` refuses (`role_exhausted_wait`, `role_exhausted_escalate`, or no policy and no cache for `lead`/`verifier`), do **not** substitute a weaker model: wait, escalate to the parent lane, or run the step yourself.
- **Verifier stays fixed** for a task so verdicts compare; resolve it once and reuse it.
- **Judge from another family**: pass `--builder-family <the author's family>` for a reviewer or judge.
- Effort rule: the role's effort is the start; raise one step for an unknown cause or a design with no precedent, lower one step for lookups. Never `max` (reserved for escalation).
- No `runtug` on the host: use your own session model for exploration only, and say so in the result.
