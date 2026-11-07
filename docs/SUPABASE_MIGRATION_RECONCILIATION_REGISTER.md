# Supabase migration reconciliation register

**Snapshot date:** 2026-10-27  
**Branch:** `fix/create-offer-status-contract`  
**Status:** INVENTORY ONLY — reconciliation is not complete.

## Evidence captured

- The connected Supabase project's migration history returned 161 applied versions. Latest remote version: `20261026034925 enable_rls_on_unexposed_reference_tables`.
- At the 2026-10-27 snapshot, the repository branch contained 17 SQL migration files in `supabase/migrations/`.
- At that snapshot, the two CREATE_OFFER proposal files below were newer than the reported remote latest version and were not in the remote applied history:
  - `20261027090000_fix_create_offer_action_status_contract.sql`
  - `20261027100000_restrict_direct_create_offer_rpc.sql`
- A count difference does not prove every missing remote migration must be recreated as an individual file. Some historical changes may be represented by a baseline, external/manual changes, or files lost from version control. That must be established from schema and SQL definitions.

## Local migration inventory at 2026-10-27 snapshot (17 files)

| Version | File |
|---|---|
| 20260824065000 | `20260824065000_create_project_documents.sql` |
| 20260824080000 | `20260824080000_create_project_inspections.sql` |
| 20260829090000 | `20260829090000_create_decision_tree_v1.sql` |
| 20260829091000 | `20260829091000_create_decision_answer_transaction.sql` |
| 20260829091500 | `20260829091500_seed_decision_tree_v1.sql` |
| 20260829092000 | `20260829092000_link_decision_tree_to_canonical_taxonomy.sql` |
| 20260829093000 | `20260829093000_persist_selected_product_master.sql` |
| 20260829100000 | `20260829100000_product_requests_v1.sql` |
| 20260829102000 | `20260829102000_grant_authenticated_v1_decision_tree_access.sql` |
| 20260829110000 | `20260829110000_product_request_to_demand_bridge_v1.sql` |
| 20260829112000 | `20260829112000_add_product_request_updated_at.sql` |
| 20260829113000 | `20260829113000_improve_mvp_matching_and_country_fields.sql` |
| 20260829130000 | `20260829130000_fix_offers_insert_rls_actor_lookup.sql` |
| 20260901090000 | `20260901090000_security_gate_dt_v1.sql` |
| 20260901120000 | `20260901120000_action_definition_read_rpc_v1.sql` |
| 20261027090000 | `20261027090000_fix_create_offer_action_status_contract.sql` (proposal; not applied) |
| 20261027100000 | `20261027100000_restrict_direct_create_offer_rpc.sql` (proposal; not applied) |

## Reconciliation work required

For each of the 161 remote version records, add one row to a future full register with:
1. remote version and migration name;
2. matching tracked file path and file hash, if found;
3. classification: `MATCHED`, `BASELINE`, `MANUAL/EXTERNAL`, `MISSING_SOURCE`, or `UNRESOLVED`;
4. evidence comparing the SQL change to the current live schema;
5. whether the migration is safe/relevant for a clean disposable database;
6. reviewer and resolution note.

The full remote history must be exported without truncation and joined to a complete recursive Git tree of the branch. Do not infer matches from timestamps or similar names alone.

## Safe procedure

1. Read/export the remote schema and migration history only; do not write to production.
2. Download all repository migration files and compare definitions/version IDs.
3. Create a baseline/replay plan only after classifying every remote version.
4. Test the plan in a newly created disposable PostgreSQL/Supabase database.
5. Review grants, RLS, extensions, triggers, functions, and seed data before deciding whether a clean reconstruction is equivalent.
6. Keep any CREATE_OFFER proposals separate until their own authorization and draft-compatibility gates pass.

## Explicit prohibitions for this audit

- Do not run `supabase db reset`, `supabase db push`, or bulk replay against production.
- Do not mark migration parity as passed based only on counts.
- Do not claim this register contains all 161 remote rows; it currently records the verified count, latest version, and all local filenames only.
- No production migration or data mutation was performed for this inventory.


## Branch inventory refresh — 2026-11-07 (read-only)

