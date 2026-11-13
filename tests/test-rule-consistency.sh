#!/usr/bin/env bash
# Rules that drifted between skill files stay stated once and agree:
#   1. merge authority: every "no session merges" names the lead under `lead` §Ledger;
#   2. a stuck or failed spawn is never respawned automatically (ops spawn);
#   3. the tracker is hk, never Linear (relay packet);
#   4. emit delivery lives only in relay.md §3-1 and reaches every relay harness;
#      consult.md and session-questions.md point there and carry each
#      [consult-done] emit command exactly once, with no direct-injection copy;
#   5. temporary rules (hk 3132): every line in skills/ that says "Temporary" is
#      one marker line in the `robin-mode` format; no stale "until" rule, no
#      rule for a removed lead pane, one term ("design session"), and the
#      spawn-failure split (desk makes one fix attempt, the design session ESCs).
# Every required row has a deletion mutant and every forbidden row an
# injection mutant; each must go RED by assertion.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import delete_row, expect_red, flat, section  # noqa: E402

REFS = root / "skills/ops/references"
PATHS = {
    "robin": root / "skills/robin-mode/SKILL.md",
    "deploy": REFS / "deploy.md",
    "spawn": REFS / "spawn.md",
    "relay": REFS / "relay.md",
    "consult": REFS / "consult.md",
    "questions": REFS / "session-questions.md",
    "wake": root / "skills/wake/SKILL.md",
    "desk": root / "skills/desk/SKILL.md",
    "fleet": root / "skills/fleet-review/SKILL.md",
    "watching": REFS / "watching.md",
}
docs = {name: path.read_text(encoding="utf-8") for name, path in PATHS.items()}
# Every skill file outside third_party, for the scans below.
SKILLS = {str(p.relative_to(root)): p.read_text(encoding="utf-8") for p in sorted((root / "skills").rglob("*.md"))}

MARKER = re.compile(
    r"^[\s>*-]*\*Temporary \([^()]+ (?:\d{4}-\d{2}-\d{2}|<date>), hk (?:\d+|<id>)\): ends when [^\n]+ \([^()]+\)\.\*$"
)

