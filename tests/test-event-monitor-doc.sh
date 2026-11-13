#!/usr/bin/env bash
# #636 part A (AC1+AC5): the polling-monitor ban must stay executable.
#
# A director session accumulated 256 session-bound polling monitors over 96h
# and lost 34 of them in one reboot (hk:doc
# task/2026-09-24/director-monitors-to-panewire). The fix is contract text:
# ops/references/watching.md bans per-job polling loops and binds the allowed
# signals to the deployed-build event table, and makes a spawner idle-wait on
# pushed events instead of re-checking every turn. This guard:
#
#   1. watching.md §감시 정책 carries the ban, the event-subscription rule, the
#      missing-event -> task rule, a numeric concurrency cap with its
#      rationale, and a pointer to the event table;
#   2. watching.md §스폰 후 대기 carries the idle-until-event rule, the per-turn re-check ban,
#      and the single blocking-wait exception;
#   3. mutants (wording removed) go RED through an assertion. The event table is
#      panewire's document and is not checked here (hk 4424).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import os
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import expect_red, flat, section  # noqa: E402
policy_path = Path(os.environ.get("WATCHING_DOC", root / "skills/ops/references/watching.md"))
wait_path = policy_path

policy_text = policy_path.read_text(encoding="utf-8")
wait_text = wait_path.read_text(encoding="utf-8")


def check_policy(text: str) -> None:
    """§감시 정책 must ban per-job polling loops, route to event subscription,
    escalate missing events to tasks, and carry a numeric cap with rationale."""
    sec = flat(section(text, "## 감시 정책"))
    assert re.search(r"폴링 루프.{0,80}(감시하지|금지|상한은 0)", sec) or re.search(
        r"상한은 0", sec
    ), "per-job polling-loop ban missing (cap must be 0)"
    assert re.search(r"job\.\*", sec) and "lane.event" in sec and "idle-wake" in sec, (
        "event-subscription rule must name job.* / lane.event / idle-wake"
    )
    assert re.search(r"부족한 이벤트.{0,60}태스크", sec), (
        "missing events must go to a task, not back to polling"
    )
    assert re.search(r"동시 3개 이하|3개 이하", sec), (
        "concurrency cap number (3) missing"
    )
    assert re.search(r"3개 이하.{0,400}256", sec), (
        "cap rationale must cite the 96h/256 measured count next to the cap"
    )
    assert "panewire 이벤트 문서" in sec, "section must point at the event table"
    # 미배포 유실 신호(pane 소실·정체)는 걷어내지 않고 잡별 루프가 아닌 단발
    # 조회로 커버한다는 처방이 §감시 정책 안에 있어야 한다 — 없으면 "예외 없음"
    # 과 표의 미배포 행이 모순된다(테스터 B1).
    assert re.search(r"공백 신호는 걷어내지 않는다.{0,300}단발", sec), (
        "gap-signal prescription (미배포 유실 신호 → 단발 조회) missing"
    )
    # 처방의 수단·판정 기준도 계약이다 — herdr 는 로컬 소켓 1대분이고, 원격은
    # ssh 또는 operator 토큰 경로며, 소실·정체 판정 기준이 있어야 실행 가능하다.
    assert re.search(r"herdr agent list.{0,80}로컬", sec), (
        "gap-signal means must mark herdr agent list as local-socket only"
    )
    assert re.search(r"ssh.{0,20}herdr agent list", sec) and "operator" in sec, (
        "gap-signal means must cover remote hosts (ssh) and operator-token hub queries"
    )
    assert "판정 기준" in sec, (
        "loss/stall judgement criteria missing from the gap-signal prescription"
    )
    # 정체 판정의 비교 대상은 pane 출력이다 — revision/last-event 비교는
    # 일하는 워커를 전부 정체로 잘못 잡는다(테스터 RR1).
    assert "pane read" in sec, (
        "stall criterion must compare pane-read output, not revision counters"
    )


def check_wait(text: str) -> None:
    """Builder must idle after spawning, wake on pushed events, never re-check
    per turn, and get exactly one blocking wait."""
    sec = flat(section(text, "## 스폰 후 대기"))
    assert re.search(r"유휴로 대기하고.{0,40}알림으로 깨어난다", sec), (
        "idle-until-completion-notification rule missing"
    )
    assert re.search(r"턴마다.{0,60}폴링 반복은 금지|턴.{0,20}확인.{0,20}금지", sec), (
        "per-turn re-check ban missing"
    )
    assert re.search(r"블로킹 명령 1개", sec) and "panewire wait" in sec, (
        "single bounded blocking-wait exception missing"
    )
    assert "bounded timeout" in sec, (
        "the blocking wait must be bounded (timeout required)"
    )
    assert "panewire 이벤트 문서" in sec, "spawn-wait must point at the event table"
    assert "공백 신호" in sec, (
        "spawn-wait must point at the gap-signal rule for undeployed signals"
    )