- The GitHub tree for `fix/create-offer-status-contract` now contains **18** SQL files in `supabase/migrations/`. The 17-row table above is retained as the historical 2026-10-27 snapshot.
- Static comparison found one branch-tracked migration not listed in that snapshot: `20261028180000_fix_message_participant_authorization.sql`.
- The file defines a replacement `public.is_message_participant(uuid, uuid, uuid)` predicate, revokes function EXECUTE from `PUBLIC`, and grants EXECUTE to `authenticated`. Its header says it is branch-only pending review and explicit application to a non-production environment. The repository's security audit also records it as prepared on the branch and not applied to production.
- A fresh read-only `list_migrations` call against the QIMA project failed with PostgreSQL `28P01: password authentication failed for user "postgres"`. No credential was requested, decrypted, or changed, and no retry using secrets was attempted. Therefore the remote applied-migration count/latest version could not be refreshed in this run.
- The earlier remote snapshot (161 applied versions; latest reported `20261026034925`) remains historical evidence dated 2026-10-27 only. It must not be represented as a current 2026-11-07 remote count, nor used to assert whether the newly inventoried message-participant migration is currently applied.
- **Current classification:** branch inventory discrepancy identified and documented; production migration parity remains **UNRESOLVED** until a read-only remote history export can be obtained with working database credentials and matched to the complete Git tree.
- **Safety:** only GitHub repository files and read-only migration metadata were inspected. No `apply_migration`, `execute_sql`, migration replay, data read/write, schema change, grant change, production deployment, PR merge, or branch-protection change was performed.



## QA258 — disposable PostgreSQL execution of the branch-only message migration — 2026-11-07

- The current Git branch has 18 SQL files in `supabase/migrations/`; the 18th file `20261028180000_fix_message_participant_authorization.sql` is now executed unchanged by the isolated GitHub Actions PostgreSQL regression runner.
- `tests/sql/run-legacy-messages-rls-regression.sh` preserves the prior synthetic predicate test, then creates a separate temporary `qima_message_migration_test` database, runs a minimal fixture, applies the actual migration file, executes the migration assertions, and drops the temporary database with a shell EXIT trap.
- The actual function and its PUBLIC/authenticated grants are exercised. INSERT/SELECT policies in the test are minimal synthetic fixtures, not evidence that the live Supabase policies match them.
- QIMA CI #931 [run 42373665792](https://github.com/meridane/QimaTrade-MVP/actions/runs/42373665792) succeeded: 322 Playwright tests, zero failures; CREATE_OFFER integration and both concurrency assertions passed; synthetic legacy RLS passed; actual message-participant migration disposable-db regression passed; participant self-enrollment RLS passed. npm audit reported zero findings at all severities. CodeQL #885 [run 42373665927](https://github.com/meridane/QimaTrade-MVP/actions/runs/42373665927) succeeded.
- The read-only remote `list_migrations` refresh remains blocked by PostgreSQL `28P01` authentication failure. The 161-version remote history recorded on 2026-10-27 remains a historical snapshot, not a current parity result. The migration's applied status on Supabase is unknown.
- No migration was applied to any Supabase project. No production data/schema/policy/grant, migration history, secret, production configuration, or deployment was modified. The test database exists only for the duration of the isolated CI job.



## QA259 — guard destructive test runner database target — 2026-11-07

- The runner `tests/sql/run-legacy-messages-rls-regression.sh` now validates `DATABASE_URL` before the first `psql` call. Only PostgreSQL URIs for `qima_test` on port 5432 with `localhost`, `127.0.0.1`, or `[::1]` are accepted. Remote hosts, another database path, and query-bearing URLs exit with code 2; the URL is not printed.
- New `tests/sql/test-legacy-messages-runner-guard.sh` injects a `psql` stub and verifies three unsafe URL classes are rejected before any database client invocation.
- CI runs this negative guard test immediately before the actual migration test. The positive CI connection remains the isolated service URI `postgresql://postgres:postgres@localhost:5432/qima_test`.
- QIMA CI #933 [run 42378012790](https://github.com/meridane/QimaTrade-MVP/actions/runs/42378012790) succeeded: 322/322 Playwright; TypeScript, audit, build, PostgreSQL integration, URL guard, actual branch migration disposable-db test, and self-enrollment regression all passed. CodeQL #887 [run 42378012776](https://github.com/meridane/QimaTrade-MVP/actions/runs/42378012776) succeeded.
- The guard does not establish live Supabase migration parity. The remote `list_migrations` refresh is still blocked by PostgreSQL `28P01`; no production connection or mutation was attempted. No migration was applied to any Supabase project.



