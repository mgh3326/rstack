#!/usr/bin/env bash
# hk 2780: the desk method lives in skills/desk plus ops and roles.md.
#   1. skills/desk/SKILL.md has its required sections; each cites the failure it prevents.
#   2. The resume read order is fixed, and the skill stays harness-neutral.
#   3. The required lines stay in the desk skill, ops references and roles.md, and
#      install/sets.json gives desk to the full set only.
# Every required row has a mutant that deletes the matched text and must go RED.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import delete_row, expect_red, flat, section  # noqa: E402

PATHS = {
    "desk": "skills/desk/SKILL.md",
    "spawn": "skills/ops/references/spawn.md",
    "decision": "skills/ops/references/decision-request.md",
    "ops": "skills/ops/SKILL.md",
    "roles": "skills/robin-mode/roles.md",
    "robin": "skills/robin-mode/SKILL.md",
}
docs = {name: (root / rel).read_text(encoding="utf-8") for name, rel in PATHS.items()}

SECTIONS = ("## Commitments", "## Resume", "## Before `tasks add`", "## Delegation threshold",
            "## Spawn failure", "## Decisions", "## Facts", "## Task record", "## Time", "## Containment")
RESUME_ORDER = ("`date ", "hk tasks with a next action", "Open decisions", "Inbox READY/ESC",
                "Live jobs", "PRs awaiting gate")
NOT_NEUTRAL = re.compile(r"claude|codex|AskUserQuestion|spawn_agent|\.agents/", re.IGNORECASE)


