---
name: verify-batch
description: >
  Verify a batch of changes against a fixed recipe: build, tests, lint, type
  checks. Produces a pass/fail verdict with raw evidence. For verifier agents
  (Willow) checking a worker's batch, or any agent asked to independently
  verify someone else's work.
version: 1
---

# Verify a batch

You are verifying someone else's work. Your verdict is what makes their batch
"done" — nothing is done until it has been seen to pass.

## The recipe

Run the project's verification recipe **in full, in this order, every time**:

1. **Build** — the project's build command, from a clean state if the recipe says so.
2. **Tests** — the full suite the recipe names, not a subset you judge relevant.
3. **Lint** — the project's linter, with the project's configuration.
4. **Types** — the type checker, if the project has one.

If no recipe has been given to you yet, ask the coordinator for one before
verifying anything. Do not invent a recipe from the repo's README mid-batch —
recipes are fixed at the start so every batch is judged the same way.

A check skipped because "this batch looks fine" is the one that lets a
regression through. Small batch, big batch, cosmetic batch: same recipe.

## The verdict

Every batch gets exactly one of:

- **PASS** — every check ran and every check passed. Say so plainly.
- **FAIL** — one or more checks failed. Name the failing check, paste the
  actual failing test names and error output (trimmed, never invented), and
  send it back to the batch's author by @mention.
- **UNVERIFIED** — you could not run the checks. Say why. This is not a pass.

Never "mostly passed". Never "should be fine". If you cannot produce the
verdict, say which check you could not run.

## Broken batch vs. broken environment

Before blaming the batch, decide which of these you are looking at:

| Symptom | Likely | Confirm by |
|---|---|---|
| Import/module errors on files the batch never touched | Environment | Same command on a clean checkout |
| Missing dependency, stale lockfile | Environment | Diff the lockfile against baseline |
| A test that also fails on the untouched baseline | Flake or pre-existing | Run it on the baseline |
| Failures only in files the batch changed | The batch | — |

Report which one it is. An environment failure goes to the coordinator, not
back to the worker.

## Patterns worth escalating

Escalate to the coordinator (not the worker) when:

- The recipe itself cannot be run at all.
- The **same** test fails across batches from **different** workers — that is
  a pattern problem, not a batch problem.
- Verification time is growing batch over batch — the batches are getting too big.
