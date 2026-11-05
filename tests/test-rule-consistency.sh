#!/usr/bin/env bash
# Rules that drifted between skill files stay stated once and agree:
#   1. merge authority: every "no session merges" names the lead under `lead` §Ledger;
#   2. a stuck or failed spawn is never respawned automatically (ops spawn);
#   3. the tracker is hk, never Linear (relay packet);
#   4. emit delivery and the non-claude exception live only in relay.md §3-1;
#      consult.md and session-questions.md point there and carry each
#      [consult-done] command once;
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
    ("deploy", "## 발주자 측 — operator-desk", "merge-exception",
     r"디자인 세션은 머지하지 않는다\. 세션의 직접 머지는 lead 뿐이다\(`lead` §Ledger\)"),
    ("spawn", "## 4. 기동·주입·감시", "stuck-no-respawn",
     r"stuck 으로 판정하고 스폰 실패로 다룬다 — 자동 재스폰하지 않는다"),
    ("relay", "## 1. 핸드오프 프롬프트 5요소", "hk-task", r"hk task 연결"),
    ("relay", "### 3-1. 완료 통지·pane kind 분기 정본", "sender-checks",
     r"\*\*지시를 보낸 쪽\*\*은 `herdr agent read <pane>`로 도착을 확인한다"),
    ("consult", None, "relay-pointer", r"\*\*`relay\.md` §3-1 정본\*\*만 따른다"),
    ("questions", None, "relay-pointer", r"\*\*`relay\.md` §3-1 정본\*\*만 따른다"),
    ("robin", "## Where each rule lives", "marker-format",
     r"\*Temporary \(<who> <date>, hk <id>\): ends when <condition> \(<hk or issue id>\)\.\*"),
    ("fleet", "## Independence", "marker-same-family",
     r"\*Temporary \(operator 2026-11-04, hk 2856\): ends when hk 2857 lands and restores the rule \(hk 2857\)\.\*"),
    ("wake", "## Merge gate", "marker-ci-cutover",
     r"\*Temporary \(operator-desk 2026-11-03, hk 2788\): ends when the hk 2788 slice 5 cutover ships \(hk 2788\)\.\*"),
    ("relay", None, "marker-emit-exception",
     r"\*Temporary \(desk 2026-09-14, hk 3132\): ends when panewire #252 is fixed and the four-pane re-measurement after panewire #264 is all ✅ \(panewire #252/#264\)\.\*"),
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
    ("spawn", "auto-respawn", r"→ ?재스폰", "\n- stuck 판정→재스폰.\n"),
    ("relay", "linear", r"Linear 이슈", "\n5. Linear 이슈 등록.\n"),
]
for doc in ("consult", "questions"):
    FORBIDDEN += [
        (doc, "copied-exception", r"등록은 필요조건이지 충분조건이 아니다", "\n- 등록은 필요조건이지 충분조건이 아니다.\n"),
        (doc, "copied-removal-condition", r"#252 가 수리되면", "\n- #252 가 수리되면 이 예외를 삭제한다.\n"),
    ]

# (row name, pattern on every flattened skill file, text a mutant appends to the first skill file)
SCANS = [
    ("repo-session-term", r"repo session", "\nA repo session reads only hk.\n"),
    ("next-unit-rule", r"next unit", "\n🔴 The `next unit:` line decides whether a lead pane closes.\n"),
    ("closing-lead-pane", r"Closing a lead pane", "\n| Closing a lead pane | reap |\n"),
    ("stale-expected-until", r"Until the hk deploy ships", "\nUntil the hk deploy ships `--expected`, comment it.\n"),
    ("stale-subtask-until", r"hk 2770\)", "\nUntil hk has sub-tasks (hk 2770), comment it.\n"),
    ("stale-fields-until", r"Until hk has the fields", "\nUntil hk has the fields (hk 2771), comment it.\n"),
]

ONCE = {
    "emit": "panewire emit --kind lane.event --lane <요청자 레인> --type ready --event-id <고유id> --text '[consult-done]",
    "prompt": "herdr agent prompt <pane> '[consult-done]",
}


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


def check_skills(skills):
    for name, text in skills.items():
        for lineno, line in enumerate(text.splitlines(), 1):
            if "Temporary" in line or "temporary relief" in line:
                assert MARKER.match(line), f"{name}:{lineno}: temporary rule without the marker line: {line.strip()[:80]}"
        for row, pattern, _ in SCANS:
            assert not re.search(pattern, flat(text), re.IGNORECASE), f"{name}: forbidden '{row}' present"


check(docs)
check_skills(SKILLS)
print(f"PASS rule-consistency required={len(REQUIRED)} forbidden={len(FORBIDDEN)} once={2 * len(ONCE)} scans={len(SCANS) + 1} skill-files={len(SKILLS)}")

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
print(f"PASS mutants assertion-red={count}/{count}")
PY
