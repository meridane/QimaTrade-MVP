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

## QA267 — restore the prepared-transaction setting after QA266 — 8 November 2026

- **Gap addressed:** QA266 temporarily enables PostgreSQL prepared transactions with `ALTER SYSTEM SET max_prepared_transactions = '10'` in the ephemeral GitHub Actions PostgreSQL 16 service. Before QA267, the workflow did not explicitly remove that CI-only override or verify that the service returned to its initial setting.
- **Baseline and setup:** the workflow now reads `SHOW max_prepared_transactions` before changing anything and requires the pristine CI-service baseline to be `0`. It writes `baseline=0` and `restore_required=true` to the setup step outputs before issuing the ALTER SYSTEM change, so the later cleanup step knows whether a change may have been made even if setup/restart subsequently fails.
- **Always-run restoration:** immediately after QA266, a step with `if: always()` invokes `tests/sql/restore-prepared-transactions-config.sh`. If setup did not record a change, the script is a no-op. Otherwise it validates the dedicated loopback `qima_test` URL and captured baseline, requires exactly one PostgreSQL 16 service container, waits for the service to be reachable, executes `ALTER SYSTEM RESET max_prepared_transactions`, restarts the disposable container, and waits for readiness again.
- **Postconditions:** the script requires `SHOW max_prepared_transactions` to equal the captured baseline (`0`), the QA266 GID `qa266_prepared_cleanup_blocker` to be absent from `pg_prepared_xacts`, and `qima_message_migration_test` to be absent from `pg_database`. A remaining prepared transaction/database, ambiguous container selection, unexpected baseline, unavailable service, or reset/restart failure fails the CI step rather than being reported as restored.
- **Mocked guard regression:** `tests/sql/test-prepared-transactions-config-restore.sh` verifies reset/restart/verification ordering, the no-op path when no change was recorded, rejection of remote URLs and unapproved baselines before external commands, rejection of ambiguous container selection, and failure when QA266 resources remain. These stubs test shell control flow only; the actual restoration is separately executed against the live ephemeral PostgreSQL service in CI.
- **Real CI evidence:** QIMA CI #959 [run 42416615766](https://github.com/meridane/QimaTrade-MVP/actions/runs/42416615766) completed successfully on code HEAD `97e20a66e9cbba884c408c1698c948b1e9321195`. Both jobs passed: TypeScript, npm audit at the configured `high` threshold, Next.js build, Chromium, **322/322 Playwright tests (5.4 seconds)**, CREATE_OFFER PostgreSQL integration/concurrency, QA259–QA267 cleanup regressions, and participant self-enrollment RLS. The PostgreSQL job log explicitly records `ALTER SYSTEM` followed by: `QA267 passed: ALTER SYSTEM RESET was followed by a PostgreSQL restart; max_prepared_transactions returned to baseline 0, and no QA266 prepared transaction or disposable database remained.`
- **Static analysis and superseded run:** QIMA CodeQL #912 [run 42416614249](https://github.com/meridane/QimaTrade-MVP/actions/runs/42416614249) completed successfully. Earlier CI #958 [run 42416545077](https://github.com/meridane/QimaTrade-MVP/actions/runs/42416545077) was cancelled when the final harness correction produced a newer HEAD; it is superseded, not a failed test run. CodeQL #911 [run 42416545083](https://github.com/meridane/QimaTrade-MVP/actions/runs/42416545083) also completed successfully on the preceding code HEAD.
- **Vercel:** the combined status on QA267 code HEAD reports the existing `upgradeToPro=build-rate-limit` failure. GitHub Actions build/tests are successful, but no fresh Preview-READY result is asserted and no deployment was forced.
- **Limits:** this verifies restoration of the setting and cleanup of QA266 resources on the disposable GitHub Actions PostgreSQL 16 service only. It does not establish behavior on Supabase or any persistent/production database, and it does not test recovery from Docker daemon failure or a PostgreSQL process that cannot be restarted.
- **Safety:** no Supabase production connection, data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection change was used or modified. The ALTER SYSTEM SET/RESET operations and both PostgreSQL restarts were confined to the ephemeral CI service.


## QA268 — explicit failure handling for prepared-configuration restoration — 8 November 2026

