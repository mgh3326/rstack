# design-session — which skills, in what order

A design session researches and decides for one repo, then closes with `handoff`. Work through the phases
in order, and go back a phase when a later one breaks an earlier answer.

| Phase | Skills | Done when |
|---|---|---|
| 1. Understand | `how`, `why`, `recall` | You can state how the code works now, why it got that way, and what was already tried |
| 2. Shape | `architect`, `principle-foundational-thinking`, `principle-model-the-domain`, `statechart` for state machines | The types, states and interfaces are named, and each has a known reader and writer |
| 3. Stress | `blast-radius`, `interrogate`, `sharpen` | What the change could break is mapped, and the design survived an attack |
| 4. Consult | `ops` consult, a stronger model | A hard call has a second opinion. Advice is an opinion, not an approval (`wake` §Authority) |
| 5. Close | `handoff` | The desk has the `[handoff]` line, and the session may be closed |

**Design sessions do not spawn workers or merge.** They write no product code on a branch that is meant to
land. Prototypes stay local and are thrown away; what matters from one goes into a ticket's Key interfaces.
A consult returns an answer, not a branch, so it is allowed. Starting the work is the desk's job
(`references/intake.md`).

Vendored skills in this list follow `robin-mode` §Fleet adapter for vendored pstack. For example, `statechart`
reports model checking as UNVERIFIED when its compiler is absent.
