#!/usr/bin/env bash
# Contract: every workflow job that sets up Python calls the one local composite
# (.github/actions/setup-python-cached) after checkout. The composite restores the exact pinned
# toolchain from the Actions cache before actions/setup-python, keys it by OS, arch and exact
# version, runs setup three times with 30 s and 90 s backoff, pins its actions to full SHAs, and
# reads an x.y.z version from .python-version (.python-version-macos on macOS runners). Each pin has one mutant that must go RED.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
python3 -I - "$root" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import expect_red

CALL = "uses: ./.github/actions/setup-python-cached"
# (workflow, job) pairs that set up Python on origin/main 7950d87.
JOBS = [("ci.yml", "contracts"), ("post-ci.yml", "contracts"),
        ("deploy.yml", "deploy-macos"), ("deploy.yml", "install-smoke")]
SETUP = "uses: actions/setup-python@"

files = {p.name: p.read_text() for p in (root / ".github/workflows").glob("*.yml")}
files["action"] = (root / ".github/actions/setup-python-cached/action.yml").read_text()
files[".python-version"] = (root / ".python-version").read_text()
files[".python-version-macos"] = (root / ".python-version-macos").read_text()


def job(text, name):
    m = re.search(rf"(?ms)^  {re.escape(name)}:\n(.*?)(?=^  \S|\Z)", text)
    assert m, f"missing job {name}"
    return m.group(1)


def check(files):
    workflows = {k: v for k, v in files.items() if k.endswith(".yml")}
    action = files["action"]
    version = files[".python-version"]

    for name, text in workflows.items():
        assert not re.search(r"uses:\s*actions/setup-python@", text), f"{name} calls actions/setup-python directly"
    for name, jobname in JOBS:
        body = job(workflows[name], jobname)
        assert CALL in body, f"{name} job {jobname} does not call the composite"
        assert body.index("uses: actions/checkout") < body.index(CALL), \
            f"{name} job {jobname} calls the composite before checkout"
    calls = sum(text.count(CALL) for text in workflows.values())
    assert calls == len(JOBS), f"composite is called {calls} times, want {len(JOBS)}"

    assert "using: composite" in action, "action is not a composite"
    assert ".python-version" in action, "action does not read .python-version"
    assert re.search(r'if \[\[ "\$RUNNER_OS" == macOS \]\]; then\n\s+file=\.python-version-macos', action), \
        "action does not read .python-version-macos on macOS"
    assert r'[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]' in action, "action does not validate x.y.z"
    key = r"key: setup-python-toolchain-\$\{\{ runner\.os \}\}-\$\{\{ runner\.arch \}\}-py\$\{\{ steps\.version\.outputs\.version \}\}"
    assert re.search(key, action), "cache key lacks os, arch or exact version"
    assert "path: ${{ runner.tool_cache }}/Python/${{ steps.version.outputs.version }}" in action, \
        "cache path is not the Python tool cache for that version"
    assert action.index("uses: actions/cache@") < action.index(SETUP), "cache is not restored before setup-python"

    assert len(re.findall(SETUP, action)) == 3, "setup-python is not attempted exactly three times"
    for n in (1, 2, 3):
        assert f"id: setup-python-{n}\n" in action, f"no setup-python attempt {n}"
    assert "sleep 30" in action and "sleep 90" in action, "no 30 s and 90 s backoff"

    pins = re.findall(r"(?m)^\s*uses: (.+)$", action)
    assert len(pins) == 4, f"{len(pins)} uses lines, want cache plus three setup attempts"
    for pin in pins:
        assert re.fullmatch(r"[\w.-]+/[\w.-]+@[0-9a-f]{40} # v\d+\.\d+\.\d+", pin), f"not a SHA pin: {pin}"

    assert re.fullmatch(r"\d+\.\d+\.\d+\n?", version), f".python-version is not x.y.z: {version!r}"
    mac = files[".python-version-macos"]
    assert re.fullmatch(r"\d+\.\d+\.\d+\n?", mac), f".python-version-macos is not x.y.z: {mac!r}"


def mutate(name, old, new, count=-1):
    assert old in files[name], f"fixture: {old!r} not found in {name}"
    return {**files, name: files[name].replace(old, new) if count < 0 else files[name].replace(old, new, count)}


def move_cache_last(text):
    start = text.index("    - id: toolchain-cache")
    end = text.index("    - id: setup-python-1")
    block = text[start:end]
    return text[:start] + text[end:] + "\n" + block


def drop_last_setup(text):
    i = text.rindex(SETUP)
    j = text.index("\n", i)
    return text[:i] + "run: true" + text[j:]


check(files)

CHECKOUT = "      - uses: actions/checkout@v4\n"
CALL_LINE = "      - " + CALL + "\n"
expect_red("a workflow calls actions/setup-python directly", check,
           mutate("ci.yml", CHECKOUT, CHECKOUT + "      - uses: actions/setup-python@v5\n", count=1))
expect_red("a job drops the composite call", check,
           mutate("deploy.yml", CALL_LINE, "", count=1))
expect_red("the composite runs before checkout", check,
           mutate("ci.yml", CHECKOUT + CALL_LINE, CALL_LINE + CHECKOUT))
expect_red("cache key drops the arch", check,
           mutate("action", "-${{ runner.arch }}-py", "-py"))
expect_red("cache key drops the os", check,
           mutate("action", "setup-python-toolchain-${{ runner.os }}-", "setup-python-toolchain-"))
expect_red("cache key drops the exact version", check,
           mutate("action", "-py${{ steps.version.outputs.version }}", "-py"))
expect_red("cache is restored after setup-python", check,
           {**files, "action": move_cache_last(files["action"])})
expect_red("setup-python is attempted only twice", check,
           {**files, "action": drop_last_setup(files["action"])})
expect_red("backoff before attempt 3 is 60 s", check,
           mutate("action", "sleep 90", "sleep 60"))
expect_red("setup-python is pinned to a tag", check,
           mutate("action", "actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5.6.0",
                  "actions/setup-python@v5", count=1))
expect_red("version validation removed", check,
           mutate("action", r'if ! [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then', "if false; then"))
expect_red("macOS version file not used", check,
           mutate("action", "file=.python-version-macos", "file=.python-version"))
expect_red("macOS pinned version is minor only", check,
           mutate(".python-version-macos", files[".python-version-macos"],
                  ".".join(files[".python-version-macos"].strip().split(".")[:2]) + "\n"))
expect_red("pinned version is minor only", check,
           mutate(".python-version", files[".python-version"],
                  ".".join(files[".python-version"].strip().split(".")[:2]) + "\n"))
print("PASS test-ci-toolchain-cache")
PY
