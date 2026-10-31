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

Pick the model and effort **when you call the subagent**, from this sheet (the pstack approach: no `model:` in agent frontmatter, no Codex role files). Spawned workers are different: `runtug` picks their model from grade and quota.

| Role | Claude Code lead | Codex lead | Effort |
|---|---|---|---|
| Lead session (desk, integrator) | session model | `gpt-6.1-sol` | high; xhigh only for T3 design or a safety boundary |
| Explorer / reader (`how`, `why`, `blast-radius`) | `sonnet` | `gpt-6-luna` | the lead's effort, one step lower for plain lookups |
| Implementer of a decided unit | `sonnet` | `gpt-6.1-terra` | the lead's effort |
| Bug, perf, judgment | `opus` | `gpt-6.1-sol` | the lead's effort, one step higher when the cause is unknown |
| Hardest problem | `fable` | `gpt-6-astra` | one step above the lead |
| Verifier (runs the acceptance list) | `opus`, fixed | `gpt-6.1-terra`, fixed | fixed at high; never adjusted per task, so verdicts compare |
| Panel (arena, interrogate) | one each of `opus`, `fable`, `sonnet` | `astra`, `sol`, `terra`, `luna` | the lead's effort |

Rules:
- **Effort**: start at the lead's level; raise one step for an unknown cause or a design with no precedent, lower one step for lookups. Never `max` (runtug reserves it for escalation).
- **Judge from another family.** A panel's judge or a review is never the lead's family. Across vendors (Claude ↔ Codex), use `runtug delegate --role reviewer` or `--panel N`; inside one vendor, vary the model, and say so when only one model was reachable.
- **Re-run findings before trusting them**; keep the verifier's model fixed.
- Claude Code: pass `model` (and `effort`, which this sheet asks for explicitly) on the `Agent` call. Codex: pass `model` and `reasoning_effort` on `spawn_agent`.
- A model slug that is not available on the account falls back to the session model; say so in the verdict.
