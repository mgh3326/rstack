# intake — the desk's side of a `[handoff]` event

A `[handoff] <slug> <parent-id> | <doc-key>` line is a pointer; the doc and the tasks are the record. The
session that wrote them may already be gone, so read them instead of asking back. Rerunning intake is safe:
step 1 lists the dispositions already recorded on the parent.

## 1. Read the handoff doc

```sh
handoffkeep doc get <doc-key> | jq -r .body
handoffkeep tasks show <parent-id>
handoffkeep tasks comments <parent-id> --limit 500 | jq -r '.comments[].body | select(startswith("disposition: "))'
```

Dispositions live on the parent, not on the ticket. Skip any ticket whose `<n>/<N>` is already listed. Compare `## Commits read` with
`git rev-parse origin/main`. If a file a ticket cites has changed since, re-read the citation before you
accept that ticket.

## 2. Dedupe against open tasks

Export open tasks once, and stop if any export fails or is truncated: a partial list would hide the duplicate. Then search by
keyword for each ticket, leaving this handoff's own tasks out:

```sh
snap=$(mktemp)
if (for s in backlog claimed in_progress hold needs_decision verifying join reopened; do
  handoffkeep tasks export --state "$s" --limit 10000 || exit 1
done) >"$snap" && jq -es 'all(.[]; (.counts.total | type) == "number" and .counts.total <= (.tasks | length))' "$snap" >/dev/null; then
  jq -r --arg own '[handoff:<slug>' '.tasks[]
    | select((.title | startswith($own)) | not)
    | select(.title | test("<keyword>"; "i"))
    | "\(.id) \(.state) \(.title)"' "$snap"
else
  echo 'export failed: do not accept any ticket yet' >&2
fi
```

If an open task already covers the work, drop the ticket and record that task in step 3:

```sh
handoffkeep tasks transition <ticket-id> --to dropped --by operator-desk --note 'duplicate of hk <id>'
```

Similar is not the same. If the work really differs, keep the ticket and name the other task in its
disposition.

**Move a dropped ticket's edges.** Its `blocks:` tickets would otherwise wait for a task that never lands, so copy
the edge to the task that replaced it:

```sh
handoffkeep tasks comment <id> --body 'blocks: <ids from the dropped ticket>'
```

A rejected ticket has no replacement. Re-judge each ticket it blocks before you accept that ticket.

## 3. Record a disposition per ticket

Each ticket gets one comment on the parent, either accepted with its task id or a one-line reason:

```sh
handoffkeep tasks comment <parent-id> --body 'disposition: <n>/<N> accepted → <ticket-id>'
handoffkeep tasks comment <parent-id> --body 'disposition: <n>/<N> rejected: <one-line reason>'
```

These are plain comments; `handoffkeep tasks disposition` is a different record. Before moving on, check that
the number of tickets with a disposition equals `<N>`:

```sh
handoffkeep tasks comments <parent-id> --limit 500 | jq '[.comments[].body | select(startswith("disposition: ")) | split(" ")[1]] | unique | length'
```

A ticket that fails the bar is rejected, or fixed by the desk from the doc. An unclear ticket is not a reason
to wait for the closed session.

## 4. Group tickets into lead sessions

- **One lead per chain:** tickets connected by `blocks:` edges in one repo share a lead, so a chain has one
  owner who sequences it.
- **Unconnected tickets may run in parallel** under separate leads. Keep them under one lead when they touch
  the same files.
- **A single unconnected ticket needs no lead.** Spawn it as a worker.
- **Small work** the desk can do directly stays with the desk.

The first group's lead binds the parent task, which is the coordinating task that may own several PRs
(`robin-mode` §Work boundary). `panewire` refuses a task already bound to another job, so each further group
gets its own coordinating task:

```sh
handoffkeep tasks add --lane operator-desk --project <project> --kind implement \
  --title '[handoff:<slug> group <g>] <what this group delivers> (grade <G>, <Tn>)'
handoffkeep tasks comment <group-id> --body 'parent: <parent-id>'
```

## 5. Spawn

Mechanics and landing proof are `ops` spawn; worktree and brief are `wake` §The loop. Copy the ticket's
Current, Desired, Key interfaces, Out of scope and Acceptance fields into the brief, and name the doc key and
ticket ids. `panewire` refuses to start without a readable brief. Preview first, then run without `--dry-run`:

```sh
panewire lead <parent-or-group-id> -c <worktree> -p <brief> --dry-run
panewire work <ticket-id> -c <worktree> -p <brief> --dry-run
```

Start a ticket only when every task whose newest `blocks:` comment names it has landed. A lead spawns its group's later
tickets itself and reports a `next unit:` line (`robin-mode` roles.md).

## 6. Put operator questions into one decision request

All of a handoff's questions go into one request on the parent, so the operator answers them once and they
stay on one record. Do not send them as a free-text lane event. A single question uses its own options
instead of A and B below. Use `--human-only`, because these are the items the session could not settle
without the operator.

```sh
handoffkeep tasks decision-request <parent-id> --human-only \
  --question '[handoff:<slug>] <k> operator questions: <q-1 in a few words>; <q-2 in a few words>' \
  --option 'A|Accept every default in the doc' --option 'B|Answer each question in the reply' \
  --recommended A --reason '<why the defaults are safe>' \
  --default-action '자동 적용 없음' --doc <doc-key>
```

The question and option text together must fit 2048 bytes, and detail stays in the doc's
`## Operator questions`. Record the answer, then act on it (`ops` decision-request §데스크 결정 루프):

```sh
handoffkeep tasks decision-resolve <parent-id> --request <request_id> --kind answered \
  --option <X> --responder operator --text '<the operator'"'"'s words>'
```

Hold only the tickets that depend on an open question: comment `next:` and `trigger: <request_id> resolved` on
each, as in `desk` §Commitments. The other tickets proceed.
