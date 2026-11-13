# QA380 — ADMIN OPTION is not transitive across membership

## Scope

Characterize the boundary between membership ADMIN OPTION on an intermediate bridge role and ADMIN OPTION on roles held by that bridge. The runner is a non-superuser database owner with CREATEROLE, but it must not treat the bridge's administration rights as direct administration rights over `anon` or `authenticated`.

## Disposable PostgreSQL setup

- Run only in the pinned PostgreSQL 16 and 17.6 Docker containers used by the existing runner-privilege runtime test.
- Create `qa380_admin_bridge` as NOLOGIN NOINHERIT.
- Create `qa380_admin_runner` as LOGIN, CREATEROLE, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOREPLICATION, NOBYPASSRLS and owner of the disposable `qima_test` database.
- Grant `anon` and `authenticated` to the bridge with ADMIN TRUE, INHERIT FALSE, SET FALSE.
- Grant the bridge to the runner with ADMIN TRUE, INHERIT FALSE, SET FALSE.
- Assert the runner is a direct member with ADMIN OPTION on the bridge, an indirect member of both client roles, has no SET path to any of the three roles, and has no direct ADMIN OPTION membership on either client role.

## Expected result

The real `run-create-offer-integration.sh` must reject the runner with exit code 4 before fixture DDL/DML. The test compares public relations, public routines, extensions, database ownership, QA380 roles, and all memberships involving QA380 roles before and after rejection. The snapshots must be identical.

## Interpretation

PostgreSQL documents ADMIN as the ability to grant or revoke membership in the specific role on which the option is held. It documents transitive SET ROLE separately, requiring SET TRUE on every membership edge. This characterization checks that ADMIN OPTION on the bridge is not mistaken for ADMIN OPTION on its member roles. It does not claim any Production role configuration or vulnerability.

References:
- [PostgreSQL 16 GRANT — role membership options](https://www.postgresql.org/docs/16/sql-grant.html)
- [PostgreSQL 16 Role Membership](https://www.postgresql.org/docs/16/role-membership.html)

## Safety

All roles, memberships, database objects, fixtures, and temporary files remain inside the disposable PostgreSQL 16/17.6 containers. The EXIT trap removes the container and temporary files. No Supabase Production data, credentials, migrations, persistent PostgreSQL settings, remote publisher, or branch-protection configuration is accessed or modified.

## QA380 validation evidence

- QIMA CI [#1375](https://github.com/meridane/QimaTrade-MVP/actions/runs/43346649535): **SUCCESS**. PostgreSQL 16 and PostgreSQL 17.6 both emitted the explicit `QA380 passed` marker. In each environment, the runner exited 4 before fixture changes and the database, ownership, role, and membership snapshots remained unchanged.
- Verify passed the QA373–QA380 static contract, high-threshold npm audit, TypeScript, Next.js build, Chromium installation, and 347/347 Playwright tests.
- CodeQL [#1324](https://github.com/meridane/QimaTrade-MVP/actions/runs/43346649404): **SUCCESS**.
- Vercel Preview: **FAILURE** with `build-rate-limit`; no Preview deployment is claimed for this HEAD. No Production deployment occurred.
- Interpretation: this is an isolated characterization of PostgreSQL membership semantics, not evidence of a Production role configuration or vulnerability.