## QA260 — verify disposable migration database cleanup after a failed migration — 7 November 2026

- **Baseline:** PR #26 remains open, draft and mergeable on fix/create-offer-status-contract. The code change is in commits 0c696cdfc124558ff2f796d6793a6a57f76cea1c and 6ec40fd9eea2f4a7eb4648f8aca86452e16adb83. The documentation HEAD validated by CI #937 is 04a97f53b7f16912eafe763942bafc6e6e366e59.
- **Gap addressed:** QA259 verified that destructive operations are rejected before psql for unsafe database URLs, but did not exercise the EXIT trap when the disposable migration sequence fails after creating its temporary database.
- **Regression added:** tests/sql/test-legacy-messages-runner-guard.sh now injects a deterministic psql stub for a valid loopback qima_test URL. The stub allows the legacy regression script, pre-clean DROP, temporary database CREATE and migration fixture to proceed, then returns exit 42 for the actual branch migration command.
- **Assertions:** the expected command sequence is legacy regression → pre-clean DROP → CREATE → fixture → migration failure (42) → EXIT-trap DROP. The test requires the cleanup command to contain DROP DATABASE IF EXISTS qima_message_migration_test WITH (FORCE), and verifies that the runner preserves the original migration failure exit code 42.
- **Local validation:** bash tests/sql/test-legacy-messages-runner-guard.sh passed in an isolated temporary directory with a mocked runner/psql path. No PostgreSQL server was contacted by this local failure-path test.
- **QIMA CI #937:** [run 42384014441](https://github.com/meridane/QimaTrade-MVP/actions/runs/42384014441) completed successfully on documentation HEAD 04a97f5. Playwright: **322 passed in 6.8 seconds, 0 failed**. npm installation, npm audit, TypeScript, Next.js production build, Chromium installation, CREATE_OFFER PostgreSQL integration/concurrency, the unsafe-URL guard, the actual branch migration in a disposable PostgreSQL 16 database, and participant self-enrollment regression all passed.
- **QIMA CodeQL #891:** [run 42384014427](https://github.com/meridane/QimaTrade-MVP/actions/runs/42384014427) completed successfully.
- **Superseded runs:** QIMA CI #935 on the first test commit and #936 on the intermediate code commit were cancelled when later commits updated the PR head. They are not reported as test failures. CodeQL #889, #890 and #891 completed successfully.
- **Vercel:** the combined status for documentation HEAD 04a97f5 reports the provider build-rate-limit failure. This is separate from the successful GitHub Actions build; no deployment was forced or promoted.
- **Scope and safety:** the failure is simulated by a local stub. This validates that the shell EXIT trap issues the cleanup command and preserves the original exit code; it does not prove recovery from a real PostgreSQL server crash or guarantee cleanup after a network outage. The actual migration integration test remains confined to the ephemeral GitHub Actions PostgreSQL service. No Supabase production connection, data, migration, RLS policy, grant, schema, secret, production deployment, PR merge, or branch-protection setting was used or modified.


## QA261 — cleanup failure behavior for the disposable migration runner — 2026-11-08

- The EXIT cleanup now captures a non-zero `psql` status and emits a GitHub Actions warning without printing the database URL or credentials. The cleanup function returns success so a prior migration/test failure remains authoritative.
- The runner-guard regression now covers both a primary migration failure (42) followed by cleanup failure (91), and a successful migration followed by cleanup failure (91). Expected final statuses are 42 and 0 respectively; both scenarios require the cleanup warning and verify that the EXIT DROP was attempted.
- The real migration still runs only in the isolated GitHub Actions PostgreSQL 16 service. The cleanup-failure cases use a deterministic `psql` stub and do not connect to Supabase.
- QIMA CI #939 [run 42388526274](https://github.com/meridane/QimaTrade-MVP/actions/runs/42388526274) succeeded: the updated guard script passed, the actual migration disposable-db regression passed, and the PostgreSQL integration job completed successfully. Playwright: 322 passed, 0 failed. CodeQL #893 [run 42388526180](https://github.com/meridane/QimaTrade-MVP/actions/runs/42388526180) succeeded.
- **Limit:** the runner reports cleanup failure but preserves the primary result. A warning does not prove that the temporary database was deleted if PostgreSQL itself is unavailable. No production migration history, schema, data, RLS policy, or grant was modified.


