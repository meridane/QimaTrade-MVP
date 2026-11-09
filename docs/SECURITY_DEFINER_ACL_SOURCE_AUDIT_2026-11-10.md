# QIMA — SECURITY DEFINER and function EXECUTE ACL source audit

**Date:** 10 November 2026 (KST)  
**Repository:** `meridane/QimaTrade-MVP`  
**PR:** #26  
**Reviewed branch HEAD:** `a1152a8831509e472f2817d7c46743e7bbf99f82`  
**Scope:** read-only review of all 18 SQL migrations present in `supabase/migrations/`, relevant application call sites, and existing security review notes.

## Executive result

**Source review complete; effective live ACL verification BLOCKED. No production vulnerability is confirmed by this report.**

The migration source shows several functions for which the branch does not explicitly establish a non-PUBLIC execute ACL, and several SECURITY DEFINER functions use `SET search_path = public`. These are source-level hardening candidates, not proof of effective grants or exploitability. `CREATE OR REPLACE FUNCTION` preserves an existing function ACL, and grants in migrations are additive; the effective catalog state must be inspected before changing privileges.

No migration was applied to Supabase Production, no production data or schema was changed, and no live Supabase function ACL or search_path was modified. The follow-up section below records a repository-only hardening migration and its disposable-CI regression.

## Validation baseline read before this audit

- PR #26 is open, draft, and mergeable; base `main`, head `fix/create-offer-status-contract`.
- Exact PR HEAD: `a1152a8831509e472f2817d7c46743e7bbf99f82`, commit message: `docs(qima): record QA314 PostgreSQL pass and fixture fix`.
- QIMA CI #1099: **SUCCESS**. Both `CREATE_OFFER PostgreSQL integration tests` and `Typecheck, audit, build and browser tests` passed; Playwright reported **336/336**.
- CodeQL #1051: **SUCCESS**.
- Combined commit status: Vercel **SUCCESS**.
- The preceding code commit `c4b7b348978d29a13205dec3a003c66e0d026e46` contains the QA314 SQL fixture correction; the latest HEAD adds the final QA314 validation record.

These checks validate the repository test/build pipeline. They do not establish the effective privileges of the live Supabase project.

## Migration-source inventory

All 18 files under `supabase/migrations/` on the reviewed branch were scanned for function definitions, SECURITY DEFINER, search_path settings, and EXECUTE grant/revoke statements.

| Function / signature | Execution mode | Source search_path | ACL statements in branch migrations | Source-level assessment |
|---|---|---|---|---|
| `public.dt_has_tenant_access(uuid)` | SECURITY DEFINER | `public` | REVOKE PUBLIC; GRANT authenticated | Explicit PUBLIC revoke; no explicit direct-`anon` revoke. |
| `public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid)` | SECURITY DEFINER | `public` | REVOKE PUBLIC; GRANT authenticated | Explicit PUBLIC revoke. The earlier nine-argument SECURITY INVOKER overload is explicitly dropped by the later security-gate migration. |
| `public.dt_publish_product_request(uuid, uuid)` | SECURITY DEFINER | `public` | REVOKE PUBLIC; GRANT authenticated | Function checks `auth.uid() = p_user_id`; explicit PUBLIC revoke. |
| `public.current_profile_actor_id()` | SECURITY DEFINER | `public` | GRANT authenticated; no explicit REVOKE in its defining migration | ACL is not established by this migration alone; inspect the effective ACL. |
| `public.get_action_definition_v1(text, integer)` | SECURITY DEFINER | `public` | REVOKE PUBLIC, anon; GRANT authenticated | Most explicit client-role ACL among the reviewed functions. |
| `public.execute_create_offer_v1(...)` | SECURITY DEFINER | `public` | Later migration GRANTs authenticated; no explicit REVOKE in the reviewed definition/restriction migrations | Existing ACL is preserved by CREATE OR REPLACE; inspect effective ACL before any change. |
| `public.is_message_participant(uuid, uuid, uuid)` | SECURITY DEFINER | `public` | REVOKE PUBLIC; GRANT authenticated | Explicit PUBLIC revoke; no explicit direct-`anon` revoke. |
| `public.dt_select_product_master(uuid, uuid, uuid)` | SECURITY INVOKER (not SECURITY DEFINER) | `public` | GRANT authenticated; no explicit REVOKE in its defining migration | Candidate default-PUBLIC EXECUTE exposure; invoker privileges and RLS still govern table access. |

The branch's `20261027100000_restrict_direct_create_offer_rpc.sql` also revokes PUBLIC and authenticated EXECUTE on the low-level `public.create_offer_v1(...)` function, then grants authenticated EXECUTE on `execute_create_offer_v1(...)`. The low-level function definition itself is not present in the branch migration set, and that migration does not explicitly revoke a possible direct grant to `anon`. Its live definition and effective ACL therefore remain unverified.

