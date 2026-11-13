# QA391 — CREATE_OFFER zero-price acceptance and exact replay regression

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa391-zero-price-accepted-boundary-20261114-0437
Parent HEAD: f46b603934d82056d69597708598b6eae8d8d74a
Status: IMPLEMENTED — VERIFY AND POSTGRESQL RUNTIME VALIDATION PENDING

## Initial state verified

- PR #26 is OPEN, DRAFT, mergeable and unmerged; head is f46b603934d82056d69597708598b6eae8d8d74a.
- The latest QIMA CI run on that head, [#1403](https://github.com/meridane/QimaTrade-MVP/actions/runs/43481871260), completed SUCCESS. Verify, PostgreSQL 16 and PostgreSQL 17.6 full jobs all completed SUCCESS.
- Verify emitted QA390 PASS; both PostgreSQL logs emitted QA390 PASS and QA381 passed. The full jobs' later catalog, ACL, RLS, runner-privilege and cleanup steps succeeded.
- QIMA CodeQL [#1351](https://github.com/meridane/QimaTrade-MVP/actions/runs/43481871281) and the Vercel status check on HEAD completed SUCCESS.
- QA390 was confirmed CLOSED before starting QA391.

## Objective

The existing migration's price guard rejects NULL, NaN, both infinities and values strictly below zero, using the condition p_price < 0. This leaves zero as the existing accepted lower boundary. The inspected runtime suite covered negative-price rejection and the other numeric invalid cases, but did not isolate a zero-price successful CREATE_OFFER followed by exact idempotent replay. QA391 protects that existing SQL behavior without introducing a new business rule.

## Changes

1. Appended one disposable PostgreSQL DO block to tests/sql/create-offer-runtime.sql.
   - Uses a valid authenticated fixture, tenant, demand, product and provider actor.
   - Calls execute_create_offer_v1 with quantity 1::numeric and price 0::numeric.
   - Requires a complete public result with status=succeeded and objectType=Offer.
   - Requires exactly one persisted offer with price=0, one COMPLETED action execution, one COMPLETED idempotency row and one matching ACTION_SUCCEEDED event.
   - Replays the identical request with the same tenant-scoped idempotency key and requires the exact original result plus unchanged four-table counts.
2. Added tests/sql/test-create-offer-zero-price-contract.sh.
   - Pins the existing p_price < 0 guard and INVALID_PRICE error.
   - Requires the initial zero-price request, persisted zero value, successful result, exact replay, one-occurrence runtime marker and four-table count checks.
   - Requires exactly one Verify invocation and the shared PostgreSQL 16/17.6 runtime runner wiring.
3. Added the QA391 static contract to the Verify job.

## Validation

- Source-level review confirmed that QA391 is isolated to the disposable runtime fixture and that the migration and application code are unchanged.
- QA391 remains PENDING until Verify emits QA391 PASS and both full PostgreSQL 16 and PostgreSQL 17.6 jobs complete SUCCESS with the runtime marker.
- CI is triggered by the PR branch code commit. The later documentation-only updates are ignored by the workflow's docs/** path filter.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No new price acceptance policy was introduced; QA391 characterizes the existing p_price < 0 contract only.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.
