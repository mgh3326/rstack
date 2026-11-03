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
}
CAP = 1000  # Keeps descriptions comfortably scannable across harness skill routers.

def description(skill):
    content = (ROOT / ("skills" if skill != "tdd" else "third_party/pstack/skills") /
               skill / "SKILL.md").read_text()
    match = re.search(r"^description:\s*['\"]?(.*?)['\"]?$", content, re.M)
    assert match, f"{skill}: missing description"
    return match.group(1).lower()

for skill, terms in FIXTURES.items():
    text = description(skill)
    assert len(text) <= CAP, f"{skill}: description is {len(text)} chars; cap is {CAP}"
    for term in terms:
        assert term.lower() in text, f"{skill}: expected trigger term {term!r} missing"

print(f"PASS: {len(FIXTURES)} skill trigger fixtures; cap={CAP}")
# TODO: add a live-model trigger runner modeled on addyosmani/agent-skills evals/README.md.
