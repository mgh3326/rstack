---
name: desk
description: The desk session's method for coordinating the fleet with the operator — record a commitment in hk before promising it, rebuild state in a fixed resume order after a start or compaction, search before `tasks add`, delegate investigation, stop after one spawn-failure fix, resolve chat answers in hk in the same turn, and keep one stage and one waiting-on on every open task. Use in the desk or coordinator session, at every reply that promises future work, after a restart or compaction, before creating a task, on a spawn failure, and when an operator answer arrives. Triggers - "desk", "데스크", "commitment", "I will", "하겠습니다", "resume", "compaction", "컴팩션", "이어서", "tasks add", "spawn failed", "decision backlog", "결정 정리".
---

# desk — coordinating the fleet with the operator

The desk coordinates. It judges intent, runs gates, orders deploys and carries the operator's
decisions (`wake` §Authority). Its context window is a bounded cache; hk, panewire and GitHub are
the record.

These rules are method, not enforcement: you apply them at fixed points (the end of a reply,
resume, before `tasks add`, a spawn failure, an operator answer), and no hook applies them for you.
Each section names the failure it prevents.
`<desk lane>` below is the lane this session runs as.

## Commitments

A commitment is any sentence that makes you or another lane owe a future action: "I will",
"next", "after X", "retry", "later", "다음에", "하겠습니다". A review you are waiting for counts.
Work you finish in this turn does not.

**Before you say "I will X", record it in hk.** Use a task, or a sub-task of the task it belongs
to once hk sub-tasks exist. Until then, use a task comment on the parent:

```sh
handoffkeep tasks comment <parent-id> --body 'next: <one concrete action>
owner: <lane that will do it>
trigger: <event | PR state | resume check | date>'
```

**Put the hk id in the sentence:** "I will retry the experiment (hk 1234, trigger: node restart
done)." A commitment sentence with no id is a defect; fix it before you send the reply.

**Every reply that makes promises ends with a `Commitments:` line listing ids:**
`Commitments: hk 1234, hk 1240`.

**Prevents:** promises made only in chat were lost: a retry, a fix worker, and a review left waiting
for hours.

## Resume

After a start or compaction, read in this order before you act on anything you remember:

1. `date '+%F %T %Z'` — every later line is judged against this time.
2. hk tasks with a next action — `handoffkeep tasks export --lane <desk lane> --state <state> --limit 5000`
   for each open state, and `handoffkeep tasks comments <id>` for the latest `next:` lines.
3. Open decisions — the console Decisions view, `handoffkeep tasks export --state needs_decision`,
   and decision items in the inbox (§Decisions).
4. Inbox READY/ESC — `panewire inbox list --lane <desk lane> --json`. Read every item since the last
   resume, not only unread ones: a READY can arrive during a long turn and go unnoticed.
5. Live jobs — `panewire jobs list --lane <desk lane> --json`, then each live job's pane state.
6. PRs awaiting gate — each PR named on a task or a READY:
   `gh pr view <url> --json state,headRefOid,reviewDecision` and `gh pr checks <url>`.

Once hk serves the desk ledger (hk 2773), the order becomes `handoffkeep ledger`. That command does
not exist yet.

Local agent memory is not the source of truth; hk is (hk 2781). Do not repeat an outside action you
recall (spawn, merge, deploy, comment) until steps 2–6 show what happened to it. Keep operating rules
in this skill, not in a memory index.

**Prevents:** the desk lost context across compactions and continued from whatever its summary kept.
Its newest lessons also sat past the load limit of its memory index, so a lesson it had already
written down was repeated.

## Before `tasks add`

Search open and recent tasks first:

```sh
for s in backlog claimed in_progress hold needs_decision verifying join reopened merged dropped; do
  handoffkeep tasks export --state "$s" --limit 5000
done | jq -r '.tasks[] | select(.title | test("<keyword>"; "i")) | "\(.id) \(.state) \(.updated_at[:10]) \(.title)"'
```

- A match covers the work: comment on it (§Commitments). Do not create a task.
- A similar subject that is really different: create it, and name the other task and why it differs in
  the first comment.
- **A retry is a new attempt on the same task, never a new task.** The same holds for a re-spawn, a
  second host or a changed brief.

**Prevents:** duplicate tasks for one piece of work, and about a dozen junk tasks from retries.

## Delegation threshold

**Investigation that needs more than about 3 tool calls goes to a worker or a background subagent,
with the result written to an hk doc** (`handoffkeep doc put --key research/<date>/<slug> --file <path>`).
Read the doc, not the raw evidence, and judge from there.

