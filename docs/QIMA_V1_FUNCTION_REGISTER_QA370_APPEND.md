# QA370 — database-scoped role settings and default ACL bootstrap state

Date: 2026-11-13 (KST)  
Repository: meridane/QimaTrade-MVP  
Pull request: #26 — fix/create-offer-status-contract  
Work branch: work/qa370-role-settings-default-acl-20261113-0100

## Decision

The CREATE_OFFER bootstrap preflight now treats these as database-local residue:

- Any pg_db_role_setting row whose setdatabase equals the OID of current_database().
- Any row in the current database's pg_default_acl catalog.

It deliberately does not reject:

- pg_db_role_setting rows with setdatabase = 0, which represent role defaults applying across databases.
- Settings owned by another database.
- Default-ACL rows in another database, because pg_default_acl is database-local.

No extension-membership exclusion is applied to pg_default_acl: these rows represent default privilege policy for future objects in the current database, not extension-owned catalog members.

## Runtime characterization

The runtime test creates two unique databases from template0 and two unique NOLOGIN roles. It verifies:

1. Both databases start with an empty preflight.
2. A cluster-wide role default (ALTER ROLE ... SET, setdatabase = 0) does not poison either database.
3. ALTER DATABASE and ALTER ROLE ... IN DATABASE settings in the other database are detected only in that database.
4. Equivalent database and role-in-database settings in the current database are detected and their reset returns the preflight to empty.
5. A database-wide default ACL (defaclnamespace = 0) is detected without creating a table.
6. A schema-specific default ACL is also detected without creating a table.
7. A default ACL in the other database does not poison the current database.
8. Reset/revoke operations return each disposable database to empty.
9. EXIT cleanup removes both databases and both roles and verifies that no test resources remain.

The script accepts only the existing loopback qima_test:5432 service URL as an administrative entry point. It never drops or modifies qima_test itself. All mutations are confined to generated databases and roles, and cleanup uses DROP DATABASE ... WITH (FORCE).

## Files

- .github/workflows/ci.yml
- tests/sql/create-offer-bootstrap-preflight.sql
- tests/sql/run-create-offer-integration.sh
- tests/sql/test-create-offer-integration-repeat-guard.sh
- tests/sql/test-create-offer-bootstrap-preflight.sh
- tests/sql/test-create-offer-database-settings-acl-preflight.sh
- tests/sql/test-create-offer-database-settings-acl-runtime.sh
- docs/QIMA_V1_FUNCTION_REGISTER.md
- docs/QIMA_V1_FUNCTION_REGISTER_QA370_APPEND.md

## Validation

- Initial code CI: pending.
- PostgreSQL 16 runtime characterization: pending.
- PostgreSQL 17.6 runtime characterization: pending.
- Static preflight contract: pending.
- CodeQL: pending.
- Vercel: not requested; no deployment is part of QA370.

## Safety boundary

No Supabase Production data, schema, migration, SQL function, RLS policy, grant, secret, or persistent PostgreSQL configuration was modified. No Production deployment, PR merge, force update, or branch-protection change occurred. The tests do not establish a Production vulnerability or incident.

MKT-1.2 remains unapproved and MKT-1.3 remains decision-required.

## PostgreSQL documentation

- PostgreSQL 16 pg_db_role_setting: https://www.postgresql.org/docs/16/catalog-pg-db-role-setting.html
- PostgreSQL 17 pg_db_role_setting: https://www.postgresql.org/docs/17/catalog-pg-db-role-setting.html
- PostgreSQL 16 pg_default_acl: https://www.postgresql.org/docs/16/catalog-pg-default-acl.html
- PostgreSQL 17 pg_default_acl: https://www.postgresql.org/docs/17/catalog-pg-default-acl.html
