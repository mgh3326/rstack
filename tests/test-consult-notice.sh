#!/usr/bin/env bash
# hk 3714 (operator 2026-11-09): the `[consult-done]` notice names the exact hk
# doc key the answerer's sha check matched, and the asker reads that key.
#   1. answerer (consult.md §2 packet item 6, the emit example, §3 sha check):
#      on a match the notice is `[consult-done] <요지> | hk:doc/<key>`; on a
#      mismatch, an empty list or a failure it names the local answer path
#      and appends `(hk upload failed)`;
#   2. asker (consult.md §3 and §4, wake loop step 8): an `hk:doc/<key>` notice
#      is read with `handoffkeep doc get <key>`, with no prefix listing and no
#      newest-round selection; a failed get or another job's doc is
#      unavailable, never an older round; the prefix listing survives only
#      as the labelled legacy fallback.
# Every required row has a deletion mutant, and the load-bearing tokens have
# substitution or injection mutants; each must go RED by assertion.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import delete_row, expect_red, flat, section  # noqa: E402

docs = {
    "consult": (root / "skills/ops/references/consult.md").read_text(encoding="utf-8"),
    "wake": (root / "skills/wake/SKILL.md").read_text(encoding="utf-8"),
}

L = re.escape  # rows are literal text
PACKET = "## 2. 질문 패킷 (자족성 체크리스트)"
COLLECT = "## 4. 회수·기록·채택"
# consult §3 opens with a bash block whose `# 이름:` comment ends section() early, so §3 rows scope the whole doc.

# (doc, section heading or None, row name, pattern on the flattened scope)
REQUIRED = [
    # Answerer: the emit example names the hk key; the packet says which key and when not.
    ("consult", PACKET, "emit-names-hk-key",
     L("--text '[consult-done] <1줄 요지> | hk:doc/<확인한 키>'")),
    ("consult", PACKET, "packet-match-names-key",
     L("일치하면 확인한 그 키를 `hk:doc/<확인한 키>` 로 적고")),
    ("consult", PACKET, "packet-mismatch-local-marker",
     L("불일치·빈 목록·명령 실패면 `hk:doc/<확인한 키>` 대신 로컬 답변 파일 경로를 쓰고 끝에 `(hk upload failed)` 를 붙인다")),
    ("consult", None, "sha-match-names-key",
     L("On a match the notice names that exact key as `hk:doc/<key>`")),
    ("consult", None, "sha-mismatch-local-marker",
     L("on a mismatch, an empty list or any failure (a failed follow-up upload leaves an older round), the notice names the local answer path and appends `(hk upload failed)`")),
    # Asker (§3): get the named key; nothing is selected.
    ("consult", None, "asker-gets-named-key",
     L("A notice that names `hk:doc/<key>`: read that exact key with `handoffkeep doc get <key>` — no prefix listing, no newest-round selection")),
    ("consult", None, "asker-get-fails-unavailable",
     L("If that get fails or its `job` field is not your consult job, the answer is unavailable: ask the answerer for a new `panewire done`, never an older round")),
    ("consult", None, "asker-upload-failed-no-hk",
     L("A notice with `(hk upload failed)` means do not read hk (never an older round)")),
    ("consult", None, "asker-legacy-labelled",
     L("**Legacy fallback** (a notice that names a local path without the marker, from an answerer on an older install):")),
    # Asker (§4, Korean).
    ("consult", COLLECT, "collect-gets-named-key",
     L("통지가 `hk:doc/<키>` 를 적었으면 그 키를 `handoffkeep doc get <키>` 로 바로 읽고(prefix 나열·최신 라운드 선택 없음")),
    ("consult", COLLECT, "collect-get-fails-unavailable",
     L("get 실패나 다른 잡의 문서면 답 없음으로 보고 새 `panewire done` 을 요청한다 — 이전 라운드 금지")),
    ("consult", COLLECT, "collect-legacy-labelled",
     L("마커 없이 로컬 경로만 적은 레거시 통지면")),
    # wake step 8: the newest-round rule knows the hk:doc notice.
    ("wake", "## The loop", "wake-hk-doc-selects-nothing",
     L("A `[consult-done]` notice that names `hk:doc/<key>` selects nothing: read that key with `handoffkeep doc get <key>`")),
    ("wake", "## The loop", "wake-legacy-labelled",
     L("Otherwise (READY, or a legacy `[consult-done]` naming a local path without the marker) list `handoffkeep doc list --prefix reports/<job>/`")),
]

