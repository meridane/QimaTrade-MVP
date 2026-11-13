# QA385 — CREATE_OFFER zero-quantity boundary regression

Date: 2026-11-13 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa385-zero-quantity-boundary-20261113-2225
Status: CLOSED — CI #1395 SUCCESS

## Initial state verified

- PR #26: OPEN, DRAFT, mergeable, not merged; base main, HEAD 1093c19ed032a95e6d7b0b00f11268a31956e035.
- QIMA CI #1393 completed SUCCESS on that parent HEAD.
- QA384 is closed after explicit Verify, PostgreSQL 16 and PostgreSQL 17.6 success markers. CodeQL #1342 and Vercel status also completed successfully.

## Objective

Protect the existing quantity boundary without changing application behavior or selecting a new business rule. The current migration explicitly rejects p_quantity <= 0 with INVALID_QUANTITY; the runtime suite had NaN, positive/negative Infinity and other invalid-input coverage, but no isolated zero-quantity boundary case.

## Changes

1. Appended a disposable PostgreSQL runtime block to tests/sql/create-offer-runtime.sql.
   - Uses an authenticated fixture identity and otherwise-valid tenant, actor, demand, product, price and currency.
   - Calls execute_create_offer_v1 with p_quantity = 0::numeric.
   - Requires exactly INVALID_QUANTITY.
   - Compares before/after counts for idempotency_keys, action_executions, offers and action_events, and verifies that the fixture key and offer are absent.
   - Emits an explicit QA385 PASS notice.
2. Added tests/sql/test-create-offer-zero-quantity-contract.sh.
   - Protects the existing strictly-positive quantity guard and exact error.
   - Requires the runtime zero case, expected error, four-table no-side-effect assertions and success marker.
   - Requires Verify plus the shared PostgreSQL 16 and 17.6 runtime runner wiring.
3. Added the QA385 contract to the Verify job in .github/workflows/ci.yml.

## Validation

- Source-level construction was reviewed against the current migration guard and shared disposable runtime fixture.
- QIMA CI #1395 completed SUCCESS on HEAD `5d12a3cd76a9394ba96a2e8bc7cdc4bccb44abe0`. Verify emitted `QA385 PASS`; PostgreSQL 16 and PostgreSQL 17.6 runtime logs each emitted the explicit `QA385 PASS` marker. Both integration jobs completed SUCCESS.

## Safety and decision boundaries

- No migration or application code changed.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No price-zero acceptance test was added; that would freeze a separate commercial rule unnecessarily.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.


## Correction pré-validation du contrat shell

- La revue du premier commit a détecté que l'échappement du littéral BASH_SOURCE conservait un antislash dans le script généré. La résolution ROOT a été corrigée vers dirname "$0" avant de considérer un résultat CI comme valide.
- Cette correction ne modifie ni le SQL testé ni la garde de quantité. La validation QA385 reste en attente sur le HEAD corrigé.


## CI #1395 — clôture QA385 sur PostgreSQL 16 et 17.6 (13 novembre 2026)

- QIMA CI [#1395](https://github.com/meridane/QimaTrade-MVP/actions/runs/43434312922) a terminé **SUCCESS** sur le HEAD corrigé `5d12a3cd76a9394ba96a2e8bc7cdc4bccb44abe0`.
- Verify a émis le marqueur explicite `QA385 PASS`; npm audit au seuil high, TypeScript, build Next.js et **347/347 Playwright** ont réussi.
- Le job PostgreSQL 16 a terminé **SUCCESS**. Son journal contient `QA385 PASS: zero quantity is rejected as INVALID_QUANTITY before idempotency, execution, offer or action-event persistence`.
- Le job PostgreSQL 17.6 a terminé **SUCCESS** et contient le même marqueur runtime.
- Les deux jobs ont également terminé les tests CREATE_OFFER, la caractérisation QA381, les tests RLS/ACL et le nettoyage. Les harnesses de setup/nettoyage volontairement en échec ont conservé leurs conclusions individuelles attendues; les jobs d'assertion dédiés ont réussi. Le job volontairement skipped est resté skipped et son assertion a réussi.
- CodeQL [#1344](https://github.com/meridane/QimaTrade-MVP/actions/runs/43434312884) et le check Vercel du HEAD ont terminé **SUCCESS**.
- QA385 est **CLOSED**. Ces preuves concernent les environnements PostgreSQL jetables de CI; elles ne constituent pas une validation de Production ni une conclusion de vulnérabilité.
