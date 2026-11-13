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

## First runtime attempt and test-oracle correction

QIMA CI [#1377](https://github.com/meridane/QimaTrade-MVP/actions/runs/43352042983) executed the QA381 catalog setup on both PostgreSQL 16 and 17.6, then stopped at the first effective-state assertion. For qa381_default_target, the tuple was false|false|true: effective SET and USAGE were false, while the third field from has_table_privilege('qa381_create_role_runner', ...) was true.

That helper result did not match the test's intended membership-only tuple. It is treated as a test-oracle mismatch, not as evidence of a Production privilege leak or a confirmed vulnerability. The test now reports only pg_has_role(..., 'SET') and pg_has_role(..., 'USAGE') in the effective-membership tuple. Direct object access remains independently tested by actually executing SELECT as qa381_create_role_runner for each GUC setting; that runtime assertion is the behavioral oracle for table ACL inheritance.

CI #1377 completed with the Verify job successful (including npm audit at its configured high-severity threshold, TypeScript, Next.js build, and 347/347 Playwright tests), but both PostgreSQL jobs failed at the QA381 assertion before the direct-SELECT probes ran. The corrected test must pass on both pinned versions before QA381 is closed.

## QA381 validation evidence

Pending retest. No QA381 runtime pass is claimed until both pinned PostgreSQL versions emit the explicit QA381 passed marker and the complete CI Verify job succeeds.


## Second runtime attempt — explicit PUBLIC ACL isolation and failure diagnostics

QIMA CI [#1378](https://github.com/meridane/QimaTrade-MVP/actions/runs/43357796040) completed the QA374–QA380 scenarios on both PostgreSQL 16 and 17.6, then failed at the first QA381 direct-SELECT probe: a SELECT as `qa381_create_role_runner` succeeded for `qa381_default_target`, although the recorded effective membership tuple was SET=false / USAGE=false. This is a disposable test setup/ACL discrepancy. It is not evidence of a Production privilege leak and does not confirm a vulnerability.

The runtime fixture now explicitly revokes all privileges on the temporary QA381 schema and table from PUBLIC before granting USAGE/SELECT to the four target roles. It asserts with `aclexplode` that no PUBLIC schema or table ACL remains. If a direct-SELECT expectation still fails, the test prints the actual session/current user, role attributes, effective schema/table privileges, object owners and ACLs, and the creator's exact membership row for the target role. The expected SELECT/SET ROLE matrix is unchanged.

CI #1378 Verify passed the QA373–QA381 static contract, `npm audit --audit-level=high`, TypeScript, Next.js build, and 347/347 Playwright tests. Both PostgreSQL runtime jobs failed at the QA381 direct-SELECT probe. CodeQL #1327 and the Vercel Preview check succeeded for the previous code HEAD. QA381 remains pending until the revised runtime emits its explicit marker on PostgreSQL 16 and 17.6 and the complete Verify job succeeds.

Safety: this correction is limited to disposable QA schema/table ACLs, diagnostics and documentation. No Production database, Supabase credential, migration, persistent PostgreSQL setting, remote publisher, or branch-protection configuration is accessed or modified.


## Third runtime attempt — parenthesize NOT EXISTS before text casts

QIMA CI [#1379](https://github.com/meridane/QimaTrade-MVP/actions/runs/43370734121) completed the QA374–QA380 scenarios on both PostgreSQL 16 and 17.6, then stopped while evaluating the QA381 PUBLIC-ACL isolation query. Both servers returned the SQL error `argument of NOT must be type boolean, not type text`. The failure occurred before the direct SELECT/SET ROLE matrix, so it does not establish any unexpected object access and is not evidence of a Production privilege leak or a confirmed vulnerability.

Root cause: the query wrote `NOT EXISTS (subquery)::text`. PostgreSQL applied the cast to the EXISTS result before the unary NOT, leaving NOT with text rather than boolean. The query now explicitly groups each predicate as `(NOT EXISTS (subquery))::text` before concatenating the two boolean results. The static contract additionally requires exactly two parenthesized predicates and two post-predicate text casts, preventing this precedence regression.

CI #1379 Verify succeeded: the QA373–QA381 static contract, npm audit at its configured high-severity threshold, TypeScript, Next.js build, and 347/347 Playwright tests all passed. Both PostgreSQL jobs failed at the PUBLIC-ACL SQL expression after QA380. CodeQL #1328 and the Vercel status check succeeded for this HEAD. QA381 remains pending until both PostgreSQL 16 and 17.6 complete the direct SELECT/SET ROLE matrix, cleanup, and explicit QA381 marker on the corrected query.

Safety: this correction changes only the disposable QA381 test query, its static regression assertion, and documentation. No Production database, Supabase credential, migration, persistent PostgreSQL setting, remote publisher, or branch-protection configuration is accessed or modified.


## Fourth runtime diagnostic — trace owner and column-level privilege paths

QIMA CI [#1380](https://github.com/meridane/QimaTrade-MVP/actions/runs/43374675580) completed the QA374–QA380 runtime scenarios on PostgreSQL 16 and 17.6, then failed at the first QA381 direct-SELECT probe for `qa381_default_target`. Both servers reported that a SELECT as `qa381_create_role_runner` returned successfully even though the target membership row was ADMIN TRUE / INHERIT FALSE / SET FALSE and `pg_has_role(..., 'USAGE')` plus `pg_has_role(..., 'SET')` were false. The PUBLIC ACL revocation check had passed.

The captured ACL output showed the schema and table owned by `postgres`, with grants to the four QA381 target roles and no PUBLIC ACL entry. The existing failure diagnostic did not yet enumerate every direct/effective membership of the runner, its USAGE relationship to the database/schema/table owners and `pg_database_owner`, or column-level ACLs. The next diagnostic-only revision adds those observations, including `has_any_column_privilege` and per-column `has_column_privilege`, without weakening the expected SELECT/SET ROLE matrix or changing any grant.

This remains an unexplained behavior in the disposable test setup. It is not evidence of a Production privilege leak and does not confirm a vulnerability. QA381 remains pending until the expanded diagnostic identifies the access path and the complete four-setting matrix plus cleanup passes on PostgreSQL 16 and 17.6.

CI #1380 Verify succeeded, including the QA373–QA381 static contract, `npm audit --audit-level=high`, TypeScript, Next.js build, and 347/347 Playwright tests. Both PostgreSQL runtime jobs failed at the QA381 direct-SELECT probe. CodeQL [#1329](https://github.com/meridane/QimaTrade-MVP/actions/runs/43374675588) and the Vercel status check succeeded for the previous HEAD. No zero-findings claim is made for npm audit severities below its configured threshold.

Safety: this revision adds diagnostics only to the disposable PostgreSQL QA381 fixture and documents the observed failure. No Production database, Supabase credential, migration, persistent PostgreSQL setting, remote publisher, or branch-protection configuration is accessed or modified.


## Fifth runtime correction — isolate per-target object ACLs

QIMA CI [#1381](https://github.com/meridane/QimaTrade-MVP/actions/runs/43382293694) completed the QA374–QA380 runtime scenarios on PostgreSQL 16 and 17.6, then failed at the first QA381 direct-SELECT probe for `qa381_default_target`. The diagnostic output now explains the result: the fixture had granted schema USAGE and table SELECT to all four target roles on one shared schema/table. At that point the runner already had INHERIT-enabled memberships on `qa381_inherit_target` and `qa381_both_target`, so it inherited USAGE and SELECT through those other roles while the test was trying to isolate the empty-GUC target. This explains both the successful SELECT and the `has_schema_privilege=true` diagnostic; it is fixture cross-contamination, not an ADMIN OPTION bypass or evidence of a Production privilege leak.

The membership matrix itself matched the intended behavior: default target USAGE/SET false/false; set target false/true; inherit target true/false; both target true/true. The correction gives each target its own schema and probe table, grants USAGE and SELECT only to that corresponding role, checks all four PUBLIC ACLs together, and runs each direct SELECT and SET ROLE probe against its own object. Cleanup drops all four schemas and verifies that no `qa381_probe_%` schema or QA381 role remains. The expected matrix is unchanged; no assertion is weakened.

CI #1381 Verify succeeded, including the QA373–QA381 static contract, `npm audit --audit-level=high`, TypeScript, Next.js build, and 347/347 Playwright tests. Both PostgreSQL 16 and 17.6 failed at the contaminated shared-table SELECT probe. CodeQL [#1330](https://github.com/meridane/QimaTrade-MVP/actions/runs/43382293752) and the Vercel status check succeeded for that previous HEAD. QA381 remains pending until the isolated per-target schemas/tables pass the full direct SELECT/SET ROLE matrix and cleanup on both pinned PostgreSQL versions, with the explicit QA381 marker.

Safety: this correction changes only disposable QA381 schemas/tables, assertions, and documentation. It does not modify the CREATE_OFFER implementation, Production data, Supabase credentials, migrations, persistent PostgreSQL settings, remote publishing, or branch-protection configuration.


Validation follow-up: CI [#1382](https://github.com/meridane/QimaTrade-MVP/actions/runs/43386905186) was triggered for code HEAD `a2b061f4879d090d3e64537019c260a6407035fe`. At the latest check, the Verify job had passed the QA373–QA381 static contract, npm audit at the configured high-severity threshold, TypeScript, and the Next.js production build; Playwright was still running. The PostgreSQL 16 and 17.6 jobs were still in progress and had not yet reached the QA381 runtime step. CodeQL [#1331](https://github.com/meridane/QimaTrade-MVP/actions/runs/43386905174) was in progress and the Vercel status was pending. This is an interim status, not a QA381 pass. The CI workflow ignores documentation-only changes under `docs/**`, so this evidence update does not itself retrigger the workflow.