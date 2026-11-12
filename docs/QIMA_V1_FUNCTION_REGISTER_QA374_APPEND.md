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

Pending the first CI run for the QA374 code HEAD.

### QA374 CodeQL evidence

Pending the first CodeQL run for the QA374 code HEAD.

