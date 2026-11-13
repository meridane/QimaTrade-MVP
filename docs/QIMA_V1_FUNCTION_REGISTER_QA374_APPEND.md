# QIMA V1 Function Register — QA374 Appendix

Date: 2026-11-13

## QA374 — ADMIN OPTION-only runner membership path

### Scope

Exercise the alternate positive branch of the QA373 full-runner privilege preflight. QA373 proved the ordinary non-superuser path where client roles are absent and created by the fixture. QA374 starts with existing `authenticated` and `anon` roles whose memberships grant ADMIN OPTION but explicitly deny SET ROLE.

### Intended contract

- The runner is a non-superuser owner of the disposable `qima_test` database with CREATEROLE.
- Both client roles already exist before the runner starts.
- The runner has ADMIN OPTION on each client-role membership, but `pg_has_role(..., 'SET')` is false.
- The read-only runner privilege guard accepts the role through the `pg_auth_members.admin_option` branch.
- The fixture's existing GRANT statements establish SET ROLE access before the SQL runtime uses `authenticated` and `anon`.
- The final membership direction remains one-way: the runner can SET ROLE to the client roles; neither client role becomes a member of the runner.
- The full fixture, extension, migration, SECURITY DEFINER, and concurrency path must complete.

### Runtime setup

The disposable PostgreSQL container creates:

- `qa374_admin_option_runner`: LOGIN, CREATEROLE, NOSUPERUSER, NOCREATEDB, NOREPLICATION, NOBYPASSRLS.
- `qima_test`: owned by the runner.
- Existing `authenticated` and `anon` roles.
- Both memberships with `ADMIN TRUE, INHERIT FALSE, SET FALSE`.

The test asserts the pre-run state is exactly:

`anon:false:true:false|authenticated:false:true:false`

The complete runner is then invoked using the same loopback-only `DATABASE_URL` contract. It must establish SET access and complete the existing concurrency observation.

### Safety and interpretation

All roles, databases, fixtures, extensions, and migrations are synthetic and confined to a disposable Docker PostgreSQL container. The container is removed by the existing EXIT trap. No Supabase Production data, credentials, migrations, or persistent PostgreSQL configuration are accessed or changed.

This is a runtime characterization of the runner's supported role-membership path. It does not establish that any production runner currently uses this privilege configuration.

### QA374 code-validation evidence

