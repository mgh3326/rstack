---
name: handoff
description: Close a disposable design session one way — settle every open point, slice the result into independently mergeable tickets, emit them to hk as a parent task, child tasks and a handoff doc, verify them, and notify the desk so the session can be thrown away and the desk never has to ask back. Also holds the desk's intake procedure for a `[handoff]` event and the skill map for a design session. Use at the end of a design session, when the operator says the design is settled or asks to send it on, and at the desk when a `[handoff]` event arrives. Triggers - "넘겨", "넘겨줘", "desk로 보내", "데스크로 보내", "handoff", "티켓 만들어", "to-tickets", "design session", "디자인 세션 끝", "[handoff]".
---

# handoff — close a design session into hk

A design session is disposable: one per repo, in a herdr workspace named `design`. It researches and
decides, then hands off **one way**. hk is the source of truth. After §Notify the session may be
closed, so anything not written down by then is lost and the desk would have to ask back.

Run the five sections in order. Which skills to use before this one: [`references/design-session.md`](references/design-session.md).
At the desk, on a `[handoff]` event: [`references/intake.md`](references/intake.md).

## Close decisions

**Do not start §Slice until this section's table is complete. §Emit refuses a doc that fails it.**

Map the open points as a design tree: every decision branches into the decisions that hang off it. The
frontier is every decision whose prerequisites are settled. Walk it in rounds until it is empty.

1. **Resolve facts yourself**, in this order: code, docs, hk (`handoffkeep doc get`, `tasks show`).
   Finding a fact is your job, never the operator's. A delegated lookup blocks only the questions
   downstream of it.
2. **Ask the operator only for decisions.** The operator is in this session, so ask here. Number each
   question in the round, give your recommended answer, and word it so "yes" accepts that answer. A
   question that depends on another one still open in this round waits for the next round.
3. **Stop when the frontier is empty:** every branch visited, nothing silently assumed.

**Only operator-level items may stay open.** That means an item that needs the operator's authority
(`wake` §Authority) or a scope call only the operator can make, and that the operator did not answer in
this session. Everything else gets resolved now. "The desk can figure it out" is not a resolution.

The output goes into the handoff doc:

```markdown
## Decisions

| Point | Decided | By | Evidence |
|---|---|---|---|
| <open point> | <what was decided> | <code, docs, hk or operator> | <repo@sha path:line, doc key, or the operator's words> |

## Operator questions

### q-1
**Question:** <one question>
**Options:** A <option> / B <option>
**Default:** A — <what happens if nobody answers>
```

If no question is left, write `None.` under `## Operator questions`.

**Prevents:** a thrown-away session leaves a gap that only it could have closed, and the desk has to ask
the operator a question the session already had the context to answer.

## Slice into tickets

Show the operator the numbered breakdown (title, what it blocks, what it delivers) and adjust it until
they approve the granularity and the edges. Then write each ticket into the doc.

- **Independently mergeable.** One ticket is one PR (`robin-mode` §Work boundary), small enough for one
  fresh session.
- **A tracer bullet.** It cuts a narrow, complete path through every layer and can be verified alone. Do
  any prefactoring first, as its own ticket.
- **A wide refactor is the exception.** Sequence it as expand, migrate in batches, contract, with each
  batch blocked by the expand and the contract blocked by every batch.
- **Blocking edges only where one ticket truly gates another.** Number tickets with blockers first:
  `**Blocks:**` may name only higher numbers, which rules out cycles.
- **Grade and T per ticket.** T comes from `wake` §Tier and grade is reasoning difficulty. Never lower
  either to fit a quota.
- **Behavioural, not procedural.** Say what the system must do and which contract to preserve, not which
  line to edit.
- **Evidence is pinned.** An unpinned path goes stale while a ticket waits, so cite `<repo>@<sha> <path>:<line>`.

```markdown
## Tickets

### ticket-1
**Title:** <short title, no `|`>
**Kind:** <implement, verify, fix, decide or ops>
**Grade:** <S+, S, A, B or C>, <T0, T1, T2 or T3>
**Expected:** <duration, such as 6h>
**Blocks:** <higher ticket numbers separated by spaces, or none>
**Current:** <observable state now>
**Desired:** <observable end state, with edge cases>
**Key interfaces:** <types, CLI flags, contracts or callers to preserve>
**Acceptance:**
- `<command>` → <expected output>
**Out of scope:** <what not to change>
**Evidence:** `<repo>@<sha> <path>:<line>` — <what it shows>

## Commits read

- `<repo>@<sha>`
```

