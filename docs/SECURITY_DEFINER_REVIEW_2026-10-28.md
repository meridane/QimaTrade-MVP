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
- The report itself was then committed as `9975aef1596ea2b595077788872615558e80bf66`; its current combined status reports Vercel success. The earlier CI/CodeQL results do **not** automatically validate later documentation-only commits.

## Read-only findings

Catalog, grants, RLS policies, and trigger metadata were inspected. Findings below distinguish confirmed policy logic from conclusions that still require tests.

### 1. P0 review: self-enrollment into conversations and transactions may bypass participant checks

The live catalog confirms RLS is enabled and the `authenticated` role has INSERT privilege on both tables:

- `core.conversation_participants`: policy `qima_conversation_participant_insert` has check expression `user_id = auth.uid() OR can_access_request(conversation.request_id) OR can_access_conversation(conversation.id) OR is_admin()`.
- `core.transaction_parties`: policy `qima_transaction_party_insert` has check expression `user_id = auth.uid() OR can_access_transaction(transaction_id) OR is_admin()`.

The first OR branch allows a user to attempt inserting themselves into a participant/party row without proving access to the existing conversation or transaction. The helper functions `core.can_access_conversation` and `core.can_access_transaction` themselves consult participant records. This creates a plausible self-enrollment path: if the INSERT succeeds for an existing object, the new membership may then satisfy the helper used to read it.

**Assessment: HIGH-PRIORITY authorization defect candidate; not yet confirmed with an authenticated exploit test.** The exact policy expressions and table privileges are confirmed from the live catalog, but no test row was inserted and no production write was attempted.

**Required fix approach:** replace the self-membership shortcut with a rule that proves the caller already has access to the related request/conversation/transaction, or use a trusted server-side workflow that validates and creates participants. Preserve legitimate first-time conversation creation from a request the caller can access. For transaction parties, preserve only the approved transaction-creation/party-assignment flow. Do not apply a migration until negative and positive tests run on an isolated database.

Minimum tests:
1. User A cannot add themselves to User B's conversation and then read its messages.
2. User A cannot add themselves to User B's transaction and then read transaction data.
3. A request owner can join a conversation legitimately created for an accessible request.
4. A transaction party can be added through the approved creation workflow.
5. Admin behavior remains valid.
6. Attempts fail without orphan participant rows or partial side effects.

### 2. SECURITY DEFINER access helpers and actual schema privileges

The function ACL catalog reports `anon` and `authenticated` EXECUTE for these `core` helpers: `can_access_bulk(uuid)`, `can_access_context(uuid)`, `can_access_conversation(uuid)`, `can_access_document(uuid)`, `can_access_exception(uuid)`, `can_access_human_task(uuid)`, `can_access_publication(uuid)`, `can_access_request(uuid)`, `can_access_transaction(uuid)`, `can_access_transport_request(uuid)`, `is_admin()`, and `is_org_member(uuid)`.

Their search path is pinned to `pg_catalog, auth, core`. Important qualification: `anon` does not have `USAGE` on schema `core`, while `authenticated` does. Function-level EXECUTE grants alone therefore do not establish that anonymous clients can call these helpers through PostgREST. They are actively referenced by authenticated RLS policies, so do not revoke them in bulk.

### 3. Trigger function ACLs

The catalog confirms `core.handle_auth_user_created()` is attached to `auth.users` by enabled trigger `qima_auth_user_created_profile`. A separate enabled trigger `on_auth_user_created` invokes `public.handle_new_auth_user()`. Review their ACLs separately from client-facing functions; do not change them without a trigger regression test.

### 4. Private role helpers and schema exposure

`private.has_permission(app_permission)` and `private.has_role(app_role)` are SECURITY DEFINER functions with an empty search path and explicitly qualified references. Neither `anon` nor `authenticated` has `USAGE` on schema `private`. They are used by RLS policies on `public.role_permissions` and `public.user_roles`; current evidence does not show direct Data API callability.

### 5. Public CREATE_OFFER RPC remains a separate gate

