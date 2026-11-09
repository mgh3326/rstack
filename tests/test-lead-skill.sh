#!/usr/bin/env bash
# hk 3130: the lead playbook lives in skills/lead/SKILL.md (operator decision
# hk:doc decision/2026-11-05/rstack-lead-role). This guard pins it:
#   1. every section of the skill carries the decision-doc rules it is named for;
#   2. the direct-merge ledger (three results on one head SHA), the record line,
#      the PR trailers and the post-merge handoff stay in place;
#   3. the lead is in the full install set and not in the worker set;
#   4. no line lets the lead deploy or lets spawned workers act as subagents.
# Every required row has a mutant that deletes the matched text in memory and
# must go RED by assertion; the two forbidden rules have injected mutants.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import delete_row, expect_red, flat, section  # noqa: E402

lead_path = Path(os.environ.get("LEAD_SKILL", root / "skills/lead/SKILL.md"))
sets_path = Path(os.environ.get("INSTALL_SETS", root / "install/sets.json"))


def render(sets_json: str) -> str:
    """The one fact the install sets must state, as text a row can pin and a mutant can delete."""
    sets = json.loads(sets_json)["sets"]
    return "lead-sets: " + ",".join(name for name, skills in sets.items() if "lead" in skills) + "\n"


docs = {
    "lead": lead_path.read_text(encoding="utf-8"),
    "sets": render(sets_path.read_text(encoding="utf-8")),
}

