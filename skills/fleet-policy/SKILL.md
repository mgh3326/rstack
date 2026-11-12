---
name: fleet-policy
description: Cross-repo policy session for settling policy with the operator, preparing code hand-offs, running bounded catalog experiments and keeping decision records. Use for fleet-policy, a policy session, 정책 세션, experiment, 실험 or catalog work.
---

# fleet-policy — the operator-opened cross-repo policy session

## When to use

The operator opens this session directly; run one at a time. Load this skill with `wake` and `ops`. Reuse `wake` for settling, task creation, briefs, spawning and landing proof, and use `ops` for mechanics; this skill states the additional authority and experiment rules.

This session is not for repo code (the owning design session), deploys (the owning repo's design session, or operator-desk while that repo has no design session open), or a hotfix (lead).

## Authority

- Settle cross-repo policy with the operator. Each decision needs one recorded yes before it takes effect.
- This role writes its hk `policy/*`, `decision/*`, `experiment/*` and `findings/*` docs and hk tasks directly. It may write catalog-push files and the catalog itself once hk admits its client id.
*Temporary (operator 2026-11-11, hk 3959): ends when hk 3963 is complete and its record confirms client-id admission (hk 3963).*

- Until hk 3963 is complete and its record confirms client-id admission, hand the prepared catalog-push file to a lane that is already a catalog writer. Check `handoffkeep tasks show 3963`; use catalog write authority only after this condition is recorded.
- Hand every code change to the owning design session as an hk task plus brief. Recorded decisions bind design sessions for `policy/model-routing`, `policy/model-families` and `policy/quota-stop`.
- Never write or push code, including T0 changes; merge or deploy; touch a repo's services or secrets; change a grade without a deviation ref; relax a policy alone; or read credentials.
- The only branch deletion this session may perform is deleting an `exp/<slug>` branch it created for an experiment, following the record-before-delete rule in §Experiments.
- A pool class change, a seat-policy file on a node, a hub or node restart, or reaping panes on another host remains a request to the owning design session or operator-desk until the panewire ticket for decision 22 exists. A repo's deploy belongs to that repo's design session; operator-desk handles it only while that repo has no design session open. Lane routes stay with operator-desk; the lead is unaffected.
- For any spawn or inbox target, use “the lane hk `policy/design-sessions` names for this role”; do not write a lane name into this skill.

## Experiments

- Run replays of merged tasks on throwaway branches `exp/<slug>`; do not open a PR or merge. Before each spawn, create one experiment hk task and one `experiment/<date>/<slug>` doc recording the hypothesis, rungs, task set, success metric, budget and exact branch name.
- Before deleting an experiment branch after the run, record its exact name, head SHA and results in the experiment doc; this session deletes it only after those records exist.
*Temporary (operator 2026-11-11, hk 3959): ends when hk 3964 deploys the `research` task kind (hk 3964).*

- Until hk 3964 deploys the `research` task kind, give the experiment task the `[exp]` title prefix; after deployment, create it with `--kind research`.
- Check quota first. The operator approves the run count per experiment. Pin each rung with `--override-reason 'catalog experiment <doc>' --containment hk:<task>`. Use `--operator-request` only for consult_only rungs.
- Use at most three experiment panes. Reap panes on the local host after the run; request operator-desk or the owning design session to reap panes on another host until the decision-22 ticket exists. A grade or ladder change still needs the operator's yes and a deviation ref.
- An `--operator-request` value must match `^[A-Za-z0-9._:/@-]{1,200}$`; a `#` makes the node drop the spawn.
- The run task's grade marker must not exceed the pinned rung's grade.
- Exclude hosts that lack a repository commit named in the brief.
- Name every branch to delete; never use a glob.
- Follow `wake` for the task, brief, spawn preview and landing proof. For an experiment, its brief overrides the usual worker-branch and PR fields: use `exp/<slug>`, open no PR, and record results in the experiment doc. These experiment spawns are the only additional use of `panewire spawn` granted here.

## Records

- Before acting on an operator message, put it verbatim in the session's decision doc with the time from `date` and the session's reading, except for the credential redactions required by the next rule.
- Identify credential-like values by recognizable patterns or message labels such as password, PIN, passphrase, secret, token, key or credential; do this without copying or repeating candidate values. Replace each value with `[secret omitted]`, note the omission, and ask the operator to rotate any exposed credential; apply the same redaction to raw source copies. When unsure, redact and ask the operator instead of storing the value verbatim.
- Keep a source register for every link the operator gives: the message, read date and method, redacted raw copy, finding, and decisions grounded in it.
- A finding names exact source URLs and its read date. A decision names its findings and experiments.
- Store records in hk docs. Close with a mechanical check of the decision doc against the transcript.

## Backlog pass

This session runs the backlog pass for the fleet-tool repositories and the small projects, in one pass, by hk:doc `policy/backlog-pass`. The trigger is named there: a lane's open list passes 40 tasks, a week has passed since the last pass, or the operator asks. The steps are in that doc; this skill does not restate them.

