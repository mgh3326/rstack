#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import delete_row, expect_red, section

key = r"policy/operator-facing-korean"
rows = [
    ("wake-settle", "skills/wake/SKILL.md", "## Settle before spawning"),
    ("wake-brief-rules", "skills/wake/SKILL.md", "## Rules"),
    ("ops-invariants", "skills/ops/SKILL.md", "## Invariants (all references)"),
    ("decision-request", "skills/ops/references/decision-request.md", "## 운영자 결정 요청"),
    ("desk-decisions", "skills/desk/SKILL.md", "## Decisions"),
    ("fleet-review-triage", "skills/fleet-review/SKILL.md", "## Triage rubric"),
]

for name, path, heading in rows:
    text = (root / path).read_text(encoding="utf-8")
    def check(document):
        assert key in section(document, heading), f"{name}: policy pointer missing"
    check(text)
    print(f"PASS {name}")
    expect_red(name, check, delete_row(text, heading, key, name))
    print(f"RED {name} deletion mutant (expected)")
PY