CI [#1361](https://github.com/meridane/QimaTrade-MVP/actions/runs/43301779435): **SUCCESS**. PostgreSQL 16 and 17.6 both completed the full runner and emitted the explicit `QA374 passed` marker; Verify passed npm audit, TypeScript, Next.js build, and 347 Playwright tests.

### QA374 CodeQL evidence

CodeQL [#1310](https://github.com/meridane/QimaTrade-MVP/actions/runs/43301779284): **SUCCESS**.


### QA374 failure triage — 13 November 2026

- QIMA CI run #1360 failed in the full-runner runtime on PostgreSQL 16 and 17.6 after the complete runner and concurrency checks had succeeded. The failing assertion expected one `pg_auth_members` row per target role.
- PostgreSQL retained separate membership rows for the original superuser grant and the runner's later GRANT. The observed post-fixture rows were `anon:false|anon:true|authenticated:false|authenticated:true`; this reflects two grantors, not missing SET access. The independent `pg_has_role(..., 'SET')` check already returned true for both roles, and the reverse-membership checks remained false.
- The regression assertion now groups by target role, requires `bool_or(set_option)` to be true, and asserts two distinct grantors per role. This preserves the intended effective-membership contract without incorrectly requiring one catalog row per role.
- CI #1360's Verify job passed, including the QA374 static contract, npm audit, TypeScript, Next.js build, and 347 Playwright tests. The two PostgreSQL jobs failed only at the over-strict row-count assertion. The corrected runtime validation subsequently passed on both PostgreSQL 16 and 17.6 in CI #1361.


### QA374 final validation — 13 November 2026

- CI [#1361](https://github.com/meridane/QimaTrade-MVP/actions/runs/43301779435): **SUCCESS**. Both PostgreSQL versions completed the full ADMIN OPTION-only runner path, verified `anon:true:2|authenticated:true:2`, retained one-way SET ROLE membership, and completed the advisory-lock concurrency observation. Both logs emitted `QA374 passed`.
- The Verify job passed the static contract, npm audit, TypeScript, Next.js production build, and 347 Playwright tests (9.4 seconds in the recorded log).
- CodeQL [#1310](https://github.com/meridane/QimaTrade-MVP/actions/runs/43301779284): **SUCCESS**.
- Vercel Preview commit status: **SUCCESS** for this HEAD. No Production deployment was requested or performed.
- The earlier CI #1360 failure remains documented as a test assertion defect caused by multiple grantors; the corrected aggregate assertion is now validated by CI #1361.


## QA375 — ADMIN OPTION does not bypass database ownership

### Scope

Characterize the negative boundary of the alternate QA374 ADMIN OPTION path. A role that can administer the existing `authenticated` and `anon` memberships must still be rejected when it does not own the disposable `qima_test` database, even when it has CREATEROLE.

### Runtime setup

- Keep `qa374_admin_option_runner` as the owner of the already initialized `qima_test` database.
- Create `qa374_admin_option_non_owner` as LOGIN, CREATEROLE, NOSUPERUSER, NOCREATEDB, NOREPLICATION, NOBYPASSRLS.
- Grant CONNECT and ADMIN OPTION on both existing client-role memberships while explicitly keeping SET FALSE.
- Assert the database owner differs from the non-owner role and the membership state is exactly `anon:false:true:false|authenticated:false:true:false`.
- Invoke the real integration runner with the non-owner URL. It must exit 4 with the existing fail-closed owner/privilege diagnostic.
- Compare the read-only catalog/data snapshot before and after rejection, including database owner, qa373/qa374 role counts, membership rows, public relation/routine counts, extension count, offers, and action-execution rows.

### Expected result

ADMIN OPTION is not a substitute for owning `qima_test`. The role is rejected before fixture DDL/DML, and the initialized database snapshot remains byte-for-byte identical.

### Safety

All objects remain inside the disposable PostgreSQL 16/17.6 container. No production database, migration, secret, persistent setting, or branch-protection configuration is accessed or modified.

### Final validation evidence — 13 November 2026

- QIMA CI [#1364](https://github.com/meridane/QimaTrade-MVP/actions/runs/43314718836): **SUCCESS**. PostgreSQL 16 and PostgreSQL 17.6 both emitted the explicit `QA375 passed` marker. The non-owner with CREATEROLE and ADMIN OPTION but no SET ROLE was rejected with exit 4 before fixture changes; before/after catalog and data snapshots matched on both versions.
- The Verify job passed the QA373/QA374/QA375 static contract, dependency audit, TypeScript, Next.js production build, Chromium setup, and all 347 Playwright tests (10.0 seconds in the recorded log).
- CodeQL [#1313](https://github.com/meridane/QimaTrade-MVP/actions/runs/43314718852): **SUCCESS**.
- The Vercel commit status was **SUCCESS** for the Preview deployment linked to this HEAD. Preview only; no Production deployment was requested or performed.
- QA375 is closed as a runtime characterization. It does not establish that any Production runner currently has this privilege configuration.

## QA376 — ADMIN OPTION must cover every existing client role

### Scope

Characterize the complementary negative boundary of QA374: ADMIN OPTION on only one existing client-facing role must not satisfy the runner privilege guard when both `anon` and `authenticated` exist. Database ownership and CREATEROLE are necessary but not sufficient when one target role cannot be entered or administered.

### Runtime setup

- Reuse the disposable, initialized `qima_test` database after QA375.
- Create `qa376_partial_admin_runner` as LOGIN, CREATEROLE, NOSUPERUSER, NOCREATEDB, NOREPLICATION, NOBYPASSRLS and make it the database owner.
- Grant CONNECT and ADMIN OPTION only on `anon`, with INHERIT FALSE and SET FALSE.
- Do not create a membership for `authenticated`; assert that its SET and ADMIN OPTION capabilities are both false.
- Assert the complete starting state is `true|true|false|false|true|false|false|true`: database owner, CREATEROLE, non-superuser, anon SET false/admin true, authenticated SET false/admin false, and no authenticated membership row.
- Invoke the real integration runner. It must exit 4 with the existing fail-closed owner/privilege diagnostic.
- Compare the read-only catalog/data snapshot before and after rejection; no fixture DDL/DML may occur.

### Expected result

The database owner is rejected because the guard requires either SET or ADMIN OPTION for every existing target role. ADMIN OPTION for `anon` cannot compensate for the missing capability on `authenticated`.

### Safety

The scenario uses only roles and an initialized database inside the disposable PostgreSQL 16/17.6 test container. It performs no Production access, persistent configuration change, migration outside the existing disposable runner, or remote connection.

### Final validation evidence — 13 November 2026

- QIMA CI [#1365](https://github.com/meridane/QimaTrade-MVP/actions/runs/43320304379): **SUCCESS**. PostgreSQL 16 and PostgreSQL 17.6 both emitted the explicit `QA376 passed` marker. The database owner with CREATEROLE and ADMIN OPTION only for `anon`, but no SET or ADMIN OPTION for `authenticated`, was rejected with exit 4 before fixture changes; before/after catalog and data snapshots matched on both versions.
- The same two runtime jobs also emitted `QA374 passed` and `QA375 passed`; the mixed/negative membership cases and their cleanup completed successfully.
- Verify passed the QA373/QA374/QA375/QA376 static contract, npm audit with 0 vulnerabilities reported (all severities), TypeScript, Next.js production build (10.7 seconds), Chromium, and 347 Playwright tests (12.9 seconds).
- CodeQL [#1314](https://github.com/meridane/QimaTrade-MVP/actions/runs/43320304348): **SUCCESS**.
- Vercel status for this final code HEAD: **build-rate-limit**; no Preview is claimed for this HEAD. The successful GitHub Actions build is not a Vercel deployment.
- QA376 is closed as a synthetic runtime characterization only; it does not establish that any Production runner has this role configuration.




## QA377 — mixed SET and ADMIN OPTION membership path

### Scope

Exercise the positive mixed-capability branch of the full CREATE_OFFER runner privilege contract. The runner evaluates SET and ADMIN OPTION independently for each existing client role; both roles do not need to use the same membership mechanism.

### Runtime setup

- Disposable PostgreSQL 16 and 17.6 containers; only the temporary qima_test database is recreated.
- qa377_mixed_membership_runner is LOGIN, CREATEROLE, NOSUPERUSER, NOCREATEDB, NOREPLICATION, NOBYPASSRLS and owns qima_test.
- anon starts with ADMIN FALSE, INHERIT FALSE, SET TRUE.
- authenticated starts with ADMIN TRUE, INHERIT FALSE, SET FALSE.
- The exact initial state is true|false|true|true|false|true|false|true|false: database owner, non-superuser, CREATEROLE, anon SET-only, authenticated ADMIN-only.
- The real run-create-offer-integration.sh is invoked using the loopback-only qima_test URL.

### Expected and observed result

The read-only runner guard accepts the mixed capability set. The fixture skips a redundant anon grant because SET is already available and uses ADMIN OPTION to establish the missing SET access for authenticated.

Both PostgreSQL versions completed the full fixture, migrations, SECURITY DEFINER checks, and same-tenant advisory-lock concurrency observation.

The final membership state is true|true|false|false: the runner can SET ROLE to both client roles, and neither client role is a member of the runner. The grantor aggregate is anon:true:1|authenticated:true:2, preserving the original anon SET grant and the separate authenticated ADMIN-to-SET grant.

### QA377 validation history — 13 November 2026

- QIMA CI [#1367](https://github.com/meridane/QimaTrade-MVP/actions/runs/43333210739): overall **FAILURE** in Verify because the first QA377 static-contract edit introduced blank lines between Bash array continuation elements. The exact failure was a Bash syntax error at line 89 near the required CREATE DATABASE token. Both PostgreSQL runtime jobs nevertheless completed successfully and emitted the explicit QA377 passed marker.
- CI #1367 did not reach npm audit, TypeScript, Next.js build, or Playwright after the static-contract failure. The later dependency-audit enforcement step failed because no audit result had been produced; this was not an npm vulnerability finding.
- Correction commit [27b7c0d](https://github.com/meridane/QimaTrade-MVP/commit/27b7c0d704c3b1580f59aa0a8e63656859079e5f) removed the blank separators so the continued Bash array remains one valid command.
- QIMA CI [#1368](https://github.com/meridane/QimaTrade-MVP/actions/runs/43333309720): **SUCCESS**. PostgreSQL 16 and PostgreSQL 17.6 both emitted QA377 passed; the Verify job passed the static contract, npm audit at the high threshold, TypeScript, Next.js production build (6.5 seconds), Chromium setup, and 347 Playwright tests (8.4 seconds).
- PostgreSQL 17.6 reported server_version_num=170006. PostgreSQL 16 completed the same QA377 runtime marker and full job successfully.
- CodeQL [#1317](https://github.com/meridane/QimaTrade-MVP/actions/runs/43333309683): **SUCCESS**.
- Vercel Preview commit status for code commit 27b7c0d: **SUCCESS** ([Preview](https://vercel.com/bmk1/qimatrade-mvp/13RPVaMPLTtz8ybFSXimsmJhsQMG)). This is Preview only; no Production deployment was requested or performed.
- QA377 is a synthetic runtime characterization only. It does not establish that any Production runner currently uses this privilege configuration.

### Safety

All roles, database objects, fixtures, extensions, and migrations are confined to disposable PostgreSQL containers. The EXIT trap removes the container and temporary files. No Supabase Production data, credentials, migration, persistent PostgreSQL setting, remote connection, or branch-protection configuration is accessed or modified.


## QA378 — reverse mixed SET and ADMIN OPTION membership path

### Scope

Exercise the reverse positive mixed-capability branch of the full CREATE_OFFER runner privilege contract. QA377 covered anon SET-only plus authenticated ADMIN OPTION-only; QA378 swaps those capabilities to prove the guard and fixture handle each target role independently in both directions.

### Runtime setup

- Recreate only the temporary qima_test database inside the disposable PostgreSQL 16 or 17.6 container.
- Create qa378_reverse_mixed_runner as LOGIN, CREATEROLE, NOSUPERUSER, NOCREATEDB, NOREPLICATION, NOBYPASSRLS and make it the qima_test owner.
- Grant anon with ADMIN TRUE, INHERIT FALSE, SET FALSE.
- Grant authenticated with ADMIN FALSE, INHERIT FALSE, SET TRUE.
- Assert the exact initial state true|false|true|false|true|false|true|false|true.
- Invoke the real run-create-offer-integration.sh using the loopback-only qima_test URL.

### Expected result

The read-only runner guard accepts the reverse mixed capability set. The fixture skips a redundant authenticated grant because SET is already available and uses ADMIN OPTION to establish the missing SET access for anon. The complete fixture, migrations, SECURITY DEFINER checks, and same-tenant advisory-lock concurrency observation must succeed.

The final state must show SET access to both client roles, no reverse membership, and the grantor aggregate anon:true:2|authenticated:true:1.

### Safety and interpretation

All roles, the database, fixtures, extensions, and migrations remain in the disposable Docker PostgreSQL container. The EXIT trap removes the container and temporary files. No Production database, credentials, migration, persistent PostgreSQL setting, or remote connection is used.

This is a synthetic runtime characterization only; it does not establish that any Production runner currently uses this privilege configuration.

### QA378 code-validation evidence

Pending CI validation on PostgreSQL 16 and 17.6. No runtime pass is claimed until both jobs emit the explicit QA378 passed marker.

### QA378 CodeQL evidence

Pending.
