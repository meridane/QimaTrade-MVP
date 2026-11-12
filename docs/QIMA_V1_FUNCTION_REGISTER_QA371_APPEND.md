# QIMA V1 Function Register — QA371

Date: 2026-11-13

## Status

**QA371 completed.** The parameter-ACL and extension-configuration catalogues were characterized on disposable PostgreSQL 16 and PostgreSQL 17.6 instances. No new database-local preflight predicate was added because the parameter ACL catalogue is cluster-wide and the tested extension configuration relation is already rejected by the existing public-relation guard.

## Initial repository state

- Repository: `meridane/QimaTrade-MVP`.
- Pull request: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26), open, draft, unmerged and mergeable.
- Initial PR head: `dbeda232383863296a43e948081bc1f2df77c4a6`.
- Initial PR comparison: 1,575 commits ahead of `main`, 0 behind; 143 changed files.
- Human reviews: 0; review threads: 0.
- Previous code validation: QIMA CI #1333 **SUCCESS**; CodeQL #1283 **SUCCESS**.
- Previous Vercel status: **RATE LIMITED** (`build-rate-limit`).

Working branch: `work/qa371-parameter-acl-extension-config-20261113-0210`.

## 1. pg_parameter_acl — cluster-wide parameter privileges

PostgreSQL's `pg_parameter_acl` has no database-ownership key. A row cannot be attributed to `current_database()`, so treating any row as database-local residue would let a grant in one database poison unrelated database bootstrap checks.

The disposable runtime characterization:

1. Created a NOLOGIN role in the disposable PostgreSQL service.
2. Granted `SET` on parameter `work_mem` to that role.
3. Confirmed the grant in `pg_parameter_acl` from both temporary databases.
4. Confirmed `has_parameter_privilege(..., 'work_mem', 'SET')` returned true.
5. Confirmed the preflight remained `empty` in both databases while the cluster-wide grant existed.
6. Revoked the grant and confirmed the role no longer held the SET privilege.
7. Confirmed both database preflight results remained `empty`.

**Decision:** do not add `pg_parameter_acl` to the database-local preflight. This is a scope decision, not a statement that parameter ACLs are irrelevant to every runner identity. If the integration runner changes from its current superuser test connection to a restricted role, that role's parameter privileges need a separate explicit contract.

## 2. pg_extension.extconfig / extcondition — extension configuration tables

A disposable extension was created from temporary control and SQL files inside a version-pinned PostgreSQL container. Its installation script created an extension-owned table in `public`, inserted a built-in row, and called:

```sql
SELECT pg_catalog.pg_extension_config_dump(
  'public.qa371_extension_config_probe'::regclass,
  'WHERE NOT is_builtin'
);
```

The runtime test verified:

- The table was registered in `pg_extension.extconfig`.
- The matching `pg_extension.extcondition` entry was exactly `WHERE NOT is_builtin`.
- The table was recorded as an extension member in `pg_depend`.
- The existing preflight returned `not_empty` because the configuration table is a public relation, even though it is extension-owned.
- A user-config row was included in `pg_dump --data-only`, while the built-in row excluded by `extcondition` was not included.
- `DROP EXTENSION` removed the configuration relation and restored the preflight result to `empty`.

**Decision:** no separate `extconfig`/`extcondition` predicate was added for the tested public configuration table. The preflight does not execute extension-supplied condition text or dynamically inspect configuration rows; the relation itself is sufficient to reject this non-pristine bootstrap database.

**Scope limitation:** this runtime characterization covers a configuration table in `public`. A configuration relation deliberately placed in `pg_catalog` or `information_schema` was not tested and remains outside this QA371 conclusion. The preflight comments now state this limitation explicitly rather than claiming universal coverage.

## 3. Files changed

- `.github/workflows/ci.yml`
- `tests/sql/create-offer-bootstrap-preflight.sql` (scope comments only; no predicate added)
- `tests/sql/test-create-offer-database-settings-acl-runtime.sh`
- `tests/sql/test-create-offer-extension-config-runtime.sh` (new)
- `tests/sql/test-create-offer-parameter-acl-extension-config-preflight.sh` (new)
- `docs/QIMA_V1_FUNCTION_REGISTER.md`
- `docs/QIMA_V1_FUNCTION_REGISTER_QA371_APPEND.md` (new)

