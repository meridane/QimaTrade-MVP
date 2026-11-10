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


## QA273 — prepared-transaction setup marker and cleanup guarantee (8 November 2026)

- The former inline PostgreSQL setup in `.github/workflows/ci.yml` is now `tests/sql/enable-prepared-transactions-config.sh`; CI invokes a new regression test before setup.
- The setup captures and validates the disposable PostgreSQL baseline (`0`) and writes both `baseline=0` and `restore_required=true` to `GITHUB_OUTPUT` before the first mutating command. The existing restoration step still runs with `if: always()`.
- Stubbed failure cases verify marker persistence after `ALTER SYSTEM SET` exit 47, restart exit 48, post-restart SHOW exit 49, and 60 failed readiness attempts. The mock `docker exec` asserts that the marker exists before allowing the SET command.
- QIMA CI #978 [run 42438738454](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438738454) — **SUCCESS**, including the new QA273 setup regression, **322/322 Playwright tests**, CREATE_OFFER PostgreSQL integration, QA266 prepared-transaction blocker and QA267 real restoration to `max_prepared_transactions=0`; no prepared transaction or disposable database remained.
- QIMA CodeQL #931 [run 42438738450](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438738450) — **SUCCESS**. npm audit on CI #978 reported zero findings across info/low/moderate/high/critical; this is scoped to that run.
- Vercel combined status on the tested code HEAD: **SUCCESS**, Preview/check only.
- QA273 negative failure paths use deterministic command stubs and are not evidence of a production outage or confirmed vulnerability. All actual ALTER SYSTEM operations and PostgreSQL restarts occurred only in the ephemeral GitHub Actions PostgreSQL 16 service.
- The remote Supabase migration-history authentication/parity blocker remains separate and unresolved. No Supabase production connection, data, migration, schema, policy, grant, secret, persistent configuration, Production deployment, merge, or branch-protection change occurred.


## QA273 — final documentation-head validation (8 November 2026, 11:26 KST)

- **Code HEAD:** `a2e35e7d1caa9800ce1def55463b3c8beab8c173`. QIMA CI #978 [run 42438738454](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438738454) — **SUCCESS**; both jobs completed, including the QA273 setup regression, **322/322 Playwright tests**, CREATE_OFFER PostgreSQL integration, QA266 real prepared-transaction blocker handling and QA267 real PostgreSQL restoration. QIMA CodeQL #931 [run 42438738450](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438738450) — **SUCCESS**.
- **Documentation HEAD:** `2bff0eb58ca4366e13f870229b1bec34b3fed20e`, after the three QA273 register updates. QIMA CI #979 [run 42438904011](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438904011) — **SUCCESS**; both jobs completed. The PostgreSQL job log contains the QA273 marker-before-mutation regression success line, confirms the live QA266 blocker case and confirms QA267 restored `max_prepared_transactions=0` with no residual prepared transaction or disposable database. The browser job reported **322 passed**; TypeScript, npm audit, Next.js build and Chromium steps all succeeded. QIMA CodeQL #932 [run 42438904032](https://github.com/meridane/QimaTrade-MVP/actions/runs/42438904032) — **SUCCESS**.
- **npm audit:** CI #979 reported 0 info, 0 low, 0 moderate, 0 high and 0 critical findings. This is scoped to that run and is not a general guarantee of absence of vulnerabilities.
- **Vercel distinction:** the combined Vercel status on code HEAD `a2e35e7` was **SUCCESS** (Preview/check only). On final documentation HEAD `2bff0eb58ca4366e13f870229b1bec34b3fed20e`, the combined status returned **FAILURE** with target `upgradeToPro=build-rate-limit`. This is a deployment quota limitation, not a GitHub Actions or Next.js build failure. No Preview READY is claimed for the documentation HEAD and no Production deployment occurred.
- **PR comparison:** branch `fix/create-offer-status-contract` is 1008 commits ahead of `main`, 0 behind, with 67 changed files; no reviews or review threads were recorded. PR #26 remains open and draft.
- **Safety:** the final follow-up changed only documentation. No application code, Supabase production data/schema/migration/RLS/grant, secret, persistent database configuration, Production deployment, merge, or branch-protection setting was changed.


## QA273 — final-head check follow-up (8 November 2026, 12:51 KST)

- The final QA273 documentation-head checks were subsequently observed as **QIMA CI #980** [run 42439080004](https://github.com/meridane/QimaTrade-MVP/actions/runs/42439080004) — **SUCCESS** (both verification and PostgreSQL jobs completed), and **QIMA CodeQL #933** [run 42439080099](https://github.com/meridane/QimaTrade-MVP/actions/runs/42439080099) — **SUCCESS**. These checks were inspected after the earlier QA273 register snapshot and are recorded here to close that evidence gap.
- The combined status on the same documentation HEAD reported Vercel **FAILURE**, target upgradeToPro=build-rate-limit. This is a Preview build quota limitation; it is not a GitHub Actions or Next.js build failure. No Preview READY is claimed for that HEAD.

## QA274 — fail-closed Docker service-container discovery (8 November 2026, 12:51 KST)

- **Code HEAD:** d509e23a1cd10cefedaa06bd1881a7795976d931, on fix/create-offer-status-contract / PR #26.
- **Change:** both tests/sql/enable-prepared-transactions-config.sh and tests/sql/restore-prepared-transactions-config.sh now capture docker ps output and exit status in an explicit conditional. A non-zero docker ps status is preserved even if partial stdout was emitted; the partial output is never parsed or used. Only after successful discovery are non-empty lines parsed, and exactly one PostgreSQL 16 container is required before baseline queries, readiness probes, docker exec, RESET, or restart.
- **Regression coverage:** setup tests cover partial stdout plus exit 55, zero containers, and multiple containers, proving no baseline query or restoration marker is written. Restoration tests cover partial stdout plus exit 54, zero containers, and multiple containers, proving no readiness probe or RESET is attempted. Existing one-container success paths remain covered.
- **QIMA CI #981:** [run 42444679702](https://github.com/meridane/QimaTrade-MVP/actions/runs/42444679702) — **SUCCESS**; both jobs completed. The browser job reported **322 passed**; npm audit reported 0 info, 0 low, 0 moderate, 0 high, 0 critical; TypeScript, Next.js build and Chromium installation succeeded. The PostgreSQL job log contains both new QA274 regression success summaries and the real QA267 restoration confirmation (max_prepared_transactions returned to baseline 0, with no residual QA266 prepared transaction or disposable database).
- **QIMA CodeQL #934:** [run 42444679701](https://github.com/meridane/QimaTrade-MVP/actions/runs/42444679701) — **SUCCESS**.
- **Vercel:** combined status on code HEAD d509e23 reported **FAILURE** with target upgradeToPro=build-rate-limit. This is a Preview quota limitation; no Preview READY is claimed for this code HEAD and no Production deployment occurred.
- **PR comparison at code validation:** fix/create-offer-status-contract was 1017 commits ahead of main, 0 behind, with 67 changed files. No PR reviews or review threads were recorded. PR #26 remains open; its description continues to identify it as a draft.
- **Interpretation and limits:** the partial-output Docker failures are deterministic command-stub regressions; they do not prove that the Docker daemon failed or that a production vulnerability exists. The actual PostgreSQL setup, prepared-transaction blocker, cleanup and configuration restoration remain separately exercised on the ephemeral GitHub Actions PostgreSQL 16 service.
- **Safety:** no Supabase production connection, data, schema, migration, RLS policy, grant, secret, persistent database configuration, Production deployment, PR merge, or branch-protection setting was changed. All PostgreSQL mutations and restarts remain confined to the disposable GitHub Actions service.


## QA275 — initial baseline read failure and safe no-op cleanup (2026-11-08)

- The disposable PostgreSQL setup regression now injects a first-call `SHOW max_prepared_transactions` failure with exit 50.
- The setup script stops before publishing any restoration marker or executing `ALTER SYSTEM SET` / `docker restart`; the original `psql` exit status is retained.
- The workflow's `if: always()` cleanup path is separately checked with an empty marker and exits as a no-op without Docker/PostgreSQL commands.
- The initial harness defect in commit `b6a7b0b` was corrected in `1190862` before the successful CI run.
- Exact code HEAD: `1190862cdf5d38f9da7096453f978d09b805e3dd`; QIMA CI **#985** and CodeQL **#938** both completed successfully. PostgreSQL 16 integration, QA266 prepared-transaction cleanup and QA267 restoration passed in the ephemeral GitHub Actions service; no production database was used.
- This is a deterministic test-stub failure path, not a finding of a production database fault or vulnerability. No Supabase production migration/data/schema/RLS/grant/secret was touched.

## QA276 — disposable PostgreSQL baseline mismatch guard (2026-11-08)

- The setup regression now covers a successful initial SHOW max_prepared_transactions that returns 5, while the disposable service contract requires baseline 0.
- The setup script must reject the mismatch before writing either GitHub Actions output (baseline or restore_required=true), before ALTER SYSTEM SET, and before a container restart. The test checks the exact docker-ps then psql-show-1 event sequence and then verifies the if: always() restoration script safely no-ops with empty outputs.
- The first QA276 test commit 0d8ff956b0e352cce627d75064b8d9d943c629bd contained a malformed Bash insertion and CI #987 failed with a syntax error in the setup regression file. The corrected test is in 68e4dc7493badca409b9309eeddbcecdba6c5529.
- QIMA CI #988 (run 42452799606) — SUCCESS: both jobs completed, including CREATE_OFFER PostgreSQL integration, the setup regression, QA267 real PostgreSQL restoration, TypeScript, npm audit, Next.js build, Chromium and 322/322 Playwright tests. npm audit reported zero findings across info/low/moderate/high/critical for this run.
- QIMA CodeQL #940 (run 42452623123) — SUCCESS on the initial QA276 code commit; no separate CodeQL run was returned for the shell-test-only correction commit.
- Vercel combined status on corrected code HEAD was PENDING at last observation; no Preview READY or Production deployment is claimed.
- QA276 is a deterministic stubbed regression, not a live production database finding. No Supabase production migration, data, schema, RLS, grant, secret, or persistent database configuration was changed.
### QA276 — final documentation-head validation (8 November 2026)

- **Code HEAD:** 68e4dc7493badca409b9309eeddbcecdba6c5529. QIMA CI #988 (run 42452799606) — **SUCCESS**; both jobs completed, including PostgreSQL integration and cleanup, setup/restore regression suites, **322/322 Playwright tests**, npm audit (0 total findings), TypeScript, Next.js build and Chromium.
- **Documentation HEAD:** 50b53d6e7ade13e4bddef8adcc332408a534d600. QIMA CI #989 (run 42453014569) — **SUCCESS**; both jobs completed. The PostgreSQL log contains the setup regression summary and real QA267 restoration confirmation; the browser job reported **322 passed (7.0s)** and npm audit reported 0 info, 0 low, 0 moderate, 0 high and 0 critical findings.
- **QIMA CodeQL #942:** run 42453014597 — **SUCCESS** on documentation HEAD 50b53d6e7ade13e4bddef8adcc332408a534d600.
- **Vercel:** combined status on the documentation HEAD was **FAILURE**, target upgradeToPro=build-rate-limit. This is a Preview quota limitation, not a GitHub Actions or Next.js build failure; no Preview READY or Production deployment is claimed.
- **PR comparison:** 1028 commits ahead of main, 0 behind, 67 changed files. PR #26 remains open and draft; no reviews or review threads were recorded.
- **Scope:** the documentation-only follow-up records validation evidence; no application, SQL migration, production database, or persistent configuration changed.
## QA277 — restoration-marker persistence failure guard (2026-11-08)

- The setup regression injects a controlled `printf` failure (exit 52) when writing the exact `baseline` / `restore_required=true` GitHub Actions output block, after the disposable PostgreSQL container is discovered and the initial baseline `0` is read.
- The test asserts a non-zero setup result, an empty output file, no `ALTER SYSTEM SET`, no restart, and the exact pre-mutation event sequence. It then verifies the workflow's `if: always()` restoration script safely no-ops with an empty marker.
- The failure is injected by a temporary `BASH_ENV` shell hook; it is not a real filesystem permission/disk-full test and is not evidence of a production fault or vulnerability.
- Initial harness commit `e33ca3a6da08a979a4bfaac0f01a56273797c0fb` was superseded because its test hook was incorrectly escaped. Corrected test commit: `6e3751ca76eeeb7eabe1363df8415c9e78120631`.
- CI and CodeQL validation for the corrected QA277 commit are pending. No production Supabase migration/data/schema/RLS/grant/secret or persistent PostgreSQL configuration was changed.

### QA277 — final validation evidence (2026-11-08)

- Corrected test commit: `6e3751ca76eeeb7eabe1363df8415c9e78120631`; validated documentation HEAD: `40ba0a446af8ab72d0f96d4c0510b63dd7bc638f`.
- QIMA CI #991 ([run 42455954675](https://github.com/meridane/QimaTrade-MVP/actions/runs/42455954675)) — **SUCCESS**, both jobs. The setup regression containing QA277 passed; PostgreSQL integration and the real QA267 restoration to baseline 0 also passed on the disposable PostgreSQL 16 service.
- Browser/build job passed TypeScript, npm audit enforcement, Next.js build, Chromium, and **322/322 Playwright tests (6.0s)**. npm audit reported zero findings in all five severity buckets for this run.
- QIMA CodeQL #944 ([run 42455954673](https://github.com/meridane/QimaTrade-MVP/actions/runs/42455954673)) — **SUCCESS**, with no new alerts reported by the check.
- Vercel combined status: **FAILURE** due to the Preview deployment rate limit (`upgradeToPro=build-rate-limit`); no Preview READY or Production deployment is claimed.
- QA277 uses a deterministic `BASH_ENV` hook to make the marker-writing `printf` return 52; it does not prove an OS-level filesystem fault or a production vulnerability. No production Supabase migration/data/schema/RLS/grant/secret or persistent PostgreSQL configuration was changed.

### QA277 — final PR-head validation after register synchronization (2026-11-08)

- PR documentation HEAD `c70aa47601d98c50027dfada75e9444500cd6fdf`: QIMA CI #992 ([run 42456100382](https://github.com/meridane/QimaTrade-MVP/actions/runs/42456100382)) — **SUCCESS**, both jobs; QIMA CodeQL #945 ([run 42456100379](https://github.com/meridane/QimaTrade-MVP/actions/runs/42456100379)) — **SUCCESS**, no new alerts reported by the check.
- CI #992 completed the setup regression containing QA277, the PostgreSQL integration suite, and the real QA267 restoration to baseline 0. The browser/build job passed TypeScript, npm audit enforcement, Next.js build, Chromium and **322/322 Playwright tests (7.7s)**; npm audit reported zero findings in all five severity buckets for this run.
- Vercel combined status remains a Preview rate-limit failure; no Preview READY or Production deployment is claimed.
- QA277 is a controlled shell-hook regression, not a real filesystem failure or production vulnerability. No Supabase production migration/data/schema/RLS/grant/secret or persistent PostgreSQL configuration was changed.

## QA278 — actual GITHUB_OUTPUT permission denial (2026-11-08)

