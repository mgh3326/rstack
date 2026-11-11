#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import delete_row, expect_red, flat, section  # noqa: E402

def read(path):
    return (root / path).read_text(encoding="utf-8")

def render_sets(raw):
    sets = json.loads(raw)["sets"]
    return "sets: full=" + ",".join(sets["full"]) + "; worker=" + ",".join(sets["worker"])

docs = {
    "fleet": read("skills/fleet-policy/SKILL.md"),
    "wake": read("skills/wake/SKILL.md"),
    "lead": read("skills/lead/SKILL.md"),
    "roles": read("skills/robin-mode/roles.md"),
    "robin": read("skills/robin-mode/SKILL.md"),
    "agents": read("AGENTS.md"),
    "triggers": read("tests/test-skill-triggers.py"),
    "sets": render_sets(read("install/sets.json")),
}

REQUIRED = [
    ("fleet", "## When to use", "operator opens role", r"The operator opens this session directly; run one at a time"),
    ("fleet", "## When to use", "loads three skills", r"Load this skill with `wake` and `ops`"),
    ("fleet", "## When to use", "scope exclusions", r"not for repo code \(the owning design session\), deploys \(operator-desk\), or a hotfix \(lead\)"),
    ("fleet", "## Authority", "one recorded yes", r"Settle cross-repo policy with the operator\. Each decision needs one recorded yes before it takes effect"),
    ("fleet", "## Authority", "temporary marker", r"\*Temporary \(operator 2026-11-11, hk 3959\): ends when hk admits the role's client id as a catalog writer \(hk 3960\)\.\*"),
    ("fleet", "## Authority", "temporary write scope", r"Once that condition is met, write hk `policy/\*`, `decision/\*`, `experiment/\*`, `findings/\*`, catalog-push files and the catalog itself"),
    ("fleet", "## Authority", "code handoff", r"Hand every code change to the owning design session as an hk task plus brief"),
    ("fleet", "## Authority", "binding policy documents", r"Recorded decisions bind design sessions for `policy/model-routing`, `policy/model-families` and `policy/quota-stop`"),
    ("fleet", "## Authority", "no write push merge deploy etc", r"Never write or push code, including T0 changes; merge or deploy; touch a repo's services or secrets; change a grade without a deviation ref; relax a policy alone; or read credentials"),
    ("fleet", "## Authority", "requests remain with owners", r"A pool class change, a seat-policy file on a node, a hub or node restart, a deploy, or reaping panes on another host remains a request to the owning design session or operator-desk until the panewire ticket for decision 22 exists"),
    ("fleet", "## Authority", "routes and lead", r"Lane routes stay with operator-desk; the lead is unaffected"),
    ("fleet", "## Authority", "lane wording", r"For any spawn or inbox target, use “the lane hk `policy/design-sessions` names for this role”"),
    ("fleet", "## Experiments", "merged replay no PR merge", r"Run replays of merged tasks on throwaway branches `exp/<slug>`; do not open a PR or merge"),
    ("fleet", "## Experiments", "pre-spawn task and doc", r"Before each spawn, create one `\[exp\]` hk task and one `experiment/<date>/<slug>` doc recording the hypothesis, rungs, task set, success metric and budget"),
    ("fleet", "## Experiments", "quota first and operator count", r"Check quota first\. The operator approves the run count per experiment"),
    ("fleet", "## Experiments", "pin and operator request", r"Pin each rung with `--override-reason 'catalog experiment <doc>' --containment hk:<task>`\. Use `--operator-request` only for consult_only rungs"),
    ("fleet", "## Experiments", "pane limit and reap", r"Use at most three experiment panes, and reap the panes when the run is done"),
    ("fleet", "## Experiments", "grade ladder approval", r"A grade or ladder change still needs the operator's yes and a deviation ref"),
    ("fleet", "## Experiments", "operator request grammar", r"An `--operator-request` value must match `\^\[A-Za-z0-9\._:/@-\]\{1,200\}\$`; a `#` makes the node drop the spawn"),
    ("fleet", "## Experiments", "run grade bounded", r"The run task's grade marker must not exceed the pinned rung's grade"),
    ("fleet", "## Experiments", "exclude hosts without commit", r"Exclude hosts that lack a repository commit named in the brief"),
    ("fleet", "## Experiments", "name delete branches", r"Name every branch to delete; never use a glob"),
    ("fleet", "## Experiments", "wake and ops mechanics", r"Follow `wake` for the task, brief, spawn preview and landing proof"),
    ("fleet", "## Records", "operator message record", r"Before acting on an operator message, put it verbatim in the session's decision doc with the time from `date` and the session's reading"),
    ("fleet", "## Records", "source register", r"Keep a source register for every link the operator gives: the message, read date and method, raw copy, finding, and decisions grounded in it"),
    ("fleet", "## Records", "finding sources and date", r"A finding names exact source URLs and its read date"),
    ("fleet", "## Records", "decision sources", r"A decision names its findings and experiments"),
    ("fleet", "## Records", "hk docs", r"Store records in hk docs"),
    ("fleet", "## Records", "mechanical transcript check", r"Close with a mechanical check of the decision doc against the transcript"),
    ("wake", "## Authority", "wake cross-reference", r"\*\*fleet-policy session:\*\* settles cross-repo policy and experiments, then hands code to the owning design session; it never merges or deploys \(`fleet-policy` §Authority\)\. Its recorded decisions bind design sessions for `policy/model-routing`, `policy/model-families` and `policy/quota-stop`"),
    ("lead", "## Subagents", "lead spawn cross-reference", r"`panewire spawn` stays the design session's tool \(`wake` §The loop\) and the fleet-policy session's tool for its experiments only \(`fleet-policy` §Experiments\)"),
    ("roles", None, "roles vocabulary", r"\*\*fleet-policy\*\*: operator-opened session that settles cross-repo policy, runs bounded catalog experiments and keeps catalog records"),
    ("roles", None, "lead no routing role", r"A lead has no routing role: the operator opens the lead session, and its subagents resolve as implementer, explorer or verifier"),
    ("roles", None, "consult verifier refusal names", r"no policy and no cache for `consult`/`verifier`"),
    ("roles", None, "consult verifier alternate model rule", r"`consult`, `verifier`: do not start that work on any other model"),
    ("robin", "## Where each rule lives", "robin rule home", r"Cross-repo policy settling, experiments, catalog records \| `fleet-policy` \(rstack\)"),
    ("sets", None, "full not worker install", r"sets: full=[^;]*\bfleet-policy\b[^;]*; worker=(?![^;]*\bfleet-policy\b)"),
    ("triggers", None, "trigger fixture", r'"fleet-policy": \["fleet-policy", "policy session", "정책 세션", "experiment", "실험", "catalog"\]'),
    ("agents", None, "AGENTS layout", r"first-party skills \(wake, ops, lead, desk, fleet-policy, fleet-review, robin-mode\)"),
]

