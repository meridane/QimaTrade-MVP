# QIMA — Legacy messages RLS: cross-demand message injection candidate

**Date:** 2026-10-28  
**Branch:** fix/create-offer-status-contract  
**Scope:** read-only inspection of the live Supabase catalog and current app server actions. No data or schema was changed.

## Summary

A second, distinct authorization issue was identified in the legacy MVP chat path. The app at `app/demands/conversation/actions.ts` uses the `public.messages` table, not the newer `core.conversations` / `core.conversation_participants` tables.

Live catalog inspection shows:

- `public.messages` has RLS enabled and authenticated users have INSERT and SELECT grants.
- The INSERT policy `messages_insert_participants` has check:
  `is_message_participant(demand_id, offer_id, sender_actor_id) AND sender_actor_id = (SELECT p.actor_id FROM profiles p WHERE p.auth_user_id = auth.uid())`.
- The SECURITY DEFINER helper `public.is_message_participant(demand_id, offer_id, sender_actor_id)` returns true immediately if the caller's profile actor matches the supplied `sender_actor_id`, without first checking whether the caller belongs to the specified demand or offer.
- The current server action derives `sender_actor_id` from the signed-in user's profile, but sends the caller-provided `demandId` and `offerId` directly to the INSERT.

This means the policy's first condition can be satisfied by an authenticated user sending as themselves, even when they are not a participant in the referenced demand/offer. If the referenced IDs satisfy table constraints, the insert may create a message in a conversation the user should not be able to join.

**Assessment: high-priority cross-object message-injection candidate. Not yet confirmed with an authenticated exploit test.** No test message was inserted and no production write was attempted.

## Important scope distinction

The app route is currently wired to the legacy `public.demands`, `public.offers`, and `public.messages` model. The separately reviewed `core.conversations` and `core.transaction_parties` policies are another path and need their own regression tests. Fixing one path does not fix the other.

## Isolated regression tests required

Use synthetic users A and B, with separate demands/offers, in a disposable database using the authenticated role and JWT claims.

| ID | Scenario | Expected |
| --- | --- | --- |
| MSG-01 | User A inserts a message as themselves against User B's demand and offer | Denied; no row persists |
| MSG-02 | User A submits a valid demand ID paired with an unrelated offer ID | Denied; no row persists |
| MSG-03 | User A submits a nonexistent or null offer ID where not permitted by the conversation contract | Denied according to the documented contract |
| MSG-04 | User A tries to spoof User B's sender_actor_id | Denied |
| MSG-05 | Authorized demand requester sends a message in their demand/offer conversation | Allowed |
| MSG-06 | Authorized offer provider sends a message linked to the same demand and their offer | Allowed |
| MSG-07 | Unrelated user attempts to read the other participants' messages | Denied / zero rows |
| MSG-08 | Existing legitimate conversation messages remain visible to requester and provider | Allowed |
| MSG-09 | Invalid insert leaves no message row or partial side effect | Verified |

Run these tests under the same authenticated role as the API. A database-owner-only test is insufficient.

## Fix constraints

Do not apply a broad policy change before the intended chat contract is clear. The replacement check must independently validate:
1. the authenticated user's actor is the supplied sender;
2. the user is the requester for the demand, or the provider for an offer whose `demand_id` matches the message's `demand_id`, or another explicitly supported accepted-match path;
3. the demand/offer pair is consistent;
4. the helper does not treat sender identity alone as proof of access to the target object.

Keep read access limited to actual participants. Review both the `USING` policy and `WITH CHECK` policy. Preserve supported demand-only messaging only if it is part of the intended product contract.

## Related code

- `app/demands/conversation/actions.ts`: loads a demand, optionally loads an offer, reads messages filtered by demand and offer; sending inserts caller-provided demand/offer IDs and the server-derived sender actor.
- `public.messages`: RLS enabled; authenticated SELECT and INSERT granted.
- `public.is_message_participant(uuid, uuid, uuid)`: SECURITY DEFINER helper with pinned `public` search path; the sender-actor shortcut is the primary concern.
- `core.conversation_participants` and `core.transaction_parties`: separate policy candidates already tracked in `docs/PARTICIPANT_SELF_ENROLLMENT_REGRESSION_PLAN.md`.

## Validation boundary

The latest branch commit before this finding, `f7ebb281fb5b206530153b9c95220d982dd90e78`, passed QIMA CI and CodeQL; Vercel Preview is READY. Those checks do not test the live legacy message RLS policy.

No production rows, policies, grants, or schema were changed. No migration was applied. PR #26 remains open and draft. Security gate remains **NOT PASS** pending isolated regression tests and review.