## QA262 — real PostgreSQL disposable-database cleanup verification — 8 November 2026

- Added `tests/sql/assert-legacy-migration-database-absent.sh`, a read-only post-run check restricted to the dedicated loopback `qima_test` URL. It queries `pg_database` for `qima_message_migration_test` and fails if the temporary database remains.
- Extended `tests/sql/test-legacy-messages-runner-guard.sh` to cover absent (0), present (1), PostgreSQL inspection failure (91), and remote URL rejection (2 without a database call).
- Added a CI step immediately after the actual migration runner. QIMA CI #942 [run 42390456541](https://github.com/meridane/QimaTrade-MVP/actions/runs/42390456541) passed; the PostgreSQL job log explicitly confirms the database is absent after the EXIT trap. The complete browser suite passed **322/322**.
- QIMA CodeQL #895 [run 42390456540](https://github.com/meridane/QimaTrade-MVP/actions/runs/42390456540) succeeded.
- This verifies successful cleanup in the ephemeral GitHub Actions PostgreSQL 16 service only. It does not establish cleanup during a real PostgreSQL outage. Supabase remote migration-history parity remains unresolved because the read-only connector previously returned PostgreSQL `28P01`; no production migration was applied.
- No Supabase production data, migration, schema, RLS policy, grant, secret, production deployment, PR merge, or branch-protection setting was touched.


## QA263 — real SQL failure and disposable-database cleanup — 8 November 2026

- Added `tests/sql/test-legacy-messages-real-failure-cleanup.sh`. It runs the existing guarded migration runner against the isolated PostgreSQL 16 CI service, while a temporary `psql` shim delegates to the real client and substitutes only the branch-migration file argument with a temporary SQL statement that selects from a deliberately nonexistent relation.
- PostgreSQL returns the expected SQL script error (`psql` exit 3). The runner's real EXIT trap executes its normal forced DROP. The test then runs the existing read-only `pg_database` assertion through the real client and requires `qima_message_migration_test` to be absent.
- The test also requires the migration interception to occur exactly once, the expected PostgreSQL error to appear, the original exit 3 to be preserved, and no connection credentials to be printed.
- Added the test as a CI step after the QA262 successful-path cleanup assertion. Local `bash -n` passed; the real PostgreSQL execution is evidenced by QIMA CI #944 [run 42395947118](https://github.com/meridane/QimaTrade-MVP/actions/runs/42395947118), whose PostgreSQL job completed successfully and logged: `QA263 passed: PostgreSQL executed the injected SQL error (psql exit 3), the runner EXIT trap cleaned up the temporary database, and pg_database confirmed its absence.` The job also recorded the expected missing-relation server error. Browser suite: **322/322 passed**. CodeQL #897 [run 42395947097](https://github.com/meridane/QimaTrade-MVP/actions/runs/42395947097) succeeded.
- **Limit:** this proves the real SQL-error path and cleanup on the ephemeral GitHub Actions PostgreSQL 16 service. It does not prove recovery from server crash/network partition or cleanup when DROP permission is persistently denied. The actual branch migration file was not modified; the failure SQL was temporary and used only by this CI test.
- No Supabase production connection, data, migration, schema, RLS policy, grant, secret, production deployment, PR merge, or branch-protection change was used or modified.


## QA264 — active-session cleanup on PostgreSQL 16 — 8 November 2026

