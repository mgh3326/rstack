# AGENTS.md — rstack

Fleet skills, their contract tests, and the installer that links them into each harness's skill root.

## Layout
- `skills/` — first-party skills (wake, ops, lead, desk, fleet-policy, fleet-review, robin-mode). `skills/ops/references/` holds the
  ops mechanics; `skills/robin-mode/roles.md` holds the role map.
- `tests/` — contract tests (`test-*.sh`, `test-*.py`) and `tests/lib/contract.py` (section scoping, row deletion,
  mutant checks).
- `install.sh`, `install/sets.json`, `scripts/` — the installer and its manifest.
- `bin/` — retained tools (`pr-trailers`, deprecated `fleet-install` and `fleet-rev`).
- `third_party/pstack/` — pinned upstream skills. Do not edit them; the adapter is in `skills/robin-mode/SKILL.md`.

## Build and test
- Fleet sessions (spawned workers, design sessions, leads) follow the spawn preamble's host rules: run only the tests
  for what you changed.
- People and CI run the full suite: `bash tests/run-all.sh` (Python 3.9+ and Git).
- A skill-text change runs the contract tests that pin it, for example `bash tests/test-ops-wake-contract.sh`,
  `bash tests/test-lead-skill.sh`, `bash tests/test-desk-skill-contract.sh` and `bash tests/test-rule-consistency.sh`.
- Installer changes: `python3 tests/test-install.py` and `python3 tests/test-adapter.py`.

## Rules
- A rule string a contract test pins changes together with its test in the same PR. A new rule gets a required row
  with a deletion mutant; a removed rule gets a forbidden row with an injected mutant. Every mutant must go RED.
- Skill text is English. A section that is already Korean stays Korean.
- This is a public repository. Write no host names, pane ids, account ids, secrets, or lane names other than
  `operator-desk` and `lead`.
- Do not rewrite a safety or authority rule away; change its scope, reason or exception inside the rule.

## Done means
- The changed tests pass and every mutant is RED.
- The PR body ends with the Mergewake trailers (`wake` §Worker brief; `bin/pr-trailers` prints them for a PR
  opened outside a worker job).
