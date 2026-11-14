# consult — 강모델 자문 왕복

**`comms-contract: v1`** (정본 = `relay.md` §3-1).
🔴 **자문 패킷 머리에 이 줄을 그대로 옮겨 적는다.** 자문가는 이 판을 보고 완료 통지 방식을 정한다.

**원칙 1: 자문자는 이 대화의 컨텍스트가 없다** — 질문 패킷은 자족적이어야 한다.
**원칙 2: 자문 답변의 효력은 `wake` §Authority 가 정한다** — 채택 여부는 질의 세션의 계약과
운영자 승인 범위를 따른다.
**원칙 3: 자문 맥락은 추적 가능해야 한다** — pane 세션 스폰이 기본(운영자가 사후에 어떤
질문·답이 오갔는지 herdr에서 확인 가능 + 같은 세션에 후속 재질의 가능). headless 1회성은
간단한 단답 확인용 예외.

## 1. 자문처 결정

- 질의 전 요청자 레인이 hub에 등록되어 있는지 확인한다. 미등록 레인의 emit은 조용히 유실된다
  (근거: 2026-09-14 실사고 — 6건 전량 드롭, 부분 배달 0).
- **세션 이름 지정 시**: `panewire find <이름>`으로 상존·화면 확인 → 있으면 **`relay.md`의 질의
  절차**로 질의. 없으면 아래 경로로.
- **자문은 질문자 task grade 보다 한 단계 위, 다른 계열에 묻는다.** task 가 없는 세션은 S+ 에 묻는다.
  **디자인 세션은 SS 에, 세션과 다른 계열의 SS 좌석에 묻는다** — 방향을 한 번에 잡아야 하기 때문이다
  (operator decision 124, 2026-11-12); task 가 없는 다른 세션은 S+ 에 머문다. 어느 좌석이 SS 인지는
  hk:doc `policy/model-families` §Consult 가 정한다 — 이 문서는 모델명을 적지 않는다. S+ 급 질문자의
  자문은 SS 급 rung 으로 간다. SS 급 질문자는 다른 계열의 SS 급 rung 에 묻는다.
  등급 없는(unrated) rung 은 쓰지 않는다(hk:doc `policy/model-families` §Consult, A17 항목 3). panewire 는 이
  규칙을 아직 계산하지 않는다(hk 3917 항목 3). 프로필을 고르는 길은 그래도 아래 resolve 명령
  하나뿐이다: 결과가 이 규칙에 맞지 않으면 다른 프로필을 직접 고르지 말고 부모 레인에 결정을 올린다.
- *Temporary (operator 2026-11-12, hk 4173): ends when the resolve command computes the consult floor (hk 4139).*
  **예외 — 디자인 세션의 SS 고정.** resolve 의 답이 다른 계열의 SS 좌석이 아니면, 디자인 세션은 hk:doc
  `policy/model-families` §Consult 가 다른 계열의 SS 좌석으로 이름한 프로필과 effort 를 `-m <profile> --effort <e>` 로
  고정하고 `--override-reason 'consult SS, decision 124' --containment hk:<task>` 를 줄 수 있다(`<task>` 는 자문의
  hk task). 기본(default) 행이므로 `--operator-request` 는 적용 대상이 아니어서 주지 않는다.
  *Temporary (operator 2026-11-12, hk 4215): ends when panewire lifts the purpose limit (hk 4212).*
  그 좌석이 openai 계열이면 `--purpose architect` 를 추가한다.
  그 밖의 세션은 resolve 경로 하나만 쓴다 — 맞지 않으면 부모 레인에 결정을 올린다. 이것이 "resolve 가 유일한 길" 규칙의 유일한 예외다.
- **프로필·계열·effort 는 hk `policy/model-routing` 이 정한다** — 이 문서에 모델명이나 자격표를
  적지 않는다. 고르는 방법:
  `panewire resolve --role consult` 의 마지막 줄 `profile=<이름> effort=<rung>` 을 스폰의
  `-m`·`--effort` 로 쓴다. resolve 가 거부하면 다른 프로필을 직접 고르지 말고 부모 레인에 결정을
  올린다(`ops` §Escalate a decision). 질문자는 계열도 직접 확인한다: resolve 출력의 `chosen seat=<seat> model=<provider>/<model> pool=<pool> ...`
  줄(마지막 줄 앞에 찍힌다)에서 `model=` 의 `<provider>` 접두가 고른 프로필의 계열이다(예: `model=openai/gpt-6.1-sol` → `openai`). 질문자와 같은 계열이면 다른 프로필을 직접 고르지 말고 부모 레인에
  결정을 올린다(`ops` §Escalate a decision). panewire 는 이 계열 규칙을 아직 강제하지 않는다.
