# QIMA — Live Supabase Security Snapshot (read-only)

Date: 2026-10-22  
Project: `QIMA` (`yyulzlnrfcbaxovzjbnh`, region `ap-southeast-1`)  
Purpose: record read-only observations from the connected Supabase project to guide staging tests and remediation.

## Safety boundary

- This review used read-only project metadata, migration listing, table metadata, Security Advisor results and catalog SELECT queries.
- No rows were changed, no migration was applied, and no production function or policy was modified.
- The connected project is the live QIMA project. Do not run adversarial write tests against it. Use a disposable staging project with synthetic users and tenants.

## GitHub validation at review time

Commit checked: `eb2a2eb74bdc80a72428c18fb4f1600ad7d6107a`

- QIMA CI: **success** — dependency security audit, TypeScript check, production build, and Playwright smoke tests passed.
- QIMA CodeQL Security: **success**.
- These checks do not prove tenant isolation, RLS correctness, immutable history, or production database behavior.

## Supabase inventory

- 157 applied migrations were reported by the connected project.
- The latest migration reported is `20261010032725 qima_event_architecture_v1`.
- 102 public tables were returned by the table inventory.
- Migration history, repository migrations, deployed schema, grants, and function definitions still require a structured drift comparison.

## Security Advisor findings

The connected project's Security Advisor reported the following at approximately 2026-10-22 13:32 UTC:

| Finding | Severity | Count | Interpretation |
|---|---|---:|---|
| RLS enabled but no policies | INFO | 31 | Access may still be blocked, but each table needs grants, function and call-path review. |
| Mutable function search_path | WARN | 12 | Review each function; set a safe search_path where appropriate. |
| RLS disabled in public schema | ERROR | 2 | `public.attribute_options` and `public.attribute_units`. |
| Extension in public schema | WARN | 1 | `pg_trgm`; review whether moving it is safe and supported. |
| SECURITY DEFINER executable by anon | WARN | 4 | Review function intent and revoke anon execution if not needed. |
| SECURITY DEFINER executable by authenticated | WARN | 18 | Review each function's authorization checks; this finding alone does not establish exploitability. |
| Leaked-password protection disabled | WARN | 1 | Auth configuration follow-up; not changed by this review. |

Security Advisor remediation references:
- RLS enabled without policies: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- Mutable function search_path: https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable
- RLS disabled in public schema: https://supabase.com/docs/guides/database/database-linter?lint=0013_rls_disabled_in_public
- Extension in public schema: https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public
- SECURITY DEFINER executable by anon: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- SECURITY DEFINER executable by authenticated: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- Leaked-password protection: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Read-only catalog observations

The table inventory/catalog query reported:

| Table | RLS enabled | Observed policy names / commands |
|---|---:|---|
| `attribute_options` | No | none |
| `attribute_units` | No | none |
| `dt_memberships` | Yes | `dt_memberships_select` (SELECT) |
| `dt_nodes` | Yes | `dt_nodes_select` (SELECT) |
| `dt_observations` | Yes | `dt_observations_select` (SELECT) |
| `dt_rules` | Yes | `dt_rules_select` (SELECT) |
| `dt_sessions` | Yes | `dt_sessions_all` (ALL) |
| `dt_transitions` | Yes | `dt_transitions_all` (ALL) |
| `product_requests` | Yes | `product_requests_insert_own_tenant`, `product_requests_select_own_tenant`, `product_requests_update_own` |

A separate role-grant query reported that `authenticated` has SELECT, INSERT, UPDATE and DELETE table privileges on `dt_sessions`. This is a high-priority review item because the application expects the answer RPC to enforce state-machine transitions. RLS policy conditions and effective role behavior must be verified in staging before any change. Do not simply revoke grants in production: the supported product-selection path and any other legitimate writes must be identified first.

The role-grant query also reported SELECT-only table privileges for `authenticated` on `dt_observations` and `dt_transitions`, although both tables had policies whose command was listed as ALL. Effective behavior depends on both privileges and policies; test direct INSERT/UPDATE/DELETE attempts with a real authenticated staging role.

For `product_requests`, the role-grant query reported DELETE privilege for `authenticated`, while the policy inventory showed SELECT, INSERT and UPDATE policies but no DELETE policy. Verify the effective denial in staging and review whether the DELETE grant should be revoked.

For `attribute_options` and `attribute_units`, Security Advisor reported RLS disabled. The role-grant inventory showed SELECT for `authenticated`; no application or public behavior should be inferred solely from these facts. Confirm intended catalog visibility and grants before changing access.

## Required next actions

1. Create or identify a **disposable staging Supabase project**; do not use live QIMA for mutation tests.
2. Reconcile all 157 applied migrations with repository migrations and deployed schema before proposing DDL.
3. Export policies, grants, and full definitions for the flagged SECURITY DEFINER functions, especially Decision Tree and Action Engine RPCs.
4. Add staging integration tests for two tenants, session ownership, direct session DML, invalid transitions, replay/idempotency, and append-only observations/transitions.
5. Fix each confirmed issue with a reviewed migration, test it in staging, then request explicit approval before production changes.

## Status

- Static repository CI and CodeQL: passed for the commit above.
- Live project inspection: read-only observations collected.
- Multi-tenant adversarial integration tests: **not yet executed**.
- Production database changes: **none**.
