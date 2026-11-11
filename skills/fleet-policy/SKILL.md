---
name: fleet-policy
description: Cross-repo policy session for settling policy with the operator, preparing code hand-offs, running bounded catalog experiments and keeping decision records. Use for fleet-policy, a policy session, 정책 세션, experiment, 실험 or catalog work.
---

# fleet-policy — the operator-opened cross-repo policy session

## When to use

The operator opens this session directly; run one at a time. Load this skill with `wake` and `ops`. Reuse `wake` for settling, task creation, briefs, spawning and landing proof, and use `ops` for mechanics; this skill states the additional authority and experiment rules.

This session is not for repo code (the owning design session), deploys (operator-desk), or a hotfix (lead).

## Authority

- Settle cross-repo policy with the operator. Each decision needs one recorded yes before it takes effect.
*Temporary (operator 2026-11-11, hk 3959): ends when hk admits the role's client id as a catalog writer (hk 3960).*

Once that condition is met, write hk `policy/*`, `decision/*`, `experiment/*`, `findings/*`, catalog-push files and the catalog itself.
- Check admission with `handoffkeep tasks show 3960`; proceed as a catalog writer only when the task is `done` and its outcome confirms this role's client id is admitted. Until then, ask operator-desk to create hk records, including experiment tasks and docs, and do not act on a decision or spawn an experiment until its required hk record exists.
- Hand every code change to the owning design session as an hk task plus brief. Recorded decisions bind design sessions for `policy/model-routing`, `policy/model-families` and `policy/quota-stop`.
- Never write or push code, including T0 changes; merge or deploy; touch a repo's services or secrets; change a grade without a deviation ref; relax a policy alone; or read credentials.
- The only branch deletion this session may perform is deleting an `exp/<slug>` branch it created for an experiment, after the exact branch name is listed in that experiment doc; this session performs that deletion after the run.
- A pool class change, a seat-policy file on a node, a hub or node restart, a deploy, or reaping panes on another host remains a request to the owning design session or operator-desk until the panewire ticket for decision 22 exists. Lane routes stay with operator-desk; the lead is unaffected.
- For any spawn or inbox target, use “the lane hk `policy/design-sessions` names for this role”; do not write a lane name into this skill.

## Experiments

- Run replays of merged tasks on throwaway branches `exp/<slug>`; do not open a PR or merge. Before each spawn, create one `[exp]` hk task and one `experiment/<date>/<slug>` doc recording the hypothesis, rungs, task set, success metric, budget and exact branch name. Before hk admission, operator-desk creates those records; otherwise this session creates them.
- Check quota first. The operator approves the run count per experiment. Pin each rung with `--override-reason 'catalog experiment <doc>' --containment hk:<task>`. Use `--operator-request` only for consult_only rungs.
- Use at most three experiment panes. Reap panes on the local host after the run; request operator-desk or the owning design session to reap panes on another host until the decision-22 ticket exists. A grade or ladder change still needs the operator's yes and a deviation ref.
- An `--operator-request` value must match `^[A-Za-z0-9._:/@-]{1,200}$`; a `#` makes the node drop the spawn.
- The run task's grade marker must not exceed the pinned rung's grade.
- Exclude hosts that lack a repository commit named in the brief.
- Name every branch to delete; never use a glob.
- Follow `wake` for the task, brief, spawn preview and landing proof. For an experiment, its brief overrides the usual worker-branch and PR fields: use `exp/<slug>`, open no PR, and record results in the experiment doc. These experiment spawns are the only additional use of `panewire spawn` granted here.

## Records

- Before acting on an operator message, put it verbatim in the session's decision doc with the time from `date` and the session's reading; before hk admission, ask operator-desk to make that record and wait for its hk key.
- Before storing a message or raw source copy, redact any credential-like value as `[secret omitted]`, note the omission, and ask the operator to rotate the exposed credential. Apply the same redaction to raw source copies; never read or copy the credential value.
- Keep a source register for every link the operator gives: the message, read date and method, redacted raw copy, finding, and decisions grounded in it.
- A finding names exact source URLs and its read date. A decision names its findings and experiments.
- Store records in hk docs. Close with a mechanical check of the decision doc against the transcript.
