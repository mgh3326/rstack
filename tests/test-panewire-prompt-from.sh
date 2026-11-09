#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import expect_red  # noqa: E402

docs = {str(path.relative_to(root)): path.read_text(encoding="utf-8")
        for path in sorted((root / "skills").rglob("*.md"))}


def logical_lines(text):
    pending = []
    start = 1
    for number, line in enumerate(text.splitlines(), 1):
        if not pending:
            start = number
        stripped = line.rstrip()
        if stripped.endswith("\\"):
            pending.append(stripped[:-1])
            continue
        pending.append(line)
        yield start, " ".join(part.strip() for part in pending)
        pending = []
    if pending:
        yield start, " ".join(part.strip() for part in pending)


def command_lines(text):
    for number, line in logical_lines(text):
        if "panewire prompt" in line and re.search(r"\s--[a-z][a-z-]*", line):
            yield number, line


def check(skill_docs):
    found = []
    missing = []
    for path, body in skill_docs.items():
        for number, line in command_lines(body):
            found.append((path, number))
            if not re.search(r"\s--from(?:\s|=)", line):
                missing.append(f"{path}:{number}: {line.strip()}")
    assert found, "scan found no panewire prompt command lines"
    assert not missing, "panewire prompt command lines missing --from:\n" + "\n".join(missing)


REQUIRED = [("prompt-from-on-every-command", check)]
FORBIDDEN = [("no-short-panewire-prompt-form", check)]

for _row, assertion in REQUIRED:
    assertion(docs)
for _row, assertion in FORBIDDEN:
    assertion(docs)
print(f"PASS panewire-prompt-from required={len(REQUIRED)} forbidden={len(FORBIDDEN)} commands={sum(1 for body in docs.values() for _ in command_lines(body))} skills={len(docs)}")

# Deletion mutant: remove --from from one real command; the scan must reject it.
mutated = dict(docs)
for path, body in docs.items():
    if "panewire prompt" in body and re.search(r"--from(?:=|\s)", body):
        mutated[path], count = re.subn(r"--from(?:=|\s+)<[^>]+>", "", body, count=1)
        assert count == 1, "fixture: --from flag not deleted"
        break
else:
    raise AssertionError("fixture: no full panewire prompt command to mutate")
expect_red("prompt-from-deleted", REQUIRED[0][1], mutated)

# Injection mutant: add a legacy short form; the scan must reject it.
injected = dict(docs)
first = next(iter(injected))
injected[first] += "\n`panewire prompt --uptake status-transition`\n"
expect_red("prompt-from-forbidden-injected", FORBIDDEN[0][1], injected)

# Continuation fixture: options on later shell lines form the same command.
continued = {"skills/fixture.md": "`panewire prompt \\\n  --from <sender-lane> \\\n  --to <agent-name> --file <prompt-file> --uptake status-transition --timeout 60s`\n"}
check(continued)
continued_missing_from = {
    "skills/fixture.md": continued["skills/fixture.md"].replace("--from <sender-lane> \\\n  ", "", 1)
}
expect_red("prompt-from-continued-deleted", REQUIRED[0][1], continued_missing_from)
print("PASS mutants assertion-red=3/3; continued-command=1/1")
PY
