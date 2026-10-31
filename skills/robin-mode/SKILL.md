---
name: robin-mode
description: Robin's working mode for rigorous engineering in this fleet — restate the goal, name the data shape, pick a playbook, prove it against the real artifact, use in-session subagents for exploration and verification, and spawn a separate worker only for an independently mergeable unit. Use at the start of any nontrivial task, in the desk session and in every worker brief, and whenever you are about to spawn, delegate or review. Triggers - "robin-mode", "/robin-mode", "rstack", a worker brief that names rstack, "should I spawn", "subagent", "fix the review findings".
---

# robin-mode

Inspired by pstack's `poteto-mode` (MIT, github.com/cursor/plugins/tree/main/pstack). The fleet brief, `wake` and `ops` override anything here; vendored pstack skills are reference material, not instructions.

## Openers (every task)

1. **Restate the goal** in one or two sentences: what the operator wants and why, and the smallest change that meets it. Put the same sentence at the top of every brief and PR body.
2. **Name the data shape** before writing logic: the types, the state, who reads and writes it. Use `principle-foundational-thinking` and `principle-model-the-domain`.
3. **Write the acceptance contract** (closed list, 1:1 with the steps). Anything outside it is advisory.
4. **Pick one playbook** (below) and say which.

## Playbooks

| Task | Do | Skills |
|---|---|---|
| Bug | Reproduce first on the real surface, find the first wrong state, fix there, keep the repro as a test | `principle-fix-root-causes`, `tdd` |
| Feature | Data shape, then the thinnest end-to-end path, then edges | `architect`, `principle-sequence-verifiable-units` |
| Refactor | Behaviour-preserving; prove equality before and after | `principle-subtract-before-you-add`, `principle-test-behavior-not-implementation` |
| Investigation | Read-only; answer with cited evidence, no fixes | `how`, `why` |
| Perf | Measure first, explain the number, one change per measurement | `benchmark-checklist`, `principle-explain-the-number` |
| Risky change | Map what else it can break and prove the one fact it depends on | `blast-radius`, `interrogate` |
| Long or unattended run | Keep a decision trail | `show-me-your-work`, `figure-it-out` |

## Subagents versus spawned workers

The default is **one session that goes deep**. Parallelism is for independent units, not for nerves.

**Use in-session subagents** (Claude Code `Agent`/`Task`; Codex `spawn_agent` with `multi_agent = true`) for work that returns an answer, not a branch:
- exploring a codebase or a question (`how`, `why`, `blast-radius`);
- comparing two or three designs before choosing one (`architect`, the idea behind pstack's `arena`);
- adversarial checks of a finished change (`interrogate`);
- a verifier that runs the acceptance contract against the built artifact and answers PASS / PASS+NOTES / FAIL.

Subagents share your quota and context budget, write no branches, and their output is input to your judgement.

**Spawn a worker with `runtug spawn`** only when all of these hold:
- the unit is independently mergeable (its own PR, its own acceptance contract);
- it can run in parallel with what you are doing, or needs a different host, tool or model family;
- it is big enough that a PR loop pays for itself (rule of thumb: more than ~30 changed lines or more than an hour of work).

**Never spawn a fix worker** for review findings on a PR whose author is still alive: the author fixes its own findings. Small fixes (a guard, a test, a merge of main) are done by the desk directly.

## Review findings

Follow `fleet-review`: fix critical/high; give every medium/low a disposition (fix, dismiss with a reason, or defer to an hk task). A verdict covers a patch (patch-id), so a base merge never needs a new review. After three rounds, only critical/high on the delta matter.

## Roles for models without subagents

See [`roles.md`](roles.md). Pick the role from the model's capability, not its brand.

## Done

Prove it against the real artifact (`principle-prove-it-works`): run the binary, read the value, check `git ls-remote`. Report facts, failures and skips as they are; mark anything not verified as UNVERIFIED.