- The setup regression now exercises a real filesystem permission failure instead of relying only on QA277's injected printf hook: a regular output file is changed to mode 0444 and the script is executed as an unprivileged user.
- On a root-invoked test process, the harness uses runuser -u nobody; otherwise it uses the current non-root runner account. The test requires an actual Permission denied diagnostic, an empty output file, and exactly the pre-mutation events docker-ps then psql-show-1.
- The regression asserts no ALTER SYSTEM SET, no PostgreSQL restart, and a harmless if: always() cleanup no-op when the marker could not be written.
- A separate local OS-level probe run as nobody returned exit 1, left the file at zero bytes, and emitted Permission denied.
- The first code commit 2814d6be9eede293bc4c4a14314c2940014221ef failed QIMA CI run 42461613424 because the inserted test block was malformed (Bash syntax error at line 418). Corrected code commit: 813bd1601e043e422e494bb890505dbf963bafba. At this documentation revision, its QIMA CI and CodeQL checks were in progress; no final pass is claimed.
- This is a regression test of an OS-level permission denial in disposable CI, not a finding of a production filesystem problem or security vulnerability. No production Supabase migration/data/schema/RLS/grant/secret or persistent PostgreSQL configuration was touched.


### QA278 — final CI and CodeQL evidence (2026-11-08)

- Final code/documentation HEAD at this validation: b2c5d41006391ee92e88118825919eda68cd86ab.
- QIMA CI #996 ([run 42462176743](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462176743)) — **SUCCESS**, both jobs completed. The PostgreSQL integration job passed the prepared-transaction setup regression containing QA278, the QA266 real prepared-transaction cleanup blocker, and QA267's real RESET/restart/restoration to baseline 0 with no residual transaction or disposable database.
- The browser/build job passed npm ci, npm audit enforcement, TypeScript, Next.js production build, Chromium and **322/322 Playwright tests (8.3s)**. npm audit reported zero info, low, moderate, high, critical, and total findings for this run.
- QIMA CodeQL #949 ([run 42462176783](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462176783)) — **SUCCESS**; the check reports no new alerts in code changed by this pull request.
- QA278 uses an actual mode-0444 GITHUB_OUTPUT file and runs as an unprivileged account (or runuser -u nobody when the harness is root). The test requires Permission denied, a zero-byte output file, the exact pre-mutation docker-ps / psql-show event sequence, no ALTER SYSTEM SET or restart, and a no-op always() cleanup.
- Correction history: QIMA CI #994 failed on an initial malformed test insertion; QIMA CI #995 then failed because the mock SHOW counter was pre-created empty and read exited under set -e. The final code initializes that counter to 0. Both earlier failures are retained as history; only CI #996 is reported as the final passing validation.
- Vercel combined status on this HEAD remains **FAILURE** due to the Preview build rate limit (upgradeToPro=build-rate-limit); this is separate from the successful GitHub Actions build. No Preview READY or Production deployment is claimed.
- This is a filesystem permission regression in disposable CI, not a finding of a production filesystem problem or vulnerability. No Supabase production migration/data/schema/RLS/grant/secret or persistent PostgreSQL configuration was touched.



### QA279 — partial GITHUB_OUTPUT marker write (2026-11-08)

- **Code commit:** `f424bf2652daa1ae6e25744cf518d406b4123756` adds a deterministic partial-write regression to `tests/sql/test-prepared-transactions-config-setup.sh`.
- **Injected behavior:** a temporary `BASH_ENV` hook writes only `baseline=0\n` to the real temporary output file, records `marker-write-partial`, then returns exit 53 before `restore_required=true` can be persisted.
- **Assertions:** setup exits non-zero, the output contains exactly the partial baseline line, the restoration marker is absent, and the event sequence is exactly `docker-ps`, `psql-show-1`, `marker-write-partial`. No `ALTER SYSTEM SET` or PostgreSQL restart is allowed.
- **Cleanup:** the test passes `RESTORE_REQUIRED=""` and `BASELINE_MAX_PREPARED_TRANSACTIONS="0"` to the restoration script, confirming that a partial baseline output without the intent marker produces a no-op and makes no Docker/PostgreSQL calls.
- **Interpretation:** this is a deterministic shell-hook regression that exercises a real partial write to a temporary file followed by an injected command failure. It does not simulate disk-full/ENOSPC or establish a production filesystem fault or vulnerability.
- **Code commit validation:** QIMA CI #1000 ([run 42462932529](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462932529)) — **SUCCESS**, both jobs completed on code commit `f424bf2652daa1ae6e25744cf518d406b4123756`. The PostgreSQL job's prepared-transaction setup regression passed with QA279; the job also completed the real QA267 RESET/restart/restoration to baseline `0` with no residual QA266 prepared transaction or disposable database. The browser/build job passed npm installation, npm audit enforcement at the high threshold, TypeScript, Next.js production build, Chromium installation, and **322/322 Playwright tests (6.9s)**. QIMA CodeQL #953 ([run 42462932693](https://github.com/meridane/QimaTrade-MVP/actions/runs/42462932693)) — **SUCCESS**.
- **Intermediate documentation-head checks:** QIMA CI #1001 (run 42463036361) on `f15b1e5d2b3b36775a8098d280f1ac4a1722d87f` was **CANCELLED** after a newer documentation commit advanced the PR head; its PostgreSQL job did not complete and is not counted as validation. QIMA CodeQL #954 (run 42463036548) on that intermediate HEAD completed **SUCCESS**.
- **Vercel:** the combined status on the code HEAD remains **FAILURE** due to the Preview build rate limit (`upgradeToPro=build-rate-limit`); this is separate from the successful GitHub Actions build. No Preview READY or Production deployment is claimed.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.


### QA279 — final register-head validation (2026-11-08)

- **Validated HEAD:** `e4897a4d5d0ea6647a65ef1c6cea7873cca5c18c`, containing the QA279 regression and all three register updates.
- **QIMA CI #1002** ([run 42463101344](https://github.com/meridane/QimaTrade-MVP/actions/runs/42463101344)) — **SUCCESS**, both jobs completed. The PostgreSQL job's setup regression passed and logged the QA279 partial-`GITHUB_OUTPUT` write case, followed by real QA267 `ALTER SYSTEM RESET`, PostgreSQL restart, return to baseline `0`, and absence of the QA266 prepared transaction and disposable database. The browser/build job passed npm installation, npm audit enforcement at the high threshold, TypeScript, Next.js production build, Chromium, and **322/322 Playwright tests (6.8s)**.
- **QIMA CodeQL #955** ([run 42463101442](https://github.com/meridane/QimaTrade-MVP/actions/runs/42463101442)) — **SUCCESS**.
- The combined Vercel status remains **FAILURE** due to the Preview build rate limit (`upgradeToPro=build-rate-limit`); this is separate from the successful GitHub Actions build. No Preview READY or Production deployment is claimed.
- This is a deterministic partial-write regression in disposable CI, not evidence of a production filesystem fault or vulnerability. No Supabase production data, migration, schema, RLS policy, grant, secret, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection setting was changed.


## QA280 — Missing restoration baseline guard (2026-11-08)

- **Tested artifact:** `tests/sql/test-prepared-transactions-config-restore.sh`; no migration file or remote Supabase object was changed.
- **Input:** `RESTORE_REQUIRED=true`, a loopback-only `qima_test` URL, and `BASELINE_MAX_PREPARED_TRANSACTIONS` unset.
- **Expected/observed:** restoration exits `2` with the baseline validation diagnostic before invoking Docker, `pg_isready`, or `psql`; the event log stays empty and no RESET/restart/success claim occurs. The restoration script's existing baseline guard was sufficient, so this QA item adds regression coverage only.
- **Attempt history:** CI #1004 PostgreSQL job failed because the first test draft emitted doubled shell continuation backslashes (`env: '\\': No such file or directory`); the companion browser job was cancelled when the correction was pushed. This was a harness syntax error. Corrected commit: `f44f7006d0e737c4d6a64192f984c22b68e320c5`.
- **Final evidence:** QIMA CI #1005 ([42470336296](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470336296)) SUCCESS, including PostgreSQL integration and browser/build jobs; QIMA CodeQL #958 ([42470336308](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470336308)) SUCCESS. PostgreSQL logs confirm the missing-baseline regression and setup regression passed, followed by real disposable PostgreSQL 16 restoration to baseline `0` with no QA266 residue. Browser/build logs confirm npm audit had **0 total findings**, TypeScript and Next.js build passed, and **322/322 Playwright tests (6.7s)** passed. Vercel status on this code HEAD was SUCCESS.
- **Safety boundary:** this is a controlled CI regression, not a production vulnerability finding. No Supabase production data or migrations, schema, RLS, grants, secrets, or persistent database settings were touched; no Production deployment, PR merge, force-push, or branch-protection change occurred.


### QA280 documentation-head verification — CI #1006 / CodeQL #959

The QA280 entry above was present on PR HEAD `abd955099715a051259cd8ffc7ced2292da76cd4` and was revalidated after the register update:
- QIMA CI #1006 ([42470593151](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470593151)) — SUCCESS; PostgreSQL integration and browser/build jobs both passed. The restoration regression reported the missing-baseline guard; the real disposable PostgreSQL 16 QA267 restore returned to baseline `0` with no QA266 transaction or temporary database remaining. npm audit reported 0 total findings; TypeScript, Next.js build and **322/322 Playwright tests (10.1s)** passed.
- QIMA CodeQL #959 ([42470593109](https://github.com/meridane/QimaTrade-MVP/actions/runs/42470593109)) — SUCCESS.
- Vercel status for this documentation HEAD — SUCCESS. This is not a Production deployment claim.

## QA281 — Noncanonical restoration baseline matrix (2026-11-08)

- **Scope:** `tests/sql/test-prepared-transactions-config-restore.sh`; no production migration or database object changed.
- **Inputs:** empty baseline, `10`, `00`, `-1`, leading-space ` 0`, and trailing-space `0 `. Each is rejected with exit `2` before Docker, readiness, or database commands; the event log remains empty and no restoration-success message appears. Exact baseline `0` remains accepted by the successful path.
- **Validation:** QIMA CI #1008 ([42473664227](https://github.com/meridane/QimaTrade-MVP/actions/runs/42473664227)) SUCCESS; PostgreSQL regression log confirms QA281 and the real PostgreSQL 16 QA267 RESET/restart returned to `0` with no QA266 transaction or disposable database. Browser/build checks passed, including **322/322 Playwright tests (7.8s)** and npm audit enforcement at the high threshold. QIMA CodeQL #961 ([42473664222](https://github.com/meridane/QimaTrade-MVP/actions/runs/42473664222)) SUCCESS. Vercel status for the code HEAD SUCCESS; no Production deployment is claimed.
- **Safety boundary:** this is deterministic CI coverage, not a production vulnerability finding. No Supabase production data, migrations, schema, RLS, grants, secrets, or persistent PostgreSQL settings were modified; no Production deployment, PR merge, force-push, or branch-protection change occurred.

## QA281 documentation-head verification — CI #1009 / CodeQL #962 (2026-11-08)

The QA281 matrix and all three register updates were revalidated on PR HEAD `9e45637dbc8df5ac2202baf8cd0e1dfc437e8e7c`:
- QIMA CI #1009 ([42473845549](https://github.com/meridane/QimaTrade-MVP/actions/runs/42473845549)) — **SUCCESS**; PostgreSQL and browser/build jobs passed. The PostgreSQL log confirms QA281 and real PostgreSQL 16 QA267 restoration to baseline `0` with no residual QA266 transaction or temporary database. npm audit enforcement at the high threshold, TypeScript, Next.js build, and **322/322 Playwright tests (9.4s)** passed.
- QIMA CodeQL #962 ([42473845560](https://github.com/meridane/QimaTrade-MVP/actions/runs/42473845560)) — **SUCCESS**.
- Vercel combined status — **FAILURE** due to Preview build rate limit (`upgradeToPro=build-rate-limit`); this is not a GitHub Actions build failure and no Production deployment is claimed.
- No Supabase production data, migrations, schema, RLS, grants, secrets, or persistent PostgreSQL configuration were modified.


## QA282 — Exact RESTORE_REQUIRED marker contract (8 November 2026)

- **Scope:** regression-only addition to `tests/sql/test-prepared-transactions-config-restore.sh`; no restoration script, application code, migration, or CI workflow changed.
- **Matrix:** `RESTORE_REQUIRED` unset, empty, `false`, `1`, and uppercase `TRUE`. Every case exits 0 as a no-op, emits the existing “configuration was not changed; restoration is not required” message, leaves the external-command event log empty, and does not emit the QA267 success message. Each case deliberately supplies a remote URL and invalid baseline, proving the exact-marker gate runs before those validations and before Docker, readiness, or database commands. The existing successful exact-`true` plus baseline-`0` case remains the positive path.
- **Code commit:** `41eae5e0104bb4935011233e91a4e3f42d54c0c6`.
- **QIMA CI #1011** ([run 42475182013](https://github.com/meridane/QimaTrade-MVP/actions/runs/42475182013)) — **SUCCESS**. PostgreSQL integration job and browser/build job both completed successfully, including the restoration guard suite, CREATE_OFFER integration/concurrency checks, RLS regressions, dependency audit enforcement, TypeScript, Next.js production build, Chromium, and Playwright smoke tests.
- **QIMA CodeQL #964** ([run 42475182036](https://github.com/meridane/QimaTrade-MVP/actions/runs/42475182036)) — **SUCCESS**.
- **Vercel commit status:** **SUCCESS** (“Deployment has completed”) for the code commit. This is a Preview/check status only; no Production deployment is claimed.
- **Classification and safety:** deterministic environment-marker regression coverage, not evidence of a production incident or vulnerability. No Supabase production data, migration, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was touched; no Production deployment, PR merge, force-push, or branch-protection change occurred.


### QA282 documentation-head verification — CI #1012 / CodeQL #965 (8 November 2026)

- **Validated PR HEAD:** `17e3596bad28482392b083bf46a070bf9671f3c9`, containing the QA282 regression and all three register updates.
- **QIMA CI #1012** ([run 42475382591](https://github.com/meridane/QimaTrade-MVP/actions/runs/42475382591)) — **SUCCESS**. Both jobs completed: the PostgreSQL integration job passed CREATE_OFFER/concurrency, legacy messages RLS and cleanup regressions, prepared-transaction setup/restoration guards, and participant self-enrollment RLS; the browser/build job passed dependency installation and audit enforcement, TypeScript, Next.js production build, Chromium installation, and browser smoke tests.
- **QIMA CodeQL #965** ([run 42475382387](https://github.com/meridane/QimaTrade-MVP/actions/runs/42475382387)) — **SUCCESS**; no new alerts in code changed by this pull request.
- **Vercel status on this documentation HEAD:** **FAILURE** because the Preview deployment quota returned `upgradeToPro=build-rate-limit`. This is separate from the successful GitHub Actions build. No Preview READY or Production deployment is claimed.
- **Safety:** documentation-head verification only; the code tested by CI #1011 is unchanged. No Supabase production data, migrations, schema, RLS policy, grants, secrets, or persistent PostgreSQL configuration were modified; no Production deployment, PR merge, force-push, or branch-protection change occurred.


### QA283 — exact RESTORE_REQUIRED marker rejects whitespace, case, and newline variants

