# decision-request — 운영자 결정 요청

## 운영자 결정 요청 — hk 에 먼저 기록, 알림은 request_id 로

hk:doc `policy/operator-facing-korean`을 따른다: 운영자 대상 글은 한국어로 쓰고 식별자, 코드와 명령은 그대로 두며 영어만 허용되는 글에는 한국어 번역을 저장한다.

운영자에게 선택지를 묻는 결정 요청은 **pane 에 보내기 전에** hk 에 기록한다. 기록이 정본이고
pane 메시지는 그 알림이다. 콘솔(큐 drawer · Decisions)은 이 기록만 읽는다.

    handoffkeep tasks decision-request <task-id> --question "<질문>" \
      --option 'A|<요약>' --option 'B|<요약>' [--recommended A --reason "<권고 이유>"] \
      --default-action "<무응답 시 동작 — 없으면 '자동 적용 없음'>" [--default-option B] \
      [--default-trigger "<발동 조건>"] [--due <RFC3339+오프셋>] [--doc <결과·근거 문서 key>] [--block] [--human-only]

- Any `decision-request` about merge, deploy, spend (money, paid quota, purchases), tokens/credentials/external access, host/security settings, or policy/gate/cap exceptions MUST carry `--human-only`; assistant judgement must never answer these (hk refuses `human_only` on that path). If unsure, use `--human-only`.
- GPT Dots may answer a `human_only` request only as `operator_decided`, with the operator's verbatim quote and exact `request_id`; GPT Dots' own judgement never closes it.

- **기록 먼저, 알림에 request_id.** 출력의 `request_id`(`dr-<task>-<rev>`)를 붙여 알린다
  (출력 `notify` 줄). 명령이 실패하면(`NOT recorded`) 기록되지 않은 것이다 — 그때는
  "콘솔에서 보인다"고 통지하지 않는다.
- **결과 미확인(`UNKNOWN`, exit 4)이면 확인 먼저.** 요청이 서버에 간 뒤 연결·시간초과·응답 오류로 쓰기
  결과를 확인할 수 없을 때 CLI 는 `outcome UNKNOWN`을 낸다. 누구에게도 알리기 전에
  `handoffkeep tasks show <task-id>`로 `refs.decision_request`를 확인하고, 그 전에는 "기록됐다"도
  "기록 안 됐다"도 말하지 않는다(같은 명령을 그대로 재전송하면 기록된 요청이 duplicate 로 돌아온다).
- **권고와 무응답 동작은 별개다.** `--recommended`는 권고, `--default-action`은 답이 없을 때의
  동작이다(예: 권고 A, 무응답 시 "보류하고 다음 태스크"). 응답 기한은 `--due`로 따로 둔다.
- **label 은 120바이트**(한글 120자가 아니다 — 약 40자). 긴 결과 설명·근거는 `--doc` 문서에 둔다.
- 재전송은 같은 명령을 그대로 다시 실행한다 — 같은 request_id 가 돌아온다(`duplicate`).
  질문·선택지를 바꾸려면 `--supersedes <이전 request_id>`로 새 revision 을 만든다. 옛 답은 새
  요청에 붙지 않는다.
- 작업을 멈추는 요청이면 `--block`(같은 기록에서 그 태스크가 `awaiting_decision` 으로 표시된다). 멈추지 않는 요청은 태스크
  상태를 그대로 둔다 — 열린 요청은 어떤 상태의 태스크에서도 콘솔에 뜬다.
- 답이 오면 `handoffkeep tasks decision-resolve <task-id> --request <request_id> --kind answered
  --option A --responder operator`로 닫는다. 기본값을 적용했으면 `--kind default_applied
  --receipt <적용 증거>` — **기한 경과는 적용이 아니다.** 영수증 없이는 "적용됨"으로 기록되지
  않고 자동 적용 타이머도 없다. 철회는 `--kind withdrawn --text <이유>`.
- 종료(merged·dropped)된 태스크에 열린 요청이 남으면 콘솔에 "미정리 요청"으로 뜬다 —
  `decision-resolve`로 정리한다.
- 콘솔의 답변 버튼은 #580 소관이다. 그 전까지 운영자는 pane 으로 답하고 요청한 레인이 기록한다.

## 데스크 결정 루프

결정 요청이 약 120건 쌓였다(2026-11-03). 질문이 자유 글 lane event 로 나갔고, 채팅으로 받은 답은 기록되지
않았다. 데스크는 질문 하나를 아래 순서로 처리한다.

1. **질문 하나에 기록 하나.** 운영자에게는 `tasks decision-request` 로만 묻는다. lane event 나 채팅
   질문은 request_id 를 실은 알림일 뿐 기록이 아니다.
   한 질문의 선택지는 `tasks decision-request` 하나의 `--option` 값들이다. 선택지마다 `kind=decide`
   태스크를 따로 만들지 않는다.
2. **다시 물을 때는 같은 요청을 쓴다.** 같은 명령을 재실행하면 `duplicate` 가 돌아온다. 새 요청을 만들지
   않는다.
3. **채팅으로 받은 답은 같은 턴에 hk 에서 닫는다.** 그 답대로 움직이기 전에 닫는다. `--text` 에 운영자의
   말을 그대로 옮긴다:

       handoffkeep tasks decision-resolve <task-id> --request <request_id> --kind answered \
         --option <X> --responder operator --text '<운영자 원문>'

4. **진행은 해결이 아니다.** 일이 다른 길로 넘어갔으면 요청을 명시적으로 닫는다(`answered`,
   `withdrawn --text <이유>`, `default_applied --receipt <증거>`).
   결정이 채팅이나 다른 세션에서 났거나 그쪽으로 넘어갔으면, 물은 세션이 같은 턴에 그 `kind=decide`
   태스크를 닫거나 kind 를 바꾼다.
5. **resume 마다 열린 요청을 검토한다**(`desk` §Resume 3번). `--due` 가 지났거나, `--due` 가 없고 48시간이
   지난 요청마다 처분을 하나 정한다: 닫기, 철회, 또는 새 기한으로 한 번 다시 묻기. request_id 없는 decision
   lane event 는 `decision-request` 로 기록하거나, 낡은 것이면 `panewire inbox ack <id>` 로 치운다.
