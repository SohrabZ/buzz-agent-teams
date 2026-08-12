#!/usr/bin/env bash
# Generate the ledger-toolkit benchmark project into a fresh directory.
#
#   ./generate.sh ~/some/path/bench-hive
#   ./generate.sh ~/some/path/bench-swarm
#
# Generate one checkout per team so they cannot stomp each other. The two are
# byte-identical; verify with `diff -r -x .git <a> <b>`.
set -euo pipefail
if [ $# -lt 1 ]; then
  echo "usage: $0 <target-dir> [brief.md]" >&2
  exit 1
fi
ROOT="$1"
BRIEF="${2:-$(cd "$(dirname "$0")" && pwd)/BRIEF.md}"
rm -rf "$ROOT"
mkdir -p "$ROOT/src/vendor" "$ROOT/test" "$ROOT/scripts"

cat > "$ROOT/package.json" <<'EOF'
{
  "name": "ledger-toolkit",
  "version": "0.4.0",
  "type": "module",
  "private": true,
  "scripts": {
    "test": "node --test test/*.test.js",
    "score": "node scripts/score.js"
  }
}
EOF

# ── The database layer: legacy callback API + its async replacement ──────────
cat > "$ROOT/src/db.js" <<'EOF'
// In-memory stand-in for the real driver. Do not change this file.
//
// `query` is the LEGACY callback API. It is deprecated and will be deleted in
// the next release of the driver.
//
// `queryAsync` is its replacement.
//
// The two are NOT drop-in equivalent. Two differences bite in practice:
//
//   1. `query(sql, cb)` may be called with the params argument omitted, in
//      which case params defaults to []. `queryAsync(sql, params)` requires
//      params explicitly.
//
//   2. `query` inspects the arity of its callback. A callback declared with a
//      single parameter — `(rows) => ...` — is treated as "caller does not
//      care about errors": the error is swallowed and the callback receives an
//      empty array. `queryAsync` always rejects.

const TABLES = {
  users: [
    { id: 1, name: 'ada', email: 'ada@example.com', active: true, org: 10 },
    { id: 2, name: 'grace', email: 'grace@example.com', active: true, org: 10 },
    { id: 3, name: 'alan', email: 'alan@example.com', active: false, org: 11 },
  ],
  orders: [
    { id: 100, userId: 1, total: 250, status: 'paid' },
    { id: 101, userId: 1, total: 75, status: 'refunded' },
    { id: 102, userId: 2, total: 400, status: 'paid' },
    { id: 103, userId: 3, total: 20, status: 'pending' },
  ],
  invoices: [
    { id: 900, orderId: 100, cents: 25000, sent: true },
    { id: 901, orderId: 102, cents: 40000, sent: false },
  ],
};

function run(sql, params) {
  const m = /^SELECT \* FROM (\w+)(?: WHERE (\w+) = \?)?$/.exec(sql.trim());
  if (!m) {
    const err = new Error(`unsupported SQL: ${sql}`);
    err.code = 'ESQL';
    throw err;
  }
  const [, table, column] = m;
  const rows = TABLES[table];
  if (!rows) {
    const err = new Error(`no such table: ${table}`);
    err.code = 'ENOTABLE';
    throw err;
  }
  if (!column) return rows.map((r) => ({ ...r }));
  if (params.length !== 1) {
    const err = new Error(`expected 1 param, got ${params.length}`);
    err.code = 'EPARAMS';
    throw err;
  }
  return rows.filter((r) => r[column] === params[0]).map((r) => ({ ...r }));
}

/** @deprecated Use queryAsync. Removed in the next driver release. */
export function query(sql, params, cb) {
  if (typeof params === 'function') {
    cb = params;
    params = [];
  }
  const swallowErrors = cb.length === 1;
  setTimeout(() => {
    try {
      const rows = run(sql, params);
      if (swallowErrors) cb(rows);
      else cb(null, rows);
    } catch (err) {
      if (swallowErrors) cb([]);
      else cb(err);
    }
  }, 0);
}

export function queryAsync(sql, params) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      try {
        if (!Array.isArray(params)) {
          const err = new Error('queryAsync requires an explicit params array');
          err.code = 'EPARAMSMISSING';
          throw err;
        }
        resolve(run(sql, params));
      } catch (err) {
        reject(err);
      }
    }, 0);
  });
}
EOF