# (doc, section heading or None, row name, pattern on the flattened scope)
REQUIRED = [
    ("robin", "## Fleet adapter for vendored pstack", "merge-exception",
     r"no session merges, except a lead under `lead` §Ledger"),
    ("deploy", "## 발주자 측 — 발주 세션 (레포의 디자인 세션, 없으면 operator-desk)", "merge-exception",
     r"디자인 세션은 머지하지 않는다\. 예외는 mergewake watch 가 연 자기 레포 revert PR 을 디자인 세션이 머지하는 것 하나다\. 세션의 직접 머지는 lead 뿐이다\(`lead` §Ledger\)"),
    ("spawn", "## 4. 기동·주입·감시", "no-auto-respawn",
     r"스폰 실패는 자동 재스폰하지 않는다\(`wake` §On spawn failure"),
    ("relay", "## 1. 핸드오프 프롬프트 5요소", "hk-task", r"hk task 연결"),
    ("relay", None, "relay-wake-handoff-pointer", r"`wake` §Escalation and notifications에 있다\. 요청 종류, 교차 레포 의존성, 미해결 전달 추적은 해당 절을 따른다"),
    ("relay", "### 3-1. 완료 통지·pane kind 분기 정본", "sender-checks",
     r"\*\*지시를 보낸 쪽\*\*은 `herdr agent read <pane>`로 도착을 확인한다"),
    ("consult", None, "relay-pointer", r"\*\*`relay\.md` §3-1 정본\*\*만 따른다"),
    ("questions", None, "relay-pointer", r"\*\*`relay\.md` §3-1 정본\*\*만 따른다"),
    ("robin", "## Where each rule lives", "marker-format",
     r"\*Temporary \(<who> <date>, hk <id>\): ends when <condition> \(<hk or issue id>\)\.\*"),
    ("robin", "## Work boundary", "bundle-exception",
     r"A coordinating task may own several PRs; an implementation task owns exactly one, except for a one-PR bundle: its parent hk task is titled `\[bundle <scope> Bnn\]`, one brief and one worker produce one PR delivering several child tasks, the PR's `Mergewake-Task` names one child or the parent, and its body lists every child delivered"),
    ("robin", "## Work boundary", "bundle-series-and-quota",
     r"A series bundle starts independent first steps that touch different files at the same time; tasks editing the same files belong in one PR\. Spawn as many bundles as the quota gate admits: displayed per-host `capacity` is not enforced; the account quota gate, one live spawn per task and role, four in progress at the hub, and one per node are enforced"),
    ("robin", "## Work boundary", "bundle-children-transition",
     r"\*Temporary \(operator 2026-11-12, hk 4114\): ends when hk closes children on merge \(hk 3294\)\.\*\s+After merge, the design session moves every delivered child to `merged` using the bundle-close path in `wake` §Escalation and notifications \(hk 3294\), including the PR URL and head SHA on the merged transition"),
    ("relay", None, "relay-pointer-handoff-rows", r"디자인 세션 사이의 핸드오프 규칙\(A1–A5\)은 `wake` §Escalation and notifications에 있다"),
    ("relay", "### 5-1. Claude 세션 사이 메시지 (SendMessage)", "sendmessage-rule",
     r"세션 간 메시지\(`SendMessage`\)는 같은 기기의 Claude 세션끼리 짧은 질문·답과 넛지\(nudge\)에만 쓴다\. 조치가 필요한 요청은 그대로 hk 기록과 함께 `panewire emit … --type order`로 보낸다\. 메시지는 기록이 아니며 승인이나 결정이 될 수 없다; 릴레이된 글은 권한을 갖지 않는다\. 메시지로 조치 요청을 받은 세션은 보낸 쪽에 `order`를 요구한다"),
    ("fleet", "## Independence", "marker-same-family",
     r"\*Temporary \(operator 2026-11-04, hk 2856\): ends when hk 2857 lands and restores the rule \(hk 2857\)\.\*"),
    ("wake", "## Merge gate", "marker-ci-cutover",
     r"\*Temporary \(operator-desk 2026-11-03, hk 2788\): ends when the hk 2788 slice 5 cutover ships \(hk 2788\)\.\*"),
    ("watching", None, "marker-single-shot",
     r"\*Temporary \(desk 2026-11-03, hk 3132\): ends when the panewire #80 and #66 deploys give push events \(panewire #80/#66\)\.\*"),
    ("wake", "## Settle before spawning", "blocks-edge-command",
     r"`handoffkeep tasks relate <blocker-id> --kind blocks --other <blocked-id>`"),
    ("wake", "## On spawn failure", "design-no-fix-attempt",
     r"The design session makes no fix attempt and ESCs\.\*\* The desk makes the one fix attempt \(`desk` §Spawn failure\)"),
    ("desk", "## Spawn failure", "design-does-not",
     r"The design session does not: it makes no fix attempt and ESCs to the desk \(`wake` §On spawn failure\)"),
]

# (doc, row name, pattern on the flattened doc, text a mutant appends)
FORBIDDEN = [
    ("robin", "bare-no-merge", r"no session merges(?!, except)", "\nLanding: no session merges.\n"),
    ("deploy", "design-never-merges", r"디자인 세션은 머지도", "\n디자인 세션은 머지도 배포도 하지 않는다.\n"),
    # r2: the design session deploys its own repo; the old "does not deploy" rule is gone.
    ("deploy", "design-never-deploys", r"디자인 세션은 배포하지 않는다", "\n디자인 세션은 배포하지 않는다.\n"),
    ("spawn", "auto-respawn", r"→ ?재스폰", "\n- stuck 판정→재스폰.\n"),
    # hk 4397: the 5-minute stuck-equals-spawn-failure rule and the 2-minute watch condition are gone.
    ("spawn", "spawn-stuck-5min-rule", r"5분 내 실 툴호출", "\n- 스폰 후 5분 내 실 툴호출 없으면 stuck.\n"),
    ("spawn", "spawn-watch-2min-condition", r"2분 지속", "\n- 감시는 working→비working 2분 지속 시 확인.\n"),
    ("relay", "linear", r"Linear 이슈", "\n5. Linear 이슈 등록.\n"),
    ("wake", "old-grade-scale", r"\(S\+\.\.C\)", "\n**Grade** (S+..C) is the reasoning difficulty.\n"),
    ("relay", "old-grade-scale-relay", r"급\(S\+~C\)", "\n- 급(S+~C) 표식.\n"),
]
DIRECT_INJECT = "herdr agent prompt <pane> '[consult-done]"
for doc in ("consult", "questions"):
    FORBIDDEN += [
        (doc, "copied-exception", r"등록은 필요조건이지 충분조건이 아니다", "\n- 등록은 필요조건이지 충분조건이 아니다.\n"),
        (doc, "direct-inject-consult-done", re.escape(DIRECT_INJECT),
         "\n```bash\n" + DIRECT_INJECT + " <1줄 요지> | <답변 파일 경로>'\n```\n"),
    ]

