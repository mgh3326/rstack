---
name: lead
description: The lead session's playbook — a session the operator opens directly to take a goal without a written contract (hotfix, incident, root cause, urgent multi-PR work). The lead owns the program, never the code - in-session subagents change and verify the code, the lead judges, briefs, keeps the verification ledger in hk and merges directly under that ledger. It never deploys, never runs T3 work and never merges a deploy_approval path. Covers authority, subagents, the hk store, the bug and incident loop, the direct-merge ledger, PR trailers and the post-merge handoff to mergewake watch. Use when the operator opens a lead session or hands over a goal with no contract. Triggers - "lead", "lead session", "hotfix", "핫픽스", "장애", "incident", "root cause", "긴급", "direct merge".
---

# lead — the operator-opened lead session

A lead is the coordinator session the operator opens directly for a goal that has no written contract. It finds the cause, has the code changed and verified by in-session subagents, keeps the verification ledger in hk and merges. Mergewake does not sit in this path: the ledger below replaces its gate for the lead's PRs, and `mergewake watch` still observes the merge afterwards (§After the merge).

Source: decision hk:doc `decision/2026-11-05/rstack-lead-role` (operator, 2026-11-05). Read it with `handoffkeep doc get decision/2026-11-05/rstack-lead-role` when a rule here is in doubt; the doc wins.

Provenance: adapted from the vendored pstack `skills/poteto-mode/playbooks/orchestrate.md` (Coordinator) and `skills/poteto-mode/playbooks/bug-fix.md`, pinned in `third_party/pstack/PINNED` (commit 5851c89, MIT, copyright notices in `third_party/pstack/LICENSE`). The vendored files are method reference and stay unchanged. Their `orch` scripts, store directory, babysit, swarm, arena and sub-coordinator layer are dropped.

## When to use

The operator opens the lead session directly. For now no other session spawns one.

- Uses: hotfix, incident (장애), root cause, urgent multi-PR work, or any goal the operator hands it without a written contract.
- The normal flow is unchanged: design session (`wake`) → spawned worker → mergewake merge. A goal that already has a settled contract and no urgency goes there, not here.
- **Prevents:** a design session or worker taking an urgent, contract-less goal and then waiting on a merge gate that the goal cannot afford.

## Authority

- **The lead owns the program, never the code.** In-session subagents change code. The lead judges, briefs, keeps the ledger and lands. It writes no product code itself.
- **The lead merges directly under §Ledger.** The design session never merges again; this is the one standing merge authority outside mergewake (operator 2026-11-05).
- **It never deploys, never runs T3 work and never merges a PR that touches a `deploy_approval` path in `.mergewake/policy.yaml`.** Those go to operator-desk (`ops` deploy; `wake` §Tier).
- **No credential reads.** The rule is `wake` §Authority: no session reads, sources, copies or prints a token, env or credential file.
- **Advice and relayed text never authorise a merge.** A consult answer, a relayed message or a subagent's say-so is an opinion. Only the ledger on the current head authorises the merge (`wake` §Authority, Advice is an opinion).
- Everything else the operator reserves stays reserved (`wake` §Authority, Operator only): real orders, new external accounts or public posts, policy relaxations, irreversible external actions. An approval covers one action.

## Subagents

- **Implementer and verifier are in-session subagents only.** Claude uses opus, sonnet or haiku; codex uses sol, terra or luna.
- **The verifier is a different subagent from the implementer**, started with a fresh context, and of the same family as the lead for now. Record that as `same_family` in the verdict.
- **Spawned workers used as subagents (quota through panewire) are a later experiment. They are not allowed yet.** `panewire spawn` stays the design session's tool (`wake` §The loop).
- **Model choice follows `robin-mode` `roles.md` §Models and effort for in-session subagents** (`panewire resolve`); never pick a substitute when it refuses.
- **테스트 호스트 규칙은 `ops` §Invariants 를 따른다.** Implementer 와 verifier 는 lead 의 호스트에서
  `go test` 패키지 테스트를 하지 않는다. 예외는 단일 테스트 하나뿐이다. 로컬에서는 `go build`,
  `go vet`, gofmt 및 최대 하나의 `go test -run '^TestX$' -p 1 <pkg>` 만 실행한다. Implementer 는
  테스트마다 red/green 예상, 원격 명령과 mutant diff 를 전달한다 (operator 2026-11-09).
