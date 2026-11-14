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
role_name = re.search(r"(?m)^name:\s*(\S+)", docs["fleet"]).group(1)

REQUIRED = [
    ("fleet", "## When to use", "operator opens role", r"The operator opens this session directly; run one at a time"),
    ("fleet", "## When to use", "loads three skills", r"Load this skill with `wake` and `ops`"),
    ("fleet", "## When to use", "policy-session-name", r"A policy session uses its lane name as its Claude session name \(`claude --name <lane>` or `/rename <lane>`\), so others can address it"),
    ("fleet", "## When to use", "scope exclusions", r"not for repo code \(the owning design session\), deploys \(the owning repo's design session, or operator-desk while that repo has no design session open\), or a hotfix \(lead\)"),
    ("fleet", "## Authority", "one recorded yes", r"Settle cross-repo policy with the operator\. Each decision needs one recorded yes before it takes effect"),
    ("fleet", "## Authority", "permanent direct doc and task writes plus conditional catalog grant", r"This role writes its hk `policy/\*`, `decision/\*`, `experiment/\*` and `findings/\*` docs and hk tasks directly\. It may write catalog-push files and the catalog itself once hk admits its client id"),
    ("fleet", "## Authority", "catalog-only temporary marker", r"\*Temporary \(operator 2026-11-11, hk 3959\): ends when hk 3963 is complete and its record confirms client-id admission \(hk 3963\)\.\*"),
    ("fleet", "## Authority", "interim catalog handoff and admission check", r"Until hk 3963 is complete and its record confirms client-id admission, hand the prepared catalog-push file to a lane that is already a catalog writer\. Check `handoffkeep tasks show 3963`; use catalog write authority only after this condition is recorded"),
    ("fleet", "## Authority", "code handoff", r"Hand every code change to the owning design session as an hk task plus brief"),
    ("fleet", "## Authority", "binding policy documents", r"Recorded decisions bind design sessions for `policy/model-routing`, `policy/model-families` and `policy/quota-stop`"),
    ("fleet", "## Authority", "no write push merge deploy etc", r"Never write or push code, including T0 changes; merge or deploy; touch a repo's services or secrets; change a grade without a deviation ref; relax a policy alone; or read credentials"),
    ("fleet", "## Authority", "experiment branch deletion authority", r"The only branch deletion this session may perform is deleting an `exp/<slug>` branch it created for an experiment, following the record-before-delete rule in §Experiments"),
    ("fleet", "## Authority", "requests remain with owners and deploy route", r"A pool class change, a seat-policy file on a node, a hub or node restart, or reaping panes on another host remains a request to the owning design session or operator-desk until the panewire ticket for decision 22 exists\. A repo's deploy belongs to that repo's design session; operator-desk handles it only while that repo has no design session open"),
    ("fleet", "## Authority", "routes and lead", r"Lane routes stay with operator-desk; the lead is unaffected"),
    ("fleet", "## Authority", "lane wording", r"For any spawn or inbox target, use “the lane hk `policy/design-sessions` names for this role”"),
    ("fleet", "## Experiments", "merged replay no PR merge", r"Run replays of merged tasks on throwaway branches `exp/<slug>`; do not open a PR or merge"),
    ("fleet", "## Experiments", "pre-spawn task and doc", r"Before each spawn, create one experiment hk task and one `experiment/<date>/<slug>` doc recording the hypothesis, rungs, task set, success metric, budget and exact branch name"),
    ("fleet", "## Experiments", "research task kind temporary marker", r"\*Temporary \(operator 2026-11-11, hk 3959\): ends when hk 3964 deploys the `research` task kind \(hk 3964\)\.\*"),
    ("fleet", "## Experiments", "research task kind transition", r"Until hk 3964 deploys the `research` task kind, give the experiment task the `\[exp\]` title prefix; after deployment, create it with `--kind research`"),
    ("fleet", "## Experiments", "quota first and operator count", r"Check quota first\. The operator approves the run count per experiment"),
    ("fleet", "## Experiments", "pin and operator request", r"Pin each rung with `--override-reason 'catalog experiment <doc>' --containment hk:<task>`\. Use `--operator-request` only for consult_only rungs"),
    ("fleet", "## Experiments", "pane limit and reap", r"Use at most three experiment panes\. Reap panes on the local host after the run; request operator-desk or the owning design session to reap panes on another host until the decision-22 ticket exists"),
    ("fleet", "## Experiments", "grade ladder approval", r"A grade or ladder change still needs the operator's yes and a deviation ref"),
    ("fleet", "## Experiments", "operator request grammar", r"An `--operator-request` value must match `\^\[A-Za-z0-9\._:/@-\]\{1,200\}\$`; a `#` makes the node drop the spawn"),
    ("fleet", "## Experiments", "run grade bounded", r"The run task's grade marker must not exceed the pinned rung's grade"),
    ("fleet", "## Experiments", "exclude hosts without commit", r"Exclude hosts that lack a repository commit named in the brief"),
    ("fleet", "## Experiments", "name delete branches", r"Name every branch to delete; never use a glob"),
    ("fleet", "## Experiments", "record result and branch head before delete", r"Before deleting an experiment branch after the run, record its exact name, head SHA and results in the experiment doc; this session deletes it only after those records exist"),
    ("fleet", "## Experiments", "wake brief override", r"For an experiment, its brief overrides the usual worker-branch and PR fields: use `exp/<slug>`, open no PR, and record results in the experiment doc"),
    ("fleet", "## Experiments", "wake and ops mechanics", r"Follow `wake` for the task, brief, spawn preview and landing proof"),
    ("fleet", "## Records", "operator message record with redaction exception", r"Before acting on an operator message, put it verbatim in the session's decision doc with the time from `date` and the session's reading, except for the credential redactions required by the next rule"),
    ("fleet", "## Records", "secret pattern and label detection", r"Identify credential-like values by recognizable patterns or message labels such as password, PIN, passphrase, secret, token, key or credential; do this without copying or repeating candidate values"),
    ("fleet", "## Records", "uncertain secret redaction", r"Replace each value with `\[secret omitted\]`, note the omission, and ask the operator to rotate any exposed credential; apply the same redaction to raw source copies\. When unsure, redact and ask the operator instead of storing the value verbatim"),
    ("fleet", "## Records", "source register", r"Keep a source register for every link the operator gives: the message, read date and method, redacted raw copy, finding, and decisions grounded in it"),
    ("fleet", "## Records", "finding sources and date", r"A finding names exact source URLs and its read date"),
    ("fleet", "## Records", "decision sources", r"A decision names its findings and experiments"),
    ("fleet", "## Records", "hk docs", r"Store records in hk docs"),
    ("fleet", "## Records", "mechanical transcript check", r"Close with a mechanical check of the decision doc against the transcript"),
    ("fleet", "## Backlog pass", "backlog pass pointer", r"runs the backlog pass for the fleet-tool repositories and the small projects, in one pass, by hk:doc `policy/backlog-pass`"),
    ("wake", "## Authority", "wake cross-reference", r"\*\*fleet-policy session:\*\* settles cross-repo policy and experiments, then hands code to the owning design session; it never merges or deploys \(`fleet-policy` §Authority\)\. Its recorded decisions bind design sessions for `policy/model-routing`, `policy/model-families` and `policy/quota-stop`"),
    ("wake", "## Backlog pass", "wake backlog pass pointer", r"A large project's own design session runs the same pass for its own project, by hk:doc `policy/backlog-pass`"),
    ("wake", "## Authority", "policy divergence record, hold and owner", r"\*\*Policy divergence:\*\* when a design session settles an operator decision that differs from an hk policy doc owned by `fleet-policy` \(`policy/model-routing`, `policy/model-families` or `policy/quota-stop`\), record it in an hk decision doc and tell the lane hk `policy/design-sessions` names for this role\. Hold the conflicting decision until fleet-policy records the operator's explicit yes and updates the owned policy doc; fleet-policy makes that update"),
    ("lead", "## Subagents", "lead spawn cross-reference", r"`panewire spawn` stays the design session's tool \(`wake` §The loop\) and the fleet-policy session's tool for its experiments only \(`fleet-policy` §Experiments\)"),
    ("roles", None, "roles vocabulary", r"\*\*fleet-policy\*\*: operator-opened session that settles cross-repo policy, runs bounded catalog experiments and keeps catalog records"),
    ("roles", "## Rules", "explorer-resolves-as-implementer", r"An explorer is a read-only in-session searcher and resolves as `implementer`;"),
    ("roles", None, "implementer-verifier-resolve-list", r"panewire resolve --role <implementer\|verifier> --grade <G> --t <Tn>"),
    ("roles", None, "reviewer-judge-author-family-resolve-list", r"panewire resolve --role <reviewer\|judge> --author-family <author family>"),
    ("roles", None, "lead no routing role and reviewer resolution", r"A lead has no routing role: the operator opens the lead session; its subagents resolve as implementer or verifier, and its cross-family reviewer resolves as reviewer using the author-family option"),
    ("roles", None, "consult resolve form", r"panewire resolve --role consult\s+# consult takes no --grade"),
    ("roles", None, "consult verifier and lead refusal names", r"no policy and no cache for `consult`/`verifier` or a lead's implementer/searcher subagent"),
    ("roles", None, "consult verifier alternate model rule", r"`consult`, `verifier`: do not start that work on any other model"),
    ("roles", None, "lead implementer explorer refusal path", r"For a lead's implementer or searcher subagent, wait on `role_exhausted_wait` or escalate to the parent lane on `role_exhausted_escalate` or a missing policy; a lead never writes product code because a subagent resolution refused"),
    ("robin", "## Where each rule lives", "robin rule home", r"Cross-repo policy settling, experiments, catalog records \| `fleet-policy` \(rstack\)"),
    ("robin", "## Where each rule lives", "robin backlog-pass row", r"Backlog pass: who runs it, when, its steps and the intake rules \| hk `policy/backlog-pass`"),
    ("robin", "## Subagents versus spawned workers", "robin experiment spawn exception", r"A `fleet-policy` experiment replay may use `panewire spawn` without an independent PR, as defined in `fleet-policy` §Experiments; no other spawned worker is exempt from the own-PR rule"),
    ("sets", None, "full not worker install", r"sets: full=[^;]*\bfleet-policy\b[^;]*; worker=(?![^;]*\bfleet-policy\b)"),
    ("triggers", None, "trigger fixture", r'"fleet-policy": \["fleet-policy", "policy session", "정책 세션", "experiment", "실험", "catalog"\]'),
    ("agents", None, "AGENTS layout", r"first-party skills \(wake, ops, lead, desk, fleet-policy, fleet-review, robin-mode\)"),
]