- **Gap addressed:** the QA267 restoration script used `set -e` to stop when `ALTER SYSTEM RESET max_prepared_transactions` or `docker restart` failed, but it did not emit a step-specific diagnostic or make the unconfirmed restoration state explicit. QA268 adds explicit failure branches for both commands.
- **RESET failure path:** when the `docker exec ... ALTER SYSTEM RESET` command fails, the script captures and preserves its exit status, emits an Actions error stating that configuration restoration is not confirmed, and exits before attempting a container restart or any postcondition query.
- **Restart failure path:** when `docker restart` fails, the script captures and preserves its exit status, emits an Actions error stating that restored configuration is not confirmed, and exits before readiness polling or querying `SHOW max_prepared_transactions`. The script never prints the QA267 success message on either failure path.
- **Regression coverage:** `tests/sql/test-prepared-transactions-config-restore.sh` injects a RESET failure with exit 42 and a restart failure with exit 43. It asserts the exact diagnostics, the original exit codes, and the command sequences: RESET failure must not restart; restart failure must not proceed to readiness or verification. Existing no-op, loopback URL, single-container, baseline, and residual-resource tests remain active.
- **Scope of evidence:** the two failure paths use deterministic command stubs to validate shell control flow; they do not simulate or prove a real Docker daemon or PostgreSQL failure. The successful restoration path is separately exercised against the disposable PostgreSQL 16 service in GitHub Actions.
- **CI evidence:** QIMA CI #962 [run 42422099481](https://github.com/meridane/QimaTrade-MVP/actions/runs/42422099481) completed successfully on code HEAD `fd291dd9c88a890d4e82fa52bf0450f68dbc0a70`. Both jobs passed: dependency installation, npm audit at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, **322/322 Playwright tests (8.1 seconds)**, CREATE_OFFER PostgreSQL integration/concurrency, legacy RLS migration regression, QA259–QA267 cleanup regressions, QA268 restoration-failure guard tests, and participant self-enrollment regression. The PostgreSQL job log records the QA268 regression success message and the live QA267 restoration success message; no job step failed.
- **Static analysis and Preview:** QIMA CodeQL #915 [run 42422099457](https://github.com/meridane/QimaTrade-MVP/actions/runs/42422099457) completed successfully. The combined Vercel status on the code HEAD was `success`; the Vercel Preview Comments check also completed successfully. This is not a Production deployment.
- **Limits:** this confirms explicit shell handling for simulated RESET/restart command failures and a successful restoration on the ephemeral CI PostgreSQL service. It does not prove recovery from a Docker daemon outage, a PostgreSQL process that cannot restart, a network partition, or any persistent/production database condition. No vulnerability is inferred from these synthetic failure tests.
- **Safety:** only the two CI restoration scripts and documentation were changed. No Supabase production connection, data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection setting was used or modified. All real `ALTER SYSTEM` and restart operations remained confined to the ephemeral GitHub Actions PostgreSQL service.

- **Documentation-only HEAD status:** the QA268 register-only follow-up commit `d737850886dee7885b718c782d31409f6e34253b` changed only `docs/**`. Both `.github/workflows/ci.yml` and `.github/workflows/codeql.yml` declare `paths-ignore: docs/**`, and no new QIMA CI or CodeQL run was created for that docs-only commit. The combined Vercel status on that docs-only HEAD returned `failure` with `upgradeToPro=build-rate-limit`; this is the deployment quota status, not a failed GitHub Actions build. The QA268 code HEAD remains validated by CI #962 and CodeQL #915 above.

- **Superseded initial CI attempt:** QIMA CI #961 [run 42422067759](https://github.com/meridane/QimaTrade-MVP/actions/runs/42422067759) on initial commit `38ae4cf5388daa1a205a7bce6c3fbe2b2d8611bf` was cancelled after review found the newly added shell test's `printf` newline escapes needed correction. The assertion was fixed in `fd291dd9c88a890d4e82fa52bf0450f68dbc0a70`; CI #961 is superseded/cancelled, not a failed test result. CodeQL #914 [run 42422067732](https://github.com/meridane/QimaTrade-MVP/actions/runs/42422067732) completed successfully on the initial commit; final corrected code was validated by CI #962 and CodeQL #915 above.