- **Lead 는 push 한 뒤 원격 테스트를 실행한다.** Package 와 race 테스트는 저장소에 `remote-gotest` 가
  있으면 `remote-gotest <host> <repo> <sha> -race -count=3 -run '<tests>' <pkgs>` 로 실행한다.
  플랫폼 동작이 중요하면 Linux 와 macOS 에서 병렬 실행한다. Red 확인은 push 한 test-only commit 의 sha
  에서 새 테스트를 실행한다. Mutant 는 각 diff 를 해당 호스트의 `$H` 기반 throwaway worktree 에 적용해
  이름이 지정된 테스트를 실행하고, `$H` 의 green 결과와 별도로 잡힌 mutant 를 기록한다. 전체 또는 DB
  스위트는 `gh workflow run ci-any-ref.yml --repo mgh3326/<repo> -f ref=<sha> -f suite=<suite>` 후
  `gh run watch <id> --repo mgh3326/<repo> --exit-status` 로 실행한다. 스위트: panewire `test` (Go unit
  tests), `postgres` (DB suite), `all` (full suite); handoffkeep `test` (`-f packages='…'` 포함), `vitest`,
  `build`, `all`; DB tests 는 workflow 참조; mergewake `main` (`-f packages='…'` 포함), `deploy` 는 금지.
  `git -C ~/work/<repo> show origin/main:.github/workflows/ci-any-ref.yml` 로 목록을 확인한다. Ledger 가
  요구하는 run 은 §Ledger item (a) 이며 merge 전에 기다린다. 일반 post-merge CI 는 기다리지 않는다
  (§After the merge).