- Added a CI regression that keeps a second real PostgreSQL session active in `qima_message_migration_test` using `PGAPPNAME=qa264-held-session` and `SELECT pg_sleep(60)` after the actual migration assertions complete.
- The test confirms the session is active through `pg_stat_activity`, then allows the runner's EXIT trap to execute `DROP DATABASE ... WITH (FORCE)`. It requires PostgreSQL's administrator-termination FATAL message, a non-zero held-client status, and a subsequent read-only query confirming the database is absent.
- QIMA CI #946 [run 42401850431](https://github.com/meridane/QimaTrade-MVP/actions/runs/42401850431) succeeded. The PostgreSQL job log confirms the active backend was terminated and `qima_message_migration_test` was absent afterward. Full browser suite: **322/322 passed**. npm audit reported zero findings at all severities; TypeScript/build and all PostgreSQL integration regressions passed. CodeQL #899 [run 42401850439](https://github.com/meridane/QimaTrade-MVP/actions/runs/42401850439) succeeded.
- Vercel combined status reported success for code HEAD `f23e57d`, while the deployment detail still showed `BUILDING` and `target=null`; no Preview-READY or Production status is asserted.
- **Limit:** proves forced termination of a controlled active session only on the ephemeral GitHub Actions PostgreSQL 16 service. It does not establish behavior during server/network outage, persistent DROP permission failure, or remote Supabase migration parity.
- No remote Supabase migration history, production schema/data, RLS policy, grant, secret, or production deployment was modified.


- **Final documentation-head verification:** QIMA CI #947 [run 42402085380](https://github.com/meridane/QimaTrade-MVP/actions/runs/42402085380) and CodeQL #900 [run 42402085468](https://github.com/meridane/QimaTrade-MVP/actions/runs/42402085468) completed successfully on HEAD `2d17d868182c44e7bd02d23c80f17c29828359dd`. Playwright: **322 passed, 0 failed**; npm audit: zero findings; QA264 confirmed forced termination of the active PostgreSQL session and absence of the temporary database. Vercel's final documentation-head status was blocked by the daily deployment quota; no Preview-READY or Production status is asserted.


## QA265 — forced cleanup with multiple PostgreSQL sessions

- **Implementation:** added `tests/sql/test-legacy-messages-multiple-sessions-cleanup.sh` and a dedicated CI step in `.github/workflows/ci.yml`.
- **Real PostgreSQL setup:** after the existing migration assertions, the psql wrapper starts two independent clients (`qa265-active-one` and `qa265-active-two`) running `SELECT pg_sleep(60)`, plus a third client (`qa265-idle-in-transaction`) that executes `BEGIN; SELECT 1;` from a FIFO and remains open in `idle in transaction`.
- **Precondition:** the test polls `pg_stat_activity` and requires exactly one backend in each expected state before the migration runner exits and its `DROP DATABASE ... WITH (FORCE)` trap runs.
- **Termination evidence:** both active clients receive PostgreSQL's administrative-termination error. The idle client is deliberately sent a follow-up `SELECT 2` after a short delay because a psql process blocked on FIFO stdin does not necessarily observe an asynchronous socket close until it next interacts with the connection. The client then exits non-zero after detecting the closed connection.
- **Postcondition:** all three clients exit non-zero, the real read-only `pg_database` assertion confirms `qima_message_migration_test` is absent, and the output is checked for credential leakage.
- **Final validation:** QIMA CI #952 [run 42407664094](https://github.com/meridane/QimaTrade-MVP/actions/runs/42407664094) completed successfully. Playwright: **322 passed in 9.7 seconds, zero failed**; npm audit at the configured `high` threshold passed; TypeScript and Next.js build passed; the PostgreSQL job, including QA262, QA263, QA264 and QA265, passed. QIMA CodeQL #905 [run 42407664041](https://github.com/meridane/QimaTrade-MVP/actions/runs/42407664041) completed successfully.
- **Harness corrections recorded:** CI #949 failed because the initial test wrote a literal escaped `${DATABASE_URL-}` instead of reading the environment; fixed in `2741cea`. CI #950 then exposed a mismatched idle-writer readiness variable; fixed in `cd02484`. CI #951 showed that the idle psql process remained blocked on FIFO input after the server closed its socket; the post-cleanup wake-up query was added in `6428350`. These were test-harness failures, not application or production database findings. CodeQL #902, #903 and #904 completed successfully on the intermediate commits.
- **Limit:** this proves termination of two active and one idle-in-transaction session on the disposable PostgreSQL 16.15 GitHub Actions service. It does not prove behavior during server crash, network partition, prepared transactions, persistent permission failure, or on Supabase production.
- **Safety:** only a regression test, its CI invocation and documentation were changed. No Supabase production connection, data, migration, schema, RLS policy, grant, secret, production configuration, production deployment, PR merge, or branch-protection setting was used or modified.