### Important ACL semantics

- `GRANT EXECUTE ... TO authenticated` does not remove an existing PUBLIC or anon grant.
- `REVOKE ... FROM PUBLIC` removes privileges inherited through the PUBLIC pseudo-role, but does not remove a separate direct grant to `anon`.
- `CREATE OR REPLACE FUNCTION` does not reset an existing function's ACL.
- Absence of a REVOKE statement in one migration is not proof that the effective ACL is public: prior migrations, owner defaults, and project-level default privileges may affect the catalog.
- No `ALTER DEFAULT PRIVILEGES` statement was found in the 18 reviewed branch migrations. This does not exclude default privileges configured outside this repository.

## search_path review

The SECURITY DEFINER functions listed above pin `search_path` to `public`. The reviewed bodies schema-qualify application tables/functions (for example `public.dt_memberships`, `public.profiles`, and `auth.uid()`). The source review did not establish that an untrusted role can create objects in schema `public`, nor did it identify a demonstrated shadow-object exploit.

The effective `USAGE` and `CREATE` privileges on `public` for `anon` and `authenticated` must be checked. If no untrusted schema objects are needed by these function bodies, a future reviewed hardening change could consider pinning `search_path` to `pg_catalog` only, after checking every unqualified built-in/extension dependency in a disposable PostgreSQL environment. No search_path change is proposed or applied in this audit.

## Application call-site checks

- `lib/decision-tree/server.ts` calls `dt_select_product_master` through the authenticated server Supabase client. The user ID passed to the RPC comes from `supabase.auth.getUser()`; the SQL function is SECURITY INVOKER, so caller table privileges and RLS remain relevant.
- `app/api/decision-tree/select-product/route.ts` validates the required session/product identifiers and delegates to that server helper.
- The CREATE_OFFER runtime calls the supported `execute_create_offer_v1` wrapper. The wrapper itself checks non-null `auth.uid()`, tenant membership, and that the supplied provider actor equals the caller's profile actor. Those checks do not replace a catalog ACL review.
- `current_profile_actor_id()` is referenced by the offers INSERT RLS policy; its effective ACL and schema visibility should be inspected separately from direct RPC exposure.

## Live catalog verification blocker

A read-only catalog query was attempted against the project reference already documented by the repository, `yyulzlnrfcbaxovzjbnh`. No query result was returned:

- `execute_sql` failed before query execution with PostgreSQL `28P01`: password authentication failed for user `postgres`.
- `list_tables` failed before query execution with PostgreSQL `28P01`: password authentication failed for user `supabase_read_only_user`.

These are connection/authentication failures, not database findings. No data rows were read or changed. No retries, credential changes, migrations, or writes were attempted.

Consequently, the following remain **unverified**: effective `proacl` for each function, direct grants to `anon`, function owners, `has_function_privilege` results, schema `USAGE/CREATE` grants, and project-level default privileges.

## Exact read-only query required to close the blocker

An authorized maintainer or restored read-only connector should run a catalog-only query equivalent to:

```sql
SELECT
  n.nspname,
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS identity_arguments,
  p.prosecdef AS security_definer,
  p.proconfig AS function_settings,
  pg_get_userbyid(p.proowner) AS owner_name,
  p.proacl,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'core', 'private')
  AND (
    p.prosecdef
    OR p.proname IN ('create_offer_v1', 'dt_select_product_master')
  )
ORDER BY n.nspname, p.proname, identity_arguments;

SELECT
  role_name,
  has_schema_privilege(role_name, 'public', 'USAGE') AS public_usage,
  has_schema_privilege(role_name, 'public', 'CREATE') AS public_create
FROM (VALUES ('anon'), ('authenticated')) AS roles(role_name);
```

The resulting catalog output should be reviewed before applying any targeted ACL or search_path migration to Supabase Production. In particular, do not bulk-revoke EXECUTE from helpers used by authenticated RLS policies.

## Next gate

1. Restore authorized read-only catalog access or have a project maintainer run the two SELECT-only checks above.
2. Compare effective function ACLs and owners against the source inventory.
3. Confirm whether `anon` or `authenticated` can CREATE in `public`.
4. Trace all application/RLS callers before changing any function ACL.
5. If a real mismatch is confirmed, prepare a minimal new migration (do not rewrite historical migrations), plus positive/negative PostgreSQL tests in a disposable database.
6. Re-run CI and CodeQL on the resulting branch commit. Do not apply anything to Supabase Production without a separately authorized review.

