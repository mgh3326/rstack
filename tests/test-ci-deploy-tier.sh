#!/usr/bin/env bash
# Contract: the main tier is light (Linux contracts only, post-ok needs it alone), the deploy
# tier runs only for a successful Post CI push, checks out the run head sha, is one uncancelled
# group per repo and posts deploy-ok, and the any-ref workflow routes a main|deploy suite to the
# matching tier and posts the matching status. Each pin has one mutant that must go RED.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
python3 -I - "$root" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import expect_red

files = {p.name: p.read_text() for p in (root / ".github/workflows").glob("*.yml")}


def job(text, name):
    m = re.search(rf"(?ms)^  {re.escape(name)}:\n(.*?)(?=^  \S|\Z)", text)
    assert m, f"missing job {name}"
    return m.group(1)


def check(workflows):
    post = workflows["post-ci.yml"]
    deploy = workflows["deploy.yml"]
    anyref = workflows["ci-any-ref.yml"]

    assert "contracts-macos" not in post, "main tier still runs a macOS job"
    assert re.search(r"(?m)^    needs: \[contracts\]\n", job(post, "post-ok")), \
        "post-ok does not need only contracts"

    assert re.search(
        r"(?m)^  workflow_run:\n    workflows: \[\"Post CI\"\]\n    types: \[completed\]\n    branches: \[main\]\n",
        deploy,
    ), "deploy does not trigger on a completed Post CI run for main"
    assert "github.event.workflow_run.conclusion == 'success'" in deploy, "no success conclusion gate"
    assert "github.event.workflow_run.event == 'push'" in deploy, "no push event gate"

    checkouts = deploy.count("uses: actions/checkout")
    head_sha_refs = len(re.findall(
        r"ref: \$\{\{ github\.event\.workflow_run\.head_sha \|\| inputs\.ref \}\}", deploy))
    assert checkouts == 2 and head_sha_refs == checkouts, \
        f"{checkouts} checkouts but {head_sha_refs} use the run head sha"

    m = re.search(r"(?m)^concurrency:\n  group: (.+)\n  cancel-in-progress: (\S+)\n", deploy)
    assert m, "deploy has no top-level concurrency"
    for ref in ("github.ref", "inputs.ref", "head_sha"):
        assert ref not in m.group(1), f"deploy concurrency is per ref: {m.group(1)}"
    assert m.group(2) == "false", "deploy concurrency cancels a running deploy"

    assert "-f context=deploy-ok" in deploy, "deploy posts no deploy-ok status"
    assert deploy.count("statuses: write") == 1, "statuses: write is not declared exactly once"
    ok = job(deploy, "deploy-ok")
    assert "statuses: write" in ok, "statuses: write is not on the deploy-ok job"
    for name in ("deploy-macos", "install-smoke"):
        assert re.search(r"(?m)^    permissions:\n      contents: read\n", job(deploy, name)), \
            f"{name} does not declare its own contents: read permissions"
    assert "github.event.workflow_run && always()" in ok, "deploy-ok also reports a workflow_call"
    assert "suite=deploy" in ok, "deploy-ok evidence omits the suite"
    assert "target_url=" in ok, "deploy-ok evidence omits the run url"
    assert "policy_revision=n/a" in ok and "artifact_digest=n/a" in ok, "deploy-ok evidence fakes release fields"

    assert re.search(r"(?m)^    runs-on: macos-latest\n", job(deploy, "deploy-macos")), \
        "deploy-macos does not run on hosted macOS"
    assert "run: bash tests/run-all.sh" in job(deploy, "deploy-macos"), \
        "deploy-macos does not run the suite"
    assert re.search(r"(?m)^    runs-on: ubuntu-latest\n", job(deploy, "install-smoke")), \
        "install-smoke does not run on hosted Linux"
    assert re.search(r"(?m)^        run: python3 tests/test-install\.py\n", job(deploy, "install-smoke")), \
        "install-smoke does not run the installer suite, which installs into a temporary HOME"

    suite = re.search(r"(?ms)^      suite:\n(.*?)(?=^      \S|\Z)", anyref)
    assert suite, "any-ref has no suite input"
    block = suite.group(1)
    assert "type: choice" in block, "suite is not a choice"
    for entry in ("main", "deploy"):
        assert re.search(rf"(?m)^          - {entry}$", block), f"suite has no {entry} option"
    assert re.search(r"(?m)^        default: main$", block), "suite does not default to main"
    assert "uses: ./.github/workflows/post-ci.yml" in anyref, "any-ref does not call the main tier"
    assert "uses: ./.github/workflows/deploy.yml" in anyref, "any-ref does not call the deploy tier"
    grant = job(anyref, "deploy")
    assert re.search(r"(?m)^    permissions:\n      contents: read\n      statuses: write\n    uses: ", grant), \
        "any-ref deploy job does not grant statuses: write to deploy.yml's deploy-ok job"
    assert "-f context=post-ok" in anyref, "any-ref posts no post-ok status"
    assert "-f context=deploy-ok" in anyref, "any-ref posts no deploy-ok status"