FORBIDDEN = {
    "role-grants-code-push-merge-deploy": re.compile(r"(?i)\bfleet-policy(?: session)?\b[^.\n]{0,160}\b(?:may|can|is allowed to|is permitted to|is authorized to)\b[^.\n]{0,80}\b(?:write(?: code)?|push|merge|deploy)\b"),
    "operator-request-non-consult-rung": re.compile(r"(?i)--operator-request[^.\n]{0,100}(?:default|non-consult|implementer) rung"),
    "branch-delete-glob": re.compile(r"(?i)delete[^.\n]{0,60}branches?[^.\n]{0,30}(?:\*|glob)"),
    "literal-role-lane-option": re.compile(rf"--lane\s+{re.escape(role_name)}|lane\s+`{re.escape(role_name)}`"),
    "retired-lead-routing-role": re.compile(r"panewire resolve --role lead"),
    "operator-desk-creates-hk-records": re.compile(r"(?i)operator-desk (?:creates?|makes?) hk records?"),
    "unconditional-deploy-to-operator-desk": re.compile(r"(?i)deploys? \(operator-desk\)"),
    "stale-catalog-admission-task": re.compile(r"handoffkeep tasks show 3960"),
    "role-worker": re.compile(r"--role worker"),
    "routing-role": re.compile(r"--routing-role"),
    "builder-family": re.compile(r"--builder-family"),
    "role-counsel": re.compile(r"--role counsel"),
    "explorer-resolve-role": re.compile(r"panewire resolve --role [^\n`]*explorer"),
}

