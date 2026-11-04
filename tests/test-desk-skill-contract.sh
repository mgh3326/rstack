#!/usr/bin/env bash
# hk 2780: the desk method lives in skills/desk plus ops and roles.md.
#   1. skills/desk/SKILL.md has its nine sections; each cites the failure it prevents.
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
PATHS = {
    "desk": "skills/desk/SKILL.md",
    "reap": "skills/ops/references/reap.md",
    "spawn": "skills/ops/references/spawn.md",
    "decision": "skills/ops/references/decision-request.md",
    "ops": "skills/ops/SKILL.md",
    "roles": "skills/robin-mode/roles.md",
    "robin": "skills/robin-mode/SKILL.md",
}
docs = {name: (root / rel).read_text(encoding="utf-8") for name, rel in PATHS.items()}

SECTIONS = ("## Commitments", "## Resume", "## Before `tasks add`", "## Delegation threshold",
            "## Spawn failure", "## Decisions", "## Facts", "## Task record", "## Time")
RESUME_ORDER = ("`date ", "hk tasks with a next action", "Open decisions", "Inbox READY/ESC",
                "Live jobs", "PRs awaiting gate")
NOT_NEUTRAL = re.compile(r"claude|codex|AskUserQuestion|spawn_agent|\.agents/", re.IGNORECASE)


def flat(text):
    return re.sub(r"\s+", " ", text)


def section(text, heading):
    """Body of a ##/### section up to the next heading of same-or-higher level."""
    assert heading in text, f"missing heading: {heading}"
    body = text.split(heading, 1)[1]
    level = len(heading) - len(heading.lstrip("#"))
    m = re.search(rf"(?m)^#{{1,{level}}} ", body)
    return body[: m.start()] if m else body