def mutate(name, old, new, count=-1):
    assert old in files[name], f"fixture: {old!r} not found in {name}"
    return {**files, name: files[name].replace(old, new) if count < 0 else files[name].replace(old, new, count)}


expect_red("main tier keeps a macOS job", check,
           mutate("post-ci.yml", "  post-ok:\n", "  contracts-macos:\n    runs-on: macos-latest\n  post-ok:\n"))
expect_red("post-ok needs the macOS job", check,
           mutate("post-ci.yml", "    needs: [contracts]\n", "    needs: [contracts, contracts-macos]\n"))
expect_red("deploy watches another workflow", check,
           mutate("deploy.yml", 'workflows: ["Post CI"]', 'workflows: ["CI"]'))
expect_red("conclusion gate inverted", check,
           mutate("deploy.yml", "github.event.workflow_run.conclusion == 'success'",
                  "github.event.workflow_run.conclusion == 'failure'"))
expect_red("push event gate removed", check,
           mutate("deploy.yml", " && github.event.workflow_run.event == 'push'", ""))
expect_red("a checkout ignores the run head sha", check,
           mutate("deploy.yml", "ref: ${{ github.event.workflow_run.head_sha || inputs.ref }}",
                  "ref: ${{ inputs.ref }}", count=1))
expect_red("deploy cancels a running deploy", check,
           mutate("deploy.yml", "cancel-in-progress: false", "cancel-in-progress: true"))
expect_red("concurrency keyed per ref", check,
           mutate("deploy.yml", "group: deploy-${{ github.repository }}",
                  "group: deploy-${{ github.repository }}-${{ inputs.ref }}"))
expect_red("deploy-ok context renamed", check,
           mutate("deploy.yml", "-f context=deploy-ok", "-f context=deploy"))
expect_red("statuses: write leaks to another job", check,
           mutate("deploy.yml", "  deploy-macos:\n", "  deploy-macos:\n    permissions:\n      statuses: write\n"))
expect_red("deploy-ok also reports a workflow_call", check,
           mutate("deploy.yml", "github.event.workflow_run && always()", "always()"))
expect_red("a deploy job drops its own permissions", check,
           mutate("deploy.yml", "  deploy-macos:\n    if: ${{ !github.event.workflow_run || (github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.event == 'push') }}\n    runs-on: macos-latest\n    permissions:\n      contents: read\n",
                  "  deploy-macos:\n    if: ${{ !github.event.workflow_run || (github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.event == 'push') }}\n    runs-on: macos-latest\n"))
expect_red("any-ref deploy cannot grant statuses: write", check,
           mutate("ci-any-ref.yml", "      contents: read\n      statuses: write\n    uses: ./.github/workflows/deploy.yml",
                  "      contents: read\n    uses: ./.github/workflows/deploy.yml"))
expect_red("deploy-ok evidence drops the suite", check,
           mutate("deploy.yml", "suite=deploy ", ""))
expect_red("deploy target platform is not hosted macOS", check,
           mutate("deploy.yml", "runs-on: macos-latest", "runs-on: ubuntu-latest"))
expect_red("install smoke skips the installer", check,
           mutate("deploy.yml", "run: python3 tests/test-install.py", "run: true"))
expect_red("any-ref suite defaults to deploy", check,
           mutate("ci-any-ref.yml", "        default: main\n", "        default: deploy\n"))
expect_red("any-ref suite loses the deploy option", check,
           mutate("ci-any-ref.yml", "          - deploy\n", ""))
expect_red("any-ref deploy status renamed", check,
           mutate("ci-any-ref.yml", "-f context=deploy-ok", "-f context=deploy"))
expect_red("any-ref deploy suite calls the main tier", check,
           mutate("ci-any-ref.yml", "uses: ./.github/workflows/deploy.yml", "uses: ./.github/workflows/post-ci.yml"))
print("PASS test-ci-deploy-tier")
PY
