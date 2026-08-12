---
name: migration-pattern
description: >
  Set up and run a bounded, repetitive change — a migration, upgrade, or
  codemod — as a coordinated batch operation: pattern document, work list,
  rulebook, batch protocol. For coordinator agents (Comet) starting a swarm
  project.
version: 1
---

# Run a migration as a swarm

A migration lives or dies on three artifacts you create **before any worker
touches anything**: the pattern, the work list, and the rulebook. This skill
is the template for all three.

## 1. The pattern document

Read the code, the tests, and one representative unit of the work until you
can write this down completely:

```markdown
## Pattern: <old thing> → <new thing>

**Before**  (a real, representative snippet from this repo)
**After**   (the same snippet, migrated)

**Rules**
- <each mechanical transformation, one per line>

**Does NOT apply to**
- <vendored code, generated code, documentation strings, …>

**Verification per batch**
- <exact commands, in order>
```

Post it in-channel. You may be slow here — everything downstream depends on
the pattern being right, and a wrong pattern multiplied across fifty files is
the most expensive mistake a swarm can make.

Do not migrate the unit you studied. Studying is reading; the first migrated
unit is a worker's batch like any other, and it doubles as the pattern's test.

## 2. The work list

Enumerate **every** unit in scope — file, module, or call site — before
assigning any. Sweep more than one naming convention before declaring the
list complete, and say how you searched so coverage can be judged.

Track each item as: `pending → in progress → verified | blocked`, with an
owner. Post the list state whenever it changes meaningfully. An item is
`verified` only on the verifier's PASS — never on the worker's own report.

Unknown scope is what kills a swarm. A list that grows mid-project means the
enumeration was wrong; stop and re-enumerate before continuing.

## 3. The rulebook

Every edge case gets a ruling, and every ruling gets written down — to memory
and in-channel — in this shape:

```markdown
**Case:** <what the pattern didn't cover>
**Ruling:** <what to do>
**Generalizes to:** <the class of case this settles, not just this instance>
```

The third line is the one that makes escalation volume fall. A ruling scoped
to one file will be re-asked from the next file; a ruling scoped to the class
will not.

When a worker escalates: answer from the rulebook if it is covered — 
immediately, without re-deliberating. Decide and record if it is new and the
project's conventions can settle it. Escalate to the owner only when they
cannot: a behavior change nobody asked for, something irreversible, a real
product tradeoff.

## 4. Batch protocol

- A batch must be verifiable in one pass; if the verifier can't check it in
  one sitting, it is too big.
- Independent batches may run in parallel across workers — but never two
  workers in overlapping files; they share one filesystem.
- A failed batch returns to the worker who wrote it.
- Workers apply the pattern exactly. An improvement a worker wants to make is
  an escalation, not a batch.

## 5. Ending

The project ends when the list is empty and every item is verified. Publish a
final `DONE:` summary: what changed, how it was verified, what the rulebook
learned. Then stop — a swarm that invents follow-on work to stay alive has
outlived its purpose.