- 운영자 명시 전용 프로필은 gate 가 거부 사유로 필요한 인자를 알려준다: `consult_only` →
  `--operator-request hk:doc/<승인-문서-키>`(또는 `hk:task/<정수>`), `--purpose` 를 요구하면 그
  값을 준다(`operator_request_not_applicable` 이면 요청 참조를 빼고 `--purpose` 를 쓴다). 필요·근거는
  자문 패킷 자체에 적는다.

## 2. 질문 패킷 (자족성 체크리스트)

①배경 2~5줄(자문자가 모르는 전제) ②구체 질문(판정 형식 지정: 선택지/근거/확신도)
③근거 자료 — 파일 경로 + 핵심 발췌 병기(자문 세션 cwd에서 접근 가능한지 확인)
④"모르면 '모름'과 근거 — 추측 금지" ⑤시크릿·credential 값 제외 ⑥답변자는 답변 파일
작성 직후 §3 의 `panewire done` 으로 답을 hk 에 올리고(스폰된 자문 잡이면 패킷에 잡 id 를 적는다),
이어서 아래 통지를 반드시 실행한다(스폰된 자문 잡이면 통지 전에 아래 sha 확인을 한다: 일치하면 확인한 그 키를 `hk:doc/<확인한 키>` 로 적고
(예: `hk:doc/reports/consult-r9-fable/answer-r2.md`), 불일치·빈 목록·명령 실패면 `hk:doc/<확인한 키>` 대신 로컬 답변 파일 경로를 쓰고 끝에 `(hk upload failed)` 를 붙인다.
스폰 없는 질의는 로컬 답변 파일 경로를 쓴다 — operator 2026-11-09, hk 3714).
수신 하네스가 달라도 경로는 하나다(`relay.md` §3-1):

```bash
panewire emit --kind lane.event --lane <요청자 레인> --type ready --event-id <고유id> --text '[consult-done] <1줄 요지> | hk:doc/<확인한 키>'
```

## 3. 실행 — 자문 pane 스폰 (기본)

```bash
# 이름: consult-<주제> (전역 유일). cwd = 질의 대상 자료가 있는 repo/디렉토리
panewire spawn -c <dir> -m <프로필> -p <질문패킷파일> -w <ws> -l consult-<주제> --t <task 의 T> \
  --role consult --keep --override-reason '<사유: panewire resolve 결과>' \
  [--parent-job <내 잡>] --report ~/work/herdr-inbox/jobs/consult-<주제>/answer.md --effort <resolve 의 rung>
```
- 자문도 task 에 묶인다(`spawn.md` §무인 실행·task 기록). 잡 안의 pane 이면 `ARBITER_JOB` 으로
  부모 잡을 상속하고, 아니면 `--parent-job <관련 잡>` 을 주거나 자문용 hk task(제목에
  `(grade <G>, T0)`)를 만들어 `--task` 로 준다. `--t` 는 묶인 task 표식의 T 와 같아야 한다.
