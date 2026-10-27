# QIMA SECURITY DEFINER review — findings and next gate

**Date:** 2026-10-28  
**Repository:** `meridane/QimaTrade-MVP`  
**Branch:** `fix/create-offer-status-contract`  
**Supabase project:** `yyulzlnrfcbaxovzjbnh`  
**Scope:** read-only catalog review; no schema, privilege, or data changes.

## Latest branch validation

- Commit reviewed: `28893121f809b69b998e94296a60efcf5d55a854`.
- QIMA CI run [40521459516](https://github.com/meridane/QimaTrade-MVP/actions/runs/40521459516): **SUCCESS**.
- CodeQL run [40521459595](https://github.com/meridane/QimaTrade-MVP/actions/runs/40521459595): **SUCCESS**.
- Vercel Preview deployment: **READY** at [qimatrade-mxf2usfje-bmk1.vercel.app](https://qimatrade-mxf2usfje-bmk1.vercel.app).
- An earlier CI run [40521427867](https://github.com/meridane/QimaTrade-MVP/actions/runs/40521427867) was cancelled when a newer commit superseded it; do not treat that cancellation as a failed test. The later run above is the relevant result for the latest commit.

## Read-only findings

A catalog query against `pg_proc`, function ACL checks, and function configuration identified the following items requiring explicit review. These are **review flags, not proof of an exploitable vulnerability**.

### 1. SECURITY DEFINER helpers executable by `anon`

The current privilege catalog reports `anon` and `authenticated` EXECUTE for these `core` helpers:

- `core.can_access_bulk(uuid)`
- `core.can_access_context(uuid)`
- `core.can_access_conversation(uuid)`
- `core.can_access_document(uuid)`
- `core.can_access_exception(uuid)`
- `core.can_access_human_task(uuid)`
- `core.can_access_publication(uuid)`
- `core.can_access_request(uuid)`
- `core.can_access_transaction(uuid)`
- `core.can_access_transport_request(uuid)`
- `core.is_admin()`
- `core.is_org_member(uuid)`

They use a restricted function search path (`pg_catalog, auth, core`) and their predicates generally compare records against `auth.uid()` or an active public state. However, `anon` calls normally have no authenticated user identity. The safe next step is to determine which functions are referenced by RLS policies, views, other functions, and any intended public publication flow before considering a grant change. Do **not** bulk-revoke these privileges without dependency tests.

### 2. Trigger function ACLs

`core.handle_auth_user_created()` appears in the SECURITY DEFINER catalog with `anon` and `authenticated` EXECUTE privileges. It is a trigger-style function using `NEW`; confirm its trigger attachment and whether direct invocation is possible/meaningful. Review its ACL separately from the access-check helpers.

### 3. Private role helpers

`private.has_permission(app_permission)` and `private.has_role(app_role)` are SECURITY DEFINER functions with `search_path=""`, and the catalog reports EXECUTE for `anon` and `authenticated`. Their SQL explicitly references `public.user_roles`, `public.role_permissions`, and `auth.uid()`. Review whether the `private` schema is exposed through PostgREST and whether these functions are intended to be callable by `anon`; do not assume schema placement alone settles API exposure.

### 4. Public CREATE_OFFER RPC remains a separate gate

The live catalog still reports authenticated EXECUTE for `public.create_offer_v1(...)` and `public.execute_create_offer_v1(...)`. The proposed migration `20261027100000_restrict_direct_create_offer_rpc.sql` is only in the branch and has not been applied. It must be tested on a disposable database for direct-call denial and wrapper success before any production decision.

### 5. Function search paths

The reviewed QIMA functions generally pin their search paths to explicit schemas. This is good hardening, but it does not replace authorization review. Some platform-managed functions in `pgbouncer` and `vault` are outside this application review and should not be changed as part of it.

## Required follow-up before any privilege migration

1. Export dependencies for each flagged function: RLS policy expressions, views, function call sites, triggers, schema exposure, and grants.
2. Classify each function as: client-callable by authenticated users, intentionally public, server/worker-only, or trigger-only.
3. Write targeted tests for anonymous calls, signed-in non-member calls, valid members, and admins.
4. Prepare the smallest possible SQL privilege migration in a disposable environment and run regression tests.
5. Only after review, decide whether any live privilege change is warranted. No production change is authorized by this document.

## Overall gate

**Security gate: NOT PASS.** The latest CI, CodeQL, and preview deployment are green, but they do not prove live Supabase authorization correctness. Still open: demand-to-supplier visibility rules, legacy draft-offer compatibility, migration reconciliation, committed npm lockfile, and function-level privilege review. No production migration, data mutation, PR merge, or production deployment was performed.
