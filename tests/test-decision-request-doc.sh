#!/usr/bin/env bash
# #618 AC5: ops/references/decision-request.md must keep the decision-request contract
# (hk:doc task/2026-09-24/console-req-1 수정 AC A2·A3·A6·A7):
#
#   1. the CLI line `handoffkeep tasks decision-request` with the separate
#      recommendation / no-response / deadline flags;
#   2. record first, then notify with the returned request_id, and never
#      claim console visibility when the record failed (A6);
#   3. recommendation and default action are separate (A2);
#   4. a passed deadline is not an application; applied needs a receipt (A3);
#   5. the label limit is 120 bytes, not 120 characters (A7);
#   6. mutants (each rule removed) go RED through an assertion.
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
doc_path = Path(os.environ.get("DECISION_REQUEST_DOC", root / "skills/ops/references/decision-request.md"))
doc_text = doc_path.read_text(encoding="utf-8")

HEADING = "## 운영자 결정 요청"


def check(text: str) -> None:
    raw_section = section(text, HEADING)
    sec = flat(raw_section)
    assert "handoffkeep tasks decision-request" in sec, "decision-request CLI line missing"
    for flag in ("--question", "--option", "--recommended", "--default-action", "--due"):
        assert flag in sec, f"CLI line must carry {flag}"
    # Keep the safety flag in the CLI template itself; a mention in prose
    # must not mask its removal from the producer command.
    cli_lines = raw_section.splitlines()
    cli_start = next((i for i, line in enumerate(cli_lines) if "handoffkeep tasks decision-request" in line), None)
    assert cli_start is not None, "decision-request CLI line missing"
    cli_block = [cli_lines[cli_start]]
    while cli_block[-1].rstrip().endswith("\\"):
        next_line = cli_start + len(cli_block)
        assert next_line < len(cli_lines), "decision-request CLI continuation is incomplete"
        cli_block.append(cli_lines[next_line])
    assert "--human-only" in flat("\n".join(cli_block)), "decision-request CLI line must carry --human-only"
    # hk 5131 (operator decision 396 grounds, decision 339 list): --human-only is the operator-only list
    # of hk:doc policy/operator-not-a-gate, not every merge or deploy question.
    assert re.search(
        r"operator-only list of hk:doc `policy/operator-not-a-gate` §What stays the operator's alone \(decision 339\) MUST carry `--human-only`",
        sec,
    ), "human_only scope rule (decision 339 operator-only list) missing"
    assert "Any `decision-request` about merge, deploy" not in sec, "old merge/deploy human_only list still present"
    assert re.search(
        r"Merge, deploy and settings questions are not on that list: they may be answered from dots with the operator's quoted words",
        sec,
    ), "merge/deploy/settings not-human_only rule missing"
    assert re.search(r"assistant judgement must never answer these.{0,100}hk refuses `human_only`", sec), "human_only assistant refusal reason missing"
    assert re.search(r"If unsure.{0,40}`--human-only`", sec), "human_only default-when-unsure rule missing"
    assert re.search(r"`human_only` 요청은 콘솔에서 답한다", sec), "human_only console-answer rule missing"
    assert "pending_confirmation" in sec, "decision-resolve pending_confirmation fact missing"
    assert re.search(
        r"\*Temporary \(operator 2026-11-18, hk 5131\): ends when handoffkeep hk 5132 ships \(hk 5132\)\.\*",
        sec,
    ), "hk 5132 temporary marker missing"
    # hk 5131 (2a): a question with no task gets a kind=decide task in the asking lane's project first.
    assert re.search(r"태스크가 없는 질문은 요청 전에 먼저 질문하는 레인의 프로젝트에 `kind=decide` 태스크를 만든다", sec), "no-task question kind=decide rule missing"
    assert re.search(r"dots.{0,60}operator-only 요청에 답할 수 없다", sec), "dots operator-only refusal missing"
    assert "RefuseOperatorOnly" in sec, "hk refusal reason missing"
    assert "DecisionResultPendingConfirmation" in sec, "pending-confirmation fact missing"
    assert re.search(r"답이 오는 곳은 pane, 콘솔, dots 중 하나다", sec), "answer channels missing"
    assert re.search(r"pane 으로 받은 답은 같은 턴에 운영자의 말 그대로", sec), "pane-answer same-turn close missing"
    assert re.search(r"inbox 알림이 아니라 hk 기록", sec), "hk-record-over-notice rule missing"
    assert "GPT Dots may answer a `human_only` request only as `operator_decided`" not in sec, "removed GPT Dots sentence still present"
    assert "#580" not in sec, "removed #580 sentence still present"
    assert re.search(r"기록 먼저.{0,40}request_id", sec), "record-first-then-notify-with-request_id rule missing (A6)"
    assert re.search(r"NOT recorded.{0,80}통지하지 않는다", sec), "no console-visibility claim on a failed record (A6)"
    # M2 (#48): an unconfirmable write is UNKNOWN — check tasks show before
    # notifying, and claim neither recorded nor not recorded.
    assert re.search(r"UNKNOWN.{0,200}handoffkeep tasks show", sec), "UNKNOWN outcome must send the requester to tasks show first"
    assert re.search(r"알리기 전에.{0,120}tasks show", sec), "tasks show must come before any notification"
    assert re.search(r"\"기록됐다\"도\s*\"기록 안 됐다\"도 말하지 않는다", sec), "UNKNOWN must forbid both recorded and not-recorded claims"
    assert re.search(r"권고와 무응답 동작은 별개", sec), "recommendation/default separation missing (A2)"
    assert re.search(r"기한 경과는 적용이 아니다", sec) and "--receipt" in sec, "deadline != applied / receipt rule missing (A3)"
    assert re.search(r"120바이트.{0,40}120자가 아니다", sec), "120-byte (not character) label limit missing (A7)"
    assert "--supersedes" in sec and "decision-resolve" in sec, "supersede and resolve lines missing"


