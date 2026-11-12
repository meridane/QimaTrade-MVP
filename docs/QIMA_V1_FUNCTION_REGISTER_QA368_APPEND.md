# QA368 — subscription and replication-origin bootstrap audit

Date: 2026-11-12 (KST)  
Repository: `meridane/QimaTrade-MVP`  
Pull request: #26 — `fix/create-offer-status-contract`  
Work branch: `work/qa368-subscription-origin-bootstrap-20261112-2242`

## Scope and decision

QA368 characterized logical-replication subscriptions and replication origins before changing the CREATE_OFFER bootstrap preflight.

The PostgreSQL 16 and 17 documentation establishes two important scope facts:

- `pg_subscription` is a shared catalog, but `subdbid` identifies the database that owns each subscription. The preflight therefore rejects only rows whose `subdbid` matches `current_database()`. It does not select or inspect `subconninfo`, which can contain plaintext credentials.
- `pg_replication_origin` is also shared across the cluster, but its catalog has no database ownership column. A per-database bootstrap check cannot safely attribute an origin to the current database. QA368 therefore characterizes origin visibility but deliberately does not add a `pg_replication_origin` predicate.

## Code and test changes

- `tests/sql/create-offer-bootstrap-preflight.sql`: add a read-only `pg_subscription` check scoped through `subdbid` and `pg_database.oid`.
- `tests/sql/test-create-offer-bootstrap-catalog-runtime.sh`: create a disabled subscription with `connect=false` and `slot_name=NONE`, verify no replication slot is created, confirm the shared catalog row is visible from another database, and verify only the owning database is rejected by preflight.
- The same runtime test creates a disposable replication origin, confirms it is visible from the `postgres` database, confirms neither database-local preflight is affected, and drops the origin.
- `tests/sql/test-create-offer-bootstrap-preflight.sh`: statically protects database scoping, absence of connection-string reads, deliberate exclusion of cluster-wide origins, no-slot/no-remote-connect setup, and execution on both PostgreSQL CI jobs.

The subscription connection string points to loopback port 1 and `connect=false` is explicit. `slot_name=NONE`, `enabled=false`, and `create_slot=false` ensure there is no remote slot to create or drop. No publisher connection is attempted, no replication slot is created, and no `wal_level` change is made.

The runtime test uses only a uniquely named disposable database and removes the subscription and origin in normal and EXIT-trap cleanup paths.

## Final code validation

- QIMA CI #1323 on code HEAD `76eda201416699c0365ae0e27dfd4a2418d5fe39`: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43230841086.
  - Static QA366/QA367/QA368 bootstrap contract: **PASS**.
  - PostgreSQL 16 CREATE_OFFER integration, repeat-run guard, and catalog runtime characterization: **SUCCESS**.
  - PostgreSQL 17.6 version guard (`server_version_num=170006`), CREATE_OFFER integration, repeat-run guard, and catalog runtime characterization: **SUCCESS**.
  - QA368 runtime marker was observed in both PostgreSQL job logs: current-database subscriptions were rejected by the preflight; another database remained empty; no replication slot or remote connection was created; cluster-wide origins were visible across databases and did not make either database-local preflight non-empty.
  - Existing RLS/ACL, concurrency, migration-cleanup, and prepared-transaction checks completed successfully.
  - npm audit at the high threshold, TypeScript, Next.js build, Chromium installation, and audit enforcement: **SUCCESS**.
  - Playwright: **347 passed in 12.0 seconds**.
  - QA353/QA354 harness jobs retain their intentional individual `failure` conclusions; independent blocking assertions passed. The skipped harness remains `skipped` and its assertion passed.
- CodeQL #1273 on the same code HEAD: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43230840977.
- Vercel Preview on the code HEAD: **SUCCESS** — https://vercel.com/bmk1/qimatrade-mvp/7UuNctqJLS6sGNbzqeZqkbgtrmco.
- PostgreSQL emitted the expected logical-replication warning/hint during the disabled-subscription probe. This is not a test failure: QA368 deliberately leaves `wal_level` unchanged, uses `connect=false` and `slot_name=NONE`, creates no slot, and makes no publisher connection.


## Evidence boundary

The tests demonstrate catalog scope and behavior on disposable PostgreSQL instances only. They do not establish a Production replication configuration, a Production vulnerability, or a Production incident.

No Supabase Production data, schema, migration, function, RLS policy, grant, secret, or persistent configuration was modified. No Production deployment, PR merge, force update, or branch-protection change occurred.

MKT-1.2 remains unapproved and MKT-1.3 remains decision-required. No idempotency or numeric canonicalization behavior was changed.

## PostgreSQL documentation

- PostgreSQL 16 `pg_subscription`: https://www.postgresql.org/docs/16/catalog-pg-subscription.html
- PostgreSQL 17 `pg_subscription`: https://www.postgresql.org/docs/17/catalog-pg-subscription.html
- PostgreSQL 16 `CREATE SUBSCRIPTION`: https://www.postgresql.org/docs/16/sql-createsubscription.html
- PostgreSQL 17 `CREATE SUBSCRIPTION`: https://www.postgresql.org/docs/17/sql-createsubscription.html
- PostgreSQL 16 `pg_replication_origin`: https://www.postgresql.org/docs/16/catalog-pg-replication-origin.html
- PostgreSQL 17 `pg_replication_origin`: https://www.postgresql.org/docs/17/catalog-pg-replication-origin.html

## Next step

QA369 should assess whether the remaining replication-related catalog state can be scoped safely to one database without inspecting connection secrets or creating remote resources. Do not add a preflight predicate for cluster-wide state that cannot be attributed to the current database.