FORBIDDEN = {
    "role-grants-code-push-merge-deploy": re.compile(r"(?i)\bfleet-policy\b[^.\n]{0,100}\b(?:may|can|is allowed to)\b[^.\n]{0,40}\b(?:write|push|merge|deploy)\b"),
    "operator-request-non-consult-rung": re.compile(r"(?i)--operator-request[^.\n]{0,100}(?:default|non-consult|implementer) rung"),
    "branch-delete-glob": re.compile(r"(?i)delete[^.\n]{0,60}branches?[^.\n]{0,30}(?:\*|glob)"),
    "literal-role-lane-option": re.compile(r"--lane\s+fleet-policy|lane\s+`fleet-policy`"),
    "retired-lead-routing-role": re.compile(r"panewire resolve --role lead"),
}

def check(current):
    for doc, heading, row, pattern in REQUIRED:
        scope = flat(current[doc] if not heading else section(current[doc], heading))
        assert re.search(pattern, scope), f"{doc}: row '{row}' missing or weakened"
    for name, pattern in FORBIDDEN.items():
        if name == "retired-lead-routing-role":
            scope = flat(current["roles"])
        elif name == "literal-role-lane-option":
            scope = flat(current["fleet"])
        else:
            scope = flat(current["fleet"])
        match = pattern.search(scope)
        assert not match, f"forbidden rule '{name}' present: {match.group(0)!r}"

check(docs)
print(f"PASS rows={len(REQUIRED)}")

count = 0
for doc, heading, row, pattern in REQUIRED:
    expect_red(f"row-{row}-deleted", check,
               {**docs, doc: delete_row(docs[doc], heading, pattern, row)})
    count += 1

for name, injected in [
    ("role-grants-code-push-merge-deploy", "- fleet-policy may write code, push, merge and deploy.\n"),
    ("operator-request-non-consult-rung", "- Use `--operator-request` on a default rung.\n"),
    ("branch-delete-glob", "- Delete branches with a glob such as exp/*.\n"),
    ("literal-role-lane-option", "- Spawn with `--lane " + "fleet-policy`.\n"),
]:
    expect_red(f"{name}-injected", check, {**docs, "fleet": docs["fleet"] + "\n" + injected})
    count += 1
expect_red("retired-lead-routing-role-injected", check,
           {**docs, "roles": docs["roles"].replace("## Rules", "panewire resolve --role lead\n\n## Rules", 1)})
count += 1
print(f"PASS mutants assertion-red={count}/{count}")
PY