def check(current):
    for doc, heading, row, pattern in REQUIRED:
        scope = flat(current[doc] if not heading else section(current[doc], heading))
        assert re.search(pattern, scope), f"{doc}: row '{row}' missing or weakened"
    for name, pattern in FORBIDDEN.items():
        if name in {"role-worker", "routing-role", "builder-family", "role-counsel", "explorer-resolve-role"}:
            text = "\n".join(current.values())
            assert not pattern.search(text), f"skills: forbidden row '{name}' present"
            continue
        if name == "role-grants-code-push-merge-deploy":
            for doc in ("fleet", "wake", "lead", "roles", "robin"):
                match = pattern.search(flat(current[doc]))
                assert not match, f"{doc}: forbidden rule '{name}' present: {match.group(0)!r}"
            continue
        if name == "retired-lead-routing-role":
            scope = flat(current["roles"])
        elif name == "literal-role-lane-option":
            scope = flat(current["fleet"])
        else:
            scope = flat(current["fleet"])
        match = pattern.search(scope)
        assert not match, f"forbidden rule '{name}' present: {match.group(0)!r}"
    authority = section(current["fleet"], "## Authority")
    grant_pos = authority.index("This role writes its hk")
    marker_pos = authority.index("*Temporary (operator 2026-11-11, hk 3959):")
    interim_pos = authority.index("- Until hk 3963 is complete and its record confirms client-id admission,")
    assert grant_pos < marker_pos < interim_pos, "temporary marker must scope the interim restriction, not the permanent conditional grant"
    marker_line = authority[marker_pos: authority.index("\n", marker_pos)]
    interim_line = authority[interim_pos: authority.index("\n", interim_pos)]
    condition = "hk 3963 is complete and its record confirms client-id admission"
    assert f"ends when {condition}" in marker_line and f"Until {condition}" in interim_line, "catalog-write marker and restriction must share one end condition"

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
    ("literal-role-lane-option", f"- Spawn with `--lane {role_name}`.\n"),
    ("operator-desk-creates-hk-records", "- operator-desk creates hk records.\n"),
    ("unconditional-deploy-to-operator-desk", "- This session is not for deploys (operator-desk).\n"),
    ("stale-catalog-admission-task", "- Check `handoffkeep tasks show 3960`.\n"),
    ("role-worker", "- Example: `--role worker`.\n"),
    ("routing-role", "- Example: `--routing-role consult`.\n"),
    ("builder-family", "- Example: `--builder-family openai`.\n"),
    ("role-counsel", "- Example: `--role counsel`.\n"),
    ("explorer-resolve-role", "- Example: `panewire resolve --role explorer`.\n"),
]:
    target = "wake" if name == "role-grants-code-push-merge-deploy" else "fleet"
    expect_red(f"{name}-injected", check, {**docs, target: docs[target] + "\n" + injected})
    count += 1
expect_red("retired-lead-routing-role-injected", check,
           {**docs, "roles": docs["roles"].replace("## Rules", "panewire resolve --role lead\n\n## Rules", 1)})
count += 1
grant = "- This role writes its hk `policy/*`, `decision/*`, `experiment/*` and `findings/*` docs and hk tasks directly. It may write catalog-push files and the catalog itself once hk admits its client id."
marker = "*Temporary (operator 2026-11-11, hk 3959): ends when hk 3963 is complete and its record confirms client-id admission (hk 3963).*"
misplaced = docs["fleet"].replace(grant + "\n" + marker, marker + "\n\n" + grant)
expect_red("temporary-marker-misplaced-on-grant", check, {**docs, "fleet": misplaced})
count += 1
print(f"PASS mutants assertion-red={count}/{count}")
PY
