#!/usr/bin/env bash
# Stale receiver, lead role, STUCK event and trailer-generation contract.
# Every required row has a deletion mutant; every forbidden row an injection mutant.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys
root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tests/lib"))
from contract import delete_row, expect_red, flat  # noqa: E402

PATHS = {
    "fleet": root / "skills/fleet-review/SKILL.md",
    "deploy": root / "skills/ops/references/deploy-checklist.md",
    "wake": root / "skills/wake/SKILL.md",
    "roles": root / "skills/robin-mode/roles.md",
    "lead": root / "skills/lead/SKILL.md",
}
docs = {k: p.read_text(encoding="utf-8") for k, p in PATHS.items()}
# (doc, name, required regex on flattened document)
REQUIRED = [
    ("fleet", "receiver-context", r"worker-, lead-, and repo-design-session-side half \(operator-desk while that repo has no design session open\)"),
    ("fleet", "triage-receiver", r"repo's design session, else operator-desk, applies it by hand when it reads the merge gate"),
    ("fleet", "critical-high-receiver", r"on every other PR, the repo's design session judges, or operator-desk while that repo has none open"),
    ("fleet", "escalation-receiver", r"ESC to the repo's design session, else operator-desk"),
    ("fleet", "round-receiver", r"repo's design session, else operator-desk, decides"),
    ("fleet", "ladder-trigger", r"\*\*Trigger:\*\* 3 review rounds without convergence \(a new critical/high on each\)"),
    ("fleet", "rounds-not-heads", r"Review rounds are counted, not heads; a head that only merges the base is not a round"),
    ("fleet", "worker-round-3-consult-only", r"at round 3 without a pass, stop patching and ask for a consult one grade above your own seat in another family \(`ops` consult\), giving it every finding so far and asking for the root cause\. Nothing else happens at round 3"),
    ("fleet", "defer-follow-up-worker-owns", r"The worker files at most one follow-up hk task per PR, in the same project and lane and related to the parent task; put the findings in its list"),
    ("fleet", "defer-disposition-info", r"For a deferred finding, the worker replies `Disposition: defer <id>`\. The worker sends one `info` to the design session naming the task"),
    ("fleet", "defer-asks-fact-or-choice", r"Ask the design session only for a missing fact or a design choice"),
    ("fleet", "missed-merge-fix-follows-up", r"The same worker files a follow-up task for a fix that missed the merge; do not open a second PR or ESC it to the design session"),
    ("fleet", "ladder-panewire-interim-marker", r"\*Temporary \(operator 2026-11-12, hk 4268\): ends when panewire hk 4262 ships \(hk 4262\)\.\*"),
    ("fleet", "ladder-mergewake-interim-marker", r"\*Temporary \(operator 2026-11-12, hk 4268\): ends when mergewake hk 4264 ships \(hk 4264\)\.\*"),
    ("fleet", "ladder-round-5-interim", r"Until panewire hk 4262 ships, at round 5 without a pass the worker ESCs with every finding; the design session re-spawns the PR's work pinned to the next rung"),
    ("fleet", "ladder-round-5-hub-step", r"After panewire hk 4262 ships, the hub moves the worker one ladder step up on the same worktree; the design lane gets an inbox record and no interrupt"),
    ("fleet", "ladder-round-7-interim", r"Until mergewake hk 4264 ships, at round 7 without a pass the worker ESCs; the design session keeps the PR held, then cuts the scope .* or takes one SS consult on the design"),
    ("fleet", "ladder-round-7-tool", r"After mergewake hk 4264 ships, mergewake holds the PR and sends the design lane one event at round 7"),
    ("fleet", "ladder-same-worker-seat-after-5", r"The same worker does not keep patching at the same seat after round 5"),
    ("fleet", "ladder-policy-home", r"hk:doc `policy/model-families` §The escalation ladder is the one home of the order"),
    ("fleet", "ladder-pinned-respawn", r"re-spawns the PR's work pinned to the next rung with `--override-reason 'ladder step <from> → <to>, PR <n>'` and records the failed rung"),
    ("fleet", "ladder-step-three", r"then one try on another family's seat at the same grade \(operator A26\)"),
    ("fleet", "ladder-model-cap", r"effort up to that model's ladder cap"),
    ("fleet", "ladder-not-computed", r"\*\*panewire does not compute the step yet\*\* \(hk 3917 item 4\)"),
    ("fleet", "non-converging-pr-to-lead", r"\*\*Then the lead:\*\* when the ladder has no step left, or the cause is a correctness design the brief left open \(`wake` §Brief rules\), the session hands the PR, its open findings and the brief to a lead"),
    ("fleet", "reviewer-family-receiver", r"checks them all, the repo's design session, else operator-desk, does"),
    ("deploy", "join-receiver", r"레포 디자인 세션, 없으면 operator-desk로 전달한 경로/시각"),
    ("wake", "ready-receiver", r"repo's design session, else operator-desk, says you are done"),
    ("roles", "lead-in-session-only", r"A lead uses in-session subagents only, as `lead` §Subagents specifies; it never delegates or spawns workers"),
    ("roles", "lead-excluded-from-self-fallback", r"This fallback does not apply to a lead: a lead writes product code only for a small hotfix within the threshold in `lead` §Authority"),
    ("lead", "stuck-event-design", r"panewire emit --kind lane\.event --lane <repo>-design --type blocked --event-id <repo>-lead-stuck-<unique-id> --text '\[lead\] STUCK \| <what> \| <tried> \| <alternative A/B>'"),
    ("lead", "stuck-event-fallback", r"panewire emit --kind lane\.event --lane operator-desk --type blocked --event-id <repo>-lead-stuck-<unique-id> --text '\[lead\] STUCK \| <what> \| <tried> \| <alternative A/B>'"),
    ("lead", "stuck-design-lane-source", r"The repo's design session uses `<repo>-design` \(default per `decision/2026-11-10/lead-direct-merge`\)"),
    ("lead", "trailers-command", r"bin/pr-trailers --task <id> --family <family> --profile <profile> --lane lead"),
]
FORBIDDEN = [
    ("fleet", "old-round-3-ladder-step", r"round-3 ESC.{0,160}re-spawns the PR's work pinned to the next rung"),
    ("fleet", "old-round-5-scope-choice", r"In both states, at round 5 without a pass.{0,260}the design session cuts the scope"),
    ("fleet", "old-hk-4256-marker", r"hk 4256"),
    ("fleet", "old-round-3-same-seat-rule", r"same worker keeps patching at the same seat after round 3"),
    ("fleet", "old-heads-trigger", r"3 reviewed heads"),
    ("fleet", "old-desk-receiver", r"the desk applies it by hand"),
    ("fleet", "ladder-next-grade", r"another family's seat at the same or the next grade"),
    ("fleet", "old-desk-review-check", r"the desk checks it"),
    ("fleet", "old-desk-esc", r"ESC to the desk"),
    ("fleet", "old-desk-round", r"the desk decides"),
    ("fleet", "old-desk-family-check", r"the desk does\. Which reviewer"),
    ("wake", "old-ready-desk", r"or the desk says you are done"),
    ("roles", "lead-spawns", r"A lead delegates and spawns"),
    ("roles", "lead-spawn-worker-claim", r"Lead[^\n]{0,100}spawns workers"),
    ("roles", "lead-writes-no-code-absolute", r"a lead, which writes no product code"),
    ("lead", "hardcoded-stuck-lane", r"handoffkeep" + r"-design"),
    ("lead", "handwritten-trailer-list", r"otherwise `Mergewake-Author-Family`"),
]