# (doc, section heading or None, row name, pattern on the flattened scope)
REQUIRED = [
    ("desk", "## Commitments", "record-first", r"Before you say \"I will X\", record it in hk"),
    ("desk", "## Commitments", "subtask-then-comment", r"sub-task of the task it belongs to once hk sub-tasks exist\. Until then, use a task comment on the parent"),
    ("desk", "## Commitments", "id-in-sentence", r"Put the hk id in the sentence"),
    ("desk", "## Commitments", "commitments-line", r"ends with a `Commitments:` line listing ids"),
    ("desk", "## Resume", "ledger-later", r"Once hk serves the desk ledger \(hk 2773\), the order becomes `handoffkeep ledger`"),
    ("desk", "## Resume", "hk-is-truth", r"Local agent memory is not the source of truth; hk is \(hk 2781\)"),
    ("desk", "## Before `tasks add`", "search-first", r"Search open and recent tasks first"),
    ("desk", "## Before `tasks add`", "retry-same-task", r"A retry is a new attempt on the same task, never a new task"),
    ("desk", "## Delegation threshold", "threshold", r"Investigation that needs more than about 3 tool calls goes to a worker or a background subagent, with the result written to an hk doc"),
    ("desk", "## Spawn failure", "one-fix", r"one fix attempt on the same task"),
    ("desk", "## Spawn failure", "file-and-stop", r"If it still fails, file a task against the tool and stop"),
    ("desk", "## Spawn failure", "no-hopping", r"No host or model hopping, and no new task per attempt"),
    ("desk", "## Decisions", "resolve-same-turn", r"An answer given in chat is resolved in hk in the same turn"),
    ("desk", "## Decisions", "reuse-request", r"Asking again reuses the same request"),
    ("desk", "## Decisions", "review-at-resume", r"Open requests are reviewed at resume"),
    ("desk", "## Facts", "facts-same-turn", r"a fix applied, a workaround, a respawn under a new task — it comments the fact on every affected task in the same turn"),
    ("desk", "## Facts", "respawn-names-id", r"For a respawn, name the new task id on the old task"),
    ("desk", "## Facts", "brief-key", r"A brief the desk writes is put in hk at `brief/<date>/<job>` before the spawn"),
    ("desk", "## Facts", "brief-doc-put", r"handoffkeep doc put --key brief/<date>/<job> --kind note --file <brief>"),
    ("desk", "## Task record", "stage-waiting-on", r"Every open task has one stage and one waiting-on"),
    ("desk", "## Time", "clock-source", r"Clock times in records come only from `date` or the server"),
    ("reap", "### 6-2.", "never-close-lead", r"마지막 보고의 `next unit:` 줄이 단위를 가리키는 리드는 닫지 않는다"),
    ("reap", "### 6-2.", "none-closes", r"닫을 수 있는 값은 `next unit: none` 뿐이다"),
    ("reap", "### 6-2.", "lead-report-line", r"리드 보고는 이 줄을 반드시 싣는다"),
    ("reap", "### 6-2.", "tools-do-not-read", r"`panewire reap` 과 mergewake 데몬은 이 줄을 읽지 않는다"),
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
    ("roles", "## Rules", "lead-next-unit", r"A lead's every report carries a `next unit:` line"),
    ("roles", "## Rules", "contract-writer", r"A design session \(with the operator\) or a lead \(delegated, without the operator\) writes the closed contract"),
    ("roles", "## Rules", "higher-grade-not-lead", r"A hard single PR is an implementer with a higher grade, not a lead"),
    ("roles", "## Rules", "resolve-only", r"Explorer, verifier and judge are resolve-only: they name an in-session subagent's `panewire resolve` role \(below\), never a spawned seat"),
    ("roles", "## Rules", "seat-vocabulary", r"seat roles are lead, implementer, reviewer, consult and design"),
    ("roles", None, "one-turn-row", r"\| One-turn \(stops after its first turn\) \| \*\*Explorer\*\* and \*\*Consult\*\* only"),
    ("robin", "## Where each rule lives", "desk-home", r"\| `desk` \(rstack\) \|"),
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
    m = NOT_NEUTRAL.search(desk)
    assert not m, f"desk: names a harness-specific term {m.group(0)!r}"


def check_rows(d):
    for doc, heading, row, pattern in REQUIRED:
        scope = flat(section(d[doc], heading) if heading else d[doc])
        assert re.search(pattern, scope), f"{doc}: row '{row}' missing or weakened"


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


def expect_red(label, d, s=sets):
    try:
        check(d, s)
    except AssertionError:
        return
    except Exception as exc:
        raise AssertionError(f"{label} errored instead of assertion RED: {exc}") from exc
    raise AssertionError(f"mutant {label} did not go RED")


count = 0
for doc, heading, row, pattern in REQUIRED:
    text = docs[doc]
    start = text.index(heading) + len(heading) if heading else 0
    end = start + len(section(text, heading)) if heading else len(text)
    words = re.search(pattern, flat(text[start:end])).group(0).split()
    raw = re.compile(r"\s+".join(re.escape(w) for w in words)).search(text, start, end)
    assert raw, f"fixture: row {row} not found unflattened in its section"
    expect_red(f"row-{row}-deleted", {**docs, doc: text[: raw.start()] + text[raw.end():]})
    count += 1

desk = docs["desk"]
for heading in SECTIONS:
    expect_red(f"section-{heading}-removed", {**docs, "desk": desk.replace(f"\n{heading}\n", "\n## Other\n", 1)})
    count += 1
    body = section(desk, f"{heading}\n")
    expect_red(f"failure-cite-{heading}-removed", {**docs, "desk": desk.replace(body, body.replace("**Prevents:**", "Note:"), 1)})
    count += 1

first = "2. hk tasks with a next action"
second = "3. Open decisions"
assert first in desk and second in desk, "fixture: resume steps not found"
swapped = desk.replace(first, "\0").replace(second, "2. Open decisions").replace("\0", "3. hk tasks with a next action")
expect_red("resume-steps-swapped", {**docs, "desk": swapped})
expect_red("harness-specific-term", {**docs, "desk": desk + "\nUse the Claude Agent tool.\n"})
expect_red("desk-not-in-full-set", docs, {**sets, "full": [n for n in sets["full"] if n != "desk"]})
expect_red("desk-in-worker-set", docs, {**sets, "worker": sets["worker"] + ["desk"]})
count += 4
print(f"PASS mutants assertion-red={count}/{count}")
PY
