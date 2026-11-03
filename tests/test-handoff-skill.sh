#!/usr/bin/env bash
# hk 2789: the handoff skill closes a design session one way.
#   1. skills/handoff/SKILL.md has its five sections in order, plus attribution.
#   2. The code blocks in SKILL.md run as written against a stand-in CLI that keeps the flag
#      rules of today's handoffkeep: gate before writes, idempotent retries, read-back, notify.
#   3. references/intake.md and references/design-session.md carry their required content.
#   4. Every command the docs name uses flags today's CLI accepts.
# Every required row and behaviour has a mutant that must go RED, including the Close decisions gate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import atexit
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
FIXTURES = root / "tests/fixtures/handoff"
PATHS = {
    "skill": "skills/handoff/SKILL.md",
    "intake": "skills/handoff/references/intake.md",
    "design": "skills/handoff/references/design-session.md",
    "license": "skills/handoff/LICENSE-mattpocock-skills",
    "robin": "skills/robin-mode/SKILL.md",
}
docs = {name: (root / rel).read_text(encoding="utf-8") for name, rel in PATHS.items()}
sets = json.loads((root / "install/sets.json").read_text(encoding="utf-8"))["sets"]

SECTIONS = ("## Close decisions", "## Slice into tickets", "## Emit to hk", "## Verify before closing", "## Notify the desk")
NOT_NEUTRAL = re.compile(r"claude|codex|AskUserQuestion|spawn_agent|\.agents/", re.IGNORECASE)
# Flags the installed handoffkeep and panewire accept for the forms these docs use.
CLI_FLAGS = {
    "handoffkeep tasks add": {"lane", "project", "kind", "doc", "title"},
    "handoffkeep tasks export": {"state", "limit"},
    "handoffkeep tasks comment": {"body"},
    "handoffkeep tasks comments": {"limit"},
    "handoffkeep tasks show": set(),
    "handoffkeep tasks transition": {"to", "by", "note"},
    "handoffkeep tasks decision-request": {"human-only", "question", "option", "recommended", "reason", "default-action", "doc"},
    "handoffkeep tasks decision-resolve": {"request", "kind", "option", "responder", "text"},
    "handoffkeep doc put": {"key", "kind", "file"},
    "handoffkeep doc get": set(),
    "panewire emit": {"kind", "lane", "event-id", "text"},
    "panewire lead": {"c", "p", "dry-run"},
    "panewire work": {"c", "p", "dry-run"},
}


def flat(text):
    return re.sub(r"\s+", " ", text)


def section(text, heading):
    assert f"\n{heading}\n" in text, f"missing section: {heading}"
    body = text.split(f"\n{heading}\n", 1)[1]
    level = len(heading) - len(heading.lstrip("#"))
    outside, kept = True, []
    for line in body.splitlines(True):
        if line.startswith("```"):
            outside = not outside
        if outside and re.match(rf"#{{1,{level}}} ", line):
            break
        kept.append(line)
    return "".join(kept)