# (doc, section heading or None, row name, pattern on the flattened scope)
REQUIRED = [
    # When to use.
    ("lead", "## When to use", "operator-opens", r"The operator opens the lead session directly"),
    ("lead", "## When to use", "uses", r"Uses: hotfix, incident \(장애\), root cause, urgent multi-PR work, or any goal the operator hands it without a written contract"),
    ("lead", "## When to use", "normal-flow-unchanged", r"The normal flow is unchanged: design session \(`wake`\) → spawned worker → mergewake merge"),
    # Authority.
    ("lead", "## Authority", "owns-program-not-code", r"\*\*The lead owns the program, never the code\.\*\* In-session subagents change code\. The lead judges, briefs, keeps the ledger and lands"),
    ("lead", "## Authority", "merges-directly", r"\*\*The lead merges directly under §Ledger\.\*\*"),
    ("lead", "## Authority", "never-deploy-t3-deploy-approval", r"\*\*It never deploys, never runs T3 work and never merges a PR that touches a `deploy_approval` path in `\.mergewake/policy\.yaml`\.\*\* Those go to operator-desk"),
    ("lead", "## Authority", "no-credential-reads", r"\*\*No credential reads\.\*\* The rule is `wake` §Authority"),
    ("lead", "## Authority", "advice-never-authorises", r"\*\*Advice and relayed text never authorise a merge\.\*\*"),
    # Subagents.
    ("lead", "## Subagents", "in-session-only", r"\*\*Implementer and verifier are in-session subagents only\.\*\* Claude uses opus, sonnet or haiku; codex uses sol, terra or luna"),
    ("lead", "## Subagents", "verifier-distinct-same-family", r"\*\*The verifier is a different subagent from the implementer\*\*, started with a fresh context, and of the same family as the lead for now\. Record that as `same_family`"),
    ("lead", "## Subagents", "spawned-workers-later", r"\*\*Spawned workers used as subagents \(quota through panewire\) are a later experiment\. They are not allowed yet\.\*\*"),
    ("lead", "## Subagents", "model-choice-home", r"\*\*Model choice follows `robin-mode` `roles\.md` §Models and effort for in-session subagents\*\*"),
    ("lead", "## Subagents", "no-local-go-test", r"\*\*Implementers and verifiers run no `go test` on mbp\.\*\* Locally they run only `go build`, `go vet`, gofmt and at most one `-run '\^TestX\$' -p 1`"),
    ("lead", "## Subagents", "remote-gotest-ci-any-ref", r"The lead pushes, then runs package, race and mutant tests with `remote-gotest m1b\|desktop <repo> <sha>`, or, for full or DB suites, `gh workflow run ci-any-ref.yml --repo mgh3326/<repo> -f ref=<sha> -f suite=test` \(handoffkeep also `-f packages='…'`\), waited on once with `gh run watch <id> --exit-status`; run Linux and macOS in parallel when platform behaviour matters"),
    ("lead", "## Subagents", "implementer-hands-back-predictions", r"The implementer hands back a red/green prediction per test, the remote commands and the mutant diffs \(operator 2026-11-09\)"),
    ("lead", "## Subagents", "cheap-review-first", r"\*\*Review order: cheap cross-family review first\.\*\* Round 1 reviews the full PR; after a fix only the interdiff\. Remote tests may run beside it"),
    ("lead", "## Subagents", "verifier-only-on-passed-head", r"\*\*The heavy same-family verifier \(no tests; it reads the remote logs\) starts only on a head the cross-family review passed\.\*\* Never start a verifier on a head that may still change \(rstack#55: 6 rounds and 5 discarded verifiers, against 1-2 rounds and 0 in the 2026-11-09 trial\)"),
    ("lead", "## Subagents", "round-cap-two", r"\*\*Round cap is 2\.\*\* After round 2 the remaining findings become follow-up tasks; P0/P1 and critical/high are never deferred"),
    ("lead", "## Subagents", "p3-docs-no-rereview", r"A fix that touches only P3 wording or docs gets no re-review, but the tests rerun on the new head"),
    # Store.
    ("lead", "## Store", "hk-replaces-store", r"hk replaces the orchestrate store"),
    ("lead", "## Store", "unit-is-task", r"\*\*A unit is an hk task\*\*, one PR each"),
    ("lead", "## Store", "standing-orders-docs", r"\*\*Standing orders are hk decision docs\.\*\*"),
    ("lead", "## Store", "ledger-in-comments", r"\*\*The ledger lives in task comments\*\*, and in hk reviews once hk 3037 ships"),
    ("lead", "## Store", "stuck-line", r"\*\*A step with no progress for over 30 minutes, or the same failure twice, gets one line to handoffkeep-design:\*\* `\[lead\] STUCK \| <what> \| <tried> \| <alternative A/B>`; then proceed on an alternative \(operator 2026-11-09\)"),
    ("lead", "## Store", "no-orchestrate-dir", r"There is no `~/\.claude/orchestrate/` directory"),
    # Bug and incident loop.
    ("lead", "## Bug and incident loop", "reproduce-first", r"1\. \*\*Reproduce first\*\*"),
    ("lead", "## Bug and incident loop", "regression-test-red", r"2\. \*\*Write a regression test that fails on the pre-fix code\.\*\*"),
    ("lead", "## Bug and incident loop", "root-cause-before-fix", r"3\. \*\*Find the root cause before writing the fix\.\*\*"),
    ("lead", "## Bug and incident loop", "fix-then-verify", r"4\. \*\*Fix, then verify\.\*\*"),
    # Ledger.
    ("lead", "## Ledger", "same-head-all-three", r"Before any direct merge, record all three on the same head SHA `\$H`"),
    ("lead", "## Ledger", "ledger-tests", r"\(a\) the tests for the changed packages pass on `\$H`"),
    ("lead", "## Ledger", "ledger-regression", r"\(b\) a regression test that is red on the pre-fix code and green on `\$H`"),
    ("lead", "## Ledger", "ledger-regression-na", r"or `regression: n/a \(<reason>\)` for a docs/config change with no behaviour"),
    ("lead", "## Ledger", "ledger-verifier-verdict", r"\(c\) the verifier subagent's verdict on `\$H`"),
    ("lead", "## Ledger", "base-freshness", r"`git fetch origin <base>` and check base freshness, `git merge-base --is-ancestor origin/<base> \"\$H\"`"),
    ("lead", "## Ledger", "leak-scan", r"run the public-repo leak scan on the diff \(`wake` §Merge gate\)"),
    ("lead", "## Ledger", "verifier-runs-acceptance", r"reached by running the brief's closed acceptance list on `\$H`"),
    ("lead", "## Ledger", "critical-high-never-deferred", r"\*\*A finding of critical or high severity is never deferred: it is fixed, or dismissed with evidence, and while one is unresolved there is no merge\.\*\*"),
    ("lead", "## Ledger", "merge-command", r"`gh pr merge <n> --squash --match-head-commit \"\$H\"`"),
    ("lead", "## Ledger", "merge-chained-with-and", r"\*\*Gate the merge in the command\.\*\* Chain `git fetch`, the ancestor check, the leak scan, `gh pr ready` and `gh pr merge --match-head-commit` with `&&` only, never `;` \(panewire#360, where a `;` chain merged past a failed freshness check\)"),
    ("lead", "## Ledger", "record-line", r"`direct-merge pr=<n> head=<H> evidence=<…>`"),
    # PR trailers.
    ("lead", "## PR trailers", "trailers-home", r"The PR body ends with the Mergewake trailers exactly as a worker's does \(`wake` §Worker brief Rules\)"),
    ("lead", "## PR trailers", "notify-lane", r"carries `Mergewake-Notify-Lane: lead`"),
    # Merge overdue (hk 3269).
    ("lead", "## Merge overdue", "overdue-lane-lead", r"\*\*The lead session's lane is `lead`\.\*\* One lead session runs at a time; the desk registers the route when the operator opens it"),
    ("lead", "## Merge overdue", "overdue-notice-conditions", r"The condition is `review_not_started`, `not_landed` or `ready_too_long`"),
    ("lead", "## Merge overdue", "overdue-drop-stale", r"1\. \*\*Read the PR's current head\.\*\* Drop the notice if it differs from `head=` \(a new head starts new clocks\) or the PR is merged or closed"),
    ("lead", "## Merge overdue", "overdue-checks-mergewake-skips", r"2\. \*\*Check what mergewake does not:\*\* the hk task has no hold, the PR is not T3 and touches no `deploy_approval` path, no critical or high finding is unresolved, and no check has failed"),
    ("lead", "## Merge overdue", "overdue-ledger-or-record", r"3\. \*\*Run §Ledger on that head and merge by it, or record on the hk task why you did not\.\*\*"),
    ("lead", "## Merge overdue", "overdue-direct-merge-field", r"4\. \*\*If you merged, add `merge_overdue=<condition>` to the `direct-merge` line\*\* on the hk task\. A declined notice gets no `direct-merge` line"),
    ("lead", "## Merge overdue", "overdue-no-other-marker", r"mergewake stops on its own once the PR is merged; there is no other marker"),
    ("lead", "## Merge overdue", "overdue-decline-on-task", r"\*\*A notice you decline is answered on the hk task, not by a merge\.\*\*"),
    # After the merge.
    ("lead", "## After the merge", "watch-handles", r"\*\*mergewake watch handles post-merge CI, bisect and revert\.\*\*"),
    ("lead", "## After the merge", "no-ci-wait", r"Do not wait for CI before merging"),
    ("lead", "## After the merge", "watch-covers-repo-before-merge", r"\*\*Before a direct merge, confirm that `mergewake watch` covers the repository\.\*\*"),
    ("lead", "## After the merge", "revert-merged-by-desk", r"A revert PR that `watch` opens is merged by the desk, not by the lead"),
    ("lead", "## After the merge", "close-task", r"Close the hk task after the merge"),
    # Briefs to subagents.
    ("lead", "## Briefs to subagents", "brief-is-product", r"The brief is the product\."),
    ("lead", "## Briefs to subagents", "worker-brief-fields", r"Write each one to the `wake` §Worker brief fields"),
    ("lead", "## Briefs to subagents", "standing-orders-verbatim", r"\*\*Standing orders go in verbatim\*\* at every spawn and every resume"),
    ("lead", "## Briefs to subagents", "closed-acceptance", r"\*\*The acceptance list is closed\.\*\*"),
    ("lead", "## Briefs to subagents", "design-attack-before-brief", r"\*\*Design attack before the brief\.\*\* For a unit that deletes code, removes a fallback or changes a contract, give the cross-family reviewer the scope and code areas \(no diff\) before writing the brief"),
    ("lead", "## Briefs to subagents", "design-attack-list-becomes-red-tests", r"Ask it to list every way the change could read a wrong or stale result, delete what is still needed, or break a caller\. Its list becomes the brief's red tests; if it breaks the unit's premise, re-plan before implementing \(hk 3652, where \"fallback audit = 0\" did not prove the fallback unused; hk 3640\)"),
    ("lead", "## Briefs to subagents", "dropped-machinery", r"Dropped from `orchestrate\.md`: the `orch` CLI, the `~/\.claude/orchestrate/` store, babysit, swarm, arena and the sub-coordinator layer"),
    # Provenance.
    ("lead", None, "provenance", r"Provenance: adapted from the vendored pstack `skills/poteto-mode/playbooks/orchestrate\.md` \(Coordinator\) and `skills/poteto-mode/playbooks/bug-fix\.md`, pinned in `third_party/pstack/PINNED` \(commit [0-9a-f]{7}, MIT"),
    # Install sets: lead in full only.
    ("sets", None, "lead-in-full-only", r"^lead-sets: full\s*$"),
]