- **Date:** 8 November 2026 (KST).
- **Test file:** `tests/sql/test-prepared-transactions-config-restore.sh`.
- **Code commit:** `882f8adea7d4c9fda0dfdc942e55382b4caf7af0`.
- **Scenario:** the restoration guard receives leading/trailing spaces, mixed-case `True`, leading/trailing line feeds, and leading/trailing tabs in `RESTORE_REQUIRED`.
- **Expected/observed:** all seven noncanonical values exit successfully as no-ops, before validating the deliberately remote `DATABASE_URL` or invalid baseline. The mock external-command event log remains empty; Docker, `pg_isready`, and `psql` are not invoked; no `QA267 passed` success message is emitted.
- **Positive control:** the existing exact `RESTORE_REQUIRED=true` path with loopback `qima_test` and captured baseline `0` still executes the full restoration regression.
- **QIMA CI #1014** ([run 42480565945](https://github.com/meridane/QimaTrade-MVP/actions/runs/42480565945)) — **SUCCESS**. Both jobs completed: PostgreSQL integration/cleanup tests and browser/build tests. Playwright reported **322 passed**; TypeScript, Next.js build, Chromium, dependency-audit enforcement, and the prepared-transaction restoration suite passed.
- **QIMA CodeQL #967** ([run 42480565990](https://github.com/meridane/QimaTrade-MVP/actions/runs/42480565990)) — **SUCCESS**.
- **PostgreSQL evidence:** the CI log explicitly reports the QA283 marker matrix passing, then QA266's real prepared-transaction cleanup test and QA267's real `ALTER SYSTEM RESET`/restart restoration to baseline `0` with no residual QA266 transaction or disposable database.
- **Vercel:** Preview status was **PENDING** at the latest check for this code commit. No Preview READY or Production deployment is claimed.
- **Classification:** deterministic environment-variable contract regression coverage, not evidence of a production incident or confirmed vulnerability.
- **Safety:** no Supabase production data, migration, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was changed; no Production deployment, PR merge, force-push, or branch-protection change occurred.


### QA284 — CREATE_OFFER optional business fields route-to-RPC regression (8 November 2026)

- Added one route-contract regression for explicit and omitted/null values of `conditions`, `market`, `geography`, and `documentationStatus`.
- Verified each field in both the action payload (`p_input`) and the top-level SQL RPC parameter (`p_conditions`, `p_market`, `p_geography`, `p_documentation_status`). Explicit strings are preserved; omitted and explicit-null values normalize to identical explicit-null properties.
- Code commit: `b7e2e62e2f82fa5b57c8911fd41091f4517ab82c`.
- QIMA CI #1016 ([run 42486166041](https://github.com/meridane/QimaTrade-MVP/actions/runs/42486166041)): **SUCCESS**; 323/323 Playwright tests, TypeScript, Next.js build, dependency-audit enforcement, CREATE_OFFER PostgreSQL integration/concurrency, RLS and cleanup tests passed. The CI log explicitly confirms the new route-contract test.
- QIMA CodeQL #969 ([run 42486166033](https://github.com/meridane/QimaTrade-MVP/actions/runs/42486166033)): **SUCCESS**.
- PostgreSQL QA266/QA267: real prepared-transaction blocking and rollback, followed by RESET/restart to baseline 0 with no residual transaction or disposable database.
- Vercel combined status on the code commit: **SUCCESS** (Preview status only; no Production deployment).
- Classification: regression-only verification of an existing contract; no production incident or vulnerability is inferred.
- Safety: no Supabase production data, migrations, schema, RLS policy, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA285 — empty optional CREATE_OFFER values and idempotency-hash distinction (8 November 2026)

- Route test commit: `682ef4d43616416c863c653ebe88e95d38aedd8d`; SQL runtime test commit: `91cc390cf3dd129f683f9db1cfef3fd6e503f0f5`.
- The route preserves empty `conditions`, `market`, `geography`, and `documentationStatus` strings in `p_input` and top-level RPC arguments. Explicit null remains null and is not normalized to an empty string.
- The PostgreSQL runtime test reuses a completed key with empty `p_market`, `p_conditions`, and `p_geography` against SQL-NULL baselines and expects `IDEMPOTENCY_KEY_REUSE`. Existing coverage already checks `p_documentation_status = ''` versus NULL.
- QIMA CI #1018 ([run 42490794951](https://github.com/meridane/QimaTrade-MVP/actions/runs/42490794951)): **SUCCESS**; **324/324 Playwright tests**, TypeScript, Next.js build, dependency-audit enforcement, CREATE_OFFER PostgreSQL integration/concurrency, RLS and cleanup checks passed. The browser log explicitly records the QA285 route test.
- QIMA CodeQL #971 ([run 42490795034](https://github.com/meridane/QimaTrade-MVP/actions/runs/42490795034)): **SUCCESS**.
- PostgreSQL 16 disposable integration: updated runtime SQL passed; prepared-transaction QA266 and RESET/restart QA267 passed, returning to baseline 0 with no residual transaction or disposable database.
- Vercel code-commit status: **SUCCESS** (Preview only; no Production deployment).
- Classification: contract regression coverage, not a confirmed production vulnerability. No Supabase production data, migrations, schema, RLS policy, grants, secrets, or persistent configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA285 — final HEAD CI/CodeQL revalidation (8 November 2026)

- Final documentation HEAD tested: `ad66b98c6a56a667977873e8944d57027d05f43d`; QA285 route and SQL test commits remained `682ef4d` and `91cc390`.
- QIMA CI #1019 ([run 42491022728](https://github.com/meridane/QimaTrade-MVP/actions/runs/42491022728)): **SUCCESS**; 324/324 Playwright tests, TypeScript, Next.js build, audit enforcement, CREATE_OFFER PostgreSQL integration/concurrency, RLS, cleanup, QA266 and QA267 passed.
- QIMA CodeQL #972 ([run 42491022811](https://github.com/meridane/QimaTrade-MVP/actions/runs/42491022811)): **SUCCESS**.
- Vercel Preview: code commit **SUCCESS**; documentation HEAD rate-limited by `upgradeToPro=build-rate-limit`. No Production deployment or application build failure is inferred from this quota response.


### QA286 — CREATE_OFFER empty optional-string replay (9 November 2026)

- Disposable PostgreSQL 16 regression in tests/sql/create-offer-runtime.sql, code commit 485d69454a802b3e71804c841fdc294f76b81ba1.
- Four empty optional strings are included in the request input and RPC parameters. The test checks the effective request hash and persisted offer values, then confirms an exact replay returns the same completed result with exactly one idempotency key, action execution, offer, and ACTION_SUCCEEDED event.
- A same-key retry changing conditions from empty text to JSONB null / SQL NULL is rejected with IDEMPOTENCY_KEY_REUSE; no duplicate rows are added.
- QIMA CI #1021 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42493888884) — **SUCCESS**; the PostgreSQL log explicitly records QA286 passing, and the browser job passed 324/324 Playwright tests. QIMA CodeQL #974 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42493888899) — **SUCCESS**.
- QA266/QA267 real disposable PostgreSQL checks passed; the prepared-transaction configuration returned to baseline 0 and no disposable resource remained.
- No Supabase production data, migration, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was modified. The existing migrations were executed only against the disposable CI database; no Production deployment or PR merge occurred.


### QA286 — final PR HEAD CI/CodeQL revalidation (9 November 2026)

- Final documentation HEAD tested: 08403ed26d70f327f7985db8bc6fe19cb262e7df; QA286 SQL code remains unchanged in commit 485d69454a802b3e71804c841fdc294f76b81ba1.
- QIMA CI #1022 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42494130242): **SUCCESS**; PostgreSQL logs explicitly record QA286 exact replay and empty-to-NULL rejection, 324/324 Playwright tests passed, and build/typecheck/audit/RLS/cleanup plus QA266/QA267 passed.
- QIMA CodeQL #975 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42494130392): **SUCCESS**.
- Vercel: QA286 code commit Preview **SUCCESS**; final documentation HEAD returned upgradeToPro=build-rate-limit. No Production deployment or application build failure is inferred from this quota response.



### QA287 — concurrent first-time CREATE_OFFER requests with four empty optional strings (9 November 2026)

- Test location: `tests/sql/run-create-offer-integration.sh`; code commit: `1c1b40c82b41844e060de5bd529124f4381806a5`.
- Two independent PostgreSQL sessions submit the same first-time CREATE_OFFER request for the same tenant and idempotency key. Both `p_input` and RPC parameters preserve `conditions`, `market`, `geography`, and `documentationStatus` as empty strings.
- The integration runner observes the expected advisory-lock state `2|1|1|1`: two sessions on one tenant/key lock, one granted while inside the fixture delay and one waiting on that same lock.
- Both concurrent calls succeed and return byte-for-byte identical JSONB output. The output also matches the single persisted idempotency result.
- The PostgreSQL assertions verify the exact effective-request hash, exactly one completed idempotency row, one completed action execution preserving the four empty strings, one offer preserving all four empty columns, and one `ACTION_SUCCEEDED` event matching the execution result.
- QIMA CI #1025 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42500395727) — **SUCCESS**. The PostgreSQL job log explicitly records QA287 passing; the browser job passed **324/324 Playwright tests**. Dependency installation/audit enforcement, TypeScript, Next.js production build, CREATE_OFFER PostgreSQL integration/concurrency, RLS, cleanup, and QA266/QA267 passed.
- QIMA CodeQL #977 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42500395719) — **SUCCESS**.
- Vercel status on the QA287 code commit: **SUCCESS** (Preview only). No Production deployment.
- Classification: regression coverage of the existing same-tenant idempotency/advisory-lock contract; this synthetic fixture is not evidence of a production incident or confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA288 — concurrent same-key CREATE_OFFER requests with different effective payloads (9 November 2026)