check(doc_text)
print("PASS decision-request.md contract")

mutants = [
    ("cli-line-removed", doc_text.replace("handoffkeep tasks decision-request", "handoffkeep tasks transition")),
    ("human-only-cli-flag-removed", doc_text.replace("[--block] [--human-only]", "[--block]", 1)),
    ("human-only-rule-removed", re.sub(r"(?m)^- A `decision-request` on the operator-only list.*\n", "", doc_text, count=1)),
    ("human-only-old-merge-deploy-list-readded", doc_text.replace(HEADING, HEADING + "\n- Any `decision-request` about merge, deploy, spend (money, paid quota, purchases), tokens/credentials/external access, host/security settings, or policy/gate/cap exceptions MUST carry `--human-only`.", 1)),
    ("merge-deploy-as-human-only-readded", doc_text.replace("Merge, deploy and settings questions are not on that list", "Merge, deploy and settings questions are on that list", 1)),
    ("human-only-console-answer-removed", doc_text.replace("`human_only` 요청은 콘솔에서 답한다", "`human_only` 요청도 dots 에서 답한다", 1)),
    ("pending-confirmation-fact-removed", doc_text.replace("(`pending_confirmation`)", "", 1)),
    ("hk-5132-temporary-marker-removed", doc_text.replace("*Temporary (operator 2026-11-18, hk 5131): ends when handoffkeep hk 5132 ships (hk 5132).*", "", 1)),
    ("no-task-kind-decide-removed", doc_text.replace("태스크가 없는 질문은 요청 전에 먼저 질문하는 레인의 프로젝트에 `kind=decide` 태스크를 만든다", "태스크가 없는 질문은 그냥 묻는다", 1)),
    ("record-first-removed", doc_text.replace("기록 먼저, 알림에 request_id", "알림")),
    ("failed-record-claim", doc_text.replace("통지하지 않는다", "통지한다")),
    ("default-merged-into-recommendation", doc_text.replace("권고와 무응답 동작은 별개다", "권고가 곧 기본값이다")),
    ("deadline-means-applied", doc_text.replace("기한 경과는 적용이 아니다", "기한이 지나면 적용된 것으로 본다")),
    ("label-120-chars", doc_text.replace("120바이트**(한글 120자가 아니다", "120자**(")),
    ("section-removed", doc_text.replace(HEADING, "## 기타")),
    ("unknown-line-removed", re.sub(r"(?m)^- \*\*결과 미확인.*?(?=^- \*\*권고와)", "", doc_text, flags=re.S)),
    ("unknown-claims-not-recorded", doc_text.replace("\"기록됐다\"도\n  \"기록 안 됐다\"도 말하지 않는다", "\"기록 안 됐다\"고 알린다")),
    ("unknown-notify-first", doc_text.replace("누구에게도 알리기 전에", "알린 뒤에")),
    ("dots-refusal-removed", re.sub(r"(?m)^- ChatGPT\(dots\) 채널은.*\n", "", doc_text, count=1)),
    ("refuse-token-removed", doc_text.replace("RefuseOperatorOnly", "Allowed", 1)),
    ("pending-token-removed", doc_text.replace("DecisionResultPendingConfirmation", "Confirmed", 1)),
    ("answer-channels-removed", re.sub(r"(?m)^- 답이 오는 곳은 pane.*\n", "", doc_text, count=1)),
    ("pane-close-removed", doc_text.replace("pane 으로 받은 답은 같은 턴에 운영자의 말 그대로", "pane 답은 나중에", 1)),
    ("hk-record-removed", doc_text.replace("inbox 알림이 아니라 hk 기록", "inbox 알림대로", 1)),
    ("dots-may-answer-human-only-readded", doc_text.replace(HEADING, HEADING + "\n- GPT Dots may answer a `human_only` request only as `operator_decided`, with the operator's verbatim quote and exact `request_id`; GPT Dots' own judgement never closes it.", 1)),
    ("console-button-580-readded", doc_text.replace(HEADING, HEADING + "\n- 콘솔의 답변 버튼은 #580 소관이다. 그 전까지 운영자는 pane 으로 답하고 요청한 레인이 기록한다.", 1)),
]
for label, text in mutants:
    assert text != doc_text, f"{label} mutant did not change the text"
    expect_red(label, lambda t=text: check(t))
print(f"PASS mutants assertion-red={len(mutants)}/{len(mutants)}")
PY