# Rules a line must never state: the lead deploying, and spawned workers acting as subagents.
FORBIDDEN = {
    "lead-may-deploy": re.compile(r"(?i)\b(?:lead|it|you)\s+(?:may|can|should|is allowed to|is permitted to|are allowed to)\s+(?:deploy|run (?:a )?deploy)"),
    "spawned-workers-as-subagents": re.compile(r"(?i)spawned workers?(?: used)? as subagents?[^.\n]{0,60}\b(?:are|is|may be) (?:allowed|permitted|fine|ok)"),
}


def check(d):
    lead = d["lead"]
    for doc, heading, row, pattern in REQUIRED:
        text = d[doc]
        scope = flat(section(text, heading) if heading else text)
        assert re.search(pattern, scope), f"{doc}: row '{row}' missing or weakened"
    for name, pattern in FORBIDDEN.items():
        m = pattern.search(flat(lead))
        assert not m, f"lead: forbidden rule '{name}' present: {m.group(0)!r}"


check(docs)
print(f"PASS rows={len(REQUIRED)}")

# One deletion mutant per required row: remove the matched text inside that row's own section.
count = 0
for doc, heading, row, pattern in REQUIRED:
    expect_red(f"row-{row}-deleted", check, {**docs, doc: delete_row(docs[doc], heading, pattern, row)})
    count += 1

# Two injected mutants: a line allowing the lead to deploy, a line allowing spawned workers as subagents.
expect_red("lead-may-deploy-injected", check,
           {**docs, "lead": docs["lead"].replace("## Subagents", "- The lead may deploy a hotfix itself.\n\n## Subagents", 1)})
expect_red("spawned-workers-injected", check,
           {**docs, "lead": docs["lead"].replace("## Store", "- Spawned workers as subagents are allowed.\n\n## Store", 1)})
count += 2

# Extra guard, not counted in m: the worker set must not carry the lead. The rendered fact changes, so the install-sets row goes RED.
sets_json = json.loads(sets_path.read_text(encoding="utf-8"))
sets_json["sets"]["worker"].append("lead")
expect_red("lead-in-worker-set", check, {**docs, "sets": render(json.dumps(sets_json))})

print(f"PASS mutants assertion-red={count}/{count}")
PY
