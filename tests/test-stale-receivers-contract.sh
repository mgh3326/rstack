#!/usr/bin/env bash
# Stale receiver, lead role, STUCK event and trailer-generation contract.
# Every required row has a deletion mutant; every forbidden row an injection mutant.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys
root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import delete_row, expect_red, flat  # noqa: E402

PATHS = {
    "fleet": root / "skills/fleet-review/SKILL.md",
    "deploy": root / "skills/ops/references/deploy-checklist.md",
    "wake": root / "skills/wake/SKILL.md",
    "roles": root / "skills/robin-mode/roles.md",
    "lead": root / "skills/lead/SKILL.md",
}
docs = {k: p.read_text(encoding="utf-8") for k, p in PATHS.items()}
# (doc, name, required regex on flattened document)
REQUIRED = [
    ("fleet", "receiver-context", r"worker- and repo-design-session-side half \(operator-desk while that repo has no design session open\)"),
    ("fleet", "triage-receiver", r"repo's design session, else operator-desk, applies it by hand when it reads the merge gate"),
    ("fleet", "critical-high-receiver", r"repo's design session, else operator-desk, checks it"),
    ("fleet", "escalation-receiver", r"ESC to the repo's design session, else operator-desk"),
    ("fleet", "round-receiver", r"repo's design session, else operator-desk, decides"),
    ("fleet", "reviewer-family-receiver", r"checks them all, the repo's design session, else operator-desk, does"),
    ("deploy", "join-receiver", r"레포 디자인 세션, 없으면 operator-desk로 전달한 경로/시각"),
    ("wake", "ready-receiver", r"repo's design session, else operator-desk, says you are done"),
    ("roles", "lead-in-session-only", r"A lead uses in-session subagents only, as `lead` §Subagents specifies; it never delegates or spawns workers"),
    ("roles", "lead-excluded-from-self-fallback", r"This fallback does not apply to a lead, which writes no product code"),
    ("lead", "stuck-event", r"panewire emit --kind lane\.event --lane <repo>-design --type blocked --event-id <repo>-lead-stuck-<unique-id> --text '\[lead\] STUCK \| <what> \| <tried> \| <alternative A/B>'"),
    ("lead", "stuck-decision-source", r"decision/2026-11-10/lead-direct-merge"),
    ("lead", "trailers-command", r"bin/pr-trailers --task <id> --family <family> --profile <profile> --lane lead"),
]
FORBIDDEN = [
    ("fleet", "old-desk-receiver", r"the desk applies it by hand"),
    ("fleet", "old-desk-review-check", r"the desk checks it"),
    ("fleet", "old-desk-esc", r"ESC to the desk"),
    ("fleet", "old-desk-round", r"the desk decides"),
    ("fleet", "old-desk-family-check", r"the desk does\. Which reviewer"),
    ("wake", "old-ready-desk", r"or the desk says you are done"),
    ("roles", "lead-spawns", r"A lead delegates and spawns"),
    ("roles", "lead-spawn-worker-claim", r"Lead[^\n]{0,100}spawns workers"),
    ("lead", "hardcoded-stuck-lane", r"handoffkeep" + r"-design"),
    ("lead", "handwritten-trailer-list", r"otherwise `Mergewake-Author-Family`"),
]

def check(d):
    for name, pattern in []:
        pass
    for doc, name, pattern in REQUIRED:
        assert re.search(pattern, flat(d[doc])), f"{doc}: required row {name} missing"
    for doc, name, pattern in FORBIDDEN:
        assert not re.search(pattern, flat(d[doc])), f"{doc}: forbidden row {name} present"
    for line in d["lead"].splitlines():
        if line.lstrip().startswith("panewire emit") and "STUCK" in line:
            assert "--type" in line, "lead: STUCK emit has no --type"

check(docs)
count = 0
for doc, name, pattern in REQUIRED:
    expect_red(f"{doc}-{name}-deleted", check, {**docs, doc: delete_row(docs[doc], None, pattern, name)})
    count += 1
INJECTIONS = {
    "old-desk-receiver": "the desk applies it by hand",
    "old-desk-review-check": "the desk checks it",
    "old-desk-esc": "ESC to the desk",
    "old-desk-round": "the desk decides",
    "old-desk-family-check": "checks them all, the desk does. Which reviewer",
    "old-ready-desk": "or the desk says you are done",
    "lead-spawns": "A lead delegates and spawns under robin-mode.",
    "lead-spawn-worker-claim": "Lead delegates and spawns workers.",
    "hardcoded-stuck-lane": "handoffkeep-" + "design",
    "handwritten-trailer-list": "otherwise `Mergewake-Author-Family`",
}
for doc, name, pattern in FORBIDDEN:
    expect_red(f"{doc}-{name}-injected", check, {**docs, doc: docs[doc] + "\n" + INJECTIONS[name] + "\n"})
    count += 1
# Missing --type is a separate forbidden rule checked on the actual command line.
expect_red("lead-stuck-without-type-injected", check, {**docs, "lead": docs["lead"] + "\n  panewire emit --kind lane.event --lane <repo>-design --event-id x --text STUCK\n"})
count += 1
print(f"PASS stale-receivers required={len(REQUIRED)} forbidden={len(FORBIDDEN) + 1} mutants assertion-red={count}/{count}")
PY
