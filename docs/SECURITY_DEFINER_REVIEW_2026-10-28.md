# QIMA SECURITY DEFINER review — findings and next gate

**Date:** 2026-10-28  
**Repository:** `meridane/QimaTrade-MVP`  
**Branch:** `fix/create-offer-status-contract`  
**Supabase project:** `yyulzlnrfcbaxovzjbnh`  
**Scope:** read-only catalog review; no schema, privilege, or data changes.

## Latest branch validation

- Commit reviewed before this report: `28893121f809b69b998e94296a60efcf5d55a854`.
- QIMA CI run [40521459516](https://github.com/meridane/QimaTrade-MVP/actions/runs/40521459516): **SUCCESS**.
- CodeQL run [40521459595](https://github.com/meridane/QimaTrade-MVP/actions/runs/40521459595): **SUCCESS**.
- Vercel Preview deployment for that commit: **READY** at [qimatrade-mxf2usfje-bmk1.vercel.app](https://qimatrade-mxf2usfje-bmk1.vercel.app).
- The report itself was then committed as `9975aef1596ea2b595077788872615558e80bf66`. Its current combined commit status reports Vercel success. The earlier CI/CodeQL results do **not** automatically validate this later documentation-only commit.

## Read-only findings

A catalog query against `pg_proc`, function ACL checks, schema privileges, RLS policy expressions, and trigger metadata identified the following items. These are **review flags, not proof of an exploitable vulnerability**.

### 1. SECURITY DEFINER access helpers and actual schema privileges

The function ACL catalog reports `anon` and `authenticated` EXECUTE for these `core` helpers:

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

Their function search path is pinned to `pg_catalog, auth, core`. **Important qualification from the live catalog:** `anon` does not have `USAGE` on schema `core`, while `authenticated` does. Therefore, the function-level EXECUTE grants alone do not establish that anonymous clients can call these functions through PostgREST. These helpers are actively referenced by authenticated RLS policies across `core` and related schemas (for example, bulk operations, contexts, conversations, documents, transactions, and transport requests). Do not revoke them in bulk: first test dependent policies and authenticated access paths.

### 2. Trigger function ACLs

The catalog confirms `core.handle_auth_user_created()` is attached to `auth.users` by enabled trigger `qima_auth_user_created_profile`. A separate enabled trigger `on_auth_user_created` invokes `public.handle_new_auth_user()`. This confirms these are trigger-driven functions. Their ACLs should be reviewed separately from client-facing functions; do not change them without a trigger regression test.

### 3. Private role helpers and schema exposure

`private.has_permission(app_permission)` and `private.has_role(app_role)` are SECURITY DEFINER functions with an empty search path and explicitly qualified references to `public.user_roles`, `public.role_permissions`, and `auth.uid()`. The live catalog reports that neither `anon` nor `authenticated` has `USAGE` on schema `private`. These functions are nevertheless used by RLS policies on `public.role_permissions` and `public.user_roles`. Current evidence does not show they are directly callable through the Data API; preserve them until schema exposure, grants, and dependent policy tests are fully understood.

### 4. Public CREATE_OFFER RPC remains a separate gate

The live catalog reports authenticated EXECUTE for `public.create_offer_v1(...)` and `public.execute_create_offer_v1(...)`. The proposed migration `20261027100000_restrict_direct_create_offer_rpc.sql` is only in the branch and has not been applied. It must be tested on a disposable database for direct-call denial and wrapper success before any production decision. The legacy `app/api/offers/route.ts` still inserts directly into `offers` and supports drafts without demand, Product Master, or price; do not migrate it until the business contract is defined.

### 5. Function search paths

The reviewed QIMA functions generally pin their search paths to explicit schemas. This is good hardening, but it does not replace authorization review. Platform-managed functions in `pgbouncer` and `vault` are outside this application review and should not be changed as part of it.

## Next steps

1. Review effective schema exposure and grants for `public`, `core`, and `private` separately from function ACLs.
2. Test RLS dependencies for the access helpers using anonymous, signed-in non-member, valid member, and admin identities in an isolated environment.
3. Inspect grants and trigger behavior for both auth-user-created functions; test profile creation and signup rollback before considering any change.
4. Test the proposed CREATE_OFFER privilege migration and wrapper behavior on a disposable database, including idempotent retries and failure rollback.
5. Only after review, decide whether any live privilege change is warranted. No production change is authorized by this document.

## Overall gate

**Security gate: NOT PASS.** The latest prior code commit has green CI, CodeQL, and preview results, but these do not prove live Supabase authorization correctness. Still open: demand-to-supplier visibility rules, legacy draft-offer compatibility, migration reconciliation, committed npm lockfile, and function-level privilege review. No production migration, data mutation, PR merge, or production deployment was performed.
