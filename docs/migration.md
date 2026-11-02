# Consolidation provenance

Copied from agent-skills ad768e4d4421ebe5db56ec209bd36a5bc7ed2b5c.
Includes live skill, retained tool, related test and vendor review changes from
PR #333 at 00ac4bdb8848ea82f06bf5c80f372d2b5011f496 and the changed-tests-only
ops invariant from PR #334 at 56c124929dd12a1a7d948b337ab7c89a529100d1.
Retired director and legacy installer changes from those PRs are excluded.

| Old executable | Decision | Caller/evidence |
|---|---|---|
| bin/arbiter | retire | replaced by panewire jobs list (hk 2718); host rollout waits for that panewire release |
| bin/fleet-install | move with tests | docs/fleet-install.md executable examples; retained desk release-install interface |
| bin/fleet-rev | move with tests; probe rstack checkout | source README revision-audit examples; retained desk audit interface |
| bin/rob-lookup | retire | archive source superseded by handoffkeep docs linear/<ID>; active count supplied by the archive job; no source tests |
| scripts/needs-full-macos | retire | old CI classification and its test; replaced by both-platform CI for retained tests |
| scripts/resolve-ci-ref | retire | old ci-any-ref workflow and test; new CI directly checks the event head |
| scripts/shellcheck-capped | retire | old lint wrapper and bin/wrk changed-function path; neither is live here |

No director tools or policy hash pins are imported. The old installer's dependency
and quota probes are retired; installing skill links no longer executes fleet tools.
The vendored upstream scripts and agents remain absent as recorded in PINNED.

## Harness discovery evidence and limits

The manifest records discovery roots and evidence. OMP installed source has
native `discovery/builtin.ts:324`, shared `agents.ts:177` and explicit opt-in
Claude/Codex user sources (`extensibility/skills.ts:308-313`). Those opt-ins and
custom directories must be checked per host; enabling them can create duplicates.
CommandCode's installed `createSkillRegistry` scans its native and shared agent
roots; its bundled skill reference documents the native root. Devin's `skills
paths` lists native, cognition and agent roots, while a real read-only print
session also sees Claude skills. The approved exception installs Devin's full
set only in Claude's root. No documented setting disabling that compatibility
scan has been established; isolation is a follow-up investigation, not a rollout gate.
A real agy print session reports Gemini's skill root, so both use the worker set.

Filesystem checks in a temporary HOME prove the installation graph, excluded-name
absence and duplicate-source absence. They do not prove actual catalogs in every
harness. Actual before/after session catalogs for Claude, OMP, CommandCode, Gemini,
Kiro and OpenCode are UNVERIFIED here; host rollout verification must capture them.
Codex's current session catalog exposes the old recursive vendor leak. The two
read-only worker probes confirm current discovery; no actual host links were changed.
Plugins and project/configured roots outside the manifest remain host audit scope.

Source host aliases in first-party references and fixture labels are anonymised.

PR B carries the final agent-skills #333 delta from `00ac4bd` to source head
`269e6d9e98fa5158dee0cf060322827501c52dc5` (author commit `4b53f85`).
Code, tests and workspace guidance are copied; the source README configuration
warning is adapted into docs/fleet-rev.md without private host inventory.