The doc body must have exactly these four `##` sections: `## Decisions`, `## Tickets`,
`## Operator questions` and `## Commits read`. §Emit adds `## Ticket ids`. The ticket's Current, Desired,
Key interfaces, Out of scope and Acceptance fields map one to one onto the `wake` worker brief, so the
desk can copy them.

**Prevents:** horizontal slices that cannot land alone, and acceptance a reviewer cannot check.

## Emit to hk

Save the code blocks of this section, §Verify and §Notify in order to one scratch file, fill in the first
block, and run `bash <file>`. Use bash: the arrays are 0-indexed and `set -e` would close an interactive
shell. The script stops before any write if the doc fails §Close decisions or §Slice.

**Retries are idempotent, so rerun the same file after any failure.** It searches every task state for an
existing `[handoff:<slug>]` and for each `[handoff:<slug> <n>/`, reuses the first doc key, and skips a
comment that is already there. A failed search aborts the run; it never counts as "nothing found".

The script writes these records, with today's CLI:

- **Parent:** `[handoff:<slug>] <goal> (grade <G>, <Tn>)`, with kind `implement` or `decide`.
- **One child per ticket:** `[handoff:<slug> <n>/<N>] <title> (grade <G>, <Tn>)`. `panewire` refuses a task
  whose title has no grade marker, so every child carries one.
- **The link.** Until hk has parent and sub-tasks (hk 2770), the link is the title prefix plus a comment on
  each child with `parent: <id>` and `blocks: <ids>`. `blocks:` lists the tasks that cannot start until this
  one lands.
- **The handoff doc:** `handoff/<repo>/<YYYY-MM-DD>-<slug>`, kind `note`. The `decision` kind is currently
  rejected. Each child's body points at its own section with `--doc <key>#ticket-<n>`.
- **Lane and duration.** Every task goes on lane `operator-desk`, which the desk reads at resume. `Expected:`
  goes in a comment because the installed `tasks add` refuses `--expected` (`wake` §The loop step 1).

```sh
set -euo pipefail
slug=<slug>          # kebab-case, no spaces
repo=<repo>
project=<project>    # one name from `handoffkeep tasks projects`; use what the repo's recent tasks use
kind=<kind>          # implement or decide
goal='<goal>'        # one line
grade='<G>, <Tn>'
expected=<duration>  # for the whole handoff
body=<path>          # the doc body written in the two sections above
```

