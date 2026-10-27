# Legacy messages RLS — regression execution checklist

This checklist supplements `docs/LEGACY_MESSAGES_RLS_REVIEW_2026-10-28.md`. It is a test specification, not an executable SQL test: the repository's current SQL fixture covers CREATE_OFFER and does not reproduce the live legacy messaging schema/policies.

## Fixture setup (disposable database only)

Create two authenticated users with separate profiles/actors, two demands owned by different requesters, and two offers where each offer references its own demand and provider. Enable RLS and apply the exact relevant policies/helper definitions from the intended test snapshot. Use the same JWT claim setup and `authenticated` role as Supabase API requests. Do not use a superuser session to assert RLS behavior.

## Test cases

1. **MSG-01 — foreign demand insert:** as provider/user A, insert a message with demand B, offer B, sender actor A. Expect RLS denial; assert no row persists.
2. **MSG-02 — mismatched pair:** use demand A with offer B and sender actor A. Expect denial for requester and provider paths; assert no row persists.
3. **MSG-03 — sender spoof:** use sender actor B while authenticated as A. Expect denial; assert no row persists.
4. **MSG-04 — legitimate requester:** requester A inserts a message on demand A with an offer that belongs to demand A. Expect success.
5. **MSG-05 — legitimate provider:** provider A inserts a message on their offer for demand A. Expect success.
6. **MSG-06 — foreign read:** user A attempts to select messages for demand B/offer B. Expect zero rows (or denial) under RLS.
7. **MSG-07 — participant read:** requester A and provider A can read their own demand/offer conversation. Expect the intended message rows only.
8. **MSG-08 — demand-only behavior:** if demand-only chat is supported, requester A may insert with `offer_id IS NULL`; provider A must remain denied unless a separately documented business rule authorizes that path.
9. **MSG-09 — null/nonexistent reference:** test null offer and nonexistent offer behavior against the actual constraints and product contract; no unrelated message may persist.
10. **MSG-10 — no partial effects:** after every expected denial, query the message table as test owner and confirm no row was created.

## Important test mechanics

- Use independent transactions or roll back each test fixture.
- Verify behavior both through direct SQL as `authenticated` with JWT claims and through the application server action if the test harness can exercise it.
- Test both SELECT and INSERT policies; a successful insert check does not prove read isolation.
- Keep a copy of the original helper/policy definitions so failures can be compared against baseline.
- Test the exact proposed function in `supabase/proposals/20261028_fix_legacy_message_participant_rls.sql` before considering a migration.
- If the legitimate product flow supports accepted matches without an offer, multiple offers per demand, or demand-only provider messages, encode those rules explicitly before changing the proposed predicate.

## Exit criteria

All negative tests deny access and leave no rows; all legitimate requester/provider paths pass; no existing supported flow regresses; CI and CodeQL pass for the commit containing any runtime/test changes. Only then prepare a separate migration for review. Never apply the proposal directly to production.