READER = "doc list --prefix reports/<consult job>/"


def check(d):
    for doc, heading, row, pattern in REQUIRED:
        scope = flat(section(d[doc], heading) if heading else d[doc])
        assert re.search(pattern, scope), f"{doc}: row '{row}' missing or weakened"
    c = d["consult"]
    # The emit example's last field is the hk key, not a bare local path.
    emits = [l for l in c.splitlines() if "--text '[consult-done]" in l]
    assert emits and all("| hk:doc/" in l for l in emits), "consult emit example must name hk:doc/<key>"
    # An hk:doc notice is never resolved by listing the prefix: the branch up to the legacy label lists nothing.
    fc = flat(c)
    a = fc.find("A notice that names `hk:doc/<key>`")
    b = fc.find("**Legacy fallback**", a)
    assert 0 <= a < b, "consult §3: the hk:doc branch must come before the legacy fallback"
    assert "doc list" not in fc[a:b], "consult §3: the hk:doc branch must not list the prefix"
    fs = flat(section(c, COLLECT))
    a = fs.find("통지가 `hk:doc/<키>` 를 적었으면")
    b = fs.find("레거시 통지면", a)
    assert 0 <= a < b, "consult §4: the hk:doc branch must come before the legacy fallback"
    assert "doc list" not in fs[a:b], "consult §4: the hk:doc branch must not list the prefix"
    # Every prefix reader is the labelled legacy fallback.
    lines = c.splitlines()
    readers = [n for n, l in enumerate(lines) if READER in l]
    assert readers, "consult must keep the legacy prefix reader"
    for n in readers:
        w = " ".join(lines[max(0, n - 1):n + 1])
        assert "Legacy" in w or "레거시" in w, "unlabelled prefix reader: " + lines[n].strip()


check(docs)
print(f"PASS consult-notice rows={len(REQUIRED)}")

count = 0
for doc, heading, row, pattern in REQUIRED:
    expect_red(f"{doc}-{row}-deleted", check, {**docs, doc: delete_row(docs[doc], heading, pattern, row)})
    count += 1

# (label, doc, old text, new text): the weaker wording a reviewer would flag.
SUBSTITUTED = [
    ("emit-local-path", "consult", "| hk:doc/<확인한 키>'", "| <답변 파일 경로>'"),
    ("mismatch-no-marker", "consult", "끝에 `(hk upload failed)` 를 붙인다", "그대로 둔다"),
    ("sha-match-unchanged", "consult", "On a match the notice names that exact key as `hk:doc/<key>`", "On a match the notice is unchanged"),
    ("sha-mismatch-no-marker", "consult", "answer path and appends `(hk upload failed)`", "answer path"),
    ("asker-lists-prefix", "consult", "no prefix listing, no newest-round selection", "then list `handoffkeep doc list --prefix reports/<consult job>/` for a newer round"),
    ("asker-older-round", "consult", "never an older round (operator", "else read an older round (operator"),
    ("legacy-unlabelled", "consult", "**Legacy fallback** (a notice that names a local path without the marker, from an answerer on an older install): ", "Otherwise: "),
    ("collect-lists-prefix", "consult", "로 바로 읽고(prefix 나열·최신 라운드 선택 없음,", "로 읽되 `handoffkeep doc list --prefix reports/<consult job>/` 로 최신 라운드를 고르고(,"),
    ("collect-legacy-unlabelled", "consult", "마커 없이 로컬 경로만 적은 레거시 통지면", "그 밖에는"),
    ("wake-no-hk-doc", "wake", "A `[consult-done]` notice that names `hk:doc/<key>` selects nothing: read that key", "A `[consult-done]` notice selects as below"),
    ("wake-legacy-unlabelled", "wake", "Otherwise (READY, or a legacy `[consult-done]` naming a local path without the marker) list", "Otherwise list"),
]
for label, doc, old, new in SUBSTITUTED:
    mutated = docs[doc].replace(old, new)
    assert mutated != docs[doc], f"fixture: {label}: {old!r} not found"
    expect_red(f"sub-{label}", check, {**docs, doc: mutated})
    count += 1

# Injected: a bare prefix reader without the legacy label.
expect_red("unlabelled-reader-injected", check,
           {**docs, "consult": docs["consult"].replace("## 4. 회수·기록·채택", "- Read the newest with `handoffkeep " + READER + "`.\n\n## 4. 회수·기록·채택", 1)})
count += 1

print(f"PASS mutants assertion-red={count}/{count}")
PY
