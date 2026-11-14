# QA386 — CREATE_OFFER finite negative-quantity boundary regression

Date: 2026-11-13 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa386-negative-quantity-boundary-20261113-2342
Status: CLOSED — CI #1396 SUCCESS

## Initial state verified

- PR #26: OPEN, DRAFT, mergeable, not merged; base main, HEAD 5d12a3cd76a9394ba96a2e8bc7cdc4bccb44abe0.
- QIMA CI #1395 completed SUCCESS on that HEAD.
- QA385 is CLOSED after explicit Verify, PostgreSQL 16 and PostgreSQL 17.6 runtime success markers.
- CodeQL #1344 and the Vercel check on the parent HEAD completed SUCCESS.

## Objective

Add an isolated finite-negative quantity case to the existing CREATE_OFFER positive-quantity contract. The migration already rejects NULL, NaN, positive/negative Infinity and every quantity less than or equal to zero with INVALID_QUANTITY. QA384 covers negative Infinity and QA385 covers zero; the runtime suite did not contain a dedicated finite negative quantity case. This is regression coverage only and does not change application behavior or migration logic.

## Changes

1. Appended a disposable PostgreSQL runtime block to tests/sql/create-offer-runtime.sql.
   - Uses an authenticated fixture identity and otherwise-valid tenant, actor, demand, product, price and currency.
   - Calls execute_create_offer_v1 with p_quantity = -1::numeric.
   - Requires exactly INVALID_QUANTITY.
   - Compares before/after counts for idempotency_keys, action_executions, offers and action_events, and verifies that the fixture key and offer are absent.
   - Emits an explicit QA386 PASS notice.
2. Added tests/sql/test-create-offer-negative-quantity-contract.sh.
   - Protects the existing strictly-positive quantity guard and exact error.
   - Requires the runtime negative finite case, expected error, four-table no-side-effect assertions and success marker.
   - Requires Verify plus the shared PostgreSQL 16 and 17.6 runtime runner wiring.
3. Added the QA386 contract to the Verify job in .github/workflows/ci.yml.

## Validation

- Source construction was checked against the existing migration guard, QA385 disposable fixture, workflow job names and runner wiring.
- QIMA CI #1396 completed SUCCESS on HEAD c831990b34ef7aae67d83e990fc76317e2aeb028. Verify emitted QA386 PASS; PostgreSQL 16 and PostgreSQL 17.6 runtime logs each emitted the explicit QA386 PASS marker, and both jobs completed SUCCESS. npm audit at the configured high threshold, TypeScript, Next.js build and 347/347 Playwright passed. CodeQL #1345 and the Vercel status check also completed SUCCESS.

## Safety and decision boundaries

- No migration or application code changed.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No price-zero acceptance test or numeric canonicalization behavior was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.


## CI #1396 — clôture QA386 sur les deux versions PostgreSQL (14 novembre 2026)

- Le workflow QIMA CI [#1396](https://github.com/meridane/QimaTrade-MVP/actions/runs/43445633156) a terminé **SUCCESS** sur HEAD c831990b34ef7aae67d83e990fc76317e2aeb028.
- Verify a émis explicitement QA386 PASS, après QA382–QA385 PASS. npm audit au seuil high, TypeScript, build Next.js et 347/347 Playwright ont réussi.
- PostgreSQL 16 a terminé SUCCESS avec le marqueur runtime QA386 PASS: finite negative quantity is rejected as INVALID_QUANTITY before idempotency, execution, offer or action-event persistence.
- PostgreSQL 17.6 a terminé SUCCESS avec le même marqueur. Les deux environnements ont également émis QA381 passed et les marqueurs QA384/QA385.
- CodeQL [#1345](https://github.com/meridane/QimaTrade-MVP/actions/runs/43445633054) et le check Vercel du HEAD ont terminé SUCCESS.
- QA386 est CLOSED. Résultats limités à la CI et aux bases temporaires; aucune conclusion sur Production n'en est déduite.