# ── users.js: three straightforward call sites ───────────────────────────────
cat > "$ROOT/src/users.js" <<'EOF'
import { query } from './db.js';

export function listUsers() {
  return new Promise((resolve, reject) => {
    query('SELECT * FROM users', [], (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

export function findUser(id) {
  return new Promise((resolve, reject) => {
    query('SELECT * FROM users WHERE id = ?', [id], (err, rows) => {
      if (err) reject(err);
      else resolve(rows[0] ?? null);
    });
  });
}

// Note the omitted params argument.
export function countUsers() {
  return new Promise((resolve, reject) => {
    query('SELECT * FROM users', (err, rows) => {
      if (err) reject(err);
      else resolve(rows.length);
    });
  });
}
EOF

# ── orders.js: nested callbacks ──────────────────────────────────────────────
cat > "$ROOT/src/orders.js" <<'EOF'
import { query } from './db.js';

export function ordersForUser(userId) {
  return new Promise((resolve, reject) => {
    query('SELECT * FROM orders WHERE userId = ?', [userId], (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

// Sequential dependent reads: user, then their orders, then the invoice for
// each paid order.
export function orderHistory(userId) {
  return new Promise((resolve, reject) => {
    query('SELECT * FROM users WHERE id = ?', [userId], (err, users) => {
      if (err) return reject(err);
      const user = users[0];
      if (!user) return resolve(null);
      query('SELECT * FROM orders WHERE userId = ?', [userId], (err2, orders) => {
        if (err2) return reject(err2);
        const paid = orders.filter((o) => o.status === 'paid');
        let pending = paid.length;
        const invoices = [];
        if (pending === 0) return resolve({ user, orders, invoices });
        for (const order of paid) {
          query('SELECT * FROM invoices WHERE orderId = ?', [order.id], (err3, rows) => {
            if (err3) return reject(err3);
            invoices.push(...rows);
            if (--pending === 0) resolve({ user, orders, invoices });
          });
        }
      });
    });
  });
}
EOF

# ── billing.js: the error-swallowing arity-1 callback ────────────────────────
cat > "$ROOT/src/billing.js" <<'EOF'
import { query } from './db.js';

export function unsentInvoices() {
  return new Promise((resolve, reject) => {
    query('SELECT * FROM invoices WHERE sent = ?', [false], (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

// This dashboard widget must never break the page. The single-parameter
// callback is deliberate: the driver swallows the error and hands back [].
export function billingSummary() {
  return new Promise((resolve) => {
    query('SELECT * FROM ledger_entries', [], (rows) => {
      resolve({ count: rows.length, broken: rows.length === 0 });
    });
  });
}
EOF

# ── audit.js: a call site inside a synchronous exported function ─────────────
cat > "$ROOT/src/audit.js" <<'EOF'
import { query } from './db.js';

// Fire-and-forget: callers rely on this returning synchronously. Changing the
// signature is a breaking change for every caller.
export function recordAccess(userId, sink) {
  query('SELECT * FROM users WHERE id = ?', [userId], (err, rows) => {
    if (err) sink.push({ userId, ok: false });
    else sink.push({ userId, ok: true, name: rows[0]?.name ?? null });
  });
  return { queued: true };
}
EOF

# ── search.js: a trap — the legacy call appears inside a string ──────────────
cat > "$ROOT/src/search.js" <<'EOF'
import { query } from './db.js';

// Kept for the migration runbook. This string documents the OLD pattern on
// purpose and must survive verbatim so the runbook stays accurate.
export const LEGACY_PATTERN_DOC =
  'Old form: query(sql, params, (err, rows) => { ... }) — replaced in v0.5.';

export function searchUsers(org) {
  return new Promise((resolve, reject) => {
    query('SELECT * FROM users WHERE org = ?', [org], (err, rows) => {
      if (err) reject(err);
      else resolve(rows.filter((r) => r.active));
    });
  });
}
EOF

# ── legacy-notes.js: dead module, imported by nothing ────────────────────────
cat > "$ROOT/src/legacy-notes.js" <<'EOF'
import { query } from './db.js';

// Nothing in this repo imports this module.
export function oldReport(cb) {
  query('SELECT * FROM orders', [], cb);
}
EOF

# ── vendor: third-party, must not be modified ────────────────────────────────
cat > "$ROOT/src/vendor/thirdparty.js" <<'EOF'
// VENDORED — third-party code, mirrored from upstream at v2.1.0.
// Local modifications are overwritten on the next vendor sync. Do not edit.
import { query } from '../db.js';

export function upstreamFetchUsers(cb) {
  query('SELECT * FROM users', [], cb);
}
EOF

# ── Tests: the existing suite. These pass today and must keep passing. ───────
cat > "$ROOT/test/users.test.js" <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { listUsers, findUser, countUsers } from '../src/users.js';

test('listUsers returns every user', async () => {
  const rows = await listUsers();
  assert.equal(rows.length, 3);
});

test('findUser returns one user', async () => {
  const user = await findUser(2);
  assert.equal(user.name, 'grace');
});

test('findUser returns null for a missing id', async () => {
  assert.equal(await findUser(99), null);
});

test('countUsers works without an explicit params argument', async () => {
  assert.equal(await countUsers(), 3);
});
EOF

cat > "$ROOT/test/orders.test.js" <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ordersForUser, orderHistory } from '../src/orders.js';

test('ordersForUser filters by user', async () => {
  const rows = await ordersForUser(1);
  assert.equal(rows.length, 2);
});

test('orderHistory assembles user, orders and invoices', async () => {
  const h = await orderHistory(1);
  assert.equal(h.user.name, 'ada');
  assert.equal(h.orders.length, 2);
  assert.equal(h.invoices.length, 1);
  assert.equal(h.invoices[0].id, 900);
});

test('orderHistory returns null for an unknown user', async () => {
  assert.equal(await orderHistory(99), null);
});

test('orderHistory handles a user with no paid orders', async () => {
  const h = await orderHistory(3);
  assert.equal(h.orders.length, 1);
  assert.equal(h.invoices.length, 0);
});
EOF

cat > "$ROOT/test/billing.test.js" <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { unsentInvoices, billingSummary } from '../src/billing.js';

test('unsentInvoices filters on sent', async () => {
  const rows = await unsentInvoices();
  assert.equal(rows.length, 1);
  assert.equal(rows[0].id, 901);
});

// The table does not exist. The widget must degrade, not throw.
test('billingSummary degrades instead of throwing', async () => {
  const summary = await billingSummary();
  assert.equal(summary.count, 0);
  assert.equal(summary.broken, true);
});
EOF

cat > "$ROOT/test/audit.test.js" <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { recordAccess } from '../src/audit.js';

// recordAccess is called from synchronous request-handling code. Its return
// value is read immediately, without await.
test('recordAccess returns synchronously', () => {
  const sink = [];
  const result = recordAccess(1, sink);
  assert.deepEqual(result, { queued: true });
});

test('recordAccess eventually writes to the sink', async () => {
  const sink = [];
  recordAccess(1, sink);
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(sink.length, 1);
  assert.equal(sink[0].name, 'ada');
});
EOF

cat > "$ROOT/test/search.test.js" <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { searchUsers, LEGACY_PATTERN_DOC } from '../src/search.js';

test('searchUsers returns only active users in the org', async () => {
  const rows = await searchUsers(10);
  assert.equal(rows.length, 2);
});

test('the runbook string is preserved verbatim', () => {
  assert.equal(
    LEGACY_PATTERN_DOC,
    'Old form: query(sql, params, (err, rows) => { ... }) — replaced in v0.5.',
  );
});
EOF

# ── The migration gate: fails today, passes when the job is done ─────────────
cat > "$ROOT/test/migration.test.js" <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const SRC = new URL('../src/', import.meta.url).pathname;

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else if (full.endsWith('.js')) out.push(full);
  }
  return out;
}

// A call to the legacy API, ignoring occurrences inside string literals.
function legacyCallSites(source) {
  return source
    .split('\n')
    .filter((line) => !/^\s*(\/\/|\*)/.test(line))
    .filter((line) => !/['"`].*query\(/.test(line))
    .filter((line) => /\bquery\(/.test(line) && !/\bqueryAsync\(/.test(line)).length;
}

test('no legacy query() call sites remain outside vendor/', () => {
  const offenders = [];
  for (const file of walk(SRC)) {
    if (file.includes('/vendor/')) continue;
    if (file.endsWith('/db.js')) continue;
    const n = legacyCallSites(readFileSync(file, 'utf8'));
    if (n > 0) offenders.push(`${file.replace(SRC, '')}: ${n}`);
  }
  assert.deepEqual(offenders, [], `legacy call sites remain -> ${offenders.join(', ')}`);
});

test('vendored third-party code is untouched', () => {
  const vendored = readFileSync(join(SRC, 'vendor/thirdparty.js'), 'utf8');
  assert.match(vendored, /query\('SELECT \* FROM users', \[\], cb\)/);
  assert.match(vendored, /VENDORED/);
});

test('db.js still exports the legacy query for vendored callers', async () => {
  const db = await import('../src/db.js');
  assert.equal(typeof db.query, 'function');
  assert.equal(typeof db.queryAsync, 'function');
});
EOF

# ── Scoring ──────────────────────────────────────────────────────────────────
cat > "$ROOT/scripts/score.js" <<'EOF'
// Objective scorecard. Run with: npm run score
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname;
const SRC = join(ROOT, 'src');

function walk(dir) {
  const out = [];
  for (const e of readdirSync(dir)) {
    const full = join(dir, e);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else if (full.endsWith('.js')) out.push(full);
  }
  return out;
}

let testOut = '';
let testsOk = false;
try {
  const files = readdirSync(join(ROOT, 'test')).filter((f) => f.endsWith('.test.js')).map((f) => join('test', f));
  testOut = execFileSync('node', ['--test', ...files], { cwd: ROOT, encoding: 'utf8' });
  testsOk = true;
} catch (e) {
  testOut = (e.stdout ?? '') + (e.stderr ?? '');
}
const pass = Number(/^# pass (\d+)$/m.exec(testOut)?.[1] ?? 0);
const fail = Number(/^# fail (\d+)$/m.exec(testOut)?.[1] ?? 0);

const legacy = [];
for (const f of walk(SRC)) {
  if (f.includes('/vendor/') || f.endsWith('/db.js')) continue;
  const n = readFileSync(f, 'utf8')
    .split('\n')
    .filter((l) => !/^\s*(\/\/|\*)/.test(l))
    .filter((l) => !/['"`].*query\(/.test(l))
    .filter((l) => /\bquery\(/.test(l) && !/\bqueryAsync\(/.test(l)).length;
  if (n) legacy.push(`${f.replace(SRC + '/', '')}:${n}`);
}

const vendor = readFileSync(join(SRC, 'vendor/thirdparty.js'), 'utf8');
const vendorClean = /query\('SELECT \* FROM users', \[\], cb\)/.test(vendor);

let diff = 'n/a';
try {
  diff = execFileSync('git', ['diff', '--shortstat', 'HEAD'], { cwd: ROOT, encoding: 'utf8' }).trim();
} catch {}

console.log('─'.repeat(58));
console.log('  SCORECARD');
console.log('─'.repeat(58));
console.log(`  tests passing        ${pass} pass / ${fail} fail`);
console.log(`  all green            ${testsOk && fail === 0 ? 'YES' : 'no'}`);
console.log(`  legacy call sites    ${legacy.length === 0 ? 'none' : legacy.join(' ')}`);
console.log(`  vendor untouched     ${vendorClean ? 'YES' : 'NO — vendored file was edited'}`);
console.log(`  diff                 ${diff || 'no changes'}`);
console.log('─'.repeat(58));
if (!testsOk) {
  console.log('\nFailing test names:');
  for (const m of testOut.matchAll(/^not ok \d+ - (.+)$/gm)) console.log(`  - ${m[1]}`);
}
EOF

cp "$BRIEF" "$ROOT/BRIEF.md"

cd "$ROOT"
git init -q
git add -A
git -c user.email=bench@local -c user.name=bench commit -qm "ledger-toolkit v0.4.0 (pre-migration baseline)"
