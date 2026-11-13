# QA381 — CREATEROLE self-grant GUC semantics

## Scope

Characterize PostgreSQL 16+ `createrole_self_grant` behavior when a non-superuser with CREATEROLE creates roles. Distinguish the implicit bootstrap-superuser ADMIN membership from the optional creator-issued INHERIT and SET membership controlled by the GUC.

This is a PostgreSQL behavior characterization for the disposable CREATE_OFFER test environment. It does not assert that the Production runner changes this GUC or creates these roles.

## Disposable PostgreSQL setup

- Run inside the existing pinned PostgreSQL 16 and 17.6 disposable containers used by `test-create-offer-runner-privilege-runtime.sh`.
- Assert `pg_settings` reports an empty default and `context = 'user'` for `createrole_self_grant`.
- Create `qa381_create_role_runner` with LOGIN and CREATEROLE, but NOINHERIT, NOSUPERUSER, NOCREATEDB, NOREPLICATION, and NOBYPASSRLS.
- Connect as that non-superuser and create four NOLOGIN roles with the session GUC set to an empty string, `set`, `inherit`, and `set,inherit`.
- Inspect every matching `pg_auth_members` row, its grantor, ADMIN/INHERIT/SET options, and the effective `pg_has_role` results.
- Grant SELECT on one disposable probe table to each target role. Verify direct SELECT is available only for INHERIT-enabled memberships and verify SET ROLE is available only for SET-enabled memberships.
- Drop the probe schema and all temporary roles; assert no QA381 role or schema remains.

## Expected catalog and effective behavior

| `createrole_self_grant` | Membership rows | Creator-issued option row | Effective SET | Effective INHERIT/USAGE | Direct SELECT | SET ROLE |
|---|---:|---|---|---|---|---|
| empty | 1 | none | false | false | denied | denied |
| `set` | 2 | SET TRUE | true | false | denied | allowed |
| `inherit` | 2 | INHERIT TRUE | false | true | allowed | denied |
| `set,inherit` | 2 | SET TRUE + INHERIT TRUE | true | true | allowed | allowed |

Every created role must retain the separate implicit bootstrap ADMIN grant with ADMIN TRUE, INHERIT FALSE, SET FALSE. A non-empty GUC value adds a distinct creator-issued membership row; it does not replace or broaden the bootstrap ADMIN grant.

## Interpretation

The GUC is a convenience for the creator to grant itself INHERIT and/or SET on a role it just created. It does not confer ADMIN OPTION on unrelated pre-existing roles and does not change the runner's direct ADMIN/SET checks for `anon` and `authenticated`. Role attributes such as CREATEROLE are not inherited as ordinary object privileges; they require SET ROLE to a role carrying that attribute.

References:
- [PostgreSQL 16 client connection defaults — createrole_self_grant](https://www.postgresql.org/docs/16/runtime-config-client.html#GUC-CREATEROLE-SELF-GRANT)
- [PostgreSQL 17 client connection defaults — createrole_self_grant](https://www.postgresql.org/docs/17/runtime-config-client.html#GUC-CREATEROLE-SELF-GRANT)
- [PostgreSQL 16 role attributes — automatic ADMIN grant to CREATEROLE creators](https://www.postgresql.org/docs/16/role-attributes.html)
- [PostgreSQL 16 CREATE ROLE implementation](https://github.com/postgres/postgres/blob/REL_16_STABLE/src/backend/commands/user.c)

## Safety

All operations are restricted to the existing disposable PostgreSQL 16/17.6 test containers. The test creates only QA381-prefixed roles and one QA381 schema, then explicitly removes them and verifies cleanup. The container EXIT trap remains the final cleanup boundary. No Production database, Supabase credential, migration, persistent PostgreSQL setting, remote publisher, or branch-protection configuration is accessed or modified.

## QA381 validation evidence

Pending. No QA381 runtime pass is claimed until both pinned PostgreSQL versions emit the explicit `QA381 passed` marker and the complete CI Verify job succeeds.
