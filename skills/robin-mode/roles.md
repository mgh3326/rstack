# Roles by capability

A role is what a session is asked to do. Pick it from the harness's capabilities, never from a model brand. Which profiles, families and effort a role may use is hk `policy/model-routing`, applied by `panewire`; this file keeps no model or harness table.

| Capability | Roles it can take |
|---|---|
| In-session subagents | **Lead**: the session the operator opens directly, following the `lead` skill. Takes a goal without a written contract, writes the closed contract for its in-session subagents, uses in-session subagents only, and merges directly under `lead` §Ledger. **Design**: operator-run design session, same model rules as lead. **fleet-policy**: operator-opened session that settles cross-repo policy, runs bounded catalog experiments and keeps catalog records (`fleet-policy` §Authority, §Experiments and §Records). **Consult**: design and strategy advice. **Desk**: coordination with the operator, deploy orders, decisions (`desk`). |
| No subagents, strong coder | **Implementer**: builds one PR from a written contract (Current, Desired, Key interfaces, Acceptance), verifies it, and fixes its own review findings until merge. **Reviewer**: one mergewake review pass. |
| One-turn (stops after its first turn) | **Explorer** and **Consult** only, whatever else it can do. |

## Rules

- **The closed contract decides the line.** A design session (with the operator) or a lead (opened by the operator, following the `lead` skill) writes the closed contract: Current, Desired, Key interfaces and Acceptance.
- **Implementer:** builds exactly one PR from a written contract, verifies it (in-session subagents allowed), and fixes its own review findings until merge.
- **Lead:** the session the operator opens directly, following the `lead` skill. It takes a goal without a contract, writes the closed contract for its in-session subagents, uses in-session subagents only, and merges directly under `lead` §Ledger.
- **A hard single PR is an implementer with a higher grade, not a lead.** There is no separate fixer role: the PR's author fixes its findings.
- **Vocabulary:** seat roles are lead, implementer, reviewer, consult and design. Explorer, verifier and judge are resolve-only: they name an in-session subagent's `panewire resolve` role (below), never a spawned seat. No reader, tester or delegate role exists.
- **Verifier:** runs the acceptance list against the built artifact and answers PASS / PASS+NOTES / FAIL, with no fixing and no free bug hunting.
- **Leads and implementers must run on harnesses that keep going across turns**, until READY or ESC, with nobody pressing continue. **One-turn profiles may take explorer and consult roles only.** On 2026-11-03 a one-turn profile routed to implementation stopped after its first turn on every attempt. A worker that stops this way goes through `ops` spawn §4-3.
- A lead uses in-session subagents only, as `lead` §Subagents specifies; it never delegates or spawns workers.
- An implementer gets a brief whose design is already decided (data shape, files, acceptance). If the brief needs a design choice, it escalates instead of guessing.
- Whether a review pass counts as independent: `fleet-review` §Independence.
- A verifier never edits code. Whether its verdict carries over to a later head: `fleet-review` §A verdict covers a patch, not a SHA.
- A brief may state the role and a required capability (`--tags`), not a model.

## Enabling subagents

- Claude Code: built in.
- Codex: add `[features]` `multi_agent = true` to `~/.codex/config.toml` (host config change; done by operator-desk per host).

## Models and effort for in-session subagents

In-session subagents take their model from the same routing policy `panewire` enforces for spawned workers, through one call, so a lead, its subagents and its spawned workers never disagree:

```sh
panewire resolve --role <implementer|explorer|verifier> --grade <G> --t <Tn>
panewire resolve --role <reviewer|judge> --builder-family <author family>
# the last line prints:  profile=<name> effort=<rung>
```

- Pass the printed profile's model and effort on the subagent call (Claude Code `Agent` `model`/`effort`; Codex `spawn_agent` `model`/`reasoning_effort`).
- A lead has no routing role: the operator opens the lead session, and its subagents resolve as implementer, explorer or verifier.
- If `resolve` refuses (`role_exhausted_wait`, `role_exhausted_escalate`, or no policy and no cache for `consult`/`verifier` or a lead's implementer/explorer subagent), do **not** pick a substitute model or family for the subagent. What to do depends on the role:
  - `consult`, `verifier`: do not start that work on any other model. Wait on `role_exhausted_wait`; escalate to the parent lane on `role_exhausted_escalate` or a missing policy.
  - For a lead's implementer or explorer subagent, wait on `role_exhausted_wait` or escalate to the parent lane on `role_exhausted_escalate` or a missing policy; a lead never writes product code because a subagent resolution refused.
  - `reviewer`, `judge`: escalate. Never do it yourself — your own check is not independent.
  - `explorer`, `implementer`: the one allowed fallback is your own session (no new model choice); do the step there and say so in the result. This fallback does not apply to a lead: a lead writes product code only for a small hotfix within the threshold in `lead` §Authority, and otherwise an implementer subagent does.
- Effort steps, the `max` rung, grade and verifier rules are hk `policy/model-routing`; do not restate them in a brief.
- No `panewire` on the host: use your own session model for exploration only, and say so in the result.
