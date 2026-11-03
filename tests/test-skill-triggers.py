#!/usr/bin/env python3
"""Deterministic description contract; live trigger eval is intentionally TODO."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
# Each fixture names the skill and the phrase a worker prompt uses to invoke it.
FIXTURES = {
    "fleet-review": ["review finding", "triage"],
    "robin-mode": ["rstack", "nontrivial task"],
    "wake": ["wake method", "repo-session spawn"],
    "tdd": ["bug fixes", "regression test"],
    "desk": ["desk", "commitment", "resume", "compaction", "tasks add", "spawn failed"],
}
CAP = 1000  # Keeps descriptions comfortably scannable across harness skill routers.

def description(skill):
    content = (ROOT / ("skills" if skill != "tdd" else "third_party/pstack/skills") /
               skill / "SKILL.md").read_text()
    match = re.search(r"^description:\s*['\"]?(.*?)['\"]?$", content, re.M)
    assert match, f"{skill}: missing description"
    return match.group(1).lower()

def check(skill, text, terms):
    assert len(text) <= CAP, f"{skill}: description is {len(text)} chars; cap is {CAP}"
    for term in terms:
        assert term.lower() in text, f"{skill}: expected trigger term {term!r} missing"

for skill, terms in FIXTURES.items():
    check(skill, description(skill), terms)

print(f"PASS: {len(FIXTURES)} skill trigger fixtures; cap={CAP}")

# Every fixture term must be able to fail: remove it from the description and expect RED.
mutants = 0
for skill, terms in FIXTURES.items():
    text = description(skill)
    for term in terms:
        try:
            check(skill, text.replace(term.lower(), ""), terms)
        except AssertionError as exc:
            assert repr(term) in str(exc), f"{skill}: mutant of {term!r} went RED for another reason: {exc}"
            mutants += 1
        else:
            raise AssertionError(f"{skill}: removing {term!r} did not go RED")
print(f"PASS mutants assertion-red={mutants}/{mutants}")
# TODO: add a live-model trigger runner modeled on addyosmani/agent-skills evals/README.md.
