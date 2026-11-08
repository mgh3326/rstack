#!/usr/bin/env bash
# hk is the record for fleet job artifacts (hk 3630, unit 6-5): the brief goes to
# hk and is spawned with `-p hk:doc/...`; the report is uploaded by
# `panewire done --report`; job dirs are scratch. Pins the skill text.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import flat, section  # noqa: E402

wake = (root / "skills/wake/SKILL.md").read_text(encoding="utf-8")
reap = (root / "skills/ops/references/reap.md").read_text(encoding="utf-8")
consult = (root / "skills/ops/references/consult.md").read_text(encoding="utf-8")

# Step 3 (Brief) runs up to step 4.
loop = section(wake, "## The loop")
m = re.search(r"(?s)\n3\. \*\*Brief\.\*\*.*?\n4\. \*\*Model and host", loop)
assert m, "wake step 3 (Brief) missing"
step3 = m.group(0)
put = step3.find("handoffkeep doc put --key brief/<date>/<job> --kind brief")
assert put >= 0, "step 3 must put the brief with `handoffkeep doc put --key brief/<date>/<job> --kind brief`"
assert "--task <id>" in step3[put:], "step 3 doc put must link the task with --task <id>"
assert "--kind note" not in step3, "the brief kind is `brief`, not `note`"

# The spawn dry-run (step 5) comes after the put and reads the hk doc.
step5 = re.search(r"(?s)\n5\. \*\*Preview, then spawn\*\*.*?\n6\. ", loop)
assert step5, "wake step 5 missing"
spawn = step5.group(0)
assert re.search(r"panewire spawn [^\n]*\\?\n?[^\n]*-p hk:doc/brief/<date>/<job>", spawn), (
    "step 5 spawn must use -p hk:doc/brief/<date>/<job>")

# No spawn anywhere in skills/ takes the brief from a job-dir path.
for path in sorted((root / "skills").rglob("*.md")):
    text = path.read_text(encoding="utf-8")
    assert "-p ~/work/herdr-inbox/jobs/" not in text, f"{path}: -p still names a job-dir brief"

# Worker READY text names the hk key and the worker ends with panewire done.
done = flat(section(wake, "## Done"))
assert "hk:doc/reports/<job>/report.md" in done, "READY text must name hk:doc/reports/<job>/report.md"
assert "panewire done <job> --report" in done, "the worker must end with panewire done <job> --report"
assert not re.search(r"READY \| <pr> \| ~/work/herdr-inbox/jobs", done), "READY must not name the local report path"

# reap.md: job dirs are scratch; the hk job record is the record.
r = flat(reap)
assert re.search(r"job 디렉터리는 scratch|job dir[^.]*scratch|scratch", r), "reap.md must say job dirs are scratch"
assert "report_doc" in r and "screens/<job>/pane-screen.txt" in r, (
    "reap.md must name the hk job record (report_doc) and the hk pane-screen doc")

# consult.md: the answer is read back from hk.
assert "handoffkeep doc get reports/consult-" in flat(consult), (
    "consult.md must read the answer with handoffkeep doc get reports/consult-<...>/answer.md")
print("PASS hk brief/report paths")
PY
