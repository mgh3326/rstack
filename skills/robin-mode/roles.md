# Roles by capability

A role is what a session is asked to do. Pick it from the harness's capabilities, never from a model brand. Which profiles, families and effort a role may use is hk `policy/model-routing`, applied by `runtug`; this file keeps no model or harness table.

| Capability | Roles it can take |
|---|---|
| In-session subagents | **Lead**: a whole PR with design comparison, blast-radius and self-verification in one session. **Desk**: coordination, merge gate, small fixes. **Consult**: design and strategy advice. |
| No subagents, strong coder | **Implementer**: one closed-contract unit (acceptance list given, files named, no open design). **Reviewer lane**: one mergewake review pass. |
| Any harness | **Verifier**: run the acceptance list against the built artifact, answer PASS / PASS+NOTES / FAIL, no fixing, no free bug hunting. **Reader**: read-only investigation with cited evidence. |

## Rules

- A lead delegates and spawns under `robin-mode` §Subagents versus spawned workers.
- An implementer gets a brief whose design is already decided (data shape, files, acceptance). If the brief needs a design choice, it escalates instead of guessing.
- Whether a review pass counts as independent: `fleet-review` §Independence.
- A verifier never edits code. Whether its verdict carries over to a later head: `fleet-review` §A verdict covers a patch, not a SHA.
- A brief may state the role and a required capability (`--tags`), not a model.

## Enabling subagents

- Claude Code: built in.
- Codex: add `[features]` `multi_agent = true` to `~/.codex/config.toml` (host config change; done by operator-desk per host).

## Models and effort for in-session subagents

In-session subagents take their model from the same routing policy `runtug` enforces for spawned workers, through one call, so a lead, its subagents and its spawned workers never disagree:

```sh
runtug resolve --role lead                                   # lead and consult take no --grade
runtug resolve --role <implementer|explorer|verifier> --grade <G> --t <Tn>
runtug resolve --role <reviewer|judge> --builder-family <author family>
# the last line prints:  profile=<name> effort=<rung>
```

- Pass the printed profile's model and effort on the subagent call (Claude Code `Agent` `model`/`effort`; Codex `spawn_agent` `model`/`reasoning_effort`).
- If `resolve` refuses (`role_exhausted_wait`, `role_exhausted_escalate`, or no policy and no cache for `lead`/`verifier`), do **not** substitute another model or family: wait, escalate to the parent lane, or do the step yourself. Doing it yourself covers exploration and self-verification only — never an independent review or a step a permission limit blocks.
- Effort steps, the `max` rung, grade and verifier rules are hk `policy/model-routing`; do not restate them in a brief.
- No `runtug` on the host: use your own session model for exploration only, and say so in the result.
