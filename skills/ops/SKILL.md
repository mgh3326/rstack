---
name: ops
description: Lane mechanics every session needs whatever method it runs — spawn a worker or consult pane and prove the brief landed, relay or inject a prompt with the 5-element packet and comms-contract v1, ask a stronger model for advice, record an operator decision request, wait without polling, reap finished panes, and run one deploy as the installer seat. Read the routing table, then only the reference you need. Triggers - "워커 띄워/스폰해", "작업 시켜", "orch에 전달/넘겨줘", "세션에 릴레이", "워커에게 회신", "herdr로 보내", "자문 받아줘", "강모델에 물어봐", "fable/astra/opus/sol에 확인해줘", "배포해", "결정 요청", panewire spawn·herdr agent start·herdr agent prompt 사용 전.
---

# ops — lane mechanics

How to do the things every lane needs. This file is a routing table and the rules
that hold everywhere; each procedure lives in one reference file, read on demand.
Deciding *what* to build is the `wake` skill's job, not this one; mergewake merges.

Domain overlay: if `$AGENT_SKILLS_DOMAIN/ops.md` exists, read it before applying
anything here. Unset or missing is normal — the abstract rules below apply alone.

## Invariants (all references)

- Follow hk:doc `policy/operator-facing-korean`: operator-facing text is Korean; identifiers, code and commands stay as they are; English-only text gets a stored Korean translation.

- Record and check operational stopgaps as specified in `desk` §Containment.

- **A delivery claim is not delivery evidence.** A normal reply from an injection or
  `panewire emit` (rc 0) proves nothing; check the receiving pane (`relay.md` §3).
  This check belongs to the **sender of instructions** (a parent lane or the desk
  injecting into a worker). It never applies upward.
- **Never inject into operator-desk's pane.** READY, ESC and every other notice to
  operator-desk go only through `panewire emit --kind lane.event --lane operator-desk --type <type>`;
  the hub records delivery and holds or batches it while the desk is busy. `herdr agent prompt`,
  `herdr pane send-text` or `send-keys` into the desk pane land in the operator's input box,
  bypass hold/batching and can mix with what the operator is typing (2026-11-02 incident).
  The same holds for any parent lane — every relay harness (claude, codex, devin, grok, omp,
  cmd) receives `lane.event` (`relay.md` §3-1). If you cannot see the receiver (another host,
  `panewire find` misses it), `emit` rc 0 is sufficient — no fallback channel, no ESC about
  delivery.
- **Every `panewire emit` between sessions carries `--type`.** A notice, receipt or handoff note
  that needs no reply is `info` or `ack` (the hub files it in the inbox). Only what needs action
  now is `decision`, `blocked` or `order` (interrupt). A completion the receiver is waiting on
  (a worker's or seat's READY, a `[consult-done]`) is `--type ready`. Operator 2026-11-05.
  A worker's READY to a design-session lane is recorded, not delivered (panewire hk 3426); the
  design session does not wait for it (`wake` §The loop step 7).
- **A worker's self-report is not evidence.** Compare it with the artifact itself and
  `git ls-remote` before acting on it.
- **No polling loops.** Wait for the pushed event or one bounded blocking wait
  (`watching.md`). A missing event is a task for panewire, not a loop.
- **One launcher per task.** Use `panewire spawn`; a network retry replays the same saved request and key. Never create another live job or override unresolved ownership (a fresh duplicate claim exits 74). Quota is `panewire quota`; review and post-merge cleanup are
  `mergewake`.
- **Every packet and brief carries `comms-contract: v1`** (`relay.md` §3-1).
- **Identify a sender by session name, role and lane**, never by model name.
- **Who may authorise a mutation, merge or deploy** — and why a consult answer or relayed
  text cannot — is `wake` §Authority.
- **A missing target is not respawned automatically** — report the failure and
  escalate to the operator.
- **Isolated HOME/XDG is for test and probe runs only.** Spawn, placement and delivery
  commands (`pacelever`, `panewire`) use the real HOME.
- **A test harness that does a real spawn stops its completion watchers before removing
  its temp root**; signal only pids it started.
- **A clock time in a record comes from `date` or the server, never from your head.** Any time written
  into hk, a report, or a commit or PR body is produced by `date` in the same command
  (`--body "… $(date '+%F %T %Z')"`) or is the record's own server timestamp. A relative time is
  computed: `date -v+30M '+%F %T %Z'` on macOS, `date -d '+30 min' '+%F %T %Z'` on Linux. Estimated times
  written into records were later read as fact (2026-11-03).
