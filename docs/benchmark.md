# Benchmark

[← README](../README.md)

A self-contained task for comparing the two teams — or just for checking that a team delegates at
all.

## Generate

```bash
./benchmark/generate.sh ~/bench-hive
./benchmark/generate.sh ~/bench-swarm
```

Two byte-identical Node projects, each committed at a clean baseline. Zero dependencies — the test
runner is `node --test`, built into Node 18+. Verify they match:

```bash
diff -r -x .git ~/bench-hive ~/bench-swarm
```

Generate one checkout per team so they can't stomp each other, then point each team at its own and
hand it `BRIEF.md`:

> Work in `~/bench-hive`. Read `BRIEF.md` and complete it. Post the `npm run score` output when
> you're done.

## The task

`ledger-toolkit` is a small library whose database driver is dropping its deprecated callback API.
Every `query(sql, params, cb)` call site must become `queryAsync(sql, params)` without changing
behavior.

16 tests pass at baseline. A migration gate fails until the last legacy call site is gone.

## It is deliberately not a find-and-replace

A mechanical replace fails **13 of 17** tests. The traps:

| Trap | Where | Punishes |
|---|---|---|
| Arity-1 callback means errors are swallowed | `billing.js` — a widget that must degrade, not throw | Assuming the two APIs are equivalent |
| A sync function that must keep returning synchronously | `audit.js` | Reflexively making the caller `async` |
| An omitted params argument | `users.js` | The new API rejects without an explicit array |
| Nested dependent callbacks | `orders.js` | Getting sequencing wrong |
| A legacy call inside a string literal | `search.js` runbook doc | Regex edits — a test asserts it survives verbatim |
| A vendored file that legitimately uses the old API | `src/vendor/` | Migrating things you shouldn't touch |
| A dead module imported by nothing | `legacy-notes.js` | — one of two open questions the tests don't answer |

A correct migration reaches 17/17. That's been verified, so the task is known-winnable.

The brief also asks for **two written rulings** the tests deliberately don't settle: what to do
with the dead module, and what the sync-function constraint cost. That's where you see judgment
the scorecard can't measure.

## Scoring

```bash
cd ~/bench-hive && npm run score
```

```
──────────────────────────────────────────────────────────
  SCORECARD
──────────────────────────────────────────────────────────
  tests passing        17 pass / 0 fail
  all green            YES
  legacy call sites    none
  vendor untouched     YES
  diff                 6 files changed, 41 insertions(+), 94 deletions(-)
──────────────────────────────────────────────────────────
```

## What to watch beyond the score

- **How much reached you.** Every message a team sends you directly is the real metric. The Swarm's
  should thin out as Comet's rulebook fills.
- **Whether the workers ran at all.** Check session counts —
  [verifying delegation](setup.md#verifying-that-delegation-actually-happened).

## A caveat on the comparison

Seven call sites across six files is **small for a Swarm**. The article is explicit that short work
has no structure to divide, and a Swarm on a small task is largely a coordinator plus overhead. If
the Hive wins here, that's evidence about task size, not about Swarms.

To test a Swarm on its home ground, extend the generator: more modules, same seven traps
distributed across them. The rulebook only earns its keep when the same edge case recurs.
