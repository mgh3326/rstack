# handoff — from a repo session to the desk

The operator has deep design conversations in repo sessions and then brings the outcome to the desk.
Chat scrollback does not survive that move, so the repo session writes one hk doc and the desk works
from the doc.

## What the repo session produces

An hk doc with the key `handoff/<repo>/<date>-<slug>`, where `<date>` comes from `date +%F`:

```sh
handoffkeep doc put --key "handoff/<repo>/$(date +%F)-<slug>" --kind report --file <path>
```

```markdown
# Handoff — <repo>: <topic>

## Items (highest priority first)
1. <what to do and why>
   - evidence: <file:line>
   - effort: <2h | 6h | 1d>
   - dependency: <item number | hk id | none>

## Decisions made
- <decision> — <who decided, and why>

## Open questions
- <question> — <options, default, who can answer>
```

Every item carries all three fields. Write `dependency: none` when there is none. An item with no
`file:line` is a question: move it to §Open questions.

Then give the doc key to the desk (`panewire emit --kind lane.event --lane <desk lane>`, or the operator
carries it). The repo session stops there and creates no tasks from the doc.

## What the desk does with it

The desk turns **each item into a task linked under the project**:

1. Search first (`desk` §Before `tasks add`). An item that matches a task becomes a comment on it.
2. Otherwise add one task per item:
   `handoffkeep tasks add --project <project> --title '<title> (grade <G>, <T>)' --expected <effort> --doc <doc key>`.
3. Record each item's dependency on its task as `next:` and `trigger:` (`desk` §Task record).
4. Each open question that needs the operator becomes one decision request (`decision-request.md`).

Decisions made stay in the doc. A later task cites the doc key instead of asking again.
