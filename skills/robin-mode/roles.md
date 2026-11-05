# Roles by capability

A role is what a session is asked to do. Pick it from the harness's capabilities, never from a model brand. Which profiles, families and effort a role may use is hk `policy/model-routing`, applied by `panewire`; this file keeps no model or harness table.

| Capability | Roles it can take |
|---|---|
| In-session subagents | **Lead**: takes a goal without a written contract, compares designs, slices tickets, writes briefs, spawns and owns implementers, escalates policy choices. **Design**: operator-run design session, same model rules as lead. **Consult**: design and strategy advice. **Desk**: coordination with the operator, deploy orders, decisions (`desk`). |
| No subagents, strong coder | **Implementer**: builds one PR from a written contract (Current, Desired, Key interfaces, Acceptance), verifies it, and fixes its own review findings until merge. **Reviewer**: one mergewake review pass. |
| One-turn (stops after its first turn) | **Explorer** and **Consult** only, whatever else it can do. |

## Rules

- **The closed contract decides the line.** A design session (with the operator) or a lead (delegated, without the operator) writes the closed contract: Current, Desired, Key interfaces and Acceptance.
- **Implementer:** builds exactly one PR from a written contract, verifies it (in-session subagents allowed), and fixes its own review findings until merge.
- **Lead:** takes a goal without a contract. It compares designs, slices tickets, writes briefs, spawns and owns implementers, and escalates policy choices.
- **A hard single PR is an implementer with a higher grade, not a lead.** There is no separate fixer role: the PR's author fixes its findings.
- **Vocabulary:** seat roles are lead, implementer, reviewer, consult and design. Explorer, verifier and judge are resolve-only: they name an in-session subagent's `panewire resolve` role (below), never a spawned seat. No reader, tester or delegate role exists. `worker`, `builder` and `counsel` are `panewire spawn --role` flag values, not seat roles (§Spawn flags).
- **Verifier:** runs the acceptance list against the built artifact and answers PASS / PASS+NOTES / FAIL, with no fixing and no free bug hunting.
- **Leads and implementers must run on harnesses that keep going across turns**, until READY or ESC, with nobody pressing continue. **One-turn profiles may take explorer and consult roles only.** On 2026-11-03 a one-turn profile routed to implementation stopped after its first turn on every attempt. A worker that stops this way goes through `ops` spawn §4-3.
- A lead's every report carries a `next unit:` line (`ops` reap §6-2). A lead whose last report names a unit is not closed.
- A lead delegates and spawns under `robin-mode` §Subagents versus spawned workers.
- An implementer gets a brief whose design is already decided (data shape, files, acceptance). If the brief needs a design choice, it escalates instead of guessing.
- Whether a review pass counts as independent: `fleet-review` §Independence.
- A verifier never edits code. Whether its verdict carries over to a later head: `fleet-review` §A verdict covers a patch, not a SHA.
- A brief may state the role and a required capability (`--tags`), not a model.

## Spawn flags

The seat role decides the `panewire spawn` flags; the flags carry no other meaning.

| Seat role | `panewire spawn` | Home |
|---|---|---|
| Implementer (worker) | `--role worker --owner <parent lane>` | `wake` §The loop, `ops` spawn |
| Lead delegated for one PR (delegated seat) | `--role builder --lane <seat lane> --parent <parent lane>` | `wake` §Delegated seat |
| Consult | `--role counsel --routing-role consult` | `ops` consult |
| Reviewer | not spawned by a session; mergewake runs review passes | `fleet-review` |

## Enabling subagents

- Claude Code: built in.
- Codex: add `[features]` `multi_agent = true` to `~/.codex/config.toml` (host config change; done by operator-desk per host).

## Models and effort for in-session subagents

In-session subagents take their model from the same routing policy `panewire` enforces for spawned workers, through one call, so a lead, its subagents and its spawned workers never disagree:

```sh
panewire resolve --role lead                                   # lead and consult take no --grade
panewire resolve --role <implementer|explorer|verifier> --grade <G> --t <Tn>
panewire resolve --role <reviewer|judge> --builder-family <author family>
# the last line prints:  profile=<name> effort=<rung>
```

- Pass the printed profile's model and effort on the subagent call (Claude Code `Agent` `model`/`effort`; Codex `spawn_agent` `model`/`reasoning_effort`).
- If `resolve` refuses (`role_exhausted_wait`, `role_exhausted_escalate`, or no policy and no cache for `lead`/`verifier`), do **not** pick a substitute model or family for the subagent. What to do depends on the role:
  - `lead`, `consult`, `verifier`: do not start that work on any other model. Wait on `role_exhausted_wait`; escalate to the parent lane on `role_exhausted_escalate` or a missing policy.
  - `reviewer`, `judge`: escalate. Never do it yourself — your own check is not independent.
  - `explorer`, `implementer`: the one allowed fallback is your own session (no new model choice); do the step there and say so in the result.
- Effort steps, the `max` rung, grade and verifier rules are hk `policy/model-routing`; do not restate them in a brief.
- No `panewire` on the host: use your own session model for exploration only, and say so in the result.