The new extension runtime test uses only `postgres:16` and `postgres:17.6`, checks the server version number, exposes the test container on loopback only, makes no remote database connection, and removes its container and temporary files in an EXIT trap. The parameter ACL test revokes its grant and verifies the disposable roles and databases are cleaned up.

## 4. CI and static-analysis evidence

- QIMA CI #1334 on code HEAD `71e222c670a7da57a38e8ff993dcf62dcfdcdcdd`: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43268066021.
- PostgreSQL 16 integration job: **SUCCESS**; QA371 parameter ACL characterization and extension configuration runtime test passed.
- PostgreSQL 17.6 integration job: **SUCCESS**; QA371 parameter ACL characterization and extension configuration runtime test passed; server version guard reported `170006`.
- Verify job: **SUCCESS**; QA371 static contract, npm audit at the configured high-severity threshold, TypeScript, Next.js build, Chromium installation and audit enforcement all passed.
- Next.js compiled successfully in 8.5 seconds.
- Playwright: **347 passed in 12.0 seconds**.
- CodeQL #1284: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43268067654.
- Vercel status on this code HEAD: **RATE LIMITED** — https://vercel.com/bmk1?upgradeToPro=build-rate-limit; no Preview success is claimed.
- The QA353/QA354 harness jobs retain their deliberate individual failure conclusions, and the cleanup skipped-job harness remains skipped. Their independent blocking assertions passed; the overall CI workflow succeeded.

## 5. Safety boundaries

- No Supabase Production data, migrations, functions, RLS policies, grants, secrets, or persistent database configuration were changed.
- No `ALTER SYSTEM`, production deployment, PR merge, force-push, or branch-protection change was performed.
- Runtime changes were limited to disposable PostgreSQL services/containers and were cleaned up.
- These tests characterize catalogue scope and dump behavior; they do not establish a security vulnerability.

## 6. Next priority — QA372

Audit the runner's execution identity and visibility of the catalogues used by the read-only preflight. In particular, determine whether a non-superuser connection can see the relevant rows in `pg_subscription`, `pg_replication_slots`, and `pg_user_mapping`, while the URL guard currently accepts any username. Characterize on disposable PostgreSQL 16 and 17.6 first; do not broaden the URL guard or change runner credentials without evidence and an explicit contract.

MKT-1.2 (independent idempotency) and MKT-1.3 (numeric normalization) remain pending business approval.


## Final validation

- QIMA CI #1335 on evidence HEAD `a86a4209ce01a5202caef5ed467f62c6842b1d2a`: **FAILURE** only because the static documentation check expected `Vercel: **RATE LIMITED**`, while this appendix recorded `Vercel status on this code HEAD: **RATE LIMITED**`. This was a literal matcher defect, not an application or PostgreSQL failure. Both PostgreSQL integration jobs completed **SUCCESS**; Verify stopped before npm audit, TypeScript, build and browser tests.
- Fixed by commit `49eeb03546f35c59e8b9a69c61b31ae77d3c8ab3`, which now checks the exact appendix wording.
- QIMA CI #1336 on code/documentation-evidence HEAD `49eeb03546f35c59e8b9a69c61b31ae77d3c8ab3`: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43268760344.
- PostgreSQL 16 and 17.6 QA371 runtime tests: **SUCCESS**. npm audit: **0 total vulnerabilities**. TypeScript, Next.js build, Chromium, audit enforcement: **SUCCESS**. Next.js compiled in 13.1 seconds; Playwright: **347 passed in 13.7 seconds**.
- CodeQL #1285: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43268611104.
- CodeQL #1286: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43268760509.
- Vercel on the final code HEAD: **RATE LIMITED** (`build-rate-limit`); no Preview success is claimed.
- QA353/QA354 intentional failure conclusions and the skipped-harness conclusion retained their expected semantics; independent blocking assertions passed.



## Final documentation HEAD verification

- QIMA CI #1337 on `1e06f694ceffa5a1a61e248346803a4fe8623bcf`: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43269438140.
- PostgreSQL 16 and 17.6 jobs: **SUCCESS**; both QA371 runtime probes passed; PG17.6 reported `server_version_num=170006`.
- QA371 static contract: **PASS**. npm audit: **0 total vulnerabilities**. TypeScript, Next.js build, Chromium, audit enforcement: **SUCCESS**. Build: 8.4 seconds. Playwright: **347 passed in 10.5 seconds**.
- CodeQL #1287: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43269438136.
- Vercel: **RATE LIMITED**; no Preview success is claimed.