print("PASS watching.md policy ban=1 subscribe=1 missing->task=1 cap=3 rationale=1 doc-ptr=1")

check_wait(wait_text)
print("PASS watching.md spawn-wait idle-wait=1 no-per-turn-recheck=1 blocking-wait-1=1 doc-ptr=1")



policy_section_removed = re.sub(
    r"(?s)## 감시 정책.*?(?=\n## |\Z)", "", policy_text, count=1
)
assert policy_section_removed != policy_text, (
    "fixture: policy 감시 정책 section not found to remove"
)

policy_cap_removed = policy_text.replace("동시 3개 이하", "동시 적당히", 1)
assert policy_cap_removed != policy_text, (
    "fixture: policy cap number not found to weaken"
)

policy_task_rule_removed = re.sub(
    r"(?s)\*\*부족한 이벤트는.*?\n\n", "\n", policy_text, count=1
)
assert policy_task_rule_removed != policy_text, (
    "fixture: policy missing-event->task bullet not found"
)

wait_section_removed = re.sub(
    r"(?s)## 스폰 후 대기.*?(?=\n## |\Z)", "", wait_text, count=1
)
assert wait_section_removed != wait_text, (
    "fixture: wait 대기 section not found to remove"
)

policy_gap_rule_removed = re.sub(
    r"(?s)- \*\*공백 신호는.*?(?=\n- )", "", policy_text, count=1
)
assert policy_gap_rule_removed != policy_text, (
    "fixture: policy gap-signal bullet not found to remove"
)

policy_rationale_removed = policy_text.replace(
    "실측 96h에 256건", "관측된 사례", 1
)
assert policy_rationale_removed != policy_text, (
    "fixture: policy 256건 rationale not found to remove"
)

wait_bounded_removed = wait_text.replace(
    "**bounded timeout 있는 블로킹 명령 1개**", "블로킹 명령 1개", 1
)
assert wait_bounded_removed != wait_text, (
    "fixture: wait bounded-timeout wording not found to remove"
)

# 처방 수단·판정 기준 약화 — 문구가 남아도 의미가 무너지면 RED 여야 한다.
policy_gap_local_lost = policy_text.replace(
    "로컬 herdr 소켓 1대분", "fleet 조회", 1
)
assert policy_gap_local_lost != policy_text, (
    "fixture: policy herdr local-scope wording not found"
)

policy_gap_remote_lost = policy_text.replace(
    "`ssh <host> herdr agent list`", "", 1
)
assert policy_gap_remote_lost != policy_text, (
    "fixture: policy ssh fallback wording not found"
)

policy_gap_judgement_lost = policy_text.replace("**판정 기준:**", "", 1)
assert policy_gap_judgement_lost != policy_text, (
    "fixture: policy judgement-criteria wording not found"
)

policy_stall_basis_lied = policy_text.replace("pane read", "revision")
assert policy_stall_basis_lied != policy_text, (
    "fixture: policy pane-read basis not found"
)

wait_gap_pointer_lost = wait_text.replace('"공백 신호" 규칙', "규칙", 1)
assert wait_gap_pointer_lost != wait_text, (
    "fixture: wait gap-signal pointer not found"
)

mutants = [
    ("policy-section-removed", lambda: check_policy(policy_section_removed)),
    ("policy-cap-weakened", lambda: check_policy(policy_cap_removed)),
    (
        "policy-missing-event-task-rule-removed",
        lambda: check_policy(policy_task_rule_removed),
    ),
    (
        "policy-gap-signal-rule-removed",
        lambda: check_policy(policy_gap_rule_removed),
    ),
    (
        "policy-cap-rationale-removed",
        lambda: check_policy(policy_rationale_removed),
    ),
    ("wait-section-removed", lambda: check_wait(wait_section_removed)),
    (
        "wait-bounded-timeout-removed",
        lambda: check_wait(wait_bounded_removed),
    ),
    (
        "policy-gap-local-scope-lied",
        lambda: check_policy(policy_gap_local_lost),
    ),
    (
        "policy-gap-remote-means-removed",
        lambda: check_policy(policy_gap_remote_lost),
    ),
    (
        "policy-gap-judgement-removed",
        lambda: check_policy(policy_gap_judgement_lost),
    ),
    (
        "policy-stall-basis-lied",
        lambda: check_policy(policy_stall_basis_lied),
    ),
    (
        "wait-gap-pointer-removed",
        lambda: check_wait(wait_gap_pointer_lost),
    ),
]
for label, callback in mutants:
    expect_red(label, callback)
print(f"PASS mutants assertion-red={len(mutants)}/{len(mutants)}")
PY