# (doc, section or None, row, pattern on the flattened scope)
REQUIRED = [
    ("skill", "## Close decisions", "gate", r"Do not start §Slice until this section's table is complete\. §Emit refuses a doc that fails it"),
    ("skill", "## Close decisions", "walk-tree", r"Walk it in rounds until it is empty"),
    ("skill", "## Close decisions", "resolve-sources", r"Resolve facts yourself\*\*, in this order: code, docs, hk"),
    ("skill", "## Close decisions", "operator-only-open", r"Only operator-level items may stay open"),
    ("skill", "## Close decisions", "table", r"\| Point \| Decided \| By \| Evidence \|"),
    ("skill", "## Close decisions", "question-shape", r"\*\*Options:\*\* A <option> / B <option> \*\*Default:\*\*"),
    ("skill", "## Slice into tickets", "mergeable", r"Independently mergeable"),
    ("skill", "## Slice into tickets", "tracer", r"A tracer bullet"),
    ("skill", "## Slice into tickets", "edges", r"Blocking edges only where"),
    ("skill", "## Slice into tickets", "pinned", r"so cite `<repo>@<sha> <path>:<line>`"),
    ("skill", "## Emit to hk", "parent-title", r"`\[handoff:<slug>\] <goal> \(grade <G>, <Tn>\)`, with kind `implement` or `decide`"),
    ("skill", "## Emit to hk", "child-title", r"`\[handoff:<slug> <n>/<N>\] <title> \(grade <G>, <Tn>\)`"),
    ("skill", "## Emit to hk", "until-2770", r"Until hk has parent and sub-tasks \(hk 2770\)"),
    ("skill", "## Emit to hk", "doc-key", r"`handoff/<repo>/<YYYY-MM-DD>-<slug>`, kind `note`\. The `decision` kind is currently rejected"),
    ("skill", "## Emit to hk", "idempotent", r"Retries are idempotent"),
    ("skill", "## Verify before closing", "check-acceptance", r"Every ticket has acceptance and evidence"),
    ("skill", "## Verify before closing", "check-tbd", r"No ticket says \"TBD\" or \"decide later\"\. Only an operator question may stay open"),
    ("skill", "## Verify before closing", "check-show", r"`handoffkeep tasks show` returns each id"),
    ("skill", "## Verify before closing", "check-readback", r"The doc reads back"),
    ("skill", "## Notify the desk", "line", r"`\[handoff\] <slug> <parent-id> \| handoff/<repo>/<date>-<slug>`\. Then the session may be closed"),
    ("skill", "## Notify the desk", "event-id-required", r"`panewire` requires `--event-id` and refuses a repeated one"),
    ("skill", "## Notify the desk", "inbox-root", r"Set `PANEWIRE_INBOX_ROOT=<root>` from that message and rerun the whole script"),
    ("skill", "## Provenance", "grilling", r"`skills/productivity/grilling/SKILL\.md`"),
    ("skill", "## Provenance", "to-tickets", r"`skills/engineering/to-tickets/SKILL\.md`"),
    ("skill", "## Provenance", "agent-brief", r"`skills/engineering/triage/AGENT-BRIEF\.md`"),
    ("skill", "## Provenance", "mit", r"MIT, Copyright \(c\) 2026 Matt Pocock"),
    ("skill", "## Provenance", "pin", r"`4ae2317`"),
    ("license", None, "license-copyright", r"Copyright \(c\) 2026 Matt Pocock"),
    ("license", None, "license-grant", r"Permission is hereby granted, free of charge"),
    ("intake", "## 1. Read the handoff doc", "read-doc", r"handoffkeep doc get <doc-key>"),
    ("intake", "## 2. Dedupe against open tasks", "dedupe", r"--to dropped --by operator-desk --note 'duplicate of hk <id>'"),
    ("intake", "## 3. Record a disposition per ticket", "accepted", r"disposition: <n>/<N> accepted → <ticket-id>"),
    ("intake", "## 3. Record a disposition per ticket", "reason", r"disposition: <n>/<N> rejected: <one-line reason>"),
    ("intake", "## 4. Group tickets into lead sessions", "group", r"One lead per chain"),
    ("intake", "## 5. Spawn", "spawn", r"panewire lead <parent-or-group-id> -c <worktree> -p <brief> --dry-run"),
    ("intake", "## 5. Spawn", "wait-blockers", r"Start a ticket only when every task whose `blocks:` names it has landed"),
    ("intake", "## 6. Put operator questions into one decision request", "one-request", r"All of a handoff's questions go into one request on the parent"),
    ("intake", "## 6. Put operator questions into one decision request", "human-only", r"handoffkeep tasks decision-request <parent-id> --human-only"),
    ("intake", "## 6. Put operator questions into one decision request", "resolve", r"handoffkeep tasks decision-resolve <parent-id>"),
    ("design", None, "no-spawn", r"Design sessions do not spawn workers or merge"),
    ("robin", "## Where each rule lives", "home", r"\| `handoff` \(rstack\) \|"),
]
PHASES = (
    ("Understand", ("how", "why", "recall")),
    ("Shape", ("architect", "principle-foundational-thinking", "principle-model-the-domain", "statechart")),
    ("Stress", ("blast-radius", "interrogate", "sharpen")),
    ("Consult", ("ops",)),
    ("Close", ("handoff",)),
)


