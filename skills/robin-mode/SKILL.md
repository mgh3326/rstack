---
name: robin-mode
description: Robin's working mode for rigorous engineering in this fleet — restate the goal, name the data shape, pick a playbook, prove it against the real artifact, verify your own work (alone or with in-session subagents), and spawn a separate worker only for an independently mergeable unit. Also the map of where each fleet rule lives and the one adapter for vendored pstack skills. Use at the start of any nontrivial task, in the desk session and in every worker brief, and whenever you are about to spawn, delegate or review. Triggers - "robin-mode", "/robin-mode", "rstack", a worker brief that names rstack, "should I spawn", "subagent", "pstack".
---

# robin-mode

Inspired by pstack's `poteto-mode` (MIT, github.com/cursor/plugins/tree/main/pstack). This skill is the author's method: how to think, build and verify. Every other kind of decision has one home of its own (§Where each rule lives).

## Where each rule lives

Each rule is stated once, in the home below; other documents point to it. Inside the operator's and the brief's scope, each home decides its own row. If two homes conflict, report the conflict — do not pick one silently. A consult answer changes none of them.

| Decision | Home |
|---|---|
| Goal, data shape, playbook, self-verification, subagent versus worker, work boundary, the pstack adapter | this skill |
| PR, author and merge ownership, tier (T), hand-off, READY and what it carries, deploy authority | `wake` (rstack) |
| Finding scope, severity, disposition, review rounds, review evidence reuse, reviewer independence | `fleet-review` (rstack); mergewake enforces it |
| Spawn, relay, consult, wait, reap and deploy mechanics | `ops` (rstack) |
| Desk coordination: commitments, resume order, task intake, delegation threshold, task record | `desk` (rstack) |
| Closing a design session: open-point closure, tickets into hk, the handoff doc, desk intake of a `[handoff]` event | `handoff` (rstack) |
| Which profile, family and effort a role may use; where grade applies | hk `policy/model-routing`, applied by `panewire resolve` and `panewire spawn` |
| Pool spending order, quota waits and hand-over | hk `policy/quota-stop` |

## Openers (every task)

1. **Restate the goal** in one or two sentences: what the operator wants and why, and the smallest change that meets it. Put the same sentence at the top of every brief and PR body. If the evidence rules out the requested change, show it and stop (ESC).
2. **Name the data shape** before writing logic: the types, the state, who reads and writes it. Use `principle-foundational-thinking` and `principle-model-the-domain`.
3. **Write the acceptance contract** (closed list, 1:1 with the steps). Findings are judged against it by `fleet-review` §Closed contract.
4. **Pick one playbook** (below) and say which.

## Playbooks

| Task | Do | Skills |
|---|---|---|
| Bug | Reproduce first on the real surface, find the first wrong state, fix there, keep the repro as a test | `principle-fix-root-causes`, `tdd` |
| Feature | Data shape, then the thinnest end-to-end path, then edges | `architect`, `principle-sequence-verifiable-units` |
| Refactor | Behaviour-preserving; prove equality before and after. If it moves or replaces existing checks, submit the preservation table (`wake` §READY) | `principle-subtract-before-you-add`, `principle-test-behavior-not-implementation` |
| Investigation | Read-only; answer with cited evidence, no fixes | `how`, `why` |
| Perf | Measure first, explain the number, one change per measurement | `benchmark-checklist`, `principle-explain-the-number` |
| Risky change | Map what else it can break and prove the one fact it depends on | `blast-radius`, `interrogate` |
| Long or unattended run | Keep a decision trail | `show-me-your-work`, `figure-it-out` |

## Work boundary

A request has one accountable owner. A separate worker exists only for a PR that is accepted and merged on its own, and a child never repeats its lead's triage. A coordinating task may own several PRs; an implementation task owns exactly one. When a hand-off is accepted and when it ends is `wake` §READY.

## Subagents versus spawned workers

The default is **one session that goes deep**. Parallelism is for independent units, not for nerves.

