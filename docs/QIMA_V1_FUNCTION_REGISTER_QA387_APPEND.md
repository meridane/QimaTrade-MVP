# QA387 — CREATE_OFFER finite negative-price boundary regression

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa387-finite-negative-price-boundary-20261114-0013
Status: CLOSED — QIMA CI #1397 SUCCESS

## Initial state verified

- PR #26: OPEN, DRAFT, mergeable, not merged; base main, HEAD c831990b34ef7aae67d83e990fc76317e2aeb028.
- QIMA CI [#1396](https://github.com/meridane/QimaTrade-MVP/actions/runs/43445633156) completed SUCCESS on that HEAD.
- QA381, QA382, QA383, QA384, QA385 and QA386 are closed or validated by their recorded checks; QA386 has explicit Verify, PostgreSQL 16 and PostgreSQL 17.6 success markers.
- CodeQL #1345 and the Vercel status check on the parent HEAD completed SUCCESS.

## Objective

Add an isolated finite-negative price case to the existing CREATE_OFFER non-negative-price contract. The migration already rejects NULL, NaN, positive/negative Infinity and every price below zero with INVALID_PRICE. QA384 covers NaN and negative Infinity; the runtime suite had no dedicated finite negative price case. This is regression coverage only and does not change application behavior or migration logic.

## Changes

1. Appended a disposable PostgreSQL runtime block to tests/sql/create-offer-runtime.sql.
   - Uses an authenticated fixture identity and otherwise-valid tenant, actor, demand, product, quantity and currency.
   - Calls execute_create_offer_v1 with p_quantity = 1::numeric and p_price = -1::numeric.
   - Requires exactly INVALID_PRICE.
   - Compares before/after row counts for idempotency_keys, action_executions, offers and action_events, and verifies that the fixture key and offer are absent.
   - Emits an explicit QA387 PASS notice.
2. Added tests/sql/test-create-offer-negative-price-contract.sh.
   - Protects the existing non-negative price guard and exact error.
   - Requires the finite negative-price runtime case, valid positive quantity, four-table no-side-effect assertions and success marker.
   - Requires Verify plus the shared PostgreSQL 16 and 17.6 runtime runner wiring.
3. Added the QA387 contract to the Verify job in .github/workflows/ci.yml.

## Validation

- Source construction was checked against the existing migration guard, QA386 disposable fixture, workflow job names and runner wiring.
- QIMA CI #1397 completed SUCCESS on HEAD d60c7f4c520b3fd98bacb4ed45269641b686bec1. Verify emitted QA387 PASS; PostgreSQL 16 and PostgreSQL 17.6 runtime logs each emitted the explicit QA387 PASS marker and both integration jobs completed SUCCESS. The same jobs emitted QA381 passed. npm audit, TypeScript, Next.js build and 347/347 Playwright passed; CodeQL #1346 and the Vercel status check also completed SUCCESS.

## Safety and decision boundaries

- No migration or application code changed.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No zero-price acceptance test or numeric canonicalization behavior was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.


## CI #1397 — clôture QA387 sur les deux versions PostgreSQL (14 novembre 2026)

- QIMA CI [#1397](https://github.com/meridane/QimaTrade-MVP/actions/runs/43451163902) a terminé SUCCESS sur HEAD d60c7f4c520b3fd98bacb4ed45269641b686bec1.
- Verify a émis explicitement QA387 PASS; npm audit au seuil high, TypeScript, build Next.js et 347/347 Playwright ont réussi.
- Le job CREATE_OFFER PostgreSQL 16 [131973387950](https://github.com/meridane/QimaTrade-MVP/actions/runs/43451163902) et le job PostgreSQL 17.6 [131973388219](https://github.com/meridane/QimaTrade-MVP/actions/runs/43451163902) ont chacun émis le marqueur QA387 PASS et terminé SUCCESS.
- Les deux jobs ont également émis QA381 passed. Les harnesses de nettoyage volontairement en échec et le job volontairement skipped ont conservé leurs résultats attendus; les jobs d'assertion dédiés ont réussi.
- CodeQL [#1346](https://github.com/meridane/QimaTrade-MVP/actions/runs/43451163974) et le check Vercel du HEAD ont terminé SUCCESS.
- QA387 est CLOSED. Ces résultats caractérisent la CI et les bases PostgreSQL jetables; ils ne constituent ni une validation de Production ni une conclusion de vulnérabilité.
