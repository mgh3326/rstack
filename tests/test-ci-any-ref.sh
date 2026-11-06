#!/usr/bin/env bash
# Contract: the policy's any_ref_workflow exists, takes a `ref` dispatch input, validates a
# 40-hex sha, cancels per inputs.ref, and posts a commit status for every watch_checks entry.
# Each pin has one mutant that must go RED by assertion.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
python3 -I - "$root" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import expect_red


def check(policy_text, workflows):
    """workflows maps a file name under .github/workflows to its text (text pins, no YAML parser)."""
    m = re.search(r"(?m)^any_ref_workflow:\s*(\S+)\s*$", policy_text)
    assert m, "policy has no any_ref_workflow"
    name = m.group(1)
    assert name in workflows, f"any_ref_workflow {name} does not exist"
    text = workflows[name]
    assert re.search(
        r"(?m)^  workflow_dispatch:\n    inputs:\n      ref:\n(?:        .*\n)*?        required: true\n", text
    ), "workflow_dispatch has no required input ref"
    assert text.count("concurrency:") >= 1, "no concurrency block"
    blocks = re.findall(r"concurrency:\n\s+group: (.*)\n\s+cancel-in-progress: (\S+)\n", text)
    assert len(blocks) == text.count("concurrency:"), "a concurrency block lacks group and cancel-in-progress"
    for group, cancel in blocks:
        assert "inputs.ref" in group, f"concurrency is not per inputs.ref: {group}"
        assert cancel == "true", f"concurrency does not cancel: {group}"
    assert re.search(r"\^\[0-9a-fA-F\]\{40\}\$", text), "no anchored 40-hex sha validation"
    watch = re.search(r"(?m)^watch_checks:\n((?:  - .*\n)+)", policy_text)
    assert watch, "policy has no watch_checks"
    for entry in re.findall(r"  - '?([^'\n]+)'?", watch.group(1)):
        assert re.search(r"-f context=" + re.escape(entry) + r"(\s|$)", text), f"no status posted with context {entry}"


policy_text = (root / ".mergewake/policy.yaml").read_text()
workflows = {p.name: p.read_text() for p in (root / ".github/workflows").glob("*.yml")}
check(policy_text, workflows)
name = re.search(r"(?m)^any_ref_workflow:\s*(\S+)", policy_text).group(1)
text = workflows[name]


def with_text(old, new):
    assert old in text, f"fixture: {old!r} not found in {name}"
    return {**workflows, name: text.replace(old, new)}


expect_red("policy loses any_ref_workflow", check, re.sub(r"(?m)^any_ref_workflow:.*\n", "", policy_text), workflows)
expect_red("policy names a missing file", check, policy_text.replace(name, "missing-any-ref.yml"), workflows)
expect_red("input ref renamed", check, policy_text, with_text("      ref:\n        description", "      sha:\n        description"))
expect_red("concurrency not per inputs.ref", check, policy_text, with_text("ci-any-ref-ci-${{ inputs.ref }}", "ci-any-ref-ci"))
expect_red("concurrency does not cancel", check, policy_text, with_text("cancel-in-progress: true", "cancel-in-progress: false"))
expect_red("status context renamed", check, policy_text, with_text("-f context=post-ok", "-f context=ci-ok"))
expect_red("sha validation removed", check, policy_text, with_text("^[0-9a-fA-F]{40}$", "^[0-9a-fA-F]+$"))
expect_red("watch check without a status", check, policy_text.replace("  - 'post-ok'\n", "  - 'post-ok'\n  - 'extra-check'\n"), workflows)
print("PASS test-ci-any-ref")
PY
