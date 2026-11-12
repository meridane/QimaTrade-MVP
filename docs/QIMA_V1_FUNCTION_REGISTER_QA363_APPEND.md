# QA363 — CREATE_OFFER disposable bootstrap preflight and repeat-run guard

Date: 2026-11-12 (KST)

## Scope and initial finding

Inspected `tests/sql/run-create-offer-integration.sh`, `tests/sql/fixtures/create-offer-schema.sql`, the existing loopback URL guard, and both PostgreSQL integration jobs.

The runner already rejected non-loopback URLs and required the database path `qima_test`. However, it then invoked the schema fixture immediately. The fixture contains idempotent extension/role/schema setup followed by unguarded `CREATE TABLE` statements and an `auth.uid()` replacement. A second invocation against an initialized database would therefore reach fixture DDL before failing on an existing relation.

This is a disposable-runner repeatability finding, not evidence of a Production incident or vulnerability.

## Changes

### Runner preflight

Added a read-only catalog preflight to `tests/sql/run-create-offer-integration.sh`, after the strict URL allowlist and before the first fixture file or migration call.

The preflight:
- requires `current_database() = 'qima_test'`;
- rejects non-default application schemas (while excluding PostgreSQL system, toast, and temporary schemas);
- rejects relations in `public` with relkinds for tables, partitioned tables, views, materialized views, sequences, and foreign tables;
- accepts only the explicit `empty` result;
- exits with code 3 for wrong-database, non-empty, or unexpected results;
- propagates a preflight connection/query failure without proceeding;
- emits fixed diagnostics without echoing DATABASE_URL credentials.

The preflight is a single SELECT. It executes before `create-offer-schema.sql`, both branch migrations, and the runtime fixture.

### Regression tests

Added `tests/sql/test-create-offer-bootstrap-preflight.sh`.

Its static and mocked cases cover:
- initialized database rejection;
- wrong current database rejection;
- unexpected preflight result rejection;
- preflight connection failure;
- an empty database reaching only the first fixture-file call;
- query read-only shape and runner ordering.

Added `tests/sql/test-create-offer-integration-repeat-guard.sh`.

After the normal CREATE_OFFER integration runner succeeds, this test:
- captures a read-only snapshot of the public relation inventory and row-content digests for all ten fixture tables;
- wraps `psql` and invokes the runner a second time;
- requires exit code 3 and the exact non-empty-database refusal;
- requires exactly one `psql -c` query call and no `psql -f` fixture/migration call;
- verifies the schema inventory and all ten table-data digests remain identical.

The static/mocked contract runs in Verify. The real second-invocation test runs after the normal runner in both PostgreSQL 16 and PostgreSQL 17.6 jobs.

## Validation

- First code cycle, QIMA CI #1304: **FAILURE (intermediate test defect)** — the first repeat-guard snapshot query concatenated PostgreSQL's internal `"char"` relkind with text without an explicit cast. Both normal CREATE_OFFER integration runners succeeded; the repeat-guard snapshot failed with `operator is not unique: text || "char"`. Verify and the other completed checks succeeded. This was a test-query typing error, not an application or PostgreSQL integration failure.
- CodeQL #1254: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43189761028.
- Corrected the snapshot expression by explicitly casting schema/relation names and `relkind` to text.
- Final code cycle, QIMA CI #1305: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43190130837.
  - Verify: QA363 mocked/static contract **PASS**.
  - PostgreSQL 16 integration: **SUCCESS**; the second runner invocation emitted the QA363 PASS marker after one read-only query.
  - PostgreSQL 17.6 integration: **SUCCESS**; the second runner invocation emitted the same QA363 PASS marker.
  - Both runtime checks confirmed unchanged public relation inventory and unchanged row-content digests for all ten fixture tables.
  - npm ci, high-threshold npm audit, TypeScript, Next.js build, Chromium, and Playwright succeeded; **347 Playwright tests passed in 10.0 seconds**.
  - Existing QA353/QA354 harness jobs retain their deliberate individual failure conclusions; their independent blocking assertions passed. The skipped harness remains skipped and its dependent assertion passed.
- CodeQL #1255: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43190130704.
- Vercel combined status for final code HEAD `700bf4a3f09272bf91627bfe5623d9676f6ce23a`: **SUCCESS** (Preview only; no Production deployment).

## Commits and files

Work branch: `work/qa363-qima-test-bootstrap-preflight-20261112-1805`.

Commits:
- `d1e7ef96b09c20f5e5219f59bc74da9af983d656` — add read-only qima_test bootstrap preflight to the runner.
- `116f444128c469eb9db2d27c063909598f1a7a0f` — add static/mocked preflight contract tests.
- `2abc97cd79744da243e499102acc9183dddd316d` — add real initialized-database repeat-run regression.
- `70e830d57e4c24ded83239486bdefe4040dd0459` — wire Verify and both PostgreSQL jobs.
- `700bf4a3f09272bf91627bfe5623d9676f6ce23a` — cast catalog snapshot fields explicitly after CI #1304.

Files changed:
- `tests/sql/run-create-offer-integration.sh`
- `tests/sql/test-create-offer-bootstrap-preflight.sh` (new)
- `tests/sql/test-create-offer-integration-repeat-guard.sh` (new)
- `.github/workflows/ci.yml`

The work branch was fast-forwarded to `fix/create-offer-status-contract`; the final compare showed the branches identical.

## Evidence boundary and safety

QA363 verifies the disposable runner and PostgreSQL CI services only. The source guard checks non-default schemas and relations in `public`; it is not a general-purpose inventory of every possible standalone routine/type in `public`. That narrower residual scope is recorded for a later static-contract improvement.

No Supabase Production data, schema, migration, SQL function, RLS policy, grant, secret, or persistent configuration was modified. No Production deployment, PR merge, force update, or branch-protection change occurred. No vulnerability or Production incident is inferred from these synthetic disposable-database tests.

MKT-1.2 remains unapproved and MKT-1.3 remains decision-required; no idempotency retention, numeric equivalence, precision, canonicalization, or legacy-hash policy was changed.

## Next step

QA364: extend the bootstrap preflight characterization to standalone user-defined functions/types in `public`, while explicitly allowing extension-owned objects such as pgcrypto members. Keep the check read-only and continue to validate only on disposable PostgreSQL services.