- Test location: \`tests/sql/run-create-offer-integration.sh\`; code commit: \`f567d500fb89935f03cc5c9a91d32d81dd74281c\`.
- On the disposable PostgreSQL 16 integration database, session A starts the first-time request with \`conditions = ''\` and the other three optional fields (\`market\`, \`geography\`, \`documentationStatus\`) also empty. The test waits until A is observed holding the tenant/key transaction-scoped exclusive advisory lock during the fixture's \`pg_sleep\` before it starts session B.
- Session B uses the same tenant, idempotency key, actor, demand, product, name, quantity, price, currency, and remaining optional values. Its only effective change is \`conditions = NULL\` in the RPC and JSONB \`p_input\` (instead of empty text).
- The observer records \`2|1|1|1\`: two named active sessions, A granted and sleeping, B waiting on the same advisory lock. This establishes the intended concurrent ordering rather than relying on simultaneous process launch alone.
- Session A exits successfully. Session B exits nonzero and its PostgreSQL error log contains exactly the expected domain code \`IDEMPOTENCY_KEY_REUSE\`.
- The successful A response matches the single persisted idempotency result. SQL assertions verify one completed idempotency row with the first request's effective-parameter hash, one completed action execution preserving the original empty-string input, one offer preserving the original empty optional columns, and one \`ACTION_SUCCEEDED\` event matching the stored execution result. The rejected waiter creates no second offer, execution, idempotency row, or event.
- QIMA CI #1027 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42505426391): **SUCCESS**. The PostgreSQL integration/concurrency job passed, including the explicit QA288 log line; the browser job passed **324/324 Playwright tests**. npm installation and audit enforcement, TypeScript, Next.js build, Chromium, RLS, cleanup, and prepared-transaction QA266/QA267 passed.
- QIMA CodeQL #979 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42505426427): **SUCCESS**.
- Vercel combined status on code commit \`f567d500fb89935f03cc5c9a91d32d81dd74281c\`: **SUCCESS** (Preview only; no Production deployment).
- Classification: deterministic concurrency regression coverage of the existing same-tenant idempotency/advisory-lock contract. The expected \`IDEMPOTENCY_KEY_REUSE\` SQL error is the negative assertion under test, not a failed CI run or evidence of a production incident/confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA289 — CREATE_OFFER public failed-status and unsupported-status response contract (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `888150afcf2fe27e80ab67e3dbdbaee1616f194f`.
- Strengthened the existing failed-result route test to assert the complete public response: HTTP 409; exact `executionId`, `status: "failed"`, `objectId`, and nested result; no authentication challenge; and exactly one `execute_create_offer_v1` RPC call.
- Added route-level negative coverage for unsupported engine result statuses `pending`, `running`, `completed`, and the empty string. Each is rejected by the action-result contract and mapped to the generic HTTP 500 body `{"error":"ACTION_FAILED"}`; the internal `ACTION_RESULT_INVALID` code is not exposed, and the execution RPC is observed exactly once.
- The route and action-engine implementation were not changed. The existing contract already maps a valid `failed` result to HTTP 409 and the engine accepts only `succeeded` or `failed` as terminal public results; this QA entry records regression coverage, not a newly discovered production defect.
- QIMA CI #1029 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42511298360): **SUCCESS**. The browser job passed **325/325 Playwright tests**, including the strengthened failed-result test and the new unsupported-status matrix. Dependency installation and npm audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction QA266/QA267 all passed.
- QIMA CodeQL #981 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42511298369): **SUCCESS**.
- Vercel status on code commit `888150afcf2fe27e80ab67e3dbdbaee1616f194f`: **SUCCESS** (Preview only; no Production deployment).
- Classification: API contract regression coverage and fail-closed validation of unsupported action statuses. The synthetic invalid-status fixtures do not establish a production incident or confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.



### QA290 — CREATE_OFFER succeeded public response contract (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `9fb9df7da041767dae86bc037c1ea0ec2be40b06`.
- Added an explicit positive route regression for an execution RPC result with `status: "succeeded"`. It asserts HTTP 200 and the complete exact JSON response: `executionId`, `status`, `objectId`, and nested `result.offerId`.
- The test also asserts that no `WWW-Authenticate` challenge is returned, exactly one `execute_create_offer_v1` RPC is called, and the request sequence is Auth, profile, membership, action-definition lookup, then execution RPC.
- No route, action-engine, SQL, or migration implementation was changed; this locks down the existing success contract complementary to QA289's failed HTTP 409 and unsupported-status HTTP 500 cases.
- QIMA CI #1031 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42516121757): **SUCCESS**. The browser job passed **326/326 Playwright tests**, including the new QA290 test. npm installation, dependency audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, and browser suite passed.
- The PostgreSQL integration job in CI #1031 also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction QA266/QA267. The QA290 change itself is route-test-only and adds no SQL fixture.
- QIMA CodeQL #983 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42516122123): **SUCCESS**; CodeQL analysis and upload completed successfully.
- Vercel combined status on code commit `9fb9df7da041767dae86bc037c1ea0ec2be40b06`: **SUCCESS** (Preview status only; no Production deployment).
- Classification: positive API contract regression coverage. The mocked route fixture is not evidence of a production incident or confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.



### QA291 — CREATE_OFFER malformed successful RPC result at the HTTP boundary (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `158f25336f8db32fd5aec85809afa18db96a23c2`.
- Extended the route fixture with a test-only RPC result override, removed from the submitted request body before dispatch. Added eight malformed RPC result cases: null result, missing/blank/non-string `executionId`, non-string `objectId`, and null/array/primitive nested `result` payloads.
- For every malformed result, the real Next.js `POST` route is exercised through the mocked Supabase Auth/REST boundary. The route must return exactly HTTP 500 with `{"error":"ACTION_FAILED"}`, omit the internal `ACTION_RESULT_INVALID` code and a private sentinel, emit no authentication challenge, and call `execute_create_offer_v1` exactly once after the expected Auth/profile/membership/action-definition sequence.
- Existing engine unit tests already cover the normalization rules; QA291 adds route-boundary regression coverage. No application route, engine, SQL, migration, or production configuration was changed.
- QIMA CI #1033 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42521070588): **SUCCESS**. Browser job passed **327/327 Playwright tests**, including QA291. npm ci, npm audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, and browser tests passed. The isolated PostgreSQL integration job also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction QA266/QA267.
- QIMA CodeQL #985 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42521070573): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel status on code commit `158f25336f8db32fd5aec85809afa18db96a23c2`: **SUCCESS** (Preview only; no Production deployment).
- Vercel status on documentation-only HEAD `48d04ce0f788fdc7c680106612a0023d4437b9e9`: **FAILURE** (`upgradeToPro=build-rate-limit`). The Preview quota limit prevented a new Preview for this docs-only commit; QIMA CI and CodeQL were not re-triggered because both workflows exclude `docs/**`. The code commit's Preview remains **SUCCESS**; no Production deployment.
- Classification: synthetic route-contract regression coverage. The malformed RPC fixtures do not establish a production incident or confirmed vulnerability.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.

### QA292 — CREATE_OFFER action-definition contract at the HTTP boundary (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `678d397d27ab4a67785a3f9c76f689d43a361bd3`.
- Widened only the route-test helper's action-definition fixture type to `unknown`, allowing malformed JSON RPC responses to be represented without weakening application types.
- Expanded the existing route-level definition gate from 3 to 12 cases: missing definition, draft, retired, wrong action key, mismatched numeric version, string version, missing action key, missing version, missing status, unsupported status, empty RPC row set, and malformed primitive response.
- Every case must return exactly HTTP 400 with `{"error":"ACTION_NOT_PUBLISHED"}`, no `WWW-Authenticate` challenge, and no internal/diagnostic details. The test verifies exactly one authenticated `get_action_definition_v1` call with `p_action_key = CREATE_OFFER` and `p_version = 1`, the complete request order ending at definition lookup, and zero `execute_create_offer_v1` calls.
- No route, runtime, action-engine, SQL, migration, or production configuration was changed. Existing engine validation remains the implementation; QA292 locks its malformed/mismatched definition behavior at the HTTP boundary. These JSON fixtures are synthetic regression cases, not evidence of a production incident or confirmed vulnerability.
- QIMA CI #1036 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42528402681): **SUCCESS**. Browser job passed **327/327 Playwright tests**, including the 12-case QA292 definition matrix. npm ci, npm audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, and browser tests passed. The isolated PostgreSQL integration job also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction QA266/QA267.
- QIMA CodeQL #988 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42528402703): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel status on code commit `678d397d27ab4a67785a3f9c76f689d43a361bd3`: **SUCCESS** (Preview only; no Production deployment).
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.
- Final HEAD verification: QIMA CI #1037 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42528616794): **SUCCESS** on documentation HEAD `fce7d05a8f6172b09b90edfbd0285cf65f3b7d5e`; browser job passed **327/327 Playwright tests**, including QA292, and the PostgreSQL integration/RLS/cleanup/prepared-transaction jobs passed. QIMA CodeQL #989 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42528617212): **SUCCESS**. Vercel on that HEAD: **SUCCESS** (Preview only; no Production deployment).

### QA293 — CREATE_OFFER accepts a published action definition returned as a PostgREST row array (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `ab616742bb135454e727aef5985551946692231b`.
- Added a positive route-level regression in which the mocked `get_action_definition_v1` RPC returns a one-row PostgREST array: `[{ action_key: "CREATE_OFFER", version: 1, status: "published" }]`. This covers the row-array representation handled by `lib/actions/runtime.ts` (`Array.isArray(data) ? data[0] : data`) without changing runtime behavior.
- The real Next.js `POST` route must accept the first row and return HTTP 200 with the exact `executionId`, `status: "succeeded"`, `objectId`, and nested `result.offerId`. Assertions also verify no `WWW-Authenticate` challenge, the Auth/profile/membership/definition/execution request order, exactly one authenticated `get_action_definition_v1` call with `p_action_key = CREATE_OFFER` and `p_version = 1`, and exactly one `execute_create_offer_v1` call.
- The test-only fixture uses a one-row array consistent with a table-returning PostgREST RPC. No route, runtime, action-engine, SQL, migration, or production configuration was changed. QA293 is synthetic route-contract regression coverage, not evidence of a production incident or confirmed vulnerability.
- QIMA CI #1039 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42531695458): **SUCCESS**. Browser job passed **328/328 Playwright tests**, including QA293. npm ci, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, and browser tests passed. The isolated PostgreSQL job also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, active-session cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #991 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42531695658): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel status on code commit `ab616742bb135454e727aef5985551946692231b`: **SUCCESS** (Preview only; no Production deployment).
- QIMA CI #1040 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42531880610) and QIMA CodeQL #992 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42531880603) were also triggered on documentation HEAD `60051878b97ea5aaf497cf54e69fc457de5d9bdf`. Although both workflows declare `paths-ignore: docs/**`, GitHub evaluates the `pull_request` path filter against the aggregate PR diff, which still contains non-documentation changes; the documentation-only commit therefore did trigger both workflows. CI #1040 completed **SUCCESS** with **328/328 Playwright tests** and successful PostgreSQL integration/RLS/cleanup/prepared-transaction jobs; CodeQL #992 completed **SUCCESS**. The earlier code-commit checks #1039/#991 also remain successful.
- Vercel status on documentation HEAD `60051878b97ea5aaf497cf54e69fc457de5d9bdf`: **FAILURE** (`upgradeToPro=build-rate-limit`; deployment rate limited). The QA293 code commit's Preview remains **SUCCESS**; no Production deployment.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA294 — reject malformed PostgREST action-definition row arrays (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `1c60b03340f2ed1c9eec9c204d54d3347bbe1f03`.
- Extended the existing CREATE_OFFER invalid-definition matrix with two row-array cases: `[null]` and a one-row array whose first row has `action_key = PUBLISH_PRODUCT_REQUEST` instead of `CREATE_OFFER`.
- The first case exercises the runtime's PostgREST array normalization when its selected first row is null. The second exercises the engine's action-key/version contract after the runtime maps the first row. Both must be rejected before the CREATE_OFFER handler runs.
- For both cases, the route must return exactly HTTP 400 and `{"error":"ACTION_NOT_PUBLISHED"}`, omit `WWW-Authenticate`, make exactly one authenticated `get_action_definition_v1` call with `p_action_key = CREATE_OFFER` and `p_version = 1`, stop the request sequence at definition lookup, and make zero `execute_create_offer_v1` calls. The existing empty-array and malformed-definition cases remain in the same matrix.
- No route, runtime, action-engine, SQL, migration, or production configuration was changed. QA294 adds synthetic route-contract regression fixtures; these tests are not evidence of a production incident or confirmed vulnerability.
- QIMA CI #1042 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42538658786): **SUCCESS**. Browser job passed **328/328 Playwright tests**, including the QA294 matrix cases. npm ci, npm audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, and browser tests passed. The isolated PostgreSQL integration job also completed **SUCCESS**, including CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, active-session cleanup, and prepared-transaction restoration checks.
- QIMA CodeQL #994 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42538658800): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel on code commit `1c60b03340f2ed1c9eec9c204d54d3347bbe1f03`: **SUCCESS** (Preview only; no Production deployment).
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA294 final PR-head validation (9 November 2026)

- Final documentation HEAD `5b55f749e4fceb8727d543cb9a8ef7974da9b9bd` was revalidated after all three QA294 register updates.
- QIMA CI #1043 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42538857184): **SUCCESS**; browser job passed **328/328 Playwright tests**. npm ci, npm audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, browser tests, and the isolated PostgreSQL integration/RLS/cleanup/prepared-transaction jobs all completed successfully.
- QIMA CodeQL #995 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42538857062): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel on final documentation HEAD `5b55f749e4fceb8727d543cb9a8ef7974da9b9bd`: **SUCCESS** (Preview only; no Production deployment).
- The CI log contains expected negative-test PostgreSQL messages such as `IDEMPOTENCY_KEY_REUSE`, a deliberately missing relation, and prepared-transaction cleanup guards; the corresponding regression jobs completed **SUCCESS**. These are expected test assertions, not observed production incidents.


### QA295 — no fall-through from an invalid first PostgREST row (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `dab975ab38decc74102d4f4390d07a52a0e0d471`.
- Extended the existing invalid action-definition matrix with two multi-row fixtures: `[null, valid CREATE_OFFER definition]` and `[published PUBLISH_PRODUCT_REQUEST definition, published CREATE_OFFER definition]`.
- The runtime contract selects only the first PostgREST row (`Array.isArray(data) ? data[0] : data)); it must not scan later rows or fall through to a later valid definition when the first row is null or mismatched.
- Both scenarios must return exactly HTTP 400 with `{"error":"ACTION_NOT_PUBLISHED"}`, make one authenticated `get_action_definition_v1` call with `p_action_key = CREATE_OFFER` and `p_version = 1`, stop at definition lookup, and make zero `execute_create_offer_v1` calls. Existing empty-array, null-first-row, wrong-first-row, and valid single-row tests remain in the same contract suite.
- No application runtime, route, action-engine, SQL, migration, production data, or persistent configuration was changed. QA295 adds synthetic route-contract regression fixtures; they are not evidence of a production incident or confirmed vulnerability.
- QIMA CI #1045 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42539491350): **SUCCESS**; Playwright passed **328/328**. npm ci, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, browser tests, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, and prepared-transaction QA266/QA267 restoration all completed successfully.
- QIMA CodeQL #997 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42539491319): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel combined status on code commit `dab975ab38decc74102d4f4390d07a52a0e0d471`: **FAILURE** with `upgradeToPro=build-rate-limit` (Preview rate limit; not a GitHub build failure). No Preview READY status is confirmed for this commit; no Production deployment was performed.
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.


### QA296 — CREATE_OFFER RPC JSON object result contract (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `5e06f5e5f793334f8bea023a3c9f9a5390956c23`.
- Added five malformed execution RPC fixtures: an array containing a valid-looking `succeeded` object, an empty array, a string primitive, a numeric primitive, and a boolean primitive.
- The engine's result normalizer rejects arrays and primitives; the public route must return HTTP 500 with exactly `{"error":"ACTION_FAILED"}`, never expose `ACTION_RESULT_INVALID` or a private sentinel, and make exactly one execution RPC call without retry. The test also verifies the expected request order and that `__rpcResultOverride` is not forwarded in `p_input`.
- The SQL function returns `jsonb`, which can represent non-object JSON values; QA296 verifies the stricter object-shaped application action-result contract at the HTTP boundary. No application implementation or SQL migration was changed.
- These are synthetic route-contract regressions, not evidence of a production incident or confirmed vulnerability. No Supabase production data, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was changed.
- QIMA CI #1047 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42547297646): **SUCCESS**; **328/328 Playwright tests passed**. npm ci, dependency audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium installation, browser tests, isolated CREATE_OFFER PostgreSQL integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, and prepared-transaction QA266/QA267 restoration all passed.
- QIMA CodeQL #999 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42547297568): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed (75/75 TypeScript files, 3/3 GitHub Actions files, 1/1 JavaScript file).
- Vercel on code commit `5e06f5e5f793334f8bea023a3c9f9a5390956c23`: **SUCCESS** (Preview only; no Production deployment).
- Safety: no Supabase production data, migrations, schema, RLS policies, grants, secrets, or persistent PostgreSQL configuration changed; no Production deployment, PR merge, force-push, or branch-protection change.

### QA297 — PostgreSQL CREATE_OFFER JSONB object and persistence contract (9 November 2026)

- Test location: `tests/sql/create-offer-runtime.sql`; final code commit: `169f02cde879df777e485a9928c20954462e6f25`.
- Added real PostgreSQL 16 integration assertions around the first successful `execute_create_offer_v1` call in the disposable CI fixture. The returned JSONB must be an object containing `status`, `executionId`, `objectType`, and `objectId`; status must be `succeeded`, object type `Offer`, and both identifiers must be UUID strings.
- The test resolves the returned execution and offer IDs and checks persistence coherence: `action_executions` is `COMPLETED` with matching `object_id` and `result`; `idempotency_keys` is `COMPLETED` with the same execution ID and result; exactly one `ACTION_SUCCEEDED` event carries the same payload/object ID/object type; and exactly one offer row matches the returned object ID and the fixture's demand, product, provider, quantity, price, and currency.
- An identical retry must replay the same object-shaped JSONB result and leave exactly one execution, idempotency row, offer, and success event for that tenant/key. The public SQL result shape is the actual migration contract (`status`, `executionId`, `objectType`, `objectId`); no nested `result` field was assumed.
- Superseded intermediate edit commit `019b99b46bdd8e6563f3f26d8a640f598815d5a7` triggered QIMA CI #1049: the browser/typecheck job succeeded, but the PostgreSQL job failed on an unterminated SQL string at line 1239. The SQL fixture was rebuilt from its original Git blob and the replacement was corrected in commit `169f02cde879df777e485a9928c20954462e6f25`; the final file is 483,887 characters versus the original 478,015, with the intended QA297 assertions only. The intermediate failure is retained here for an auditable history; it is not the final validation result.
- QIMA CI #1050 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42555110306): **SUCCESS** on final code commit `169f02cde879df777e485a9928c20954462e6f25`. Both jobs succeeded: TypeScript, npm audit enforcement at the configured high threshold, Next.js production build, Chromium, **328/328 Playwright tests**, isolated PostgreSQL CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #1002 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42555110298): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel on final code commit `169f02cde879df777e485a9928c20954462e6f25`: **SUCCESS** (Preview only; no Production deployment).
- The QA297 SQL assertions ran only against the ephemeral PostgreSQL 16 CI fixture. No Supabase production data, migration, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.

### QA298 — CREATE_OFFER idempotency replay across committed PostgreSQL transactions (9 November 2026)

- Test location: `tests/sql/run-create-offer-integration.sh`; code commit: `f7a4f1dc42bc09e9165b95402cabe70f3f04164d`.
- Added an isolated PostgreSQL 16 integration scenario that performs the first successful `execute_create_offer_v1` call in one explicit transaction and commits it, then repeats the identical tenant/key/payload/business parameters from a second independent `psql` process and transaction.
- The runner captures `txid_current()` with each response and requires distinct transaction IDs, proving that the replay occurs after the first transaction commits rather than inside the same transaction. Both responses must be object-shaped JSONB and byte-for-byte equal; the second response must also match the persisted `idempotency_keys.result` value.
- Post-replay assertions verify exactly one completed idempotency row, one completed `action_executions` row, one offer preserving the original demand/product/provider/quantity/price/currency/conditions/market/geography/attributes/documentation values, and one `ACTION_SUCCEEDED` event whose payload/object identifiers match the stored result.
- QIMA CI #1052 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42555882623): **SUCCESS**. Both jobs completed successfully. The browser/typecheck job passed npm ci, dependency audit enforcement at the configured high threshold, TypeScript, Next.js production build, Chromium, and **328/328 Playwright tests**. The PostgreSQL job passed the full isolated CREATE_OFFER integration/concurrency suite including QA298, legacy-message RLS, participant self-enrollment RLS, disposable database cleanup, and prepared-transaction QA266/QA267 restoration. The PostgreSQL job log explicitly reports that QA298 replayed the exact persisted JSONB result from a distinct committed transaction and left one idempotency row, execution, offer, and success event.
- QIMA CodeQL #1004 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42555882639): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `f7a4f1dc42bc09e9165b95402cabe70f3f04164d`: **FAILURE** with `Deployment rate limited — retry in 24 hours` (`api-deployments-free-per-day`). This is a Preview deployment quota limitation, not a GitHub Actions build failure; no Preview READY status is confirmed for this commit.
- The QA298 runner uses only the ephemeral PostgreSQL 16 CI service. No Supabase production data, migration, schema, RLS policy, grant, secret, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change. The test is integration evidence for the fixture contract, not evidence of a production incident or confirmed vulnerability.

- Final documentation-updated PR HEAD `a0ffb73b063a4128d7781d9b123c2ec608ac6ecd` was revalidated by QIMA CI #1053 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42556138662): **SUCCESS**; both jobs passed, including **328/328 Playwright tests** and the PostgreSQL job log's explicit QA298 cross-transaction replay success.
- QIMA CodeQL #1005 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42556138558): **SUCCESS**; 75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned; results uploaded successfully.
- Vercel combined status on documentation-updated PR HEAD `a0ffb73b063a4128d7781d9b123c2ec608ac6ecd`: **FAILURE** with `Deployment rate limited — retry in 24 hours` (`api-deployments-free-per-day`). No Preview READY status is confirmed for this HEAD; this quota status does not change the successful GitHub CI or CodeQL results.

### QA299 — reject a changed CREATE_OFFER payload after a committed success (9 November 2026)

- Test location: `tests/sql/run-create-offer-integration.sh`; code commit: `e7c245bb99bb811815583076d2619888d45b9ae3`.
- Extended the PostgreSQL 16 integration runner immediately after QA298. QA298 first commits a successful CREATE_OFFER request; QA299 then starts a second independent `psql` process/transaction and reuses the same tenant/idempotency key with a changed effective payload (changed `p_input`, price, and conditions).
- The second transaction captures `txid_current()` and must differ from QA298's committed first transaction. The call must fail with `IDEMPOTENCY_KEY_REUSE`; a successful response or a different error fails the test.
- After rejection, the test compares the stored request hash and JSONB result byte-for-byte with their pre-attempt values. SQL assertions require exactly one completed idempotency row, one completed execution with the original input/result, one original offer at EUR 31.50 with the original conditions, and one `ACTION_SUCCEEDED` event matching the original result. No offer at the changed EUR 32.00 price may exist.
- QIMA CI #1055 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42563738733): **SUCCESS**. Both jobs completed successfully. The browser job passed `npm ci`, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, and **328/328 Playwright tests**. The PostgreSQL 16 integration job passed the full CREATE_OFFER suite; its log explicitly reports that QA299 rejected the changed payload in a distinct transaction with `IDEMPOTENCY_KEY_REUSE` and preserved the original hash/result/offer/execution/event without duplicates. Legacy-message RLS, participant self-enrollment RLS, disposable database cleanup, and prepared-transaction QA266/QA267 restoration also passed.
- QIMA CodeQL #1007 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42563738705): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `e7c245bb99bb811815583076d2619888d45b9ae3`: **SUCCESS** (Preview only; no Production deployment).
- QA299 ran only against the ephemeral PostgreSQL 16 CI service. No application code, migration, Supabase production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. This integration regression is not evidence of a production incident or confirmed vulnerability. No Production deployment, PR merge, force-push, or branch-protection change.

- The QA299 register-update PR HEAD `4d51447707ceb16572cf490398792e91772f5cb3` was revalidated by QIMA CI #1056 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42563946777): **SUCCESS**; both jobs passed, including **328/328 Playwright tests**, the PostgreSQL 16 CREATE_OFFER integration suite with QA299, legacy-message RLS, participant self-enrollment RLS, disposable-database cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #1008 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42563946755): **SUCCESS**; 75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned; results uploaded successfully.
- Vercel combined status on register-update PR HEAD `4d51447707ceb16572cf490398792e91772f5cb3`: **SUCCESS** (Preview only; no Production deployment).


### QA300 — keep PostgREST execution-error metadata private at the CREATE_OFFER HTTP boundary (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `09bcb0fb333407dc0bba33cda5df0e4db2c28daf`.
- Extended the route test helper with optional PostgREST `details` and `hint` values, then added one regression covering both a documented domain conflict and an unknown internal RPC failure.
- For an execution RPC error whose message is exactly `IDEMPOTENCY_KEY_REUSE`, the route must return HTTP 400 with exactly `{"error":"IDEMPOTENCY_KEY_REUSE"}`; synthetic private details/hint sentinels and the upstream `XX000` code must not appear in the public body.
- For an unrecognized database error message, the route must return HTTP 500 with exactly `{"error":"ACTION_FAILED"}`; the internal message, private details/hint sentinels, and `XX000` must remain hidden. Both cases verify the normal authenticated request order through the single execution RPC and omit `WWW-Authenticate`.
- QIMA CI #1058 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42564383936): **SUCCESS**. Both jobs completed successfully. The browser job passed `npm ci`, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, and **329/329 Playwright tests**, including QA300. The PostgreSQL 16 integration job passed the full CREATE_OFFER suite including QA299, legacy-message RLS, participant self-enrollment RLS, disposable database cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #1010 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42564383956): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `09bcb0fb333407dc0bba33cda5df0e4db2c28daf`: **SUCCESS** (Preview only; no Production deployment).
- QA300 uses synthetic route-contract fixtures; it does not establish a production incident or confirmed vulnerability. No application route/engine behavior, SQL migration, Supabase production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.

### QA301 — exact matching of public CREATE_OFFER SQL error messages (9 November 2026)

- Test location: `tests/e2e/create-offer-route-contract.spec.ts`; code commit: `7e36a8dbdfe3cdeac57eee8d0100ca524a3da1b2`.
- Added a table-driven route regression for five near-miss variants of the documented `IDEMPOTENCY_KEY_REUSE` message: trailing whitespace, appended private text, lowercase spelling, an `XX000:` prefix, and a private prefix. The existing QA300 exact-message positive control remains the documented HTTP 400 case.
- Each near-miss must be treated as an unknown internal error and return HTTP 500 with exactly `{"error":"ACTION_FAILED"}`. The original message, SQLSTATE text, PostgREST `details`/`hint`, and private sentinels must not appear in the response.
- Each case verifies the authenticated request sequence through exactly one `execute_create_offer_v1` call, the expected Bearer header on every request, and absence of an incorrect `WWW-Authenticate` challenge. No route or engine implementation change was required; this is regression coverage for the existing exact `Set.has(candidate)` allowlist.
- QIMA CI #1060 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42569555067): **SUCCESS**. Both jobs completed successfully. The browser job passed `npm ci`, dependency audit enforcement at the configured `high` threshold, TypeScript, Next.js production build, Chromium installation, and **330/330 Playwright tests**, including QA301. The PostgreSQL 16 job passed the full isolated CREATE_OFFER integration/concurrency suite, legacy-message RLS, participant self-enrollment RLS, disposable database cleanup, and prepared-transaction QA266/QA267 restoration.
- QIMA CodeQL #1012 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42569555068): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `7e36a8dbdfe3cdeac57eee8d0100ca524a3da1b2`: **SUCCESS** (Preview only; no Production deployment).
- QA301 uses synthetic route-contract fixtures. It does not establish a production incident or confirmed vulnerability. No application route/engine behavior, SQL migration, Supabase production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.

### QA302 — isolate action-definition RPC errors from execution-domain allowlisting (9 November 2026)

- Code commit: `cc7a61c410e40356730a58f7d4d719007e1d1486`; files: `lib/actions/runtime.ts` and `tests/e2e/create-offer-route-contract.spec.ts`.
- Source inspection found that `get_action_definition_v1` errors were previously rethrown using their raw `error.message`, while the route applied the same public SQL-domain allowlist to every exception. Therefore, an exact allowlisted message returned by the definition lookup could be classified like an execution-time domain conflict. This is a code-path classification issue; the synthetic regression does not establish that such a response occurred in production.
- The runtime now converts returned RPC errors and rejected definition-lookup calls to the internal `ACTION_DEFINITION_LOOKUP_FAILED` marker. It is intentionally absent from the public allowlist, so the route returns only HTTP 500 with `{"error":"ACTION_FAILED"}`. A valid missing/draft definition still follows the engine's separate `ACTION_NOT_PUBLISHED` contract.
- Added a paired route regression: a synthetic HTTP 400 from `get_action_definition_v1` carrying the exact message `IDEMPOTENCY_KEY_REUSE` plus private `details`/`hint` must return generic HTTP 500 and must not call `execute_create_offer_v1`; the same exact code from `execute_create_offer_v1` remains HTTP 400 with only `{"error":"IDEMPOTENCY_KEY_REUSE"}`. Both paths verify Bearer forwarding, request order, and non-disclosure of SQLSTATE/details/hints.
- QIMA CI #1062 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42573117014): **SUCCESS**. Browser job completed dependency installation, high-severity audit enforcement, TypeScript, Next.js production build, Chromium installation, and the Playwright suite successfully. PostgreSQL 16 integration job completed the CREATE_OFFER integration/concurrency suite, legacy messages RLS, participant self-enrollment RLS, disposable-resource cleanup, and QA266/QA267 prepared-transaction restoration successfully.
- QIMA CodeQL #1014 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42573117107): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed successfully.
- Vercel Preview Comments check on code commit `cc7a61c410e40356730a58f7d4d719007e1d1486`: **SUCCESS**. This check alone is not treated as proof that a new Preview deployment is READY. No Production deployment was performed.
- QA302 uses synthetic route-contract fixtures and source inspection; it does not establish a confirmed production vulnerability or incident. No SQL migration, Supabase Production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.


### QA303 — mask rejected action-definition RPC transport failures (9 November 2026)

- Code commit: `f9e80a0039038e1a7df9ccc7b6f29787c3758a0e`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Extended the route test harness with a transport-failure fixture for `get_action_definition_v1`. The mocked fetch records the authenticated definition request and then rejects with `ECONNRESET: GET_ACTION_DEFINITION_TRANSPORT_PRIVATE_SENTINEL`, exercising the runtime's rejected-promise catch rather than a PostgREST HTTP error response.
- Added a regression asserting HTTP 500 with exactly `{"error":"ACTION_FAILED"}`, no `WWW-Authenticate` challenge, no transport/internal marker disclosure, exactly one definition RPC request, and zero `execute_create_offer_v1` calls. The existing QA302 paired regression remains the positive control: the exact `IDEMPOTENCY_KEY_REUSE` returned by the execution RPC remains HTTP 400.
- QIMA CI #1064 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42583578314): **SUCCESS**. Browser job passed `npm ci`, npm audit enforcement at the configured `high` threshold (0 advisories in the report), TypeScript, Next.js production build, Chromium installation, and **332/332 Playwright tests**, including QA303. PostgreSQL 16 integration job passed CREATE_OFFER integration/concurrency, legacy messages RLS, participant self-enrollment RLS, disposable database cleanup, and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1016 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42583578317): **SUCCESS**; JavaScript/TypeScript analysis and result upload completed (75/75 TypeScript files, 3/3 GitHub Actions files, 1/1 JavaScript file scanned).
- Vercel combined status on code commit `f9e80a0039038e1a7df9ccc7b6f29787c3758a0e`: **SUCCESS** (Preview status only; no Production deployment).
- QA303 uses a synthetic route-transport fixture and source inspection; it does not establish a production incident or confirmed vulnerability. No application runtime behavior, SQL migration, Supabase Production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was changed. No Production deployment, PR merge, force-push, or branch-protection change.


### QA304 — lost CREATE_OFFER response after simulated commit and same-key replay (9 November 2026)

- Code commit: `9cdbad10542c604e2ada4c6941022125754fa721`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Extended the route mock with shared replay state. On the first execution-RPC request, the fixture records the exact RPC input and a successful result as committed, then rejects the fetch promise with `ECONNRESET: CREATE_OFFER_RESPONSE_LOST_AFTER_COMMIT_PRIVATE_SENTINEL`. The first HTTP request must return only HTTP 500 `{"error":"ACTION_FAILED"}`, without exposing the transport marker.
- The test asserts exactly one `execute_create_offer_v1` request on the first attempt (no automatic retry), one simulated committed creation, and no replay yet. A second HTTP request with the same idempotency key and identical effective RPC input returns the stored successful result; the fixture verifies that the serialized RPC input is identical and increments the replay count without incrementing the creation count.
- QIMA CI #1066 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42588763511): **SUCCESS**. Both jobs completed successfully. The browser job passed dependency installation, npm audit, TypeScript, Next.js production build, Chromium installation, Playwright browser tests, and audit-report upload. The PostgreSQL 16 job passed CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup, and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1018 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42588763612): **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded.
- Final HEAD validation: QIMA CI #1067 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42589039499): **SUCCESS**; both browser/build and PostgreSQL 16 integration jobs completed all steps successfully. QIMA CodeQL #1019 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42589039491): **SUCCESS**; analysis and upload completed. Vercel combined status on this documentation HEAD: **SUCCESS** (Preview only).
- Vercel combined status on code commit `9cdbad10542c604e2ada4c6941022125754fa721`: **SUCCESS** (Preview status only; no Production deployment).
- QA304 is a deterministic synthetic route-level transport fixture. It models a durable commit followed by a lost response and a subsequent idempotent replay; it is not a real network fault injected into PostgreSQL and does not establish a production incident or vulnerability. QA298 remains the separate PostgreSQL 16 integration proof for cross-transaction replay. No application runtime change, SQL migration, Supabase Production data/schema/RLS/grants/secrets, or persistent PostgreSQL configuration was modified. No Production deployment, PR merge, force-push, or branch-protection change.



### QA305 — reject changed payload after a lost committed CREATE_OFFER response (9 November 2026)

- Code commit: `3ba8c169c92d14548cd16f85755db1764d83c9b4`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Added a route-level regression that reuses QA304's shared replay fixture. The first request sends `price: 10` with a fixed idempotency key; the fixture records a successful committed result and then rejects the fetch promise with the post-commit response-loss sentinel. The first HTTP response must be HTTP 500 with only `{"error":"ACTION_FAILED"}`, and the fixture records exactly one simulated creation and no automatic retry.
- A second independent HTTP request uses the same idempotency key but changes the effective RPC input to `price: 12`. The fixture compares the complete serialized execution-RPC payload against the committed payload and returns the exact allowlisted `IDEMPOTENCY_KEY_REUSE` error. The route must return HTTP 400 with only `{"error":"IDEMPOTENCY_KEY_REUSE"}`; the original committed result remains unchanged and the creation count remains exactly one.
- Assertions cover the authenticated five-request sequence, one execution-RPC call per HTTP attempt, the same idempotency key, changed `p_input.price`, unchanged committed result, and non-disclosure of transport markers, SQLSTATE, and private details. The fixture's `replayCount` records the second idempotency lookup attempt, including the rejected changed-payload attempt; it is not a count of successful replays.
- QIMA CI #1069 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42597732484): **SUCCESS**. Both jobs completed successfully. Browser/build job passed `npm ci`, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, and **334/334 Playwright tests**, including QA305. PostgreSQL 16 integration job passed CREATE_OFFER integration/concurrency, QA298 cross-transaction replay, QA299 changed-payload-after-commit rejection, legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup, and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1021 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42597732447): **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `3ba8c169c92d14548cd16f85755db1764d83c9b4`: **SUCCESS** (Preview only; no Production deployment).
- The QA305 route fixture is synthetic: it models a durable commit followed by a lost HTTP response, then a same-key request with a changed payload. It does not inject a real network fault into PostgreSQL or establish a production incident/vulnerability. QA299 remains the separate PostgreSQL 16 integration proof for rejecting changed effective payload after a committed request. The CI workflow excludes `docs/**` via `paths-ignore`, so this documentation-only follow-up is covered by the successful code-commit validation above; it does not trigger a new CI/CodeQL run by itself. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, or application runtime behavior was modified. No Production deployment, PR merge, force-push, or branch-protection change.

### QA306 — replay equivalent numeric payloads after route normalization (9 November 2026)

- Code commit: `013b2affe99f40bf45889130bca65035b52f078f`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Extended the shared route replay fixture so a successful first execution records the simulated committed idempotency result, not only the response-loss path used by QA304/QA305. Added a regression using one fixed idempotency key: the first HTTP request sends `price: "10.00"`, `quantity: "01"`, and currency `" USD "`; the second sends numeric `price: 10`, `quantity: 1`, and currency `"USD"`. The route normalizes these representations before the execution RPC, so both complete RPC payloads must be identical.
- Expected route behavior: both requests return HTTP 200 with the exact same succeeded JSON result; one simulated creation is recorded, followed by one successful replay. The stored and replayed RPC inputs must match exactly, including the normalized currency, price, and quantity. This guards against rejecting semantically equivalent client representations as `IDEMPOTENCY_KEY_REUSE`.
- Validation limitation at record time: no QIMA CI or CodeQL workflow run was returned for code commit `013b2affe99f40bf45889130bca65035b52f078f`; the GitHub Actions runs query for this exact SHA was empty. The latest completed QIMA CI #1069 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42597732484) and CodeQL #1021 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42597732447) are **SUCCESS** on the prior QA305 code commit `3ba8c169c92d14548cd16f85755db1764d83c9b4`, but do not validate QA306. Accordingly, QA306 Playwright/CI and CodeQL results remain **NOT VERIFIED**; no success is inferred from the previous run.
- Vercel Preview for code commit `013b2affe99f40bf45889130bca65035b52f078f`: **READY** (deployment `dpl_BwdfJteunM6QxLcBScCW4aSQDDGg`, build completed in 46 seconds; Preview only, no Production deployment).
- This QA306 scenario is a synthetic route-level replay fixture and source-level normalization check. It does not prove PostgreSQL idempotency behavior by itself, establish a production incident, or confirm a vulnerability. QA298 remains the separate PostgreSQL 16 cross-transaction replay integration test. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, or production runtime behavior was modified. No Production deployment, PR merge, force-push, or branch-protection change.

### QA306 validation follow-up — 9 November 2026

- The contemporaneous QA306 entry above recorded CI/CodeQL as not verified because no workflow run was visible for code commit `013b2affe99f40bf45889130bca65035b52f078f` at that moment. A subsequent PR-head validation completed on commit `929392b2f3a6ef04994d1fb9c917833e84d7136b`, which contains the QA306 code commit: QIMA CI #1070 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42602676184) **SUCCESS**, including **335/335 Playwright tests** and the PostgreSQL 16 integration job; QIMA CodeQL #1022 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42602676156) **SUCCESS**, with analysis results uploaded (75/75 TypeScript, 3/3 GitHub Actions, 1/1 JavaScript files). This follow-up supersedes the earlier NOT VERIFIED status for QA306 while preserving the original time-of-check note.
- QA306 remains a synthetic route-level normalization/replay test; QA298 remains the separate PostgreSQL 16 cross-transaction replay integration proof. No production incident or vulnerability is inferred. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.

### QA307 — replay omitted optional fields against explicit null defaults (9 November 2026)

- Code commit: `df9d554f2fd24ee223585de2592b5100e4cd6919`; test file: `tests/e2e/create-offer-route-contract.spec.ts`.
- Added a route-level idempotency regression using one fixed key. The first request omits optional offer fields; the second sends explicit `null` for `pricingModel`, `conditions`, `market`, `geography`, `attributes`, `documentationStatus`, `lifecycle`, and `offerType`.
- The route's current normalization contract maps both representations to the same effective values: `pricingModel: "fixed"`, nullable fields to `null`, `attributes: {}`, `lifecycle: "draft"`, and `offerType: "supplier_offer"`. The test compares the complete serialized execution-RPC inputs and requires the same successful JSON result, one simulated creation, and one replay.
- Validation at this documentation update: QIMA CI #1071 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42607690939) and CodeQL #1023 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42607690954) were still **IN PROGRESS**. No Playwright, PostgreSQL, or CodeQL success is claimed for QA307 until those runs complete. The route fixture is synthetic and does not by itself establish PostgreSQL idempotency behavior, a production incident, or a vulnerability. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.

### QA307 validation follow-up — 9 November 2026

- Code commit `df9d554f2fd24ee223585de2592b5100e4cd6919` was validated on the PR branch. QIMA CI #1071 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42607690939): **SUCCESS**; browser/build job passed `npm ci`, npm audit enforcement, TypeScript, Next.js production build, Chromium installation, and **336/336 Playwright tests**, including QA307. The PostgreSQL 16 integration job also completed successfully, including CREATE_OFFER integration/concurrency, QA298/QA299, legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup, and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1023 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42607690954): **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded (75/75 TypeScript files, 3/3 GitHub Actions files, and 1/1 JavaScript file scanned).
- Vercel combined status on code commit `df9d554f2fd24ee223585de2592b5100e4cd6919`: **SUCCESS** (Preview only; no Production deployment).
- QA307 is a synthetic route-level test of omitted-versus-null normalization and replay fixture behavior. It does not by itself prove PostgreSQL idempotency semantics, establish a production incident, or confirm a vulnerability. Existing QA298/QA299 remain the PostgreSQL 16 integration proofs for replay and changed-payload rejection. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.



### QA308 — PostgreSQL JSONB object-key order and idempotency replay (9 November 2026)

- Code commit: `fbb8def4f75c04e979d55c8c0ea6f4be9046a481`; test file: `tests/sql/run-create-offer-integration.sh`.
- Added a PostgreSQL 16 integration regression using two independent `psql` processes and two distinct committed transactions. The first creates an offer with nested JSONB keys in one order; the second reuses the same tenant/idempotency key and the same semantic values while reversing both top-level and nested key order in `p_input` and `p_attributes`.
- The test requires distinct transaction IDs, an identical replay JSONB result, the stored result matching the replay, and the persisted request hash matching the canonical `md5(jsonb_build_object(...)::text)` for the full effective request.
- Persistence assertions require exactly one completed idempotency row, one completed execution, one offer with the expected fields/JSONB attributes, and one matching `ACTION_SUCCEEDED` event. The runner log explicitly reports: “QA308 JSONB key order was canonicalized recursively; a distinct committed transaction replayed the exact result with one idempotency row, execution, offer, and success event”.
- Validation on code commit `fbb8def4f75c04e979d55c8c0ea6f4be9046a481`: QIMA CI #1073 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42616938896) **SUCCESS**. Browser/build job passed dependency installation, npm audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. PostgreSQL 16 integration job **SUCCESS**, with QA308 explicitly present in the job log and all existing CREATE_OFFER, concurrency, RLS and cleanup checks successful. QIMA CodeQL #1025 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42616938912) **SUCCESS**, with JavaScript/TypeScript analysis completed and results uploaded.
- Vercel combined status for the code commit: **SUCCESS** (Preview only; no Production deployment).
- QA308 is an isolated PostgreSQL 16 integration test of PostgreSQL JSONB canonicalization and the existing request-hash contract. It does not establish a production incident or confirm a vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA308 final-head validation follow-up — 9 November 2026

- Documentation commit: `f9dd1ae25745cabcb01460374921088d019bea9c`.
- The final documentation HEAD was independently validated: QIMA CI #1074 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42617302829) **SUCCESS**. Both jobs completed successfully. The browser/build job passed dependency installation, npm audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job passed QA308, CREATE_OFFER integration/concurrency, legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup and QA266/QA267 prepared-transaction restoration.
- QIMA CodeQL #1026 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42617302810) **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded.
- Vercel combined status on the documentation HEAD: **SUCCESS** (Preview only; no Production deployment).
- This follow-up validates the documentation synchronization after the QA308 code commit. It does not infer a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA309 — JSONB array order remains significant — 9 November 2026

- Added an isolated PostgreSQL 16 integration scenario to `tests/sql/run-create-offer-integration.sh`.
- The first committed transaction creates an offer using `p_input` arrays `["red","blue"]` and nested `[1,2]`, with matching ordered arrays in `p_attributes`.
- A second independent transaction reuses the same tenant/idempotency key but reverses both top-level and nested array values in `p_input` and `p_attributes`.
- Expected contract: the changed effective JSONB payload is rejected with `IDEMPOTENCY_KEY_REUSE`; the second transaction must not create or mutate an offer.
- Assertions preserve the original request hash and JSONB result, require distinct transaction IDs, and verify exactly one completed idempotency row, one completed execution with the original input, one offer with the original ordered arrays, and one `ACTION_SUCCEEDED` event.
- This is a PostgreSQL integration regression test. Its CI execution and CodeQL status are **pending at the time of this documentation commit**; no pass is claimed until GitHub reports results for the exact code commit.
- The test distinguishes JSONB object-key canonicalization (QA308) from array-order semantics. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA309 final validation follow-up — 9 November 2026

- Validated PR head `efde24b491e0ba70c0d38394f9f34f8bfe439e67`, which contains the QA309 test commit and all three QA309 register entries.
- QIMA CI #1076 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42626222108) **SUCCESS**. The browser/build job passed npm installation, dependency audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job passed; its log explicitly reports that QA309 rejected the changed top-level and nested JSONB array order with `IDEMPOTENCY_KEY_REUSE` in a distinct committed transaction and preserved the original hash, result, offer, execution and success event. All legacy-message RLS, participant self-enrollment RLS, disposable-resource cleanup and QA266/QA267 prepared-transaction checks also passed.
- QIMA CodeQL #1028 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42626222113) **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded.
- The `Vercel Preview Comments` check completed successfully. The separate combined `Vercel` status remained **FAILURE** with `api-deployments-free-per-day`; a READY Preview deployment for this final HEAD is therefore not claimed.
- This validation is tied to the exact PR head above. Although the follow-up commits only change documentation, this PR also contains non-documentation code changes, so GitHub's pull_request path filtering still queues CI and CodeQL on the updated PR head. The runs for documentation HEAD `02cc31056308acbe61ff509fccc0b922bfaf48d8` were observed queued after this follow-up; they are distinct from the completed validation of `efde24b491e0ba70c0d38394f9f34f8bfe439e67` recorded above.
- QA309 is a disposable PostgreSQL 16 regression test, not evidence of a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA310 — numeric-scale idempotency characterization — 10 November 2026

- Added a disposable PostgreSQL 16 integration scenario for three isolated same-key retries: a numeric value inside p_input (1 versus 1.0), p_price (21 versus 21.0), and p_quantity (2 versus 2.0).
- The characterization asserts PostgreSQL JSONB equality for 1 and 1.0, compares the corresponding JSONB text/hash representations, and exercises execute_create_offer_v1 with each changed representation after the first request has committed.
- The current implementation is expected to distinguish the text-based effective-request hashes and return IDEMPOTENCY_KEY_REUSE for each changed-scale retry, while preserving the original hash, result, completed execution, offer, and success event. This is a characterization of the current implementation, not a claim that the behavior is the desired product contract.
- Whether mathematically equal numeric values with different display scales should be treated as the same idempotent request remains an API/product-contract decision. No runtime normalization or migration change is included pending that decision.
- Code test commit: 47f07ad59637d81e92c0ce2c842fc1b1562c3a0f. QIMA CI #1080 and CodeQL #1032 were queued/in progress when this entry was added; no pass is claimed until their results are checked for the exact commit.
- QA310 uses only the disposable PostgreSQL integration database. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA310 final validation follow-up — 10 November 2026

- Validated code commit 47f07ad59637d81e92c0ce2c842fc1b1562c3a0f.
- QIMA CI #1080 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42642188204) **SUCCESS**. TypeScript, production build, dependency audit, Chromium and **336/336 Playwright tests** passed. The disposable PostgreSQL 16 integration job passed all CREATE_OFFER, legacy-message RLS, participant self-enrollment RLS, cleanup, and prepared-transaction checks. Its log explicitly reports the QA310 assertions: JSONB 1 and 1.0 compare equal, while the current text-based request hash distinguishes the p_input, price, and quantity numeric scales; all three changed-scale retries were rejected and the original records remained unchanged.
- QIMA CodeQL #1032 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42642188233) **SUCCESS**; JavaScript/TypeScript analysis and result upload completed.
- The combined Vercel status for the code commit was **FAILURE**. A READY Preview for this commit is not claimed; the combined-status response did not provide a failure reason.
- The PostgreSQL log also shows pre-existing QA111 and QA112 coverage for numeric scale in p_input/p_attributes and p_price/p_quantity. QA310 is therefore a consolidated cross-check with explicit snapshots of all three first results, not a newly discovered production issue or a claim that the underlying numeric-scale behavior was previously untested.
- The current behavior remains a contract question: whether mathematically equal numbers with different display scales should share an idempotency key. No runtime normalization is introduced without an explicit API/product decision.
- QA310 was executed only against the disposable PostgreSQL 16 CI service. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA310 final PR-head verification — 10 November 2026

- Final documentation HEAD 0eb019da64b5479cc8a192a849863505112ed30a passed QIMA CI #1081 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42642690279) **SUCCESS** and QIMA CodeQL #1033 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42642690438) **SUCCESS**.
- CI #1081 completed TypeScript, dependency audit, Next.js production build, Chromium, **336/336 Playwright tests**, the full disposable PostgreSQL 16 CREATE_OFFER integration/concurrency suite (including QA310), legacy-message RLS, participant self-enrollment RLS, prepared-transaction restoration, and disposable-resource cleanup.
- The PostgreSQL job log explicitly reports the QA310 result: JSONB 1 and 1.0 compare equal, but the current text-based effective-request hash distinguishes p_input, price, and quantity scale; all three changed-scale retries were rejected and the first hashes/results/executions/offers/events remained unchanged.
- CodeQL #1033 completed JavaScript/TypeScript analysis and uploaded its results successfully.
- The combined Vercel status for this HEAD is **FAILURE** with upgradeToPro=build-rate-limit; no READY Preview or Production deployment is claimed.
- This validation is tied to the exact HEAD above. No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.

 
### QA311 — PostgreSQL JSONB duplicate object keys and idempotency replay (10 November 2026)

- Added a disposable PostgreSQL 16 integration regression to tests/sql/run-create-offer-integration.sh. The first committed transaction passes duplicate top-level and nested object keys in both p_input and p_attributes; the second independent committed transaction reuses the same tenant/idempotency key with the equivalent canonical objects after duplicate keys have been removed.
- The duplicate-key inputs use conflicting earlier values followed by the intended final values. PostgreSQL JSONB parsing retains the last value for each duplicate object key, including nested objects. The test first asserts that each duplicate-key JSONB value is IS NOT DISTINCT FROM its canonical equivalent.
- The replay must return the exact original JSONB result. Assertions verify distinct transaction IDs, the canonical full-request hash, one completed idempotency row, one completed execution with canonical input, one offer with canonical attributes, and one matching ACTION_SUCCEEDED event.
- The PostgreSQL 16 integration step in QIMA CI #1083 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42648204220) completed SUCCESS. Its job log explicitly reports: “QA311 JSONB duplicate top-level and nested object keys collapsed to the last values; a distinct committed transaction replayed the canonical result with one idempotency row, execution, offer, and success event.” All other steps in that PostgreSQL integration job also passed.
- QIMA CodeQL #1035 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42648204152) completed SUCCESS and uploaded its JavaScript/TypeScript analysis results.
- At the time of this entry, the browser/build job in QIMA CI #1083 had passed npm ci, dependency audit enforcement, TypeScript, and the Next.js production build; Playwright Chromium installation was still IN PROGRESS, so the overall QIMA CI run was not yet complete and no Playwright pass is claimed for QA311.
- The combined Vercel status for code commit 8bf95b09ed231bb4ebd3dada171debd901e45c4c was SUCCESS (Preview status only; no Production deployment).
- QA311 characterizes PostgreSQL JSONB duplicate-key parsing and the existing idempotency hash contract. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA311 final PR-head validation follow-up — 10 November 2026

- Final PR documentation HEAD: 61d10d6a145aad3aef7cf14609220630d1bf758e, containing QA311 code commit 8bf95b09ed231bb4ebd3dada171debd901e45c4c and all three QA311 register entries.
- QIMA CI #1084 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42648687673) **SUCCESS**. The browser/build job passed npm ci, dependency audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job also completed **SUCCESS**; its log explicitly confirms that duplicate top-level and nested keys in p_input and p_attributes collapsed to the final JSONB values and the second committed transaction replayed the original result with exactly one idempotency row, execution, offer, and success event. Legacy-message RLS, participant self-enrollment RLS, prepared-transaction restoration and disposable-resource cleanup all passed.
- QIMA CodeQL #1036 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42648687141) **SUCCESS**; JavaScript/TypeScript analysis completed and results were uploaded.
- The earlier code-commit QIMA CI #1083 was cancelled after the PR head advanced; its PostgreSQL integration job had already completed successfully with the QA311 log result. Final validation is provided by the complete CI #1084 run above.
- The combined Vercel status for final documentation HEAD 61d10d6a145aad3aef7cf14609220630d1bf758e is **FAILURE** with api-deployments-free-per-day; no READY Preview for this final HEAD is claimed.
- QA311 is an isolated PostgreSQL 16 integration regression. It characterizes JSONB duplicate-key parsing and the existing idempotency contract; it does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA312 — duplicate JSONB keys inside array objects and array-order preservation (10 novembre 2026)

- Added a disposable PostgreSQL 16 integration regression in `tests/sql/run-create-offer-integration.sh`. The first committed transaction supplies duplicate keys inside objects contained in arrays in both `p_input` and `p_attributes`, including duplicate keys in nested objects within the array elements. A second independent committed transaction reuses the same idempotency key with the equivalent canonical arrays after duplicate keys are removed.
- Explicit JSONB assertions confirm PostgreSQL keeps the last value for each duplicate key inside array objects, including nested object paths. The test also verifies that array lengths and element order remain unchanged: the second item remains at index 1, while canonical values at index 0 and nested paths are preserved.
- The replay must return the exact original result. Assertions verify distinct transaction IDs, identical canonical full-request hash and stored result, one completed idempotency row, one completed execution, one offer with canonical attributes, and one matching `ACTION_SUCCEEDED` event.
- QIMA CI #1086 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42655729153) completed **SUCCESS** on code commit `f3a00d93e8d248fa237607c45e96d89a21637bce`. The browser/build job passed dependency installation and audit, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job completed successfully; its log explicitly reports: “QA312 JSONB duplicate keys inside array objects collapsed to the last values; a distinct committed transaction replayed the canonical result with one idempotency row, execution, offer, and success event.” All RLS, disposable database cleanup and prepared-transaction restoration checks also passed.
- QIMA CodeQL #1038 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42655729107) completed **SUCCESS**. JavaScript/TypeScript analysis results were successfully uploaded and processed.
- QA312 characterizes PostgreSQL JSONB parsing and the existing idempotency contract. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA312 final PR-head validation follow-up — 10 novembre 2026

- Final QA312 documentation HEAD before this follow-up: `916ecdfec465b26186525b9b360c0c0c41aa440c`, containing the QA312 PostgreSQL integration regression and all three register entries.
- QIMA CI #1087 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42656169558) completed **SUCCESS** on that HEAD. The browser/build job passed dependency installation and audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. The PostgreSQL 16 integration job completed **SUCCESS** and its log explicitly confirms QA312: duplicate JSON object keys inside arrays in `p_input` and `p_attributes` collapsed to PostgreSQL JSONB's last-value representation; a second committed transaction replayed the exact result without duplicates. Legacy-message RLS, participant self-enrollment RLS, prepared-transaction restoration and disposable-resource cleanup also passed.
- QIMA CodeQL #1039 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42656169446) completed **SUCCESS**; JavaScript/TypeScript analysis results were uploaded and processing completed.
- GitHub's `Vercel Preview Comments` check was successful on the QA312 documentation HEAD; this is not treated as proof of a READY deployment. No Production deployment was performed.
- This is test evidence from disposable CI infrastructure. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA311/QA312 regression-retention correction and final validation — 10 novembre 2026

- A review of the QA312 code diff identified that the first QA312 edit had replaced the final QA311 shell-test block instead of appending a second block. This was corrected in commit `0b37a18100ad77011efcf16604c5d1a726bfddcf`: the original QA311 block was restored from the verified pre-QA312 version, and the QA312 array-object block remains immediately after it. The current integration runner contains exactly one `# QA311:` section and one `# QA312:` section, with both distinct idempotency fixtures present.
- QIMA CI #1089 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42656754738) completed **SUCCESS** on code commit `0b37a18100ad77011efcf16604c5d1a726bfddcf`. The PostgreSQL 16 integration log explicitly reports both QA311 and QA312 success: duplicate top-level/nested object keys replayed canonically, and duplicate keys inside array objects replayed canonically while array order assertions passed. The browser/build job passed dependency installation and audit enforcement, TypeScript, Next.js production build, Chromium installation and **336/336 Playwright tests**. All RLS, disposable database cleanup and prepared-transaction restoration checks passed.
- QIMA CodeQL #1041 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42656754755) completed **SUCCESS**; JavaScript/TypeScript analysis results were uploaded and processing completed.
- Intermediate documentation-head workflows QIMA CI #1088 and CodeQL #1040 were superseded when the QA311-retention correction advanced the branch; final code validation is provided by #1089 and #1041 above.
- QA311 and QA312 are disposable PostgreSQL 16 regression tests. They characterize JSONB parsing and the existing idempotency contract; they do not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### QA313 duplicate-key final JSON null versus absent properties — 10 novembre 2026

- Added a disposable PostgreSQL 16 integration regression in tests/sql/run-create-offer-integration.sh. The first committed transaction supplies duplicate top-level and nested keys in both p_input and p_attributes, with the final occurrence explicitly set to JSON null. A second independent committed transaction uses the equivalent canonical objects with those properties explicitly set to null; it must replay the exact original result.
- The test then retries the same idempotency key twice: once with the affected p_input properties omitted and once with the affected p_attributes properties omitted. Both changed effective payloads must raise IDEMPOTENCY_KEY_REUSE. Assertions preserve the original request hash/result, one completed idempotency row, one completed execution, one offer, and one matching ACTION_SUCCEEDED event.
- Initial QIMA CI #1091 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42664310333) failed in the PostgreSQL fixture with UNAUTHENTICATED because the first version ran the changed-payload RPC attempts from a superuser verification DO block without setting the authenticated JWT/role context. This was a test-harness setup defect; it was not evidence of an application authentication regression or vulnerability.
- Corrected in commit 9df672adcfab725f1915eeed90bd19c46e45cefa: changed-payload retries now execute in a separate psql session with SET request.jwt.claim.sub and SET ROLE authenticated; read-only state verification remains in a separate privileged session. The runner retains exactly one QA311, QA312, and QA313 section.
- Final QIMA CI #1092 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42664780990) completed SUCCESS on code commit 9df672adcfab725f1915eeed90bd19c46e45cefa. The PostgreSQL 16 integration log explicitly reports QA313 success: duplicate keys ending in JSON null replay as canonical explicit-null properties, while same-key retries omitting those properties are rejected and the original records remain unchanged. The browser/build job passed dependency installation and audit enforcement, TypeScript, Next.js production build, Chromium installation and 336/336 Playwright tests. RLS, disposable database cleanup and prepared-transaction restoration checks passed.
- QIMA CodeQL #1044 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42664781025) completed SUCCESS; JavaScript/TypeScript analysis results were uploaded and processing completed.
- GitHub's Vercel status on the code HEAD reported the Free-plan api-deployments-free-per-day rate limit. This is recorded as a Preview quota limitation, not a code-test failure; no Production deployment was performed.
- QA313 characterizes PostgreSQL JSONB duplicate-key handling and the existing idempotency contract. It does not establish a production incident or vulnerability. No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.



### QA314 duplicate JSON keys ending in JSON null inside JSONB array objects — 10 novembre 2026

- Added a disposable PostgreSQL 16 regression for duplicate keys ending in JSON null inside objects within JSONB arrays in `p_input` and `p_attributes`. A canonical explicit-null retry in a distinct committed transaction must replay the original result; retries omitting either first-element property must be rejected with `IDEMPOTENCY_KEY_REUSE`.
- The regression verifies array order and length, explicit-null canonicalization, the unchanged request hash/result, and exactly one completed idempotency row, execution, offer, and success event.
- Code commit: `b7b78136215a030fd4372ff7155062a74d3549f1`. QIMA CI #1094 and CodeQL #1046 were **QUEUED** when this entry was written; no final CI result is claimed here.
- No Supabase Production data/schema/RLS/grants/secrets, migration, persistent PostgreSQL configuration, or Production deployment was modified.


### QA314 CI validation follow-up — 10 November 2026

- Rechecked PR #26 at head `ca58aab40eae3dfd640658cb54ee235a3f78d579`: the pull request remains open, draft, and mergeable; comparison against `main` reports 1,208 commits ahead and 0 behind.
- QIMA CI #1096 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42673637723) reports a workflow-run conclusion of **failure**. Its jobs endpoint lists only one job, `Typecheck, audit, build and browser tests`, and that job completed **success**. All listed steps succeeded, including dependency installation/audit enforcement, TypeScript, Next.js build, Chromium installation, and **336/336 Playwright tests**. The job log contains no PostgreSQL integration step. The run-level failure is not explained by the available job payload/log; it is not attributed to QA314.
- QIMA CodeQL #1048 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42673637105) completed **success**.
- Workflow comparison: `.github/workflows/ci.yml` on `main` (blob `ba9841190e2c1a518c7ab43ae0c100391d6ff1bc`) does not define `postgres-integration`; the PR branch version (blob `c70e3a8f21e2fda410ae3b892265a6dbff73da7b`) does define that job. Nevertheless, the observed pull-request run #1096 did not include it. The available evidence establishes the omission, but does not by itself prove GitHub's workflow-version resolution as the cause.
- The current connected GitHub actions interface exposes workflow/run reads and reruns but no `workflow_dispatch` operation. The local execution container also has no `psql`, Docker, or Podman, and outbound DNS to GitHub is unavailable; QA314 could not be run independently in this environment.
- **QA314 remains NOT VALIDATED.** The 336 browser tests do not validate the PostgreSQL fixture. Do not treat the queued/omitted integration job or the run-level status as a PostgreSQL result. Next step: an authorized repository maintainer should dispatch the existing CI workflow against `fix/create-offer-status-contract` if the branch-specific workflow is selectable, or arrange a separately reviewed base-workflow change that makes the PostgreSQL job available to PR runs; then verify the exact SHA and the `CREATE_OFFER PostgreSQL integration tests` job.
- Vercel's combined commit status remains **failure** because of the Free-plan `api-deployments-free-per-day` quota; this is a Preview limitation, not a test result.
- No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change. No production vulnerability is inferred from these synthetic/CI observations.


### QA314 PostgreSQL validation and fixture correction — 10 November 2026

- The first QA314 PostgreSQL execution was obtained in QIMA CI #1097 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42686629868) on documentation commit `0a3423e09cccedc8a70c395070dacc95038f4e81`. The integration job exposed a test-fixture SQL syntax error, `syntax error at or near "s"`, in the first changed-payload assertion. Two `RAISE EXCEPTION` messages contained the unescaped apostrophe in `array object's`, which prematurely terminated the SQL string literal. This was a test-harness defect, not an application/runtime failure or a production vulnerability.
- Fixed exactly two occurrences in `tests/sql/run-create-offer-integration.sh` in code commit `c4b7b348978d29a13205dec3a003c66e0d026e46`, replacing the apostrophe-containing wording with SQL-safe wording. The QA314 scenario and its four negative retries were otherwise unchanged.
- Final QIMA CI #1098 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42687022991) completed **SUCCESS** on exact code SHA `c4b7b348978d29a13205dec3a003c66e0d026e46`. Both jobs passed: `Typecheck, audit, build and browser tests` and `CREATE_OFFER PostgreSQL integration tests`. The PostgreSQL 16.15 log explicitly confirms QA311, QA312, QA313, and QA314; QA314's canonical explicit-null replay succeeded, all absent-property retries were rejected, array order and original records were preserved. The remaining RLS, disposable-database cleanup, prepared-transaction restoration, and self-enrollment checks also passed.
- The browser/build job passed npm installation and audit enforcement, TypeScript, Next.js production build, Chromium installation, and **336/336 Playwright tests**. QIMA CodeQL #1050 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42687023024) completed **SUCCESS**.
- This supersedes the earlier QA314 follow-up note that manual dispatch or local PostgreSQL execution would be needed: the subsequent PR workflow run #1097 did include the PostgreSQL integration job, exposed the fixture quoting defect, and #1098 validated the correction. No manual dispatch was performed.
- QA314 is now **VALIDATED on disposable PostgreSQL 16.15 CI infrastructure**. This is regression-test evidence about the test fixture and existing JSONB/idempotency contract; it does not establish a production incident or vulnerability.
- No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### Source-only SECURITY DEFINER and EXECUTE ACL review — 10 November 2026

- Read-only source audit completed against all 18 SQL migrations on PR HEAD `a1152a8831509e472f2817d7c46743e7bbf99f82`, plus the relevant Decision Tree call sites. Detailed inventory: [SECURITY_DEFINER_ACL_SOURCE_AUDIT_2026-11-10.md](SECURITY_DEFINER_ACL_SOURCE_AUDIT_2026-11-10.md).
- Source-level ACL hardening candidates: `current_profile_actor_id()` and `execute_create_offer_v1(...)` have no explicit PUBLIC revoke in the reviewed defining/restriction migrations; `dt_select_product_master(...)` is SECURITY INVOKER and its migration grants authenticated without an explicit PUBLIC revoke. `create_offer_v1(...)` is revoked from PUBLIC/authenticated by the branch migration, but no explicit direct-`anon` revoke is present. These are not effective-ACL findings: CREATE OR REPLACE preserves ACLs, grants are additive, and default privileges may be configured outside the repository.
- The reviewed SECURITY DEFINER functions pin `search_path = public`; their application relations and `auth.uid()` calls are schema-qualified. Whether `anon` or `authenticated` can CREATE in `public` is unverified. No search_path or ACL change was made.
- Read-only live catalog verification was blocked before query execution: Supabase `execute_sql` returned PostgreSQL `28P01` for `postgres`, and `list_tables` returned `28P01` for `supabase_read_only_user`. No catalog rows were returned and no data was changed.
- Baseline on exact reviewed HEAD: QIMA CI #1099 **SUCCESS** (both browser/build and PostgreSQL integration jobs; Playwright **336/336**), CodeQL #1051 **SUCCESS**, combined Vercel status **SUCCESS**. These checks do not validate live ACLs.
- No production vulnerability is confirmed. Next gate: restore authorized read-only catalog access or have a project maintainer run the catalog-only SELECTs in the detailed report; only then decide whether a minimal new migration and isolated positive/negative tests are justified.
- No Supabase Production data/schema/RLS/grants/secrets, SQL migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### Explicit RPC EXECUTE ACL hardening prepared — 10 November 2026

- Rechecked the defining migrations and authenticated call sites for `current_profile_actor_id()`, `dt_select_product_master(uuid, uuid, uuid)`, and `execute_create_offer_v1(...)`. Each has an authenticated caller, while the branch migrations do not explicitly revoke the PostgreSQL default PUBLIC EXECUTE privilege. No `ALTER DEFAULT PRIVILEGES` statement exists in the 18 reviewed migrations. This is a clean-install source configuration observation, not proof of the live project's effective ACL.
- Added `supabase/migrations/20261110070000_harden_public_rpc_execute_acl.sql`: revoke all function privileges from PUBLIC and `anon`, then explicitly grant EXECUTE to `authenticated` for those three entry points. The low-level `create_offer_v1(...)` remains unchanged pending effective owner/catalog verification.
- Added `tests/sql/function-execute-acl-regression.sql` and `tests/sql/run-function-execute-acl-regression.sh`. The runner is restricted to the dedicated loopback `qima_test` CI URL, creates a separate `qima_acl_test` database, applies the migration twice, verifies PUBLIC/anon denial and authenticated EXECUTE, and cleans up its temporary database and any roles it created.
- Added the regression runner to the PostgreSQL integration job. This test validates the migration on disposable PostgreSQL; it does not validate the live Supabase catalog.
- Live Supabase catalog verification remains blocked by PostgreSQL `28P01`; effective Production ACLs remain unverified. No Production vulnerability is confirmed and the migration has not been applied to Supabase Production.
- Validation on this code commit: **pending**. No Supabase Production data/schema/RLS/grants/secrets, production migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### RPC EXECUTE ACL regression follow-up — 10 November 2026

- Code commit `4f768c103aecb50a7a53a939021020af072c228f` added the additive ACL migration and disposable PostgreSQL runner. QIMA CI #1102 passed the existing CREATE_OFFER PostgreSQL integration suite, TypeScript, dependency audit, Next.js build, and **336/336 Playwright**; CodeQL #1054 and Vercel Preview Comments also passed.
- The new ACL regression step failed at its post-migration `regprocedure` lookup because the test identity string for `execute_create_offer_v1(...)` omitted one `text` argument. The actual migration signature is 18 arguments and the migration itself was applied twice in the disposable database before the assertion error.
- Corrected the test identity to the exact 18-argument signature and added an explicit assertion that PostgreSQL's fresh-database default PUBLIC EXECUTE ACL is present before the migration, as well as the simulated direct `anon` grant.
- The failure is confined to the regression test's signature string. It does not establish a production ACL issue. Live Supabase catalog access remains blocked by PostgreSQL `28P01`; no Production ACL/migration/data change was made.
- Corrected regression validation: **pending next CI run**.


### RPC EXECUTE ACL regression follow-up — CI #1103

- QIMA CI #1103 passed the existing CREATE_OFFER PostgreSQL integration suite and the TypeScript/audit/build/browser job (**336/336 Playwright**); CodeQL #1055 and Vercel Preview Comments passed.
- The new ACL test stopped before applying the migration because its inserted precondition used an incomplete `DO $` delimiter. The function identity string correction from the prior attempt was present; this second failure is another test-fixture formatting defect, not a live ACL finding.
- Changed the precondition delimiter to `$acl$` and retained the explicit default-PUBLIC and direct-`anon` precondition assertions. The migration was not executed in CI #1103; end-to-end validation remains pending.
- Live Supabase catalog access remains blocked by PostgreSQL `28P01`. No Production ACL/data/schema/migration change was made.


### RPC EXECUTE ACL hardening — CI validation complete — 10 November 2026

- PR code HEAD `227a6dc95d521addb6f75fd1ae6cbe4e644864ea`: QIMA CI #1104 **SUCCESS**, CodeQL #1056 **SUCCESS**; the browser/build job passed **336/336 Playwright**.
- The disposable PostgreSQL ACL step logged `function EXECUTE ACL regression PASS`: PostgreSQL default PUBLIC EXECUTE and a direct anon grant were removed for `current_profile_actor_id()`, `dt_select_product_master(uuid, uuid, uuid)`, and `execute_create_offer_v1(...)`; authenticated retained an explicit EXECUTE grant. The migration was applied twice in the dedicated temporary `qima_acl_test` database, and the runner completed successfully.
- Existing CREATE_OFFER PostgreSQL integration, legacy-message RLS, participant self-enrollment RLS, prepared-transaction cleanup/restore, and database cleanup checks all passed. CI #1102 and #1103 fixture failures are documented above and superseded by #1104.
- Vercel Preview Comments passed, but the combined Vercel status remains failed due to `upgradeToPro=build-rate-limit`; no Preview READY is confirmed.
- This is disposable-CI migration evidence only. Live Supabase catalog access still fails with PostgreSQL `28P01`, so effective Production ACLs remain unverified; no Production vulnerability is confirmed and the migration has not been applied to Supabase Production.
- Next gate: authorized read-only live ACL/owner/schema-privilege output and human review before any Production migration. No Supabase Production data/schema/RLS/grants/secrets, production migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### Authenticated-only helper RPC anon ACL hardening — 10 November 2026

- Added branch-only migration `supabase/migrations/20261110080000_harden_authenticated_helper_anon_acl.sql` to reassert authenticated-only EXECUTE privileges for four helpers: `dt_has_tenant_access(uuid)`, `dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid)`, `dt_publish_product_request(uuid, uuid)`, and `is_message_participant(uuid, uuid, uuid)`.
- Source call-site review found no anonymous application caller: tenant access is used by RLS policies scoped to authenticated; Decision Tree answer submission and product-request publication authenticate the current user before the RPC; the legacy-message participant helper is used by the authenticated message RLS path. This is a source-level caller review, not proof of effective live ACLs.
- Extended `tests/sql/function-execute-acl-regression.sql` from three to seven function signatures. The disposable fixture establishes default PUBLIC EXECUTE plus a direct `anon` grant, applies both ACL migrations twice, and asserts no effective PUBLIC/anon EXECUTE and an explicit authenticated grant for all seven functions.
- Code commit `3357a3bf5cf65de0d5dd4d6be051126ce1f71bf5` is on PR #26. QIMA CI run [#1106](https://github.com/meridane/QimaTrade-MVP/actions/runs/42710206948) and CodeQL run [#1058](https://github.com/meridane/QimaTrade-MVP/actions/runs/42710207078) were **IN PROGRESS** when this entry was written; no pass is claimed yet.
- Live Supabase catalog access remains blocked by PostgreSQL `28P01`. This proves only the intended migration semantics when the disposable regression passes; it does not confirm a Production vulnerability or effective Production ACL. The migration has not been applied to Supabase Production.
- Next gate: finish CI #1106 / CodeQL #1058, inspect the ACL regression log, then update this record with the final result. Keep `create_offer_v1(...)` and schema CREATE privileges unchanged until authorized live owner/ACL evidence is available.


### Final validation — authenticated-only helper RPC anon ACL hardening — 10 November 2026

- The first run on code commit `3357a3bf5cf65de0d5dd4d6be051126ce1f71bf5`, QIMA CI #1106, was **CANCELLED** when the subsequent documentation commit advanced the PR ref while the workflow's `cancel-in-progress: true` concurrency group was active. This was cancellation, not a test failure. CodeQL #1058 completed **SUCCESS**.
- The replacement full run on final pre-validation HEAD `3c7a2e29f6d4b4bcfc2cda00cdb00527f47a4b59`, QIMA CI [#1107](https://github.com/meridane/QimaTrade-MVP/actions/runs/42710427788), completed **SUCCESS**. Both jobs passed: CREATE_OFFER PostgreSQL integration and TypeScript/dependency audit/Next.js build/browser tests.
- The PostgreSQL job log contains `function EXECUTE ACL regression PASS` and `covered functions: 7`. It created seven disposable function stubs with default PUBLIC EXECUTE and direct `anon` grants, applied both `20261110070000_harden_public_rpc_execute_acl.sql` and `20261110080000_harden_authenticated_helper_anon_acl.sql` twice, and passed the postconditions: no PUBLIC/anon EXECUTE and explicit authenticated EXECUTE on all seven signatures. Existing CREATE_OFFER QA311–QA314, RLS, cleanup, and prepared-transaction checks also passed.
- The browser/build job passed npm installation, dependency audit, TypeScript, Next.js production build, Chromium installation, and **336/336 Playwright**. CodeQL [#1059](https://github.com/meridane/QimaTrade-MVP/actions/runs/42710427629) completed **SUCCESS**.
- Vercel Preview Comments completed **SUCCESS** and the combined Vercel status for HEAD `3c7a2e2` was **SUCCESS**. No Production deployment was made.
- Live Supabase catalog access remains blocked by PostgreSQL `28P01`; effective Production ACLs and owners remain unverified. These tests establish migration semantics on disposable PostgreSQL only, not a Production vulnerability. Neither ACL migration has been applied to Supabase Production.
- Next gate: obtain authorized read-only catalog output for function owners/effective ACLs and `public` schema CREATE privileges. Keep the low-level `create_offer_v1(...)` ACL unchanged until its effective owner and SECURITY DEFINER caller relationship are verified.


### ACL regression postcondition coverage correction — 10 November 2026

- Review of `tests/sql/function-execute-acl-regression.sql` found that the pre-migration fixture and direct-`anon` grant covered seven function signatures, but the post-migration `v_function_oids` array contained only the first three. The test therefore did not assert the final ACL state for the four helper functions in `20261110080000_harden_authenticated_helper_anon_acl.sql`, despite printing `covered functions: 7`.
- Expanded the postcondition array to all seven exact signatures: `current_profile_actor_id()`, `dt_select_product_master(uuid,uuid,uuid)`, `execute_create_offer_v1(...)`, `dt_has_tenant_access(uuid)`, `dt_submit_answer(...)`, `dt_publish_product_request(uuid,uuid)`, and `is_message_participant(uuid,uuid,uuid)`. The existing loop now checks effective anon denial, effective authenticated access, and explicit absence of PUBLIC/direct-anon EXECUTE ACL entries for all seven.
- This is a regression-test coverage correction, not evidence of a Production ACL weakness. Both ACL migrations remain PR-only and have not been applied to Supabase Production.
- Code commit: `614c07a11cfc42ddc41e9d9ac40e0d28b6dc7da1`. QIMA CI #1109 and CodeQL #1061 were **IN PROGRESS** when this note was prepared; no result is claimed here. Vercel status was **PENDING**.
- Next gate: inspect the PostgreSQL job log for all seven postconditions, verify the full CI/CodeQL outcome, then append final results. Live Supabase catalog access remains blocked by PostgreSQL `28P01`; no Production vulnerability is confirmed.


### Final validation — direct-anon ACL fixture precondition — 10 November 2026

- A second review of the seven-function regression found that its pre-migration `has_function_privilege('anon', ...)` assertion could be satisfied through PUBLIC inheritance. Although the fixture issued direct `GRANT EXECUTE TO anon` statements, it did not independently assert that each direct anon ACL entry existed before the migrations. This was a test-precondition coverage gap, not evidence that either ACL migration failed or that Production was exposed.
- Commit `8ba029a3a802365946075d618d235a6aea074b17` adds an explicit `aclexplode(...)` precondition for `grantee = anon` on every one of the seven function OIDs, and fails clearly if the `anon` role is absent. The existing postconditions continue to assert no PUBLIC/direct-anon EXECUTE and an explicit authenticated EXECUTE grant for all seven signatures.
- QIMA CI [#1111](https://github.com/meridane/QimaTrade-MVP/actions/runs/42731262768) on code HEAD `8ba029a3a802365946075d618d235a6aea074b17`: **SUCCESS**. The PostgreSQL job completed CREATE_OFFER integration/concurrency, the seven-function ACL regression, legacy-message RLS, unsafe-URL guard, disposable database cleanup, prepared-transaction cleanup/restore, and participant self-enrollment RLS. Its log contains `function EXECUTE ACL regression PASS` and `covered functions: 7`.
- The browser/build job completed **SUCCESS**: npm install, dependency audit, TypeScript, Next.js build, Chromium install, and **336 passed**. npm audit reported **0 total** (0 info, low, moderate, high, critical). The log's `ECONNRESET` line comes from the explicit Playwright case that simulates an Auth transport failure and verifies the route returns a sanitized 401; the test passed.
- CodeQL [#1063](https://github.com/meridane/QimaTrade-MVP/actions/runs/42731262767): **SUCCESS**. Combined Vercel status for the code HEAD: **SUCCESS**. The preceding postcondition-array correction was also validated by QIMA CI #1110 and CodeQL #1062; CI #1109 was cancelled by the workflow's concurrency policy when the PR ref advanced, not by a test failure.
- Live Supabase catalog verification remains blocked. Project metadata lists QIMA (`yyulzlnrfcbaxovzjbnh`) as ACTIVE_HEALTHY on PostgreSQL 17.6.1.166, but the read-only `execute_sql` call still failed before query execution with PostgreSQL `28P01` for user `postgres`. The security-advisor endpoint separately returned a hibernation message inconsistent with the project metadata. No catalog rows were returned; this provider/connection inconsistency is not a database finding. Effective Production ACLs, owners, and `public` schema CREATE privileges remain unverified.
- Both ACL migrations remain PR-only and have not been applied to Supabase Production. The disposable regression proves the tested migration semantics on PostgreSQL 16 CI only; it does not establish a Production vulnerability. No Production data/schema/RLS/grants/secrets, persistent database configuration, deployment, PR merge, force-push, or branch-protection setting was changed.
- Next gate: restore an authorized read-only catalog query path or have a project maintainer run the SELECT-only owner/ACL/schema-privilege checks in the audit report. Keep the low-level `create_offer_v1(...)` ACL unchanged until its effective owner and SECURITY DEFINER caller relationship are verified.


### SECURITY DEFINER search_path metadata guard — 10 November 2026

A focused re-read of the defining migrations confirmed the execution metadata for the seven functions covered by the ACL hardening regression:

| Function | Source execution mode | Source search_path |
|---|---|---|
| `current_profile_actor_id()` | SECURITY DEFINER | `public` |
| `dt_select_product_master(uuid, uuid, uuid)` | SECURITY INVOKER | `public` |
| `execute_create_offer_v1(...)` | SECURITY DEFINER | `public` |
| `dt_has_tenant_access(uuid)` | SECURITY DEFINER | `public` |
| `dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid)` | SECURITY DEFINER | `public` |
| `dt_publish_product_request(uuid, uuid)` | SECURITY DEFINER | `public` |
| `is_message_participant(uuid, uuid, uuid)` | SECURITY DEFINER | `public` |

The separate `get_action_definition_v1(text, integer)` function is also SECURITY DEFINER with `search_path = public`; its defining migration already explicitly revokes PUBLIC and anon and grants authenticated.

The reviewed bodies schema-qualify application relations (for example `public.dt_memberships`, `public.profiles`, and `public.offers`) and the Auth identity function (`auth.uid()`). The unqualified calls observed in these bodies are PostgreSQL/PLpgSQL built-ins such as `coalesce`, `nullif`, `trim`, `now`, `jsonb_build_object`, `md5`, `hashtextextended`, `gen_random_uuid`, `to_jsonb`, and `btrim`. PostgreSQL implicitly searches `pg_catalog` before user schemas when it is not explicitly listed in `search_path`; this source review did not find an unqualified application relation/function dependency in the reviewed bodies.

No `search_path` migration is proposed. Effective `CREATE`/ `USAGE` grants on schema `public`, owners, and live function ACLs remain unverified because the read-only Supabase catalog connection is blocked by PostgreSQL `28P01`. This review therefore does not establish a Production vulnerability or prove that the live schema is safe.

The disposable ACL regression fixture now mirrors the source-audited execution modes (six SECURITY DEFINER, one SECURITY INVOKER) and `search_path=public` for all seven signatures. It asserts those `pg_proc.prosecdef` and `proconfig` attributes both before and after applying the two ACL-only migrations twice. This protects the fixture contract and confirms those ACL migrations do not alter function security metadata; it remains a synthetic PostgreSQL test, not a live catalog inspection.

Validation on the new code commit: pending GitHub Actions. No Supabase Production data/schema/RLS/grants/secrets, migration application, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.