## QA269 — post-restart readiness and effective-configuration rejection (8 November 2026, 08:33 KST)

- **Validated PR:** [#26](https://github.com/meridane/QimaTrade-MVP/pull/26), base `main`, head branch `fix/create-offer-status-contract`.
- **Validated code HEAD:** `9bcfa4319ec737351add4d80d870def604ddc083` (`test(postgres): cover QA269 restoration verification failures`).
- **Scope:** regression coverage added only to `tests/sql/test-prepared-transactions-config-restore.sh`. The restoration runner and CI workflow were not changed.
- **QA269-A — PostgreSQL unavailable after restart:** the deterministic `pg_isready` stub succeeds for the pre-reset probe and fails for all 60 post-restart probes. A no-op `sleep` stub keeps the bounded retry test fast. The script exits nonzero, emits the existing “did not return to max_prepared_transactions=0” error, and performs neither configuration nor residual-resource success checks.
- **QA269-B — effective value remains wrong:** the readiness stub stays successful, but the `SHOW max_prepared_transactions` stub returns `10` for all 60 verification attempts instead of the captured baseline `0`. The script exits nonzero, reports that the baseline was not restored, and does not inspect residual resources or print the QA267 success message.
- **Deterministic assertions:** each case confirms 61 readiness probes (one pre-reset plus 60 post-restart), 60 bounded retry sleeps, and the expected number of configuration queries. These are mocked failure-path tests; they do not simulate an actual PostgreSQL outage or prove a production configuration defect.
- **QIMA CI #966:** [run 42425895151](https://github.com/meridane/QimaTrade-MVP/actions/runs/42425895151) — **SUCCESS**. TypeScript, dependency audit, Next.js build, Chromium and **322/322 Playwright tests** passed. The npm audit report recorded 0 info, 0 low, 0 moderate, 0 high and 0 critical findings. The PostgreSQL integration job also succeeded, including the existing QA259–QA268 checks, the QA269 restoration guard suite, and the real QA267 restoration on the ephemeral PostgreSQL 16 service.
- **PostgreSQL log evidence:** the QA269 regression summary was emitted; the real restoration step then confirmed `ALTER SYSTEM RESET`, PostgreSQL restart, `max_prepared_transactions=0`, no remaining QA266 prepared transaction and no remaining disposable database.
- **QIMA CodeQL #919:** [run 42425895131](https://github.com/meridane/QimaTrade-MVP/actions/runs/42425895131) — **SUCCESS**.
- **Vercel combined status:** **SUCCESS** on this tested code HEAD. This is a Preview/check status only; no Production deployment was made.
- **Limits and interpretation:** QA269 proves fail-closed behavior for two deterministic mocked post-restart failure modes and bounded retries. QA267 separately proves successful restoration on the ephemeral CI PostgreSQL service. Neither synthetic negative case establishes a production outage, a confirmed vulnerability, or a production configuration problem.
- **Safety:** no Supabase production connection, data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection setting was used or modified. The only code change was a CI regression test; real PostgreSQL configuration changes remained confined to the disposable GitHub Actions service.
- **Migration scope note:** QA269 does not add, alter, apply, or reconcile any Supabase migration. It covers only the temporary PostgreSQL configuration-restoration test harness used by GitHub Actions.


## QA269 — final documentation-head status (8 November 2026, 08:36 KST)

- **Documentation HEAD:** `9b2dc7be78b4896893f9f26acf7e1149a24d9599`; the three QA269 register updates are documentation-only.
- **GitHub Actions:** no new QIMA CI or CodeQL run was created for this docs-only HEAD because both workflows ignore `docs/**`. The unchanged tested code parent `9bcfa4319ec737351add4d80d870def604ddc083` remains validated by QIMA CI #966 (**SUCCESS**) and CodeQL #919 (**SUCCESS**).
- **Vercel combined status on the documentation HEAD:** **FAILURE**, target `upgradeToPro=build-rate-limit`. This is a deployment quota status, not a GitHub Actions build failure. No Preview READY is claimed for this documentation HEAD and no Production deployment occurred.
- **Migration note:** this status record does not change or reconcile any Supabase migration or production database state.


## QA269 — correction: pull_request path-filter behavior and validation (8 November 2026, 08:40 KST)

- **Correction to the preceding QA269 final documentation-head status:** the statement that no new QIMA CI or CodeQL run was created because the workflows declare `paths-ignore: docs/**` was inaccurate. For `pull_request` events, GitHub evaluates the aggregate PR changed-file set. PR #26 still contains application, test and workflow changes outside `docs/**`, so documentation-only follow-up commits also triggered both workflows.
- **QIMA CI #968:** [run 42426113135](https://github.com/meridane/QimaTrade-MVP/actions/runs/42426113135) — **SUCCESS** on documentation HEAD `c87c9212fc281b6667367b4a1e29944cb3ff50e3`. Both jobs completed: TypeScript, npm audit, Next.js build, Chromium, **322/322 Playwright tests**, CREATE_OFFER PostgreSQL integration/concurrency, QA259–QA269 regression guards, real QA267 restoration and participant self-enrollment RLS. The npm audit JSON reported 0 info, 0 low, 0 moderate, 0 high and 0 critical findings.
- **QIMA CodeQL #921:** [run 42426113105](https://github.com/meridane/QimaTrade-MVP/actions/runs/42426113105) — **SUCCESS** on the same documentation HEAD.
- **Code unchanged:** the only difference between validated code HEAD `9bcfa4319ec737351add4d80d870def604ddc083` and `c87c9212fc281b6667367b4a1e29944cb3ff50e3` was the QA269 register documentation. The successful #968/#921 checks therefore cover the same code.
- **Follow-up behavior:** this correction is also documentation-only, but because the PR's aggregate diff still includes non-documentation paths, GitHub may start another pull-request CI and CodeQL run for the corrected documentation HEAD. The correction commit itself does not alter application or SQL code.
- **Vercel:** the combined status on `c87c9212fc281b6667367b4a1e29944cb3ff50e3` was **FAILURE** with `upgradeToPro=build-rate-limit`. This is the deployment quota status, not a GitHub Actions failure; no Preview READY is claimed for that HEAD and no Production deployment occurred.
- **Safety and interpretation:** QA269-A and QA269-B remain deterministic mocked failure-path tests, not proof of a real PostgreSQL outage or a confirmed vulnerability. QA267 separately verifies successful restoration on the ephemeral PostgreSQL 16 CI service. No Supabase production data, migration, schema, policy, grant, secret, persistent configuration, Production deployment, merge, or branch-protection setting was changed.

- **Migration reconciliation:** this correction is a CI documentation note only; it does not resolve the separate remote Supabase authentication/parity blocker.


## QA270 — post-restart configuration-read failure (8 November 2026)

- The QA270 test was already present on the PR branch at the start of the subsequent maintenance run. It verifies that a successful readiness probe followed by a failed `SHOW max_prepared_transactions` psql query returns the original exit status 44 and prevents resource postcondition checks or a false success message.
- QIMA CI #971 [run 42431842941](https://github.com/meridane/QimaTrade-MVP/actions/runs/42431842941) and CodeQL #924 [run 42431842966](https://github.com/meridane/QimaTrade-MVP/actions/runs/42431842966) both completed successfully. The CI PostgreSQL job also confirmed the real QA267 restoration on the ephemeral PostgreSQL service.
- The Vercel combined status on the QA270 code HEAD was success. This was not a Production deployment.
- This is a deterministic shell regression test for the read-query failure branch, not evidence of a production outage or vulnerability.

## QA271 — postcondition query failure handling (8 November 2026)

- The restoration runner now emits separate diagnostics and preserves the original psql exit code if the `pg_prepared_xacts` query fails or if the `pg_database` query fails.
- The regression test injects psql exit 45 and 46, asserts the corresponding diagnostic and confirms that the QA267 success message is not emitted.
- Commits: runner `24c8a67fabe1da553c70048f346bd63c5bc63c1b`; test `03c32a0fa1398cbba9634c8da9aa96e7127c7c4e`.
- A focused local shell harness passed for both guarded query failures. At the time this entry was written, no QIMA CI or CodeQL run had been returned for HEAD `03c32a0fa1398cbba9634c8da9aa96e7127c7c4e`; final repository validation remains pending. Vercel reports `build-rate-limit`, which is separate from CI.
- This work is limited to the disposable CI restoration harness. No production Supabase migration, data, policy, grant, secret, or configuration was touched.



## QA271 — final validation status and current PR head (8 November 2026)

- **Final documentation candidate HEAD:** `237943d2d5e2efbfdba8364d718cb574a19c18dc`; validated code candidate immediately before the two documentation commits: `03c32a0fa1398cbba9634c8da9aa96e7127c7c4e`.
- **Current PR branch:** `fix/create-offer-status-contract`; comparison with `main` reports 996 commits ahead and 0 behind. PR #26 remains open and draft, with 65 changed files, no reviews and no review threads.
- **QA270 last validated ancestor:** code HEAD `f053712cfac205b03ce9696122460eb47a334682`; QIMA CI #971 [run 42431842941](https://github.com/meridane/QimaTrade-MVP/actions/runs/42431842941) — **SUCCESS**, including **322/322 Playwright tests**, successful PostgreSQL integration job, the QA270 SHOW-query failure regression summary, and the real QA267 restoration confirmation. CodeQL #924 [run 42431842966](https://github.com/meridane/QimaTrade-MVP/actions/runs/42431842966) — **SUCCESS**.
- **QA271 validation:** a focused local shell harness passed for both guarded psql postcondition failures (exit 45 for `pg_prepared_xacts`, exit 46 for `pg_database`). However, GitHub returned no QIMA CI or CodeQL workflow runs for QA271 code HEAD `03c32a0fa1398cbba9634c8da9aa96e7127c7c4e` or the subsequent documentation HEAD. Therefore QA271 is **not yet CI-validated**; the successful QA270 runs must not be presented as covering QA271.
- **Combined status on QA271 documentation HEAD:** Vercel **FAILURE**, target `upgradeToPro=build-rate-limit`. This is separate from GitHub Actions and does not establish a Next.js build failure. No Preview READY is claimed for QA271 HEAD.
- **Canonical register retrieval limitation:** `docs/QIMA_V1_FUNCTION_REGISTER.md` remains over the GitHub file-content connector's supported retrieval size; the connector returns its blob metadata but no body, including for line-range requests. It was not replaced or truncated. QA270/QA271 are recorded in this append-only companion register and in the migration reconciliation register.
- **Safety:** no production Supabase data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection setting was changed.



## QA272 — prepared-transaction restoration retry regression (8 November 2026)

- No Supabase migration or database change was made. QA272 only extends the disposable PostgreSQL restoration shell regression test.
- The new deterministic cases cover: two failed pre-reset readiness probes followed by recovery; two failed post-restart readiness probes followed by recovery; and two temporary `SHOW max_prepared_transactions = 10` results followed by convergence to baseline `0`.
- Intermediate CI #975 [run 42435627687](https://github.com/meridane/QimaTrade-MVP/actions/runs/42435627687) failed because the test mock referenced an optional variable under Bash `set -u` without a default. The failure was diagnosed from the job log and corrected in commit `e56da2f80b2d4a37182b500c68b020ebae0cbcb9`; no production issue was inferred.
- Final CI #976 [run 42435736103](https://github.com/meridane/QimaTrade-MVP/actions/runs/42435736103) — **SUCCESS**, including both CI jobs, **322/322 Playwright tests**, PostgreSQL integration, the QA272 retry regression, and real QA267 restoration on the ephemeral PostgreSQL 16 service.
- CodeQL #929 [run 42435736264](https://github.com/meridane/QimaTrade-MVP/actions/runs/42435736264) — **SUCCESS**.
- CI #976 npm audit reported 0 info, 0 low, 0 moderate, 0 high and 0 critical findings. This is an audit result for that run only.
- Vercel on the code HEAD reported `upgradeToPro=build-rate-limit`; this is a Preview/deployment quota issue, not a GitHub Actions failure. No Preview READY or Production deployment is claimed.
- QA272 retry/recovery cases use command stubs and do not prove an actual PostgreSQL outage or vulnerability. QA267 independently verifies the successful reset/restart and cleanup against the temporary PostgreSQL service.
- The pre-existing remote Supabase migration-history authentication/parity blocker remains unresolved; QA272 does not attempt to bypass it.
- No production data, migration, schema, RLS policy, grant, secret, persistent database configuration, Production deployment, merge, or branch-protection setting was changed.