## Safety statement

This is a source-level configuration review with a failed live-catalog connection attempt. It does **not** confirm an exploitable vulnerability or production incident. No Supabase Production data/schema/policy/grant/secret, SQL migration, persistent PostgreSQL configuration, deployment, PR merge, force-push, or branch-protection setting was changed.


## Follow-up: explicit RPC EXECUTE ACL hardening prepared in the PR

A source-level review of the three API entry points found that their defining migrations create/replace the functions and grant EXECUTE to `authenticated`, but do not explicitly revoke the PostgreSQL default PUBLIC EXECUTE privilege. The 18 branch migrations contain no `ALTER DEFAULT PRIVILEGES` statement. On a clean PostgreSQL installation with default function ACLs, newly created functions receive EXECUTE for PUBLIC; a direct grant to `anon` can also survive unless it is explicitly revoked. This is a **fresh-install source configuration observation**, not evidence of the effective ACL on the live Supabase project.

A narrowly scoped additive migration has been prepared:

- `public.current_profile_actor_id()`: revoke all from PUBLIC and anon; explicitly grant authenticated.
- `public.dt_select_product_master(uuid, uuid, uuid)`: revoke all from PUBLIC and anon; explicitly grant authenticated.
- `public.execute_create_offer_v1(...)`: revoke all from PUBLIC and anon; explicitly grant authenticated.

The authenticated grants preserve the callers found in the application: the offers INSERT RLS helper, the signed-in Decision Tree selection route, and the authenticated CREATE_OFFER route/server action. The low-level `create_offer_v1(...)` ACL is deliberately unchanged pending effective-owner/catalog verification.

A dedicated regression runner creates a separate `qima_acl_test` database on the loopback PostgreSQL CI service, defines stub functions with PostgreSQL's default PUBLIC ACL plus a direct anon grant, applies the migration twice, and asserts that PUBLIC/anon no longer have EXECUTE while authenticated retains an explicit EXECUTE grant. The runner refuses any DATABASE_URL other than the dedicated loopback `qima_test` service and removes its temporary database and any roles it created.

This regression validates the migration's ACL semantics on disposable PostgreSQL only. It does not read or change the live Supabase catalog. The live read-only catalog query remains blocked by PostgreSQL `28P01` authentication failure, so effective Production ACLs remain unverified and no Production vulnerability is confirmed. The migration is committed to the PR only; it has not been applied to Supabase Production.


### Disposable RPC ACL regression correction — 10 November 2026

- QIMA CI #1102 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42702756183) ran on code commit `4f768c103aecb50a7a53a939021020af072c228f`. The existing CREATE_OFFER PostgreSQL integration suite completed **SUCCESS**, and the TypeScript/audit/build/browser job completed **SUCCESS** with **336/336 Playwright**. CodeQL #1054 completed **SUCCESS** and Vercel Preview status was **SUCCESS**.
- The new disposable ACL regression reached its post-migration assertion and failed while resolving the test's `regprocedure` identity string for `execute_create_offer_v1(...)`: the assertion string omitted one `text` argument between the numeric and JSONB arguments. The actual function and migration signatures contain 18 arguments; the migration's REVOKE/GRANT statements themselves executed twice before the assertion failed.
- Corrected the test signature to the exact 18-argument identity and strengthened the precondition to assert that fresh PostgreSQL supplies a PUBLIC EXECUTE ACL before the migration, in addition to the explicit direct `anon` grant.
- This is a test-fixture identity-string defect, not a failure of the migration SQL, application runtime, or live Supabase. No Production ACL was read or changed; live catalog access remains blocked by PostgreSQL `28P01`.
- Validation of the corrected test and migration on the next CI SHA: **pending**. No Supabase Production data/schema/RLS/grants/secrets, production migration, persistent PostgreSQL configuration, Production deployment, PR merge, force-push, or branch-protection change.


### CI #1103 follow-up — dollar-quote fixture correction — 10 November 2026

- QIMA CI #1103 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42703118503) passed the existing CREATE_OFFER PostgreSQL integration script, and the TypeScript/audit/build/browser job passed with **336/336 Playwright**. CodeQL #1055 completed **SUCCESS** and Vercel Preview Comments completed **SUCCESS**.
- The new ACL regression step failed before including the hardening migration: the newly inserted PL/pgSQL precondition block was serialized with an incomplete `DO $` dollar-quote delimiter, producing a PostgreSQL syntax error at line 34. The corrected function identity string is now present; the failure is isolated to the test SQL delimiter, not the migration or live Supabase.
- Replaced that block's delimiter with the distinct `$acl$` tag, leaving the existing postcondition block unchanged. The precondition now explicitly verifies both the default PUBLIC EXECUTE ACL and the simulated direct `anon` grant before migration.
- The migration was **not executed** in CI #1103 because the syntax error occurred before the `\\ir` include. The runner's cleanup path executed as the job exited; the dedicated job container was then stopped. The next CI run must prove the migration and postconditions end-to-end.
- Corrected regression validation: **pending next CI run**. Live Supabase catalog access remains blocked by PostgreSQL `28P01`; no Production ACL, schema, data, or migration was changed.


