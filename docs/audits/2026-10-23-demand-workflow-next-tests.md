# QimaTrade — Demand workflow: next validation steps

Date: 23 October 2026
Branch: `chore/qima-free-autopilot-review`
Scope: documentation and read-only source review. No production data, schema, migrations, merges, or deployments changed.

## Current source evidence

Historical Notion MVP tests (24 August 2026):
- [TEST 12 — Demand Qualification](https://app.notion.com/p/3c6595ef63608198a061f3e4f1090779): marked VALIDÉ for a saved qualification.
- [TEST 13 — Explainable Match](https://app.notion.com/p/3c6595ef636081c0a172ed67c0bf50b8): marked VALIDÉ for the historical MVP scoring example.
- [TEST 15 — MVP End-to-End](https://app.notion.com/p/3c6595ef636081e2a003c46133bf050c): marked VALIDÉ for Demand → Qualification → Match → Offer → Conversation → commercial message.
- [TEST 17 — Unauthorized Write Protection](https://app.notion.com/p/3c6595ef6360818f95a1ccded1e4f660): historical PASS for a nonparticipant unable to send a message.
- [TEST 18 — Double Submission / Idempotence](https://app.notion.com/p/3c6595ef636081539b22f030fcc8127e): historical PASS for one visible message after two quick sends.
- [TEST 28 — Qualification Persistence & Link Integrity](https://app.notion.com/p/3c6595ef6360811da2aff06ac1df1841), [TEST 29 — Demand Workflow Reload / No Data Loss](https://app.notion.com/p/3c6595ef636081a6bf27f5abfd76bbaa), and [TEST 30 — Partial Update Must Not Erase Data](https://app.notion.com/p/3c6595ef6360811293fbd2ad532e107f) were marked for execution before V1.

These pages are historical MVP evidence only; none of these statuses proves the current branch or production Supabase is validated.

## Read-only code observations

- `app/demands/list/page.tsx` loads demands filtered by the signed-in user's `profiles.actor_id`, and determines qualification from `scope.qualification`.
- `app/demands/match/page.tsx` reads the selected demand, parses `scope`, filters offers by `product_master_id`, and ranks offers by quantity, budget, currency, market, and requested attributes.
- `app/demands/conversation/page.tsx` accepts demand context from `?demand=`, `?match=`, or `?id=`, and an optional `?offer=`; it calls server actions to load and send messages.
- `playwright.config.ts` configures browser tests, but a green smoke-test run does not by itself validate this authenticated multi-step workflow.

## Next tests, in order

1. **WF-DEMAND-01 — Create and persist:** create a synthetic demand in an isolated test environment; verify required fields and generated ID.
2. **WF-DEMAND-02 — Qualification round trip:** save qualification, reload, and verify budget, currency, deadline, geography, commercial terms, documentation, and attributes remain unchanged.
3. **WF-DEMAND-03 — Partial update:** change only budget; verify all unrelated fields remain unchanged.
4. **WF-DEMAND-04 — List/edit/reopen:** demand appears only for its owner; edit and reopen the same demand without creating an accidental duplicate.
5. **WF-MATCH-01 — Explainable matching:** seed synthetic offers covering quantity/budget/currency/market/attribute pass and fail cases; verify ranking and explanation.
6. **WF-CHAT-01 — Context integrity:** open conversation with both demand and offer IDs; verify stored messages retain correct demand, offer, sender, and timestamp.
7. **WF-CHAT-02 — Reload/idempotence:** reload conversation and verify persisted messages; double-submit once and verify no duplicate.
8. **WF-SEC-01 — Participant isolation:** with synthetic users, prove a nonparticipant cannot read or write the conversation or demand.
9. **WF-SEC-02 — Cross-tenant isolation:** prove each tenant cannot read or mutate another tenant's records using the actual deployed policies/functions in an isolated Supabase environment.

## Acceptance rules

- Record environment, commit SHA, test input, expected result, actual result, and evidence link for every test.
- Statuses must distinguish `HISTORICAL MVP PASS`, `NOT RUN ON CURRENT SHA`, `PASS ON CURRENT SHA`, and `BLOCKED`.
- Do not use production records for test fixtures. Do not run migrations, reset databases, change grants/policies, merge PRs, or deploy as part of this validation sequence.
- Security remains **NOT PASS** until the real schema/policies and cross-tenant behavior are verified. The isolated PostgreSQL shim is not equivalent to full Supabase.
