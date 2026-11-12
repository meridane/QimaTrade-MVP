# QA369 — replication-slot bootstrap catalog scope

Date: 2026-11-12 (KST)  
Repository: `meridane/QimaTrade-MVP`  
Pull request: #26 — `fix/create-offer-status-contract`  
Work branch: `work/qa369-replication-slot-catalog-20261112-2314`

## Decision

`pg_replication_slots` is a cluster-wide view. PostgreSQL 16 and 17 expose a database OID (`datoid`) and database name only for logical slots; physical slots have no database owner.

The CREATE_OFFER bootstrap preflight now rejects only:

- `slot_type = 'logical'`
- `datoid` equal to the OID of `current_database()`

It deliberately ignores physical slots and logical slots associated with other databases. Cluster-wide replication origins remain excluded.

## Runtime characterization

The runtime test starts a separate Docker PostgreSQL container pinned to `postgres:16` or `postgres:17.6`, with `wal_level=logical`, `max_replication_slots=10`, and `max_wal_senders=10`. This does not alter the existing CI PostgreSQL service.

It creates two disposable databases and verifies:

1. Both databases start with an empty preflight.
2. A physical slot has NULL `database` and `datoid`, and does not make either database non-empty.
3. A logical slot in the first database makes only that database non-empty.
4. A logical slot in the second database leaves the first database empty and marks only its owner non-empty.
5. Dropping all slots returns both databases to empty.

No remote connection or publisher is contacted. All slots and the disposable container are removed by the EXIT cleanup path.

## Files

- `.github/workflows/ci.yml`
- `tests/sql/create-offer-bootstrap-preflight.sql`
- `tests/sql/test-create-offer-replication-slot-preflight.sh`
- `tests/sql/test-create-offer-replication-slot-catalog-runtime.sh`

## Validation

- QIMA CI #1326: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43236261275.
- PostgreSQL 16 QA369 runtime: **PASS**.
- PostgreSQL 17.6 QA369 runtime: **PASS**.
- Static contract: **PASS**.
- npm audit: **0 vulnerabilities at all reported severities**.
- TypeScript and Next.js build: **SUCCESS**.
- Playwright: **347 passed in 10.0 seconds**.
- CodeQL #1276: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43236261372.
- Vercel: **FAILURE** because the free daily deployment limit was reached; no Preview is claimed for this HEAD.

The deliberate QA353/QA354 failure harnesses and skipped harness retain their expected individual conclusions; independent blocking assertions passed. The overall CI workflow succeeded.

## Safety boundary

No Supabase Production data, schema, migration, SQL function, RLS policy, grant, secret, or persistent configuration was modified. No Production deployment, merge, force update, or branch-protection change occurred. No Production vulnerability or incident is inferred from disposable catalog tests.

MKT-1.2 remains unapproved and MKT-1.3 remains decision-required.

## Next step

QA370: audit `pg_db_role_setting` and `pg_default_acl` for database-local bootstrap residue and potential effects on test execution. Keep the audit read-only until disposable positive/negative probes establish whether either category should be rejected.