## Final validation — explicit RPC EXECUTE ACL hardening — 10 November 2026

- QIMA CI #1104: **SUCCESS** (https://github.com/meridane/QimaTrade-MVP/actions/runs/42703470956). The CREATE_OFFER PostgreSQL integration job passed, including the new disposable ACL step; its log contains the exact marker `function EXECUTE ACL regression PASS`. Existing CREATE_OFFER integration/concurrency, legacy messages RLS, participant self-enrollment RLS, prepared-transaction cleanup/restore, database cleanup, and unsafe-URL guards all passed.
- The ACL regression ran in a separate temporary `qima_acl_test` database on PostgreSQL 16 CI. It created stubs for the three target signatures with default PUBLIC EXECUTE and a direct `anon` grant, applied `20261110070000_harden_public_rpc_execute_acl.sql` twice, and verified no PUBLIC EXECUTE ACL, no effective/direct anon EXECUTE, and an explicit authenticated EXECUTE grant for each function. The runner completed successfully; no live Supabase connection was used.
- The TypeScript/dependency-audit/Next.js build/browser job passed, including **336/336 Playwright**. CodeQL #1056: **SUCCESS** (https://github.com/meridane/QimaTrade-MVP/actions/runs/42703470851).
- Vercel Preview Comments check: **SUCCESS**; combined Vercel status remains **FAILURE** because the provider reports `upgradeToPro=build-rate-limit`. No Preview READY is confirmed on this HEAD.
- The earlier CI #1102 signature-string defect and CI #1103 incomplete dollar-quote delimiter are retained in the history above; both were test-fixture defects and are superseded by the passing CI #1104 run.
- This proves the migration's intended ACL semantics on disposable PostgreSQL, not the effective ACL of the live Supabase project. The read-only live catalog attempt remains blocked by PostgreSQL `28P01`; effective Production ACLs are still unverified and no Production vulnerability is confirmed. The migration is in this draft PR only and has **not** been applied to Supabase Production.
- Current next gate: obtain authorized read-only live catalog output, compare the three effective ACLs/owners and public-schema CREATE privileges with this migration, then request normal human review/approval before any Production migration. Do not apply the migration from this automation.


## Follow-up: direct anon ACL hardening for authenticated-only helpers — 10 November 2026

A second, narrowly scoped migration was added after reviewing the branch call sites for four helpers that already revoke PUBLIC and explicitly grant authenticated, but do not explicitly revoke a separate direct grant to `anon`:

- `public.dt_has_tenant_access(uuid)`: used by RLS policies declared for `authenticated`.
- `public.dt_submit_answer(uuid, uuid, integer, uuid, text, text, uuid)`: the server helper obtains the current user before invoking the RPC; the function itself checks `auth.uid() = p_user_id`.
- `public.dt_publish_product_request(uuid, uuid)`: the API route authenticates with `auth.getUser()` and passes the current session token; the function checks the same user binding.
- `public.is_message_participant(uuid, uuid, uuid)`: the legacy message authorization helper is used by the authenticated message RLS path and checks the current profile actor.

The additive migration `20261110080000_harden_authenticated_helper_anon_acl.sql` applies `REVOKE ALL ... FROM PUBLIC, anon` and re-grants EXECUTE to `authenticated` for these four signatures. It is branch-only; no Production migration was applied. The low-level `create_offer_v1(...)` function remains untouched because its effective owner/caller relationship still requires live catalog evidence.

The disposable regression was expanded from three to seven signatures. It creates each stub with PostgreSQL's default PUBLIC EXECUTE ACL, adds a direct `anon` grant, applies both ACL migrations twice, and checks that PUBLIC/anon no longer have effective EXECUTE while authenticated retains an explicit grant. This test is synthetic ACL semantics only; it does not establish the live Supabase catalog state.

Validation at documentation time: QIMA CI #1106 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42710206948) and CodeQL #1058 (https://github.com/meridane/QimaTrade-MVP/actions/runs/42710207078) were still **IN PROGRESS**. Final validation must be recorded after the PostgreSQL job completes. Live catalog access remains blocked by PostgreSQL `28P01`; no Production vulnerability is confirmed.