The live catalog reports authenticated EXECUTE for `public.create_offer_v1(...)` and `public.execute_create_offer_v1(...)`. Proposed migration `20261027100000_restrict_direct_create_offer_rpc.sql` is not applied. It must be tested on a disposable database for direct-call denial and wrapper success. The legacy `app/api/offers/route.ts` still inserts directly into `offers` and supports drafts without demand, Product Master, or price; do not migrate it until the business contract is defined.

### 6. Function search paths

Reviewed QIMA functions generally pin their search paths. Platform-managed functions in `pgbouncer` and `vault` are outside this application review and should not be changed as part of it.

## Next steps

1. Create isolated regression tests for the potential self-enrollment path before proposing a targeted RLS migration.
2. Review effective schema exposure and grants separately from function ACLs.
3. Test access-helper policies and both auth-user-created triggers using anonymous, non-member, valid-member, and admin cases.
4. Test the proposed CREATE_OFFER privilege migration, idempotent retries, and rollback on a disposable database.
5. Only after review, decide whether any live privilege change is warranted. No production change is authorized by this document.

## Overall gate

**Security gate: NOT PASS.** The prior code commit has green CI, CodeQL, and preview results, but these do not prove live Supabase authorization correctness. Open items include the participant self-enrollment candidate, demand-to-supplier visibility, legacy draft-offer compatibility, migration reconciliation, committed npm lockfile, and function-level privilege review. No production migration, data mutation, PR merge, or production deployment was performed.


## 7. Additional finding: legacy message INSERT policy may allow cross-demand injection

Read-only inspection of the live catalog and the current app server action identified a separate issue from the newer `core` participant policies.

- `app/demands/conversation/actions.ts` writes to legacy `public.messages`.
- RLS is enabled on `public.messages`; authenticated has INSERT and SELECT table privileges.
- `messages_insert_participants` calls `public.is_message_participant(demand_id, offer_id, sender_actor_id)` and checks that `sender_actor_id` belongs to the authenticated profile.
- The SECURITY DEFINER helper returns true when the current user's actor matches the supplied sender actor, without validating that the actor is authorized for the target demand/offer. The server action correctly derives sender actor from the user's profile but accepts demand/offer IDs as action input.

**Assessment: high-priority cross-object message-injection candidate, not yet confirmed by an authenticated exploit test.** No production insert or read attempt was made. The function's behavior is confirmed from the live definition; exploitability still depends on the complete schema constraints and RLS evaluation in the authenticated API path.

Required isolated tests and fix constraints are documented in `docs/LEGACY_MESSAGES_RLS_REVIEW_2026-10-28.md`. The newer `core.conversation_participants` / `core.transaction_parties` candidate remains separate and is tracked in `docs/PARTICIPANT_SELF_ENROLLMENT_REGRESSION_PLAN.md`.

## Latest validation after documentation updates

- Commits `f7ebb281fb5b206530153b9c95220d982dd90e78` and subsequent documentation commits do not modify application runtime or the database.
- QIMA CI run `40531582247`: SUCCESS for `f7ebb28...`.
- CodeQL run `40531582636`: SUCCESS for `f7ebb28...`.
- Vercel Preview for `f7ebb28...`: READY.
- These results do not validate the new live RLS findings; no authenticated exploit regression test has run.
- No production data/schema/privilege changes, no migration application, no PR merge, and no production deployment.

## Revalidation de branche — 28 octobre 2026

HEAD `fac4c83853350bab61ce97a0a0881bcc9470f332` : QIMA CI **SUCCESS**, CodeQL **SUCCESS**, Vercel Preview **SUCCESS**. La CI inclut les tests PostgreSQL isolés CREATE_OFFER, legacy messages et auto-inscription aux participants.

Limite de preuve : les deux suites RLS supplémentaires reproduisent des politiques simplifiées dans des schémas de test dédiés. Elles ne constituent pas un replay des politiques exactes de Supabase live et ne valident pas l'application des propositions RLS à la base de production. Le Security Gate demeure **NOT PASS**. La règle tenant↔demande, le chemin historique de brouillon, la revue des permissions RPC et la réconciliation des migrations restent ouverts. Aucune écriture ou migration production n'a été exécutée.
