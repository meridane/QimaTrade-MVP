# QIMA — Participant self-enrollment regression plan

**Date:** 2026-10-28  
**Branch:** fix/create-offer-status-contract  
**Purpose:** define the smallest safe test gate for the live RLS policy candidate; this is not a migration and does not modify Supabase.

## Evidence confirmed in the live catalog

The following policy expressions were observed in the production catalog using read-only inspection:

- core.conversation_participants / qima_conversation_participant_insert: the policy permits the row when user_id = auth.uid() **or** when the caller can access the linked request/conversation **or** when the caller is an admin.
- core.transaction_parties / qima_transaction_party_insert: the policy permits the row when user_id = auth.uid() **or** when the caller can access the linked transaction **or** when the caller is an admin.
- core.can_access_conversation(uuid) and core.can_access_transaction(uuid) consult participant records. That makes self-enrollment a plausible authorization bypass if the insert is accepted and the helper subsequently sees the new row.

**Status: high-priority candidate, not a confirmed exploit.** We have not inserted a test row or attempted to read another user's data in production.

## Required isolated regression matrix

Run only against a disposable PostgreSQL/Supabase-compatible database populated with synthetic users and records.

| ID | Scenario | Expected result |
| --- | --- | --- |
| CP-01 | User A inserts themselves into User B's existing conversation | Denied; no participant row persists |
| CP-02 | User A attempts to read messages in User B's conversation without membership | Denied / zero rows |
| CP-03 | User A attempts self-enrollment, then message read in one transaction | Entire attempt denied; no partial side effect |
| TP-01 | User A inserts themselves into User B's existing transaction | Denied; no party row persists |
| TP-02 | User A attempts to read User B's transaction after the insert attempt | Denied / zero rows |
| CP-04 | Authorized request owner joins a conversation legitimately created for their request | Allowed |
| TP-03 | Trusted transaction-creation workflow assigns a legitimate party | Allowed |
| ADM-01 | Authorized administrator performs the supported participant/party operation | Existing intended behavior preserved |
| RLS-01 | Unauthenticated request tries either insert | Denied |

For each negative test, assert both the SQL/API error or zero-row behavior and the absence of a persisted membership row. Tests must run with the same database roles and JWT claims as the real authenticated API path; a superuser-only test is insufficient.

## Fix constraints

Do not simply remove every participant insert policy or revoke table access without checking the supported creation flows.

1. Remove the unconditional self-membership shortcut unless an independently validated business rule proves it safe.
2. Allow first-time conversation membership only through a path that proves access to the linked request or a trusted server-side creation workflow.
3. Assign transaction parties only through a trusted transaction-creation/party-assignment workflow, or a policy proving pre-existing authorization without relying on the row being inserted.
4. Preserve administrator behavior and valid request-owner / transaction-party workflows.
5. Test USING policies for subsequent reads as well as WITH CHECK for inserts.
6. Re-check table grants, RLS enabled/forced state, helper function behavior, and all policy interactions before proposing a migration.

## Current validation boundary

- The latest branch commit 3dd6439639a2c7095dc320bc8af78ddc9f3c94f2 has QIMA CI **SUCCESS**, CodeQL **SUCCESS**, and Vercel Preview **READY**.
- These checks do not test the live participant policies; the existing SQL fixture focuses on CREATE_OFFER.
- No production data or schema has been changed. No migration has been applied. PR #26 remains open and draft.

## Gate

**Do not ship a participant-policy migration until CP-01, CP-02, TP-01, TP-02, and the legitimate positive-path tests pass on an isolated database.** The exact replacement predicates depend on how conversations and transactions are created in the app; inspect those workflows before writing the migration.
