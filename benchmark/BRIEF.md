# Brief: migrate ledger-toolkit off the deprecated callback API

`ledger-toolkit` is a small internal library. Its database driver ships two APIs:

- `query(sql, params, cb)` — the legacy error-first callback API. **Deprecated. The driver
  deletes it in the next release.**
- `queryAsync(sql, params)` — the replacement. Returns a promise.

**Your job: remove every use of `query()` from this codebase, replacing it with `queryAsync()`,
without changing what the library does.**

## Definition of done

```bash
npm test     # everything green
npm run score
```

`npm test` currently fails. The suite in `test/` describes the behavior that must survive the
migration — it is the specification, and you do not get to edit it. `test/migration.test.js`
is the gate: it fails until the last legacy call site is gone.

`npm run score` prints an objective scorecard. Post it when you are done.

## Read `src/db.js` first

The two APIs are **not** drop-in equivalent. The header comment in `src/db.js` documents where
they diverge. At least one call site in this codebase depends on each divergence, and a
mechanical find-and-replace will produce code that passes a casual read and fails the suite.

## Constraints

- Do not edit anything under `test/`.
- Do not edit `src/db.js`.
- Do not add dependencies. Node 22, no npm install.
- Keep the diff to the migration. This is not the moment to improve unrelated code.

## Two questions the tests do not answer

Decide these yourselves. Write down the ruling and the reasoning — I want to see the call, not
just the code.

1. **`src/legacy-notes.js`** uses the legacy API and is imported by nothing in the repo. Migrate
   it, delete it, or leave it? Whichever you pick, justify it.

2. **`src/audit.js`** exposes a synchronous function that starts a query and returns
   `{ queued: true }` immediately. The tests pin that synchronous return. Say what you did with
   it and what it would cost to do the "clean" thing instead.

## When you finish

Reply with:

- the `npm run score` output
- your two rulings
- anything you hit that the brief did not anticipate