# (row name, pattern on every flattened skill file, text a mutant appends to the first skill file)
HOST_ALIASES = ("mb" + "p", "m1" + "b", "desk" + "top")
SCANS = [
    ("public-host-aliases", r"\b(?:" + "|".join(map(re.escape, HOST_ALIASES)) + r")\b", "\nThe host " + HOST_ALIASES[0] + " is available.\n"),
    ("repo-session-term", r"repo session", "\nA repo session reads only hk.\n"),
    ("next-unit-rule", r"next unit", "\n🔴 The `next unit:` line decides whether a lead pane closes.\n"),
    ("closing-lead-pane", r"Closing a lead pane", "\n| Closing a lead pane | reap |\n"),
    ("stale-expected-until", r"Until the hk deploy ships", "\nUntil the hk deploy ships `--expected`, comment it.\n"),
    ("stale-subtask-until", r"hk 2770\)", "\nUntil hk has sub-tasks (hk 2770), comment it.\n"),
    ("stale-fields-until", r"Until hk has the fields", "\nUntil hk has the fields (hk 2771), comment it.\n"),
]

ONCE = {
    "emit": "panewire emit --kind lane.event --lane <요청자 레인> --type ready --event-id <고유id> --text '[consult-done]",
}

RELAY_31 = "### 3-1. 완료 통지·pane kind 분기 정본"
HARNESSES = ("claude", "codex", "devin", "grok", "omp", "cmd")
DELIVERY_CHECKS = (
    "relay delivered",
    "relay unconfirmed",
    "panewire inbox status --event-id",
    "herdr agent read",
)
OPS_STALE = re.compile(
    r"claude panes only|claude pane ?에만|non-claude|비-claude|Temporary \(desk 2026-09-14"
)


def check_relay_table(text):
    """§3-1 lists every relay harness with lane.event and the sender's checks."""
    sec = flat(section(text, RELAY_31))
    rows = re.findall(r"\|\s*([a-z]+)\s*\|\s*✅\s*\|", sec)
    assert rows == list(HARNESSES), f"relay §3-1 rows {rows}, want {list(HARNESSES)}"
    assert "**배달 확인" in sec, "relay §3-1 배달 확인 list missing"
    start = sec.index("**배달 확인")
    end = sec.find("**`comms-contract: v1`**", start)
    assert end != -1, "relay §3-1 delivery-check paragraph not followed by comms-contract"
    checks = sec[start:end]
    for phrase in DELIVERY_CHECKS:
        assert phrase in checks, f"relay §3-1 delivery check missing: {phrase}"
    assert "ssh <host> herdr agent read" in checks, (
        "relay §3-1 remote delivery check (ssh <host> herdr agent read) missing"
    )


def check_ops_stale(skills):
    """The claude-only exception may not come back anywhere under skills/ops."""
    for name, text in skills.items():
        if not name.startswith("skills/ops/"):
            continue
        m = OPS_STALE.search(flat(text))
        assert not m, f"{name}: stale claude-only relay rule {m.group(0)!r}"


def check(d):
    for doc, heading, row, pattern in REQUIRED:
        scope = flat(section(d[doc], heading) if heading else d[doc])
        assert re.search(pattern, scope), f"{doc}: row '{row}' missing or weakened"
    for doc, row, pattern, _ in FORBIDDEN:
        assert not re.search(pattern, flat(d[doc])), f"{doc}: forbidden row '{row}' present"
    for doc in ("consult", "questions"):
        for kind, command in ONCE.items():
            n = d[doc].count(command)
            assert n == 1, f"{doc}: [consult-done] {kind} command appears {n} times, want 1"
    check_relay_table(d["relay"])