def check_static(d, s):
    skill = d["skill"]
    positions = [skill.find(f"\n{h}\n") for h in SECTIONS]
    assert -1 not in positions, f"skill: missing section {SECTIONS[positions.index(-1)]}"
    assert positions == sorted(positions), "skill: the five sections are out of order"
    for doc, heading, row, pattern in REQUIRED:
        scope = flat(section(d[doc], heading) if heading else d[doc])
        assert re.search(pattern, scope), f"{doc}: row '{row}' missing or weakened"
    for name in ("skill", "intake", "design"):
        m = NOT_NEUTRAL.search(d[name])
        assert not m, f"{name}: names a harness-specific term {m.group(0)!r}"
        for lane in re.findall(r"--(?:lane|by) (\S+)", d[name]):
            assert lane == "operator-desk", f"{name}: names a lane other than operator-desk: {lane}"
    rows = re.findall(r"(?m)^\| (\d)\. (\w+) \| (.*?) \|", d["design"])
    assert [r[1] for r in rows] == [p[0] for p in PHASES], f"design: phases are not in order: {rows}"
    for (_, _, cell), (phase, skills) in zip(rows, PHASES):
        assert [x for x in re.findall(r"`([^`]+)`", cell)][: len(skills)] == list(skills), f"design: {phase} skills differ: {cell}"
        for name in skills:
            assert name in s["full"], f"design: {name} is not in the full install set"
    assert "handoff" in s["full"], "handoff missing from the full install set"
    assert "handoff" not in s["worker"], "handoff must not be in the worker install set"


def check_cli_forms(d):
    for name in ("skill", "intake", "design"):
        text = d[name].replace("\\\n", " ")
        for line in text.splitlines():
            for m in re.finditer(r"\b(handoffkeep (?:tasks|doc) [a-z-]+|panewire (?:emit|lead|work))\b(.*)", line):
                form, rest = m.group(1), m.group(2)
                if "`" in line.split(form)[0][-1:]:
                    continue  # An inline mention in prose, not a command line.
                assert form in CLI_FLAGS, f"{name}: command not checked against the CLI: {form}"
                rest = re.sub(r"\"[^\"]*\"|'[^']*'", "ARG", rest).split("|")[0]
                for flag in re.findall(r"(?:^|\s)--?([a-z][a-z-]*)", rest):
                    assert flag in CLI_FLAGS[form], f"{name}: {form} has no --{flag} on today's CLI"


def script_blocks(skill):
    blocks = []
    for heading in SECTIONS[2:]:
        blocks += re.findall(r"(?ms)^```sh\n(.*?)^```$", section(skill, heading))
    assert len(blocks) == 4, f"skill: expected 4 sh blocks in Emit, Verify and Notify, found {len(blocks)}"
    return blocks


GOOD_BODY = """# Handoff

## Decisions

| Point | Decided | By | Evidence |
|---|---|---|---|
| Storage | Keep one table | code | repo@abc1234 store.go:10 |
| Scope | Two tickets | operator | "two is fine" |

## Tickets

### ticket-1
**Title:** Add the reader
**Kind:** implement
**Grade:** A, T1
**Expected:** 6h
**Blocks:** 2
**Current:** No reader.
**Desired:** A reader exists.
**Key interfaces:** `read()`
**Acceptance:**
- `tool read` → prints the row
**Out of scope:** Writing.
**Evidence:** `repo@abc1234 store.go:10` — the table

### ticket-2
**Title:** Add the writer
**Kind:** fix
**Grade:** S+, T2
**Expected:** 2h
**Blocks:** none
**Current:** No writer.
**Desired:** A writer exists.
**Key interfaces:** `write()`
**Acceptance:**
- `tool write` → exits 0
**Out of scope:** Reading.
**Evidence:** `repo@abc1234 store.go:20` — the row

## Operator questions

### q-1
**Question:** Ship behind a flag? TBD by the operator.
**Options:** A yes / B no
**Default:** A — stays off

## Commits read

- `repo@abc1234`
"""