```sh
section() { awk -v h="$2" '$0 == h { f = 1; next } /^##/ { f = 0 } f' "$1"; }
field() { awk -v h="**$2:**" 'index($0, h) == 1 { v = substr($0, length(h) + 1); sub(/^ +/, "", v); print v; exit }' <<<"$1"; }
field_body() { awk -v h="**$2:**" 'index($0, h) == 1 { f = 1; print; next } /^\*\*/ { f = 0 } f' <<<"$1"; }
refuse() { echo "handoff: $*" >&2; exit 1; }

# The gate: §Close decisions and §Slice, checked on the doc itself.
check_decisions() {
  awk -F'|' '
    /^## / { sec = $0; next }
    sec != "## Decisions" || !/^\|/ || /^\|[-: |]+$/ || $2 ~ /^ *Point *$/ { next }
    {
      rows++
      if (NF != 6) { print "decision row needs 4 cells: " $0; bad = 1; next }
      for (i = 2; i <= 5; i++) { v = $i; gsub(/ /, "", v); if (v == "") { print "empty cell: " $0; bad = 1 } }
      by = $4; gsub(/ /, "", by)
      if (by !~ /^(code|docs|hk|operator)$/) { print "By must be code, docs, hk or operator: " $0; bad = 1 }
    }
    END { if (!rows) { print "## Decisions has no rows"; bad = 1 } exit bad }
  ' "$1" >&2 || refuse "close the decisions first"
}

check_questions() {
  local q sec f
  grep -qx '## Operator questions' "$1" || refuse "no ## Operator questions section"
  for q in $(grep -oE '^### q-[0-9]+$' "$1" | cut -c5-); do
    sec=$(section "$1" "### $q")
    for f in Question Options Default; do
      [ -n "$(field "$sec" "$f")" ] || refuse "$q has no $f"
    done
  done
}

check_tickets() {
  local n m sec f
  N=$(grep -c '^### ticket-[0-9][0-9]*$' "$1") || refuse "no tickets"
  for n in $(seq 1 "$N"); do
    sec=$(section "$1" "### ticket-$n")
    [ -n "$sec" ] || refuse "ticket numbers must run 1 to $N: no ticket-$n"
    for f in Title Kind Grade Expected Blocks Current Desired 'Key interfaces' 'Out of scope'; do
      [ -n "$(field "$sec" "$f")" ] || refuse "ticket-$n has no $f"
    done
    field_body "$sec" Acceptance | grep '^- ' >/dev/null || refuse "ticket-$n has no acceptance check"
    field_body "$sec" Evidence | grep -E '[^[:space:]]+:[0-9]+' >/dev/null || refuse "ticket-$n has no file:line evidence"
    field "$sec" Grade | grep -E '^(S\+|S|A|B|C), T[0-3]$' >/dev/null || refuse "ticket-$n Grade must look like 'A, T1'"
    case "$(field "$sec" Title)" in *'|'*) refuse "ticket-$n Title has a |" ;; esac
    if [ "$(field "$sec" Blocks)" != none ]; then
      for m in $(field "$sec" Blocks); do
        case "$m" in *[!0-9]*) refuse "ticket-$n Blocks must be numbers or none" ;; esac
        [ "$m" -gt "$n" ] && [ "$m" -le "$N" ] || refuse "ticket-$n may block only tickets $((n + 1)) to $N, not $m"
      done
    fi
  done
}

check_open_items() {
  if awk '/^## Operator questions$/ { q = 1; next } /^## / { q = 0 } !q' "$1" |
    grep -inE 'TBD|decide later|나중에 결정' >&2; then
    refuse "only an operator question may stay open"
  fi
}

check_commits() { section "$1" '## Commits read' | grep -E '[0-9a-f]{7,40}' >/dev/null || refuse "no commit SHAs under ## Commits read"; }

check_body() {
  check_decisions "$1"
  check_questions "$1"
  check_tickets "$1"
  check_open_items "$1"
  check_commits "$1"
}

check_body "$body"

# Search one snapshot of every state. An export failure aborts here.
snap=$(mktemp)
out=$(mktemp)
readback=$(mktemp)
trap 'rm -f "$snap" "$out" "$readback"' EXIT
for s in backlog claimed in_progress hold needs_decision verifying join reopened merged dropped; do
  handoffkeep tasks export --state "$s" --limit 5000
done >"$snap"
find_task() { jq -rs --arg p "$1" '[.[].tasks[] | select(.title | startswith($p)) | .id] | min // empty' "$snap"; }

parent=$(find_task "[handoff:$slug]")
if [ -n "$parent" ]; then
  doc=$(jq -ers --argjson id "$parent" 'first(.[].tasks[] | select(.id == $id)) | .body_doc' "$snap")
else
  doc="handoff/$repo/$(date +%F)-$slug"
  parent=$(handoffkeep tasks add --lane operator-desk --project "$project" --kind "$kind" --doc "$doc" \
    --title "[handoff:$slug] $goal (grade $grade)" | jq -er .id)
fi

ids=()
for n in $(seq 1 "$N"); do
  sec=$(section "$body" "### ticket-$n")
  id=$(find_task "[handoff:$slug $n/")
  if [ -z "$id" ]; then
    id=$(handoffkeep tasks add --lane operator-desk --project "$project" --kind "$(field "$sec" Kind)" \
      --doc "$doc#ticket-$n" \
      --title "[handoff:$slug $n/$N] $(field "$sec" Title) (grade $(field "$sec" Grade))" | jq -er .id)
  fi
  ids+=("$id")
done

comment_once() {
  local existing
  existing=$(handoffkeep tasks comments "$1" --limit 500)
  jq -e --arg b "$2" 'any(.comments[]; .body == $b)' <<<"$existing" >/dev/null ||
    handoffkeep tasks comment "$1" --body "$2" >/dev/null
}

# Second pass: a ticket's blocks: names tasks created after it.
for n in $(seq 1 "$N"); do
  sec=$(section "$body" "### ticket-$n")
  blocks=
  if [ "$(field "$sec" Blocks)" != none ]; then
    for m in $(field "$sec" Blocks); do blocks="$blocks ${ids[m - 1]}"; done
  fi
  blocks=${blocks# }
  comment_once "${ids[n - 1]}" "parent: $parent
blocks: ${blocks:-none}
Expected: $(field "$sec" Expected)"
done
comment_once "$parent" "doc: $doc
children: ${ids[*]}
Expected: $expected"

{
  cat "$body"
  printf '\n## Ticket ids\n\nParent: %s\n\n| Ticket | Task | Title |\n|---|---|---|\n' "$parent"
  for n in $(seq 1 "$N"); do
    printf '| %s/%s | %s | %s |\n' "$n" "$N" "${ids[n - 1]}" "$(field "$(section "$body" "### ticket-$n")" Title)"
  done
} >"$out"
handoffkeep doc put --key "$doc" --kind note --file "$out" >/dev/null
echo "parent=$parent doc=$doc tickets=${ids[*]}"
```