**Use in-session subagents** (Claude Code `Agent`/`Task`; Codex `spawn_agent` with `multi_agent = true`) for work that returns an answer, not a branch:
- exploring a codebase or a question (`how`, `why`, `blast-radius`);
- comparing two or three designs before choosing one (`architect`, the idea behind pstack's `arena`);
- adversarial checks of a finished change (`interrogate`);
- a verifier that runs the acceptance contract against the built artifact and answers PASS / PASS+NOTES / FAIL.

Subagents share your quota and context budget, write no branches, and their output is input to your judgement.

**The author verifies its own acceptance**, alone or through in-session subagents (or a delegate). That evidence is the author's and never replaces independent review (`fleet-review` §Independence). A separate verifier step is not a required path for every PR, and the tier sets risk and permissions, not which process runs the tests. Work that writes uses an isolated worktree or one clear writer.

**Spawn a worker with `panewire spawn`** only when all of these hold:
- the unit is independently mergeable (its own PR, its own acceptance contract);
- it can run in parallel with what you are doing, or needs a different host, tool or model family;
- a PR loop pays for itself (a cost hint, not a rule: roughly more than ~30 changed lines or an hour of work).

Review findings go back to the PR's current author (`wake` §READY), never to a new worker while that author is alive.

## Review findings

Triage by `fleet-review`.

## Fleet adapter for vendored pstack

The brief, host safety, `wake` authority and `fleet-review` govern fleet work. Vendored pstack is method reference. This adapter covers the conflicts enumerated in `third_party/pstack/REVIEW.md`:

1. **Autonomy and external actions:** use only the brief's authorised tools and scope. `principle-never-block-on-the-human` permits reversible work within that scope. Merge, deploy and data migration are irreversible actions requiring the authority in `wake`; a worker never merges or arms auto-merge.
2. **Unattended sessions:** "going to bed" grants no new authority. Stop for an unsafe decision.
3. **Subagents:** follow §Subagents versus spawned workers. Missing `pstack:comment-sicko` is not an available agent: for `no-comments`, review inline and report that substitution. Never launch a missing upstream executable.
4. **Models:** ignore all pstack Models sections, model slugs, `pstack-models.md` and `/setup-pstack`. Use `panewire resolve` and `roles.md`.
5. **Landing:** only the repo session merges after the gate. No babysit, swarm or arena routing; robin-mode is not babysit/swarm/arena.
6. **Waves:** a wave is a series of independently green PRs, never stacked PRs. Rebase only before the first push; thereafter merge the base, never force-push. Candidate worktrees belong in scratch, outside canonical checkouts and skill discovery roots.
7. **Review ownership:** the author handles its own findings. `fleet-review` decides scope, severity, disposition and independence; `interrogate` and `blast-radius` supply analysis without replacing the review gate.
8. **Waits:** no polling, watchers or autonomous loops from pstack. Use `ops` waiting procedures.
9. **Questions:** every "ask the user", AskUserQuestion or confirmation in interrogate, reflect, no-comments and verification skills becomes an `ops` decision ESC event with question, options and default. Continue only with a safe default.
10. **Transcripts and missing scripts:** do not audit real agent transcripts or configuration. `show-me-your-work` uses a local TSV decision trail without its missing log.sh or transcript audit. `recall` uses supplied evidence, not transcript search. `reflect` uses the active supplied conversation only; its node scripts are absent. `statechart` may sketch a diagram but must report model checking UNVERIFIED because its compiler is absent. Never imply an omitted check ran.
11. **Cleanup:** mergewake owns post-merge branch/worktree cleanup; upstream cleanup playbooks grant no authority.
12. **Host safety:** no local database servers; run changed tests only, leave full suites to CI, and stop only the PIDs you started. Verification skills and benchmarks inherit these limits.
13. **Sources:** `why` may query only brief-authorised services. Report unavailable evidence as a gap.
14. **Reply format:** use the openers here; naming every pstack principle is optional, never a review gate.

`install/sets.json` defines harness roles and the worker subset. `third_party/pstack/INSTALL` is the full vendored allowlist. The vendor checkout must live outside every harness's scanned skill directories. Relative links into excluded skills are reference material and do not install them.

## Roles for models without subagents

See [`roles.md`](roles.md). Pick the role from the harness's capability, not its brand.

## Bug playbook

1. Reproduce the bug and identify one deterministic, fast command that can fail on the bug
   before changing code. If no such command is available, stop and emit ESC with the missing
   evidence and a proposed safe default.
2. Write three to five falsifiable hypotheses, each with the observation that would rule it
   out. Check them against code and the red command; do not edit until one cause is supported.
3. Add or refine the regression check, confirm the red command fails for the bug, make the
   smallest fix, and confirm the same command passes. Then check nearby behavior and report the
   evidence. Questions that require an owner decision become an ESC to the parent.

Adapted from mattpocock/skills `engineering/diagnosing-bugs` (MIT, copyright Matthew Pocock):
red-command gate and falsifiable hypotheses. https://github.com/mattpocock/skills

## Done

Prove it against the real artifact (`principle-prove-it-works`): run the changed thing the way its user runs it — the real binary, script, install dry-run or rendered file — not only a unit test or the diff. Quote the command and its output, and check `git ls-remote`. If the real artifact cannot run in this environment, say UNVERIFIED rather than substituting a mock. Report facts, failures and skips as they are.