def check(d):
    for name, pattern in []:
        pass
    for doc, name, pattern in REQUIRED:
        assert re.search(pattern, flat(d[doc])), f"{doc}: required row {name} missing"
    for doc, name, pattern in FORBIDDEN:
        assert not re.search(pattern, flat(d[doc])), f"{doc}: forbidden row {name} present"
    for line in d["lead"].splitlines():
        if line.lstrip().startswith("panewire emit") and "STUCK" in line:
            assert "--type" in line, "lead: STUCK emit has no --type"

check(docs)
count = 0
for doc, name, pattern in REQUIRED:
    expect_red(f"{doc}-{name}-deleted", check, {**docs, doc: delete_row(docs[doc], None, pattern, name)})
    count += 1
INJECTIONS = {
    "old-round-3-ladder-step": "On the round-3 ESC the session re-spawns the PR's work pinned to the next rung.",
    "old-round-5-scope-choice": "In both states, at round 5 without a pass, the design session cuts the scope or takes one SS consult.",
    "old-hk-4256-marker": "Temporary (operator 2026-11-12, hk 4257): ends when mergewake hk 4256 ships.",
    "old-round-3-same-seat-rule": "The same worker keeps patching at the same seat after round 3 is not allowed.",
    "old-heads-trigger": "**Trigger:** 3 reviewed heads without convergence",
    "old-desk-receiver": "the desk applies it by hand",
    "ladder-next-grade": "then another family's seat at the same or the next grade.",
    "old-desk-review-check": "the desk checks it",
    "old-desk-esc": "ESC to the desk",
    "old-desk-round": "the desk decides",
    "old-desk-family-check": "checks them all, the desk does. Which reviewer",
    "old-ready-desk": "or the desk says you are done",
    "lead-spawns": "A lead delegates and spawns under robin-mode.",
    "lead-spawn-worker-claim": "Lead delegates and spawns workers.",
    "lead-writes-no-code-absolute": "This fallback does not apply to a lead, which writes no product code.",
    "hardcoded-stuck-lane": "handoffkeep-" + "design",
    "handwritten-trailer-list": "otherwise `Mergewake-Author-Family`",
}
for doc, name, pattern in FORBIDDEN:
    expect_red(f"{doc}-{name}-injected", check, {**docs, doc: docs[doc] + "\n" + INJECTIONS[name] + "\n"})
    count += 1
# Missing --type is a separate forbidden rule checked on the actual command line.
expect_red("lead-stuck-without-type-injected", check, {**docs, "lead": docs["lead"] + "\n  panewire emit --kind lane.event --lane <repo>-design --event-id x --text STUCK\n"})
count += 1
print(f"PASS stale-receivers required={len(REQUIRED)} forbidden={len(FORBIDDEN) + 1} mutants assertion-red={count}/{count}")
PY