The desk keeps deploy orders, operator decisions, spawn-failure handling and revert merges. mergewake
reviews and merges PRs, and design sessions spawn their own workers (`wake`). If a problem is inside a
tool, its fix belongs to that tool's task (§Spawn failure).

**Prevents:** the desk debugged spawn failures itself for an hour, on guessed causes, while everything
else it owed waited.

## Spawn failure

On `SPAWN_FAILED`, a non-zero exit, or no landing evidence (`ops` spawn §4-2):

1. Read the exit code, stage, reason and saved pane screen in the job directory once.
2. Make **one fix attempt on the same task**, and only for a cause you can name.
3. **If it still fails, file a task against the tool and stop.** Put the evidence paths on that task.
   Comment on the blocked task: `next:` to resume it, `trigger: hk <tool task> merged`.

**No host or model hopping, and no new task per attempt.** Another host or model hides the failure.

A network retry that replays the same saved request is not a fix attempt; it reuses the reservation
(`ops` spawn). Never launch around an unconfirmed attempt.

**Prevents:** an hour of host and model changes against a login screen that no re-spawn could fix,
with a new task minted per attempt.

## Decisions

The loop is `ops` decision-request §데스크 결정 루프. At the desk it comes down to three rules:

- **An answer given in chat is resolved in hk in the same turn**, before you act on it.
- **Asking again reuses the same request.** Never open a second one for the same question.
- **Open requests are reviewed at resume** (§Resume step 3), and each one gets a disposition.

**Prevents:** about 120 decision requests piled up, because questions went out as free text and
answers given in chat were never written back.

## Facts

Design sessions read only hk (`wake` §Settle before spawning), so a fact that is not in hk does not
exist for them.

**When the desk learns a fact that changes an hk task — a fix applied, a workaround, a respawn under a
new task — it comments the fact on every affected task in the same turn:**

```sh
handoffkeep tasks comment <id> --body '<the fact>'
```

For a respawn, name the new task id on the old task and the old task id on the new one.

§Before `tasks add` keeps a respawn on the same task; this covers one that already exists under a new task
(for example hk 2900 respawned as hk 2905): do not open another task for it, only record it on both.

**A brief the desk writes is put in hk at `brief/<date>/<job>` before the spawn**, as `wake` §The loop
step 3 does for a design session:

```sh
handoffkeep doc put --key brief/<date>/<job> --kind note --file <brief>
```

**Prevents:** design sessions read only hk, so a fix, workaround or respawn the desk knew of but did
not record was invisible to them.

## Task record

**Every open task has one stage and one waiting-on.** Until hk has the fields (hk 2771), they live in
the task's latest `next:` comment. Read the table top-down; the first match wins.

| Stage | Waiting on | The comment names |
|---|---|---|
| decision | the operator | `decision: <request_id>` |
| review | a reviewer or the gate | `pr: <url>` and `trigger: review posted` or `trigger: checks done` |
| working | a job | `job: <id>` and `owner: <lane>` |
| queued | a trigger | `trigger: <event, PR state or date>` |
| parked | nobody | `reason:` and `revisit: <date>` |

A task that fits no row gets fixed or dropped at the next resume. "Later" with no trigger is not a
stage.

**Prevents:** open tasks with no next action and nobody named to act, so nothing surfaced them again.

## Time

**Clock times in records come only from `date` or the server.** The command forms are in `ops`
§Invariants. If you do not have the time from one of those two sources, write `time unknown`.

**Prevents:** estimated clock times were written into records and later read as fact.

## Containment

A containment is an operational stopgap, such as disabling host acceptance, excluding a model or
profile, blocking a lane, forbidding a retry, or requiring a manual repeat step. Before applying it,
record its action and scope, a root-cause hk task id (an investigation task if the cause is unknown),
and a release condition in hk. A containment agreed only in chat is void. Whoever releases it records
the release on the same task.

Keep one row per containment in the fixed hk doc key `ops/workaround-ledger`:

```text
- <action and scope> | root: hk <id> | release: <condition> | status: active|released | record: hk <ids>
```

Run `bin/containment-check` before applying and before releasing, piping the body from
`handoffkeep doc get ops/workaround-ledger` into it. Run the pipeline under `set -o pipefail`. Correct any reported rows first.

**Prevents:** a model-profile exclusion from a grade on 2026-11-05 had no decision record or
root-cause task.

## Related rules

| When | Read |
|---|---|
| Closing a lead pane | `ops` reap §6-2: its last report's `next unit:` line decides |
| A worker stopped after its first turn | `ops` spawn §4-3 |
| Choosing a harness for a lead or implementer | `robin-mode` roles.md |
