#!/usr/bin/env bash
# Rules that drifted between skill files stay stated once and agree:
#   1. merge authority: every "no session merges" names wake §Direct merge;
#   2. a stuck or failed spawn is never respawned automatically (ops spawn);
#   3. the tracker is hk, never Linear (relay packet);
#   4. emit delivery and the non-claude exception live only in relay.md §3-1;
#      consult.md and session-questions.md point there and carry each
#      [consult-done] command once.
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
}
docs = {name: path.read_text(encoding="utf-8") for name, path in PATHS.items()}

# (doc, section heading or None, row name, pattern on the flattened scope)
REQUIRED = [
    ("robin", "## Fleet adapter for vendored pstack", "merge-exception",
     r"no session merges, except the design session under `wake` §Direct merge"),
    ("deploy", "## 발주자 측 — operator-desk", "merge-exception",
     r"디자인 세션의 머지는 `wake` §Direct merge\(임시 완화\)뿐이다"),
    ("spawn", "## 4. 기동·주입·감시", "stuck-no-respawn",
     r"stuck 으로 판정하고 스폰 실패로 다룬다 — 자동 재스폰하지 않는다"),
    ("relay", "## 1. 핸드오프 프롬프트 5요소", "hk-task", r"hk task 연결"),
    ("relay", "### 3-1. 완료 통지·pane kind 분기 정본", "sender-checks",
     r"\*\*지시를 보낸 쪽\*\*은 `herdr agent read <pane>`로 도착을 확인한다"),
    ("consult", None, "relay-pointer", r"\*\*`relay\.md` §3-1 정본\*\*만 따른다"),
    ("questions", None, "relay-pointer", r"\*\*`relay\.md` §3-1 정본\*\*만 따른다"),
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


check(docs)
print(f"PASS rule-consistency required={len(REQUIRED)} forbidden={len(FORBIDDEN)} once={2 * len(ONCE)}")

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
print(f"PASS mutants assertion-red={count}/{count}")
PY