**Prevents:** a retry mints duplicate tickets, and a failed search reads as "nothing filed yet".

## Verify before closing

The block below runs the checklist on what hk returns, not on your local file. If it fails, fix the cause
and rerun the whole script.

- [ ] Every ticket has acceptance and evidence.
- [ ] No ticket says "TBD" or "decide later". Only an operator question may stay open.
- [ ] `handoffkeep tasks show` returns each id.
- [ ] The doc reads back, and it lists every id.

```sh
handoffkeep doc get "$doc" | jq -er .body >"$readback"
[ "$(cat "$out")" = "$(cat "$readback")" ] || refuse "doc $doc does not read back as written"
check_body "$readback"
for id in "$parent" "${ids[@]}"; do
  handoffkeep tasks show "$id" | jq -e --argjson id "$id" '.id == $id' >/dev/null || refuse "tasks show $id failed"
  grep -qw "$id" "$readback" || refuse "doc does not list task $id"
done
echo "verified parent=$parent tickets=${#ids[@]}"
```

**Prevents:** a session closes on a write it never read back.

## Notify the desk

Send one line: `[handoff] <slug> <parent-id> | handoff/<repo>/<date>-<slug>`. Then the session may be closed.
Emit rc 0 is enough. `panewire` requires `--event-id` and refuses a repeated one, so each attempt gets its own id.
Only emit rc 0 writes the `notified:` comment, and a rerun skips the notice only when that comment exists. Do not
read `duplicate event_id` as delivered: emit keeps its record even when the daemon refuses it.

If emit reports `inbox root mismatch (daemon=<root>, ...)`, nothing reached the desk: this shell's default inbox
differs from the daemon's. Set `PANEWIRE_INBOX_ROOT=<root>` from that message and rerun the whole script.

```sh
existing=$(handoffkeep tasks comments "$parent" --limit 500)
if jq -e 'any(.comments[]; .body == "notified: operator-desk")' <<<"$existing" >/dev/null; then
  echo "already notified: $parent"
else
  panewire emit --kind lane.event --lane operator-desk --event-id "handoff-$slug-$parent-$(date +%s)-$$" \
    --text "[handoff] $slug $parent | $doc"
  handoffkeep tasks comment "$parent" --body 'notified: operator-desk' >/dev/null
fi
```

Open operator questions stay in the doc. The desk turns them into one decision request (`references/intake.md`).

**Prevents:** finished tickets sit unnoticed until the desk's next resume.

## Provenance

Adapted, not copied, from [mattpocock/skills](https://github.com/mattpocock/skills) at `4ae2317` (MIT,
Copyright (c) 2026 Matt Pocock; the full notice is in [`LICENSE-mattpocock-skills`](LICENSE-mattpocock-skills)):

- `skills/productivity/grilling/SKILL.md`: the design tree, frontier rounds, recommended answers worded so
  "yes" accepts them, and "facts are your job, decisions are the user's". Added here: the decision table and
  the rule on what may stay open.
- `skills/engineering/to-tickets/SKILL.md`: tracer-bullet slices, blocking edges, expand-contract for wide
  refactors, and operator approval of the breakdown. Changed here: the tracker is hk.
- `skills/engineering/triage/AGENT-BRIEF.md`: Current/Desired, Key interfaces, testable acceptance and Out of
  scope. Changed here: the upstream avoids file paths because they go stale, while this skill requires
  evidence pinned to a commit.
