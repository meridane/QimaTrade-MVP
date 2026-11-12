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

### Initial validation evidence

Pending the first QA375 CI run.