- `--report` 는 자문 잡(또는 부모 잡) 디렉터리 안이어야 하므로 답변 파일도 그 경로로 지정한다.
- `--keep` 은 보호 표시다(#603): 자문 세션은 답변 뒤에도 후속 질의를 받으므로 `panewire reap` 이
  후보로 올리지 않고, mergewake reap 도 `consult-*` 이름을 닫지 않는다. 다 쓴 자문 pane 은
  요청자가 직접 닫는다.
- 주입·제출검증 = **`relay.md` §3**, 완료 통지·배달 확인의 정본과
  답변 회수 분기는 **`relay.md` §3-1** 및 **session-questions.md §1**(답변 파일 계약)를 따른다.
- **Store the answer in hk before the notice.** The answerer runs `panewire done <consult job> --report <answer file>`
  right after writing the answer, then the `[consult-done]` emit. `<consult job>` is the spawn's job id
  (the `-l consult-<주제>` label unless `--job` was given). This uploads the file to hk as
  `reports/<consult job>/<file name>` and sets the job record's `report_doc`. The emit alone runs no
  `panewire done`, so without this step the answer stays only in the job dir on the answerer's host.
  A follow-up round runs it again; a changed answer at the same path is stored as `answer-r<N>.md`.
- **Confirm the sha before `[consult-done]`.** Same check as `wake` §Done: newest round by the newest-round rule, then
  `handoffkeep doc get <that key> | jq -r .sha256` against `shasum -a 256 <answer file>`. On a match the notice names that exact key as `hk:doc/<key>`
  (for example `hk:doc/reports/consult-r9-fable/answer-r2.md`; operator 2026-11-09, hk 3714);
  on a mismatch, an empty list or any failure (a failed follow-up upload leaves an older round), the notice names the local
  answer path and appends `(hk upload failed)`.
- **The asking session reads the answer from hk** after the inbox item arrives (design and desk lanes are inbox-only, `watching.md` §Inbox wake line).
  A notice that names `hk:doc/<key>`: read that exact key with `handoffkeep doc get <key>` — no prefix listing, no newest-round selection.
  If that get fails or its `job` field is not your consult job, the answer is unavailable: ask the answerer for a new `panewire done`, never an older round (operator 2026-11-09, hk 3714).
  A notice with `(hk upload failed)` means do not read hk (never an older round): the failure-marker check in the newest-round rule.
  **Legacy fallback** (a notice that names a local path without the marker, from an answerer on an older install): find the newest with `handoffkeep doc list --prefix reports/<consult job>/` (newest-round rule, `wake` loop step 8: highest `-rN`, else the base name, over only the keys starting with the literal `reports/<consult job>/`;
  a follow-up is stored as `answer-r<N>.md`) and `handoffkeep doc get <key>`.
- 자문자는 답변 파일을 작성한 직후 §2 의 `[consult-done]` 통지를 실행한다(`panewire emit`).
  대기·기한 후 확인·착지 확인 분기는 **`relay.md` §3-1 정본**을 따른다.
- 이벤트 수신 뒤 파일이 없으면 ①`herdr agent read <target> --lines 40`으로
  답변이 화면에만 있는지 확인 — 있으면 "파일 미작성, 화면 전사본" 명시 ②없으면
  "무응답 (기한 N분 경과)"으로 보고하고 운영자에게 표면화한다. 재질의는 1회까지, 헤더에
  `[재질의 — 이전 질의 무응답]`을 명시한다.
- `emit` rc=0 의 의미, 누가 도착을 확인하는지, 배달 확인 절차는 **`relay.md` §3-1 정본**만 따른다(여기에 다시 적지 않는다).
- 자문 세션은 답변 후 **바로 정리하지 않는다** — 운영자 맥락 검토·후속 재질의용으로 유지,
  정리는 운영자 몫(자문 pane은 회수 후 종료).
- 자문 난도가 높으면 **2계열 교차 자문**(서로 다른 계열 두 곳)으로 판정 일치 여부까지 확인 —
  불일치면 그 자체가 "운영자 표면화" 신호다.
- **상존 세션 질의가 나은 경우**: 그 세션의 컨텍스트가 자산일 때(예: 디자인 세션의 전황, 분석을
  직접 쓴 세션). 이때는 스폰 없이 `relay.md`의 질의 절차로.
- (예외) 단답 확인·형식 검증처럼 맥락 보존 가치가 없는 질문만 headless 1회성 허용 — 모델과
  effort 는 같은 `panewire resolve --role consult` 결과를 그 하네스의 비대화형 실행에 넘긴다.

## 4. 회수·기록·채택

- 자문 답변은 스폰 때 정한 `--report` 경로(`~/work/herdr-inbox/jobs/consult-<주제>/answer.md`)에
  쓰고(`panewire done --report` 의 입력이자 scratch), `panewire done` 으로 hk `reports/<consult job>/` 에 올린다(§3).
  정본은 hk 다. 통지가 `hk:doc/<키>` 를 적었으면 그 키를 `handoffkeep doc get <키>` 로 바로 읽고(prefix 나열·최신 라운드 선택 없음,
  get 실패나 다른 잡의 문서면 답 없음으로 보고 새 `panewire done` 을 요청한다 — 이전 라운드 금지), 통지에 `(hk upload failed)` 가 있으면 hk 를 읽지 않는다(최신 라운드 규칙의 실패 표지 확인).
  마커 없이 로컬 경로만 적은 레거시 통지면 `handoffkeep doc list --prefix reports/<consult job>/` 로 나온 키를 최신 라운드 규칙(`wake` loop step 8: 리터럴 `reports/<consult job>/` 로 시작하는 키만 남기고,
  가장 높은 `-rN`, 없으면 기본 이름)으로만 골라
  `handoffkeep doc get <key>` 로 읽는다.
  스폰 없는 상존 세션 질의는 `session-questions.md` §1 경로를 쓴다.
- 보고: 질문 요지 / 자문처(모델·계열·pane) / 핵심 답변 / 교차 자문 시 일치 여부 / **채택·
  기각과 그 이유는 질의 세션이 별도로 판단해 기록**.
- 자문 결과로 승인 범위 밖 행동이 필요해지면 → 실행하지 말고 운영자에게 결정 요청.

## 설계 배경

- 기존 "단일 모델 지정 자문 프로토콜"(세션→inbox→지정 모델 답변)의 일반화 — 자문처를 이름이 아닌
  **능력(티어)**으로 지정해 세션 생멸과 무관하게 동작한다.
- pane 스폰이 기본인 이유(07-29 운영자 결정): headless는 싸지만 자문 맥락이 어디에도 안
  남는다 — 운영자가 "무슨 근거로 그 판단이 나왔나"를 사후 추적하려면 pane 세션이 필요하고,
  같은 자문자에게 이어서 물을 수도 있다.