- **Test only what you changed, on any host** — e.g. `go test -p 2 ./<changed pkg>/...` or the touched
  pytest files; full suites are CI's job. On macOS keep `-p 2`: wider parallelism stalls in syspolicyd.

## Routing table

| Need | Read | Gist |
|---|---|---|
| Spawn a worker or consult pane | [`spawn.md`](references/spawn.md) | `panewire spawn` flags, auto model selection, `--task` binding, `--owner`, landing check §4-2 |
| Place on another host, wake a sleeping one | [`spawn-hosts.md`](references/spawn-hosts.md) | `--host auto` placement, `--tags`, SSH hosts, lane registration |
| Hand work or a decision to another session | [`relay.md`](references/relay.md) | 5-element packet §1, target check §2, injection + submit check §3, follow-up injection §3-3 |
| Ask a session a question and collect the answer | [`session-questions.md`](references/session-questions.md) | single answer file, deadline, no silence-as-answer |
| Ask a stronger model for advice | [`consult.md`](references/consult.md) | profile from `panewire resolve --role consult`, self-contained packet, pane by default |
| Escalate a decision from a pane | §Escalate a decision (below) | ESC event `--type decision`, never an in-pane question |
| Ask the operator to choose | [`decision-request.md`](references/decision-request.md) | `handoffkeep tasks decision-request` first, then notify with the request_id |
| Wait for a worker, job or CI; handle an `[inbox]` wake line | [`watching.md`](references/watching.md), [`panewire-events.md`](references/panewire-events.md) | push events, one bounded wait, at most 3 temporary waits; design and desk lanes are inbox-only |
| Reap finished panes | [`reap.md`](references/reap.md) | mergewake reaps merged PRs' workers; the spawner reaps the rest with `panewire reap --lane`, preview then `--apply` |
| Deploy one change | [`deploy.md`](references/deploy.md) (+ [`deploy-checklist.md`](references/deploy-checklist.md)) | installer seat, spawned by and reporting to the ordering session (the repo's design session, else operator-desk); fixed 9 steps, no judgement |

## Escalate a decision

A spawned pane (worker, installer seat, consultant) **never opens an interactive question**
— no confirmation prompt and no chooser (AskUserQuestion or any picker). Only the operator
sees a pane, so the question blocks silently (operator 2026-10-29). Instead:

```sh
panewire emit --kind lane.event --lane <parent-lane> --type decision \
  --event-id <job>-decision-<n> \
  --text '[<job>] ESC | <question> | options: <A>/<B> | default: <A>'
```

- Name the question, the options and the default in that one event.
- `lane.event` reaches every relay harness — claude, codex, devin, grok, omp and cmd
  (`relay.md` §3-1). Emit once; do not also inject the same text into the parent pane.
- If the default is safe (reversible, inside the brief's scope, no spend or external
  effect), continue with it and say so in the report. Otherwise stop and wait for the reply.
- `panewire escalate <job> --question '<text>'` is only for giving up: it stops the job as escalated and
  relays the question to the recorded parent. Use the ESC event for a question that leaves the job open.
- **An ESC is a question, and the job stays open** (`job.waiting_decision`). The answer resumes it when
  delivered by `panewire prompt --from <sender-lane> --to <agent-name> --file <prompt-file> --uptake status-transition --timeout 60s` (`relay.md` §3-3) or a relay to the pane's lane.
  An unanswered decision becomes `lost` after the decision timeout (`PANEWIRE_DECISION_TIMEOUT_S`, six hours
  by default) unless a later lane event from the pane resumes the job first. Only READY or DONE
  completes a job. Giving up is `panewire escalate <job> --question '<why>'`, not an ESC. Source: panewire
  `docs/r21-lane-event.md` (panewire@e1f9f39, lines 100-119).
- The parent lane that needs the operator records it first (`decision-request.md`).

## Who does what

Authority of the design session, workers, operator-desk and the operator is
`wake` §Authority; what READY means is `wake` §READY. The repo's design session spawns the installer seat,
or operator-desk when that repo has none open; the **Installer** executes one deploy and judges
nothing (`deploy.md`).