# (doc, section heading or None, row name, pattern on the flattened scope)
REQUIRED = [
    # r2 (hk:doc decision/2026-11-07/design-session-desk-authority): the desk is the fallback for a
    # project that has no design session open, and it receives the session's hand-off.
    # PR #48 finding r4501835276: a closed session's jobs keep its lane as owner.
    ("desk", None, "desk-reads-closed-lane", r"A closed session's jobs keep its lane as owner \(`wake` §The loop step 5\)"),
    ("desk", None, "desk-session-name", r"A desk session uses its lane name as its Claude session name \(`claude --name <lane>` or `/rename <lane>`\), so others can address it"),
    ("desk", None, "desk-intake-heading", r"## Intake"),
    ("desk", None, "sessionless-lane-intake", r"세션이 열려 있지 않은 레인으로 온 주문, ESC, READY, finding은 desk가 받아 직접 처리하거나, 일이 많으면 다시 레인으로 나눈다\. 다시 나눌 때는 운영자에게 해당 레포의 디자인 세션을 열어 달라고 하고, 세션이 열리면 그 세션에 일을 넘긴다\. 수신함에 남겨 다음 세션을 기다리지 않는다\."),
    ("desk", "## Resume", "sessionless-inbox-until-wake", r"\*Temporary \(operator 2026-11-12, hk 4152\): ends when panewire wakes the desk for a lane with no live session \(hk 4150\)\.\* 그때까지 desk는 resume할 때와 다음에 깨어날 때 세션이 없는 레인들의 수신함도 직접 확인하고, 도착한 일을 처리한다\."),
    ("desk", None, "sessionless-sender-route", r"보낸 쪽은 계속 그 레포의 디자인 레인으로 보낸다\."),
    ("desk", None, "desk-scope", r"The desk takes a project's ESC decisions, spawn failures, merge holds and deploys only while that project has no design session open — with one open they are the session's \(`wake` §Authority\)\."),
    ("desk", None, "desk-close-handoff", r"It\s+receives a closing session's one-line hand-off; a session sends no notice before touching a target several projects share\. Lane routes stay with the desk\."),
    ("desk", "## Containment", "ledger-key", r"`ops/workaround-ledger`"),
    ("desk", "## Commitments", "record-first", r"Before you say \"I will X\", record it in hk"),
    ("desk", "## Commitments", "subtask-then-comment", r"sub-task of the task it belongs to once hk sub-tasks exist\. Until then, use a task comment on the parent"),
    ("desk", "## Commitments", "id-in-sentence", r"Put the hk id in the sentence"),
    ("desk", "## Commitments", "commitments-line", r"ends with a `Commitments:` line listing ids"),
    ("desk", "## Resume", "ledger-later", r"Once hk serves the desk ledger \(hk 2773\), the order becomes `handoffkeep ledger`"),
    ("desk", "## Resume", "resume-task-cli-forms", r"`handoffkeep tasks export --state <state> --limit 5000 --lane <desk lane>`.{0,100}`handoffkeep tasks comments <id>`"),
    ("desk", "## Resume", "resume-export-completeness", r"`tasks export` returns an envelope; check its `complete` and `truncated` fields before treating the rows as exhaustive"),
    ("desk", "## Resume", "hk-is-truth", r"Local agent memory is not the source of truth; hk is \(hk 2781\)"),
    ("desk", "## Before `tasks add`", "search-first", r"Search open and recent tasks first"),
    ("desk", "## Before `tasks add`", "retry-same-task", r"A retry is a new attempt on the same task, never a new task"),
    ("desk", "## Delegation threshold", "threshold", r"Investigation that would keep the desk off its queue for more than about ten minutes, or that needs reading across several files or logs, goes to a background subagent \(or a worker when it needs another host\), with the result written to an hk doc"),
    ("desk", "## Delegation threshold", "known-target-lookups", r"Short lookups whose target is known stay with the desk"),
    ("desk", "## Spawn failure", "one-fix", r"one fix attempt on the same task"),
    ("desk", "## Spawn failure", "file-and-stop", r"If it still fails, file a task against the tool and stop"),
    ("desk", "## Spawn failure", "no-hopping", r"No host or model hopping, and no new task per attempt"),
    ("desk", "## Decisions", "resolve-same-turn", r"An answer given in chat is resolved in hk in the same turn"),
    ("desk", "## Decisions", "reuse-request", r"Asking again reuses the same request"),
    ("desk", "## Decisions", "review-at-resume", r"Open requests are reviewed at resume"),
    ("desk", "## Facts", "facts-same-turn", r"a fix applied, a workaround, a respawn under a new task — it comments the fact on every affected task in the same turn"),
    ("desk", "## Facts", "respawn-names-id", r"For a respawn, name the new task id on the old task"),
    ("desk", "## Facts", "respawn-same-task-default", r"keeps a respawn on the same task; this covers one that already exists under a new task"),
    ("desk", "## Facts", "brief-key", r"A brief the desk writes is put in hk at `brief/<date>/<job>` before the spawn"),
    ("desk", "## Facts", "brief-doc-put", r"handoffkeep doc put --key brief/<date>/<job> --kind note --file <brief>"),
    ("desk", "## Task record", "stage-waiting-on", r"Every open task has one stage and one waiting-on"),
    ("desk", "## Time", "clock-source", r"Clock times in records come only from `date` or the server"),
    ("spawn", "### 4-3.", "nudge-once-terminal", r"첫 턴 뒤 보고 없이 멈추면 한 번만 재촉한다\. 그 뒤에도 보고 없이 멈추면 그 attempt 는 terminal"),
    ("decision", "## 데스크 결정 루프", "one-record", r"질문 하나에 기록 하나"),
    ("decision", "## 데스크 결정 루프", "reuse", r"다시 물을 때는 같은 요청을 쓴다"),
    ("decision", "## 데스크 결정 루프", "chat-answer", r"채팅으로 받은 답은 같은 턴에 hk 에서 닫는다"),
    ("decision", "## 데스크 결정 루프", "resolve-command", r"handoffkeep tasks decision-resolve <task-id> --request <request_id> --kind answered"),
    ("decision", "## 데스크 결정 루프", "progress-not-resolution", r"진행은 해결이 아니다"),
    ("decision", "## 데스크 결정 루프", "resume-review", r"resume 마다 열린 요청을 검토한다"),
    ("ops", "## Invariants (all references)", "clock-invariant", r"A clock time in a record comes from `date` or the server, never from your head"),
    ("roles", "## Rules", "multi-turn", r"Leads and implementers must run on harnesses that keep going across turns"),
    ("roles", "## Rules", "one-turn-limit", r"One-turn profiles may take explorer and consult roles only"),
    ("roles", "## Rules", "contract-writer", r"A design session \(with the operator\) or a lead \(opened by the operator, following the `lead` skill\) writes the closed contract"),
    ("roles", "## Rules", "higher-grade-not-lead", r"A hard single PR is an implementer with a higher grade, not a lead"),
    ("roles", "## Rules", "resolve-only", r"Explorer, verifier and judge are resolve-only: they name an in-session subagent's `panewire resolve` role \(below\), never a spawned seat"),
    ("roles", "## Rules", "seat-vocabulary", r"seat roles are lead, implementer, reviewer, consult and design"),
    ("roles", None, "one-turn-row", r"\| One-turn \(stops after its first turn\) \| \*\*Explorer\*\* and \*\*Consult\*\* only"),
    ("robin", "## Where each rule lives", "desk-home", r"\| `desk` \(rstack\) \|"),
]