def check_skills(skills):
    for name, text in skills.items():
        for lineno, line in enumerate(text.splitlines(), 1):
            if "Temporary" in line or "temporary relief" in line:
                assert MARKER.match(line), f"{name}:{lineno}: temporary rule without the marker line: {line.strip()[:80]}"
        for row, pattern, _ in SCANS:
            assert not re.search(pattern, flat(text), re.IGNORECASE), f"{name}: forbidden '{row}' present"


check(docs)
check_skills(SKILLS)
check_ops_stale(SKILLS)
print(f"PASS rule-consistency required={len(REQUIRED)} forbidden={len(FORBIDDEN)} once={2 * len(ONCE)} scans={len(SCANS) + 2} skill-files={len(SKILLS)}")

count = 0
for doc, heading, row, pattern in REQUIRED:
    expect_red(f"{doc}-{row}-deleted", check, {**docs, doc: delete_row(docs[doc], heading, pattern, row)})
    count += 1
for doc, row, pattern, injected in FORBIDDEN:
    expect_red(f"{doc}-{row}-injected", check, {**docs, doc: docs[doc] + injected})
    count += 1
for doc in ("consult", "questions"):
    for kind, command in ONCE.items():
        expect_red(f"{doc}-{kind}-copied", check, {**docs, doc: docs[doc] + f"\n```bash\n{command} x | y'\n```\n"})
        count += 1
first = next(iter(SKILLS))
for row, _, injected in SCANS:
    expect_red(f"skills-{row}-injected", check_skills, {**SKILLS, first: SKILLS[first] + injected})
    count += 1
expect_red("skills-unmarked-temporary", check_skills, {**SKILLS, first: SKILLS[first] + "\n**Temporary relief (operator 2026-11-04).** Until hk 1 lands.\n"})
expect_red("skills-marker-without-condition", check_skills, {**SKILLS, first: SKILLS[first] + "\n*Temporary (operator 2026-11-04, hk 1).*\n"})
count += 2

# The relay table names exactly the six harnesses, each on lane.event.
for harness in HARNESSES:
    row = f"| {harness} | ✅ |"
    mutated = docs["relay"].replace(row, "", 1)
    assert mutated != docs["relay"], f"fixture: relay row {harness} not found"
    expect_red(f"relay-harness-{harness}-deleted", check, {**docs, "relay": mutated})
    count += 1
for label, row, replacement in (
    ("relay-harness-cmd-not-relayed", "| cmd | ✅ |", "| cmd | ❌ |"),
    ("relay-harness-extra", "| cmd | ✅ |", "| cmd | ✅ |\n| kiro | ✅ |"),
):
    mutated = docs["relay"].replace(row, replacement, 1)
    assert mutated != docs["relay"], f"fixture: relay row {row!r} not found"
    expect_red(label, check, {**docs, "relay": mutated})
    count += 1

# The sender's delivery checks are named in §3-1.
for i, phrase in enumerate(DELIVERY_CHECKS):
    mutated = docs["relay"].replace(phrase, "아무 확인")
    assert mutated != docs["relay"], f"fixture: delivery check {phrase!r} not found"
    expect_red(f"relay-delivery-check-{i}-removed", check, {**docs, "relay": mutated})
    count += 1

# The deleted claude-only exception may not come back under skills/ops.
STALE_LINES = (
    "claude panes only",
    "claude pane 에만",
    "claude pane에만",
    "non-claude parent",
    "비-claude pane",
    "*Temporary (desk 2026-09-14, hk 3132): ends when panewire #252 is fixed.*",
)
ops_skill = "skills/ops/SKILL.md"
for i, line in enumerate(STALE_LINES):
    expect_red(f"ops-stale-{i}-injected", check_ops_stale,
               {**SKILLS, ops_skill: SKILLS[ops_skill] + "\n" + line + "\n"})
    count += 1

print(f"PASS mutants assertion-red={count}/{count}")
PY