class Run:
    def __init__(self, skill, body, env=None, state_dir=None):
        self.dir = Path(state_dir or tempfile.mkdtemp(prefix="handoff-test."))
        atexit.register(shutil.rmtree, self.dir, ignore_errors=True)
        body_path = self.dir / "body.md"
        body_path.write_text(body, encoding="utf-8")
        values = (f"set -euo pipefail\nslug=demo\nrepo=demo-repo\nproject=fleet-ops\nkind=implement\n"
                  f"goal='Ship the demo'\ngrade='A, T1'\nexpected=1d\nbody={body_path}\n")
        (self.dir / "run.sh").write_text(values + "\n".join(script_blocks(skill)[1:]), encoding="utf-8")
        self.state = self.dir / "state.json"
        self.log = self.dir / "panewire.log"
        full_env = {**os.environ, "PATH": f"{self.dir / 'bin'}:{os.environ['PATH']}", "HK_STUB_STATE": str(self.state),
                    "PANEWIRE_STUB_LOG": str(self.log), **(env or {})}
        bin_dir = self.dir / "bin"
        if not bin_dir.exists():
            bin_dir.mkdir()
            for tool in ("handoffkeep", "panewire"):
                shutil.copy(FIXTURES / tool, bin_dir / tool)
                (bin_dir / tool).chmod(0o755)
        self.proc = subprocess.run(["bash", str(self.dir / "run.sh")], env=full_env, capture_output=True, text=True, timeout=120)

    @property
    def hk(self):
        return json.loads(self.state.read_text()) if self.state.exists() else {"tasks": [], "comments": [], "docs": {}}

    @property
    def notified(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def assert_refused(self, label, reason):
        assert self.proc.returncode != 0, f"{label}: expected a refusal, script exited 0"
        assert reason in self.proc.stderr, f"{label}: expected {reason!r}, got: {self.proc.stderr}"
        assert not self.hk["tasks"] and not self.hk["docs"], f"{label}: wrote to hk before refusing"
        assert not self.notified, f"{label}: notified the desk"


def scenario_happy(skill):
    good = Run(skill, GOOD_BODY)
    assert good.proc.returncode == 0, f"happy path failed: {good.proc.stderr}"
    tasks = good.hk["tasks"]
    titles = [t["title"] for t in tasks]
    assert titles == ["[handoff:demo] Ship the demo (grade A, T1)", "[handoff:demo 1/2] Add the reader (grade A, T1)",
                      "[handoff:demo 2/2] Add the writer (grade S+, T2)"], f"titles: {titles}"
    parent, one, two = (t["id"] for t in tasks)
    assert all(t["lane"] == "operator-desk" for t in tasks), "tasks are not on the desk lane"
    assert [t["kind"] for t in tasks] == ["implement", "implement", "fix"], "ticket Kind was not applied"
    key = tasks[0]["body_doc"]
    assert re.fullmatch(r"handoff/demo-repo/\d{4}-\d{2}-\d{2}-demo", key), f"doc key: {key}"
    assert tasks[1]["body_doc"] == f"{key}#ticket-1", "child does not point at its section"
    bodies = {(c["task_id"], c["body"]) for c in good.hk["comments"]}
    assert (one, f"parent: {parent}\nblocks: {two}\nExpected: 6h") in bodies, f"ticket 1 link comment: {bodies}"
    assert (two, f"parent: {parent}\nblocks: none\nExpected: 2h") in bodies, f"ticket 2 link comment: {bodies}"
    doc = good.hk["docs"][key]
    for text in ("## Decisions", "## Operator questions", "## Commits read", f"| 1/2 | {one} |", f"| 2/2 | {two} |", f"Parent: {parent}"):
        assert text in doc, f"doc lacks {text!r}"
    assert len(good.notified) == 1, f"notify: {good.notified}"
    assert re.fullmatch(rf"emit --kind lane\.event --lane operator-desk --event-id handoff-demo-{parent}-\d+-\d+ --text \[handoff\] demo {parent} \| {re.escape(key)}", good.notified[0]), f"notify: {good.notified}"
    assert (parent, "notified: operator-desk") in {(c["task_id"], c["body"]) for c in good.hk["comments"]}, "notice not recorded in hk"


def scenario_retry(skill):
    """A rerun changes nothing, even when the first run stopped part way."""
    good = Run(skill, GOOD_BODY)
    assert good.proc.returncode == 0, f"first run failed: {good.proc.stderr}"
    before = good.hk
    again = Run(skill, GOOD_BODY, state_dir=good.dir)
    assert again.proc.returncode == 0, f"rerun failed: {again.proc.stderr}"
    assert again.hk["tasks"] == before["tasks"], "rerun created tasks"
    assert again.hk["comments"] == before["comments"], "rerun repeated comments"
    assert len(again.notified) == 1, f"rerun notified again: {again.notified}"
    assert "already notified" in again.proc.stdout, f"rerun did not report the earlier notice: {again.proc.stdout}"
    state = again.hk
    state["tasks"] = state["tasks"][:2]
    state["comments"], state["docs"] = [], {}
    again.state.write_text(json.dumps(state))
    resumed = Run(skill, GOOD_BODY, state_dir=again.dir)
    assert resumed.proc.returncode == 0, f"resume failed: {resumed.proc.stderr}"
    assert [t["id"] for t in resumed.hk["tasks"]] == [1000, 1001, 1002], "resume did not create only the missing ticket"


def scenario_gate(skill):
    """Nothing is written while the doc fails §Close decisions or §Slice."""
    Run(skill, GOOD_BODY.replace("| Scope | Two tickets | operator |", "| Scope | | operator |")).assert_refused("open-decision", "close the decisions")
    Run(skill, GOOD_BODY.replace("| Scope | Two tickets | operator |", "| Scope | Two tickets | session |")).assert_refused("bad-source", "close the decisions")
    no_table = re.sub(r"(?s)\| Point.*?\n\n", "\n", GOOD_BODY, count=1)
    Run(skill, no_table).assert_refused("no-decisions", "close the decisions")
    Run(skill, GOOD_BODY.replace("**Default:** A — stays off\n", "")).assert_refused("question-no-default", "q-1 has no Default")
    Run(skill, GOOD_BODY.replace("- `tool read` → prints the row\n", "")).assert_refused("no-acceptance", "ticket-1 has no acceptance")
    Run(skill, GOOD_BODY.replace("`repo@abc1234 store.go:20` — the row", "see the table")).assert_refused("no-evidence", "ticket-2 has no file:line evidence")
    Run(skill, GOOD_BODY.replace("No reader.", "TBD")).assert_refused("tbd-in-ticket", "only an operator question may stay open")
    Run(skill, GOOD_BODY.replace("**Blocks:** none", "**Blocks:** 1")).assert_refused("backward-edge", "ticket-2 may block only")
    Run(skill, GOOD_BODY.replace("- `repo@abc1234`\n", "")).assert_refused("no-commits", "no commit SHAs")


def scenario_failed_search(skill):
    """A failed search is not "nothing found"."""
    Run(skill, GOOD_BODY, env={"HK_STUB_FAIL_EXPORT": "dropped"}).assert_refused("export-failed", "export failed")


def scenario_read_back(skill):
    """A doc that does not read back stops the session from notifying."""
    bad_read = Run(skill, GOOD_BODY, env={"HK_STUB_CORRUPT_DOC": "1"})
    assert bad_read.proc.returncode != 0 and "does not read back" in bad_read.proc.stderr, f"read-back: {bad_read.proc.stderr}"
    assert not bad_read.notified, "notified after a failed read-back"


def scenario_notify_refused(skill):
    """A refused emit fails the run, a plain rerun stays failed, and only a real delivery counts."""
    mismatch = {"PANEWIRE_STUB_ROOT_MISMATCH": "1"}
    notice = {"notified: operator-desk"}
    refused = Run(skill, GOOD_BODY, env=mismatch)
    assert refused.proc.returncode != 0, "script exited 0 although the desk was not notified"
    assert "inbox root mismatch" in refused.proc.stderr, f"notify refusal: {refused.proc.stderr}"
    assert not notice & {c["body"] for c in refused.hk["comments"]}, "recorded a notice that was refused"
    rerun = Run(skill, GOOD_BODY, env=mismatch, state_dir=refused.dir)
    assert rerun.proc.returncode != 0, "a rerun claimed success although the desk was never notified"
    fixed = Run(skill, GOOD_BODY, state_dir=refused.dir)
    assert fixed.proc.returncode == 0, f"rerun after the fix failed: {fixed.proc.stderr}"
    assert len(fixed.notified) == 1, f"delivered notices: {fixed.notified}"


SCENARIOS = (scenario_happy, scenario_retry, scenario_gate, scenario_failed_search, scenario_read_back, scenario_notify_refused)


def check_all(d, s):
    check_static(d, s)
    check_cli_forms(d)


check_all(docs, sets)
for scenario in SCENARIOS:
    scenario(docs["skill"])
print(f"PASS handoff-skill sections={len(SECTIONS)} rows={len(REQUIRED)} phases={len(PHASES)}")


def expect_red(label, d, s=sets, scenario=None):
    try:
        check_all(d, s)
        if scenario:
            scenario(d["skill"])
    except AssertionError:
        return
    except Exception as exc:
        raise AssertionError(f"{label} errored instead of assertion RED: {exc}") from exc
    raise AssertionError(f"mutant {label} did not go RED")


count = 0
for doc, heading, row, pattern in REQUIRED:
    text = docs[doc]
    start = text.index(f"\n{heading}\n") + len(heading) + 2 if heading else 0
    end = start + len(section(text, heading)) if heading else len(text)
    words = re.search(pattern, flat(text[start:end])).group(0).split()
    raw = re.compile(r"\s+".join(re.escape(w) for w in words)).search(text, start, end)
    assert raw, f"fixture: row {row} not found unflattened in its section"
    expect_red(f"row-{row}-deleted", {**docs, doc: text[: raw.start()] + text[raw.end():]})
    count += 1

skill = docs["skill"]
for heading in SECTIONS:
    expect_red(f"section-{heading}-removed", {**docs, "skill": skill.replace(f"\n{heading}\n", "\n## Other\n", 1)})
    count += 1
first, second = "## Close decisions", "## Slice into tickets"
swapped = skill.replace(f"\n{first}\n", "\n@@\n").replace(f"\n{second}\n", f"\n{first}\n").replace("\n@@\n", f"\n{second}\n")
expect_red("sections-swapped", {**docs, "skill": swapped})
expect_red("harness-specific-term", {**docs, "skill": skill + "\nUse the Claude Agent tool.\n"})
expect_red("private-lane", {**docs, "intake": docs["intake"] + "\n--lane other-lane\n"})
expect_red("refused-flag", {**docs, "skill": skill.replace('--kind "$kind" --doc "$doc"', '--kind "$kind" --expected 1d --doc "$doc"', 1)})
expect_red("phase-removed", {**docs, "design": re.sub(r"(?m)^\| 3\. Stress.*\n", "", docs["design"])})
expect_red("skill-not-installed", docs, {**sets, "full": [n for n in sets["full"] if n != "interrogate"]})
expect_red("handoff-not-in-full-set", docs, {**sets, "full": [n for n in sets["full"] if n != "handoff"]})
expect_red("handoff-in-worker-set", docs, {**sets, "worker": sets["worker"] + ["handoff"]})
count += 8

# The whole Close decisions gate removed: the prose and the check that enforces it.
close = section(skill, "## Close decisions")
no_gate = skill.replace(close, "\nWrite down what you remember.\n\n", 1)
expect_red("close-decisions-gate-prose-removed", {**docs, "skill": no_gate})
count += 1

# Each of these keeps the prose and breaks only the behaviour, so only a real run can see it.
BEHAVIOUR = {
    "close-decisions-gate-not-run": (scenario_gate, 'check_body "$body"\n', ""),
    "decision-table-unchecked": (scenario_gate, '  check_decisions "$1"\n', ""),
    "questions-unchecked": (scenario_gate, '  check_questions "$1"\n', ""),
    "tickets-unchecked": (scenario_gate, '  check_tickets "$1"\n', "  N=$(grep -c '^### ticket-[0-9][0-9]*$' \"$1\")\n"),
    "open-items-unchecked": (scenario_gate, '  check_open_items "$1"\n', ""),
    "commits-unchecked": (scenario_gate, '  check_commits "$1"\n', ""),
    "export-failure-ignored": (scenario_failed_search, '  handoffkeep tasks export --state "$s" --limit 5000\n', '  handoffkeep tasks export --state "$s" --limit 5000 || true\n'),
    "parent-search-removed": (scenario_retry, 'parent=$(find_task "[handoff:$slug]")\n', "parent=\n"),
    "child-search-removed": (scenario_retry, 'id=$(find_task "[handoff:$slug $n/")\n', "id=\n"),
    "comments-repeat": (scenario_retry, "jq -e --arg b \"$2\" 'any(.comments[]; .body == $b)' <<<\"$existing\" >/dev/null ||\n    ", ""),
    "read-back-removed": (scenario_read_back, '[ "$(cat "$out")" = "$(cat "$readback")" ] || refuse "doc $doc does not read back as written"\n', ""),
    "notify-removed": (scenario_happy, 'panewire emit --kind lane.event --lane operator-desk --event-id "handoff-$slug-$parent-$(date +%s)-$$" \\\n    --text "[handoff] $slug $parent | $doc"\n', ":\n"),
    "event-id-dropped": (scenario_happy, ' --event-id "handoff-$slug-$parent-$(date +%s)-$$" \\\n    --text', ' --text'),
    "notice-repeats-on-rerun": (scenario_retry, """if jq -e 'any(.comments[]; .body == "notified: operator-desk")' <<<"$existing" >/dev/null; then""", "if false; then"),
    "notice-recorded-before-emit": (scenario_notify_refused, """  panewire emit --kind lane.event""", """  handoffkeep tasks comment "$parent" --body 'notified: operator-desk' >/dev/null\n  panewire emit --kind lane.event"""),
    "fixed-event-id": (scenario_notify_refused, '"handoff-$slug-$parent-$(date +%s)-$$"', '"handoff-$slug-$parent"'),
    "ids-not-in-doc": (scenario_happy, """printf '| %s/%s | %s | %s |\\n' "$n" "$N" "${ids[n - 1]}" """, """printf '| %s/%s | %s | %s |\\n' "$n" "$N" "?" """),
}
for label, (scenario, old, new) in BEHAVIOUR.items():
    assert skill.count(old) == 1, f"fixture: mutant {label} matches {skill.count(old)} times"
    expect_red(label, {**docs, "skill": skill.replace(old, new)}, scenario=scenario)
    count += 1
print(f"PASS mutants assertion-red={count}/{count}")
PY