# Rules a line in desk must never state.
# (doc, section heading or None, row name, pattern on the flattened scope, injected mutant text)
FORBIDDEN = [
    ("desk", "## Delegation threshold", "three-tool-calls", r"3 tool calls",
     "Investigation that needs more than about 3 tool calls goes to a worker.\n"),
    ("desk", None, "old-closed-lane-inbox-scope",
     r"until that repo's next design session opens the desk reads their ESCs and spawn\s+failures in that lane's inbox",
     "so until that repo's next design session opens the desk reads their ESCs and spawn failures in that lane's inbox (`wake` §The loop step 5).\n"),
]


def check_sections(desk):
    positions = [desk.find(f"\n{h}\n") for h in SECTIONS]
    assert -1 not in positions, f"desk: missing section {SECTIONS[positions.index(-1)]}"
    for heading in SECTIONS:
        assert "**Prevents:**" in section(desk, f"{heading}\n"), f"desk: {heading} cites no failure"


def check_resume_order(desk):
    steps = re.findall(r"(?m)^(\d)\. (.*)$", section(desk, "## Resume\n"))
    assert [n for n, _ in steps] == list("123456"), f"desk: resume is not 6 numbered steps: {steps}"
    for (n, line), expected in zip(steps, RESUME_ORDER):
        assert line.startswith(expected), f"desk: resume step {n} must be {expected!r}, found {line!r}"


def check_neutral(desk):
    scrubbed = re.sub(r"claude --name <lane>|Claude session name", "", desk, flags=re.IGNORECASE)
    m = NOT_NEUTRAL.search(scrubbed)
    assert not m, f"desk: names a harness-specific term {m.group(0)!r}"


def check_rows(d):
    for doc, heading, row, pattern in REQUIRED:
        scope = flat(section(d[doc], heading) if heading else d[doc])
        assert re.search(pattern, scope), f"{doc}: row '{row}' missing or weakened"
    for doc, heading, row, pattern, _ in FORBIDDEN:
        scope = flat(section(d[doc], heading) if heading else d[doc])
        assert not re.search(pattern, scope), f"{doc}: forbidden rule '{row}' present"


def check_sets(sets):
    assert "desk" in sets["full"], "desk missing from the full install set"
    assert "desk" not in sets["worker"], "desk must not be in the worker install set"


def check(d, sets):
    check_sections(d["desk"])
    check_resume_order(d["desk"])
    check_neutral(d["desk"])
    check_rows(d)
    check_sets(sets)


sets = json.loads((root / "install/sets.json").read_text(encoding="utf-8"))["sets"]
check(docs, sets)
print(f"PASS desk-skill-contract sections={len(SECTIONS)} rows={len(REQUIRED)}")


def red(label, d, s=sets):
    expect_red(label, check, d, s)


count = 0
for doc, heading, row, pattern in REQUIRED:
    red(f"row-{row}-deleted", {**docs, doc: delete_row(docs[doc], heading, pattern, row)})
    count += 1

for doc, heading, row, pattern, injected in FORBIDDEN:
    if heading:
        mutant = docs[doc].replace(f"{heading}\n", f"{heading}\n{injected}\n", 1)
    else:
        mutant = docs[doc] + f"\n{injected}\n"
    red(f"forbidden-{row}-injected", {**docs, doc: mutant})
    count += 1

desk = docs["desk"]
for heading in SECTIONS:
    red(f"section-{heading}-removed", {**docs, "desk": desk.replace(f"\n{heading}\n", "\n## Other\n", 1)})
    count += 1
    body = section(desk, f"{heading}\n")
    red(f"failure-cite-{heading}-removed", {**docs, "desk": desk.replace(body, body.replace("**Prevents:**", "Note:"), 1)})
    count += 1

first = "2. hk tasks with a next action"
second = "3. Open decisions"
assert first in desk and second in desk, "fixture: resume steps not found"
swapped = desk.replace(first, "\0").replace(second, "2. Open decisions").replace("\0", "3. hk tasks with a next action")
red("resume-steps-swapped", {**docs, "desk": swapped})
red("harness-specific-term", {**docs, "desk": desk + "\nUse the Claude Agent tool.\n"})
red("desk-not-in-full-set", docs, {**sets, "full": [n for n in sets["full"] if n != "desk"]})
red("desk-in-worker-set", docs, {**sets, "worker": sets["worker"] + ["desk"]})
count += 4
print(f"PASS mutants assertion-red={count}/{count}")
PY