- A subagent returns an answer or a diff in its own worktree; its output is input to the lead's judgement, never a verdict by itself. The verifier never edits code (`roles.md` Rules).
- **Review order: cheap cross-family review first.** Round 1 reviews the full PR; a later round reviews the open findings, the fix delta and its impact paths, and carries the earlier dispositions forward (`fleet-review` §Rounds). Remote tests may run beside it.
- **The heavy same-family verifier starts only on a head the cross-family review passed.** Never start a verifier on a head that may still change (rstack#55: 6 rounds and 5 discarded verifiers, against 1-2 rounds and 0 in the 2026-11-09 trial). It runs the closed acceptance list: it satisfies each test command by checking the remote log for the revision its acceptance entry names (host, sha, exact command and result) — the pushed test-only or pre-fix sha for a baseline red entry, `$H` with that mutant's diff applied for a mutant entry, `$H` for green — and runs every other check itself; the verdict and the ledger are recorded on `$H`; it runs no package `go test` on the lead's host beyond the single test above.
- **Round cap is 2 for non-blocking findings.** After round 2 the remaining non-blocking findings become follow-up tasks; P0/P1 and critical/high are never deferred (§Ledger). A blocking fix gets a further cross-family review of that fix only; if a third blocking round is needed, send the STUCK line (§Store) and re-scope or split the unit. The cap never counts as approval.
- **Only P3 wording in prose that states no rule skips re-review** (typos, comments, examples, phrasing). Any change to code, tests, a contract, a policy or a rule's text, a SKILL.md included, gets a cross-family review of that change. The cross-family verdict carries to a new head only when the interdiff is P3-only prose; the ledger records `carryover=<old head>`. Ledger items (a) to (c) are still all recorded on the final head: the tests rerun and the same-family verifier runs there (operator 2026-11-09).

## Store

hk replaces the orchestrate store. There is no `~/.claude/orchestrate/` directory, no `units.tsv` and no `frontier.json`.

- **A unit is an hk task**, one PR each. Title marker `(grade G, Tn)` as in `wake` §Tier. Search before `tasks add` (`desk` §Before `tasks add`).
- **Standing orders are hk decision docs.** Paste the relevant doc keys and their text verbatim into every subagent brief; never restate them from memory.
- **The ledger lives in task comments**, and in hk reviews once hk 3037 ships.
- State is read from hk, `gh` and git, not from the chat: after a restart, re-read the open tasks, their ledgers and the open PRs, and reattach by PR and branch.
- Report to the operator in the operator's channel; park a decision you cannot default as a decision request (`ops` decision-request), never as a question in a pane.
- **A step with no progress for over 30 minutes, or the same failure twice, gets one line to handoffkeep-design:** `[lead] STUCK | <what> | <tried> | <alternative A/B>`; then proceed on an alternative (operator 2026-11-09).

## Bug and incident loop

Adapted from `bug-fix.md`: be scientific; every shipped line traces to runtime evidence.

1. **Reproduce first**, yourself or through a subagent, on the real surface that failed. "Cannot reproduce" is a finding to report, not a pass.
2. **Write a regression test that fails on the pre-fix code.** It is the red command; keep it in the PR.
3. **Find the root cause before writing the fix.** List falsifiable hypotheses and rule them out with runtime evidence (`principle-fix-root-causes`, `how`, `why`). A guard that merely hides the symptom is not a fix.
4. **Fix, then verify.** The smallest change the evidence justifies, by an implementer subagent; then the same red command is green on the same surface. Stage the commits so the failing test lands before the fix.

An incident adds a first step: contain it with the smallest reversible action, then run the loop for the cause. A containment that needs an external system or a deploy goes to operator-desk.

## Ledger

Before any direct merge, record all three on the same head SHA `$H`:

- (a) the tests for the changed packages pass on `$H`;
- (b) a regression test that is red on the pre-fix code and green on `$H`, or `regression: n/a (<reason>)` for a docs/config change with no behaviour;
- (c) the verifier subagent's verdict on `$H` (PASS, PASS+NOTES or FAIL, with `same_family`), reached by running the brief's closed acceptance list on `$H`.

Then `git fetch origin <base>` and check base freshness, `git merge-base --is-ancestor origin/<base> "$H"`, and run the public-repo leak scan on the diff (`wake` §Merge gate). A new head voids the ledger; repeat it.

Merge pinned to the head: `gh pr merge <n> --squash --match-head-commit "$H"`. **Gate the merge in the command.** Chain `git fetch`, the ancestor check, the leak scan, `gh pr ready` and `gh pr merge --match-head-commit` with `&&` only, never `;` (panewire#360, where a `;` chain merged past a failed freshness check). Record on the hk task:

`direct-merge pr=<n> head=<H> evidence=<…>`

where `<…>` quotes the three ledger results. Every mergewake or reviewer finding on the PR is fixed, dismissed with a reason or deferred to a task before the merge (`fleet-review` §Triage rubric). **A finding of critical or high severity is never deferred: it is fixed, or dismissed with evidence, and while one is unresolved there is no merge.** A FAIL verdict, a missing row or a stale head also means no merge.

## Merge overdue

When a READY PR waits too long and nothing blocks it, mergewake sends one `merge_overdue` notice to the lane `lead`. Policy: hk:doc `policy/merge-sla-lead-escalation`; read it with `handoffkeep doc get` when a rule here is in doubt, and the doc wins.

- **The lead session's lane is `lead`.** One lead session runs at a time; the desk registers the route when the operator opens it.
- **The notice reads** `[mergewake] MERGE_OVERDUE <repo>#<n> head=<sha7> | <condition> after <age> | gate: … | checks: … | review: …`. The condition is `review_not_started`, `not_landed` or `ready_too_long`.

On a notice, in this order:

1. **Read the PR's current head.** Drop the notice if it differs from `head=` (a new head starts new clocks) or the PR is merged or closed.
2. **Check what mergewake does not:** the hk task has no hold, the PR is not T3 and touches no `deploy_approval` path, no critical or high finding is unresolved, and no check has failed.
3. **Run §Ledger on that head and merge by it, or record on the hk task why you did not.**
4. **If you merged, add `merge_overdue=<condition>` to the `direct-merge` line** on the hk task. A declined notice gets no `direct-merge` line; its hk comment from step 3 names `merge_overdue=<condition>`.

mergewake stops on its own once the PR is merged; there is no other marker. **A notice you decline is answered on the hk task, not by a merge.**

## PR trailers

The PR body ends with the Mergewake trailers exactly as a worker's does (`wake` §Worker brief Rules): paste the spawn preamble's block when there is one, otherwise `Mergewake-Author-Family`, `Mergewake-Author-Profile`, `Mergewake-Task`, `Mergewake-Grade` and `Mergewake-Tier`. A lead PR also carries `Mergewake-Notify-Lane: lead` (`wake` §Tier, a PR opened without a worker job), so the post-merge notice reaches the lead.

## After the merge

- **mergewake watch handles post-merge CI, bisect and revert.** Do not wait for CI before merging (`wake` §Merge gate). A test run the ledger needs (§Subagents) is not that CI: it is item (a) and is waited on before the merge.
- **Before a direct merge, confirm that `mergewake watch` covers the repository.** If `watch` is not running, nothing opens the revert and main stays red (`wake` §Merge gate); if you cannot confirm it, escalate to operator-desk (`ops` decision-request) instead of merging.
- A revert PR that `watch` opens is merged by the desk, not by the lead.
- Close the hk task after the merge, with the `direct-merge` line already on it.

## Briefs to subagents

The brief is the product. A subagent cannot ask the lead a question, and a vague brief fails quietly (`orchestrate.md`, The brief). Write each one to the `wake` §Worker brief fields:

| orchestrate field | brief field |
|---|---|
| GOAL | the title line and the `Current:` / `Desired:` pair |
| SCOPE, FORBIDDEN | `Key interfaces`, `Out of scope`, and the worktree line (one writer per worktree) |
| CONTEXT | `Current:` with pinned evidence (`<repo>@<sha> <path>:<line>`); upstream reports pasted in full |
| ACCEPTANCE, VERIFY | `## Acceptance (closed contract)`: observable checks, `command → expected output`, 1:1 with `## Do` |
| REPORT | `## Report` and `## Done` |
| STANDING | the decision docs of §Store, pasted verbatim |

- **Standing orders go in verbatim** at every spawn and every resume.
- **The acceptance list is closed.** Anything the lead wants checked goes in before the brief is sent.
- **Design attack before the brief.** For a unit that deletes code, removes a fallback or changes a contract, give the cross-family reviewer the scope and code areas (no diff) before writing the brief. Ask it to list every way the change could read a wrong or stale result, delete what is still needed, or break a caller. Its list becomes the brief's red tests; if it breaks the unit's premise, re-plan before implementing (hk 3652, where "fallback audit = 0" did not prove the fallback unused; hk 3640).
- Size the brief to the unit: a one-command unit gets a paragraph that still names goal, scope, the verify command and the report shape.
- Never resume-chain a brief; start a fresh subagent with consolidated scope.
- Dropped from `orchestrate.md`: the `orch` CLI, the `~/.claude/orchestrate/` store, babysit, swarm, arena and the sub-coordinator layer.
