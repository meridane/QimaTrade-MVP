# QA367 — large objects and foreign-data bootstrap catalog

Date: 2026-11-12 (KST)  
Repository: `meridane/QimaTrade-MVP`  
Pull request: #26 — `fix/create-offer-status-contract` (open draft)

## Initial state reviewed

- PR #26 was open, unmerged, draft, and mergeable at the start of this run.
- Initial PR HEAD: `733d1e4df0dd8a37acde217c0b0b83122769247a`.
- Initial comparison with `main`: 1,556 commits ahead, 0 behind.
- Initial PR file count: 135; no submitted reviews and no review threads.
- Initial QIMA CI #1319: success.
- Initial CodeQL #1269: success.
- Initial Vercel status: failure with `build-rate-limit`; no Preview was claimed.
- The canonical function register ended with QA366. Its blob SHA was `02c614e353fdbf7e222404f04946d01a7ce5ca5d`.

## Scope and findings

QA367 assessed independent database-local objects that can exist without an ordinary application relation:

- Large objects in `pg_largeobject_metadata`.
- Foreign-data wrappers in `pg_foreign_data_wrapper`.
- Foreign servers in `pg_foreign_server`.
- User mappings in `pg_user_mapping`.

A large object is treated as database-local data residue: even an empty large object has a metadata row, so any row makes the disposable bootstrap database non-empty. No extension-membership exemption is applied to large objects.

Foreign-data wrappers and servers are checked for extension ownership using `pg_depend` membership dependencies (`refclassid = pg_extension`, `deptype = 'e'`). Independently created wrappers and servers are rejected; extension-owned members are ignored.

User mappings are checked independently. The runtime test places a user mapping on a server that is itself registered as a member of the `postgres_fdw` extension. This demonstrates that the mapping predicate is not merely relying on the server predicate.

## Code changes

The read-only SQL preflight in `tests/sql/create-offer-bootstrap-preflight.sql` now checks:

1. Any row in `pg_largeobject_metadata`.
2. Any foreign-data wrapper not owned by an extension.
3. Any foreign server not owned by an extension.
4. Any user mapping not owned by an extension.

The static contract in `tests/sql/test-create-offer-bootstrap-preflight.sh` requires these catalog checks, their dependency predicates, the corresponding runtime probes, and the existing read-only/runner-order guarantees.

The existing `tests/sql/test-create-offer-bootstrap-catalog-runtime.sh` is still run from both PostgreSQL jobs in `.github/workflows/ci.yml`; no workflow change was needed.

## Disposable runtime characterization

The runtime test creates a uniquely named disposable database and removes it in its EXIT trap. It installs `postgres_fdw` alongside the existing extensions.

It then verifies:

- The extension-owned `postgres_fdw` wrapper does not make an extension-only database non-empty.
- `lo_create(0)` creates one row in `pg_largeobject_metadata`; the preflight returns `not_empty`. After `lo_unlink`, it returns `empty`.
- A standalone FDW wrapper using the extension's handler and validator is detected; after dropping it, the state returns to `empty`.
- A standalone foreign server is detected; after dropping it, the state returns to `empty`.
- A server added to the `postgres_fdw` extension is verified as extension-owned and excluded.
- A user mapping on that extension-owned server is still detected independently; after dropping the mapping, the preflight returns to `empty` while the extension-owned server remains.
- Dropping the temporary extension and its server restores the extension-free empty baseline.

No foreign table is created or queried, and no remote FDW connection is attempted. The server options use loopback values only.

## Code validation

QIMA CI #1320 on code HEAD `396692ea7ae6dd1495ac2338830ebbdbe6af7e77`: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43217765870.

- Static QA366/QA367 bootstrap catalog contract: **PASS**.
- PostgreSQL 16 CREATE_OFFER integration, repeat-run guard, and QA367 runtime catalog characterization: **SUCCESS**.
- PostgreSQL 17.6 version guard (`server_version_num=170006`), integration, repeat-run guard, and QA367 runtime characterization: **SUCCESS**.
- Existing concurrency, RLS, ACL, migration cleanup, and prepared-transaction checks completed with their expected outcomes.
- npm audit at the high threshold: **SUCCESS**.
- TypeScript: **SUCCESS**.
- Next.js build: **SUCCESS**.
- Chromium installation: **SUCCESS**.
- Playwright: **347 passed in 8.9 seconds**.
- QA353/QA354 retain their intentional individual failure conclusions; their independent assertions passed. The skipped harness remains skipped and its assertion passed.

CodeQL #1270 on the same code HEAD: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43217766464.

The PostgreSQL runtime log emitted the existing QA365 publication warning that `wal_level` is insufficient for logical changes. QA367 does not create a subscription, create a replication slot, or change `wal_level`; this warning is not a QA367 failure.

Vercel combined status on the code HEAD remains **FAILURE** due to `build-rate-limit`. The successful GitHub Actions Next.js build is not represented as a Vercel Preview. No Production deployment occurred.

## Commits and files

Work branch: `work/qa367-large-objects-fdw-bootstrap-20261112-2121`.

- `a5cd70a` — add large-object and FDW/user-mapping preflight predicates.
- `3aeacf1` — add disposable large-object and FDW runtime probes.
- `67624cd` — correct shell quoting in the QA367 runtime block.
- `396692e` — extend the static bootstrap contract for QA367.

Three unique code files changed:

1. `tests/sql/create-offer-bootstrap-preflight.sql`
2. `tests/sql/test-create-offer-bootstrap-catalog-runtime.sh`
3. `tests/sql/test-create-offer-bootstrap-preflight.sh`

The work branch was fast-forwarded to `fix/create-offer-status-contract` with an expected-HEAD check. No force update was used.

## Evidence boundary and safety

The runtime tests establish behavior only in disposable PostgreSQL databases. They do not establish a Production vulnerability, Production incident, or Production data exposure.

No Supabase Production data, schema, migration, SQL function, RLS policy, grant, secret, or persistent configuration was modified. No Production deployment, PR merge, force update, or branch-protection change occurred.

MKT-1.2 remains unapproved and MKT-1.3 remains decision-required. No idempotency retention, numeric equivalence, price precision, canonicalization, or legacy-hash policy was changed.

## Next step

QA368 should first audit whether database-local replication metadata such as subscriptions and replication origins can exist independently in the disposable test database, whether those objects are relevant to a pristine CREATE_OFFER bootstrap, and whether their runtime characterization can be performed without remote connections or changing server configuration. Do not add catalog predicates until that relevance and the extension/ownership semantics are demonstrated on disposable PostgreSQL 16 and 17.6.