## QA266 — prepared transaction blocks forced disposable-database cleanup — 8 November 2026

- **PostgreSQL rule under test:** PostgreSQL 16 documents that DROP DATABASE ... WITH (FORCE) attempts to terminate connections but does not terminate prepared transactions; the command fails while prepared transactions remain in the target database. See [PostgreSQL 16 DROP DATABASE](https://www.postgresql.org/docs/16/sql-dropdatabase.html).
- **CI-only configuration:** immediately before QA266, the GitHub Actions PostgreSQL 16 service container is configured with ALTER SYSTEM SET max_prepared_transactions = '10' and restarted. The step verifies the setting through the dedicated loopback qima_test connection. This change exists only in the ephemeral CI service; no Supabase project or persistent environment is configured.
- **Regression added:** tests/sql/test-legacy-messages-prepared-transaction-cleanup.sh delegates normal runner operations to the real psql client. After the actual branch migration and its assertions succeed in qima_message_migration_test, the wrapper creates a marker table, inserts a row in a transaction, and executes PREPARE TRANSACTION 'qa266_prepared_cleanup_blocker'.
- **Runner behavior:** the existing EXIT trap attempts DROP DATABASE IF EXISTS qima_message_migration_test WITH (FORCE). PostgreSQL refuses the drop. The runner emits its best-effort cleanup warning and preserves the successful migration/test exit status; it does not claim that the database was removed.
- **Blocker assertions:** the test requires exactly one matching row in pg_prepared_xacts, confirms the database remains present in pg_database, and verifies that the read-only database-absence assertion fails closed. A direct DROP attempt captures PostgreSQL's error: database "qima_message_migration_test" is being used by prepared transactions, with one prepared transaction in the database.
- **Explicit disposable cleanup:** a separate psql session executes ROLLBACK PREPARED 'qa266_prepared_cleanup_blocker'; the test then drops only the disposable database, requires zero matching prepared transactions, and reruns the read-only pg_database assertion to confirm absence. PostgreSQL documents that ROLLBACK PREPARED can be issued from any session and that prepared transactions are visible in pg_prepared_xacts; see [PostgreSQL 16 PREPARE TRANSACTION](https://www.postgresql.org/docs/16/sql-prepare-transaction.html).
- **CI integration:** .github/workflows/ci.yml adds an isolated setup step for the ephemeral service and runs QA266 after QA265. QIMA CI #954 [run 42410428830](https://github.com/meridane/QimaTrade-MVP/actions/runs/42410428830) completed successfully. The PostgreSQL job log records the prepared-transaction blocker, the expected failed DROP attempts, ROLLBACK PREPARED, the explicit DROP, and the final QA266 success message. The browser suite passed **322/322 in 9.4 seconds**; npm installation, the configured high-severity audit gate, TypeScript, Next.js build, Chromium, CREATE_OFFER PostgreSQL integration/concurrency, QA259–QA266 cleanup regressions, and participant self-enrollment regression all passed. QIMA CodeQL #907 [run 42410428833](https://github.com/meridane/QimaTrade-MVP/actions/runs/42410428833) completed successfully. The Vercel status check on this code HEAD reported success; no Production deployment was performed.
- **Limits:** this verifies the documented prepared-transaction blocker and the runner's honest best-effort behavior on the ephemeral PostgreSQL 16.15 GitHub Actions service. It does not establish production database behavior, remote Supabase migration parity, server-crash recovery, network-partition recovery, or persistent permission recovery. Prepared transactions should not be left unresolved; PostgreSQL warns that they retain locks and can interfere with vacuum, and recommends leaving the feature disabled when no transaction manager is configured.
- **Safety:** only the new regression script, its CI invocation/configuration, and documentation were changed. The actual branch migration file was executed only in the disposable CI database and was not modified. No Supabase production connection, data, migration history, schema, RLS policy, grant, secret, production configuration, Production deployment, PR merge, or branch-protection setting was used or modified.
