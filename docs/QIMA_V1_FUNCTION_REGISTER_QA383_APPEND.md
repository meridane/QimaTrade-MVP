# QA383 — CREATE_OFFER tenant-scoped idempotency lock and lookup contract

Date: 2026-11-13 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Branch: `fix/create-offer-status-contract`  
Working branch: `work/qa383-tenant-idempotency-scope-contract-20261113-2033`  
Status: **STATIC CONTRACT PASS — FULL CI #1390 SUCCESS**

## Initial state verified

- PR #26 is OPEN, DRAFT, mergeable, not merged; base `main`, head `9d6218f8f8fc9778cbcbd059fcf5e7f0f775ee0c`.
- PR metadata reports 1,679 commits and 158 changed files; no behind commits were reported in the prior branch comparison.
- QIMA CI [#1388](https://github.com/meridane/QimaTrade-MVP/actions/runs/43409348348) completed **SUCCESS** on `9d6218f8f8fc9778cbcbd059fcf5e7f0f775ee0c`.
- PostgreSQL 16 and PostgreSQL 17.6 jobs both emitted the explicit **QA381 passed** marker.
- Verify emitted the explicit **QA382 PASS** marker and completed **347/347 Playwright tests**, npm audit at the configured high threshold, TypeScript and Next.js build.
- CodeQL [#1337](https://github.com/meridane/QimaTrade-MVP/actions/runs/43409348473) completed **SUCCESS**.
- The PR has no submitted human reviews at the time of this run.

## Objective

Protect the existing `public.execute_create_offer_v1` tenant-scoped idempotency contract against accidental refactors that:
- omit tenant ID or idempotency key from the advisory transaction lock;
- query an existing key without both tenant and key;
- stop persisting the tenant/key pair on the idempotency and execution rows;
- update a completed idempotency row outside its tenant/key scope; or
- reorder the business arguments passed to `public.create_offer_v1`.

This is a static regression guard for the current RPC. It does not introduce a new idempotency policy or change runtime behavior.

## Changes

1. Added `tests/sql/test-create-offer-tenant-idempotency-scope-contract.sh`.
   - Verifies the exact public RPC parameter order.
   - Requires one advisory transaction lock based on both `p_tenant_id` and `p_idempotency_key`.
   - Requires that the lock precede the existing-row lookup.
   - Requires the lookup to match `tenant_id` and `key` and retain `FOR UPDATE`.
   - Requires the request-hash mismatch to retain `IDEMPOTENCY_KEY_REUSE`.
   - Requires idempotency and execution inserts to persist both scope values.
   - Requires the completion update to remain scoped by tenant and key.
   - Verifies the ordered 15-argument mapping into `create_offer_v1`.
   - Verifies the existing disposable same-key/two-tenant regression still checks distinct executions/offers, equal business hashes, isolated replays and unchanged tenant B state after a rejected tenant A payload.

2. Updated `.github/workflows/ci.yml` so the Verify job executes the new contract exactly once.

3. Updated the canonical function register and QA382 appendix with the final CI #1388 evidence; added this QA383 appendix.

## Decision gates deliberately unchanged

- MKT-1.1 demand-to-tenant authorization/eligibility remains subject to an approved ownership model.
- MKT-1.2 independent legacy-draft idempotency scope, retention, browser persistence, cross-tab semantics and storage architecture remain **PROPOSAL ONLY — NOT APPROVED**.
- MKT-1.3 numeric precision/scale equivalence, JSONB numeric normalization, NULL/empty semantics and hash-version compatibility remain **DECISION REQUIRED — NOT APPROVED**.

QA383 protects the existing server RPC's tenant/key isolation mechanics only. It does not decide independent draft semantics or alter tenant authorization policy.

## Pre-publication validation

- Source inspection confirmed the current migration contains the expected 18-parameter signature, tenant/key advisory lock, tenant/key `FOR UPDATE` lookup, tenant-scoped inserts/update and ordered 15-argument `create_offer_v1` call.
- Source inspection confirmed the existing disposable runtime test retains same-key requests for two tenants, distinct execution/offer assertions, equal request hashes, independent replay assertions and rejection of a changed tenant A payload without changing tenant B.
- The new shell contract has not yet run in GitHub Actions on this HEAD. Do not claim QA383 PASS until Verify emits its marker.
- Runtime behavior is unchanged; the existing PostgreSQL 16/17.6 integration suite will rerun as part of CI.

## Safety

- No application code, SQL function, migration, schema, RLS policy, grant, secret, Production data or persistent PostgreSQL configuration changed.
- No Supabase Production access or write was performed.
- No Production deployment, PR merge, force update or branch-protection change was performed.


## CI #1389 — validation intermédiaire (13 novembre 2026)

- QIMA CI [#1389](https://github.com/meridane/QimaTrade-MVP/actions/runs/43418623371) est **IN PROGRESS** sur HEAD `5b72f9fd22367c9059f01a71dbf4f3278cb4672e`.
- Le step `Verify CREATE_OFFER tenant-scoped idempotency lock and lookup contract` a terminé **SUCCESS**. Les contrats QA382, QA371/QA372, TypeScript, npm audit (seuil high configuré) et build Next.js ont également terminé **SUCCESS**.
- L'installation de Chromium est encore en cours; Playwright est en attente.
- Les jobs PostgreSQL 16 et 17.6 sont encore dans les tests d'intégration/concurrence; aucun nouveau marqueur QA381 n'est disponible pour ce HEAD au dernier contrôle.
- CodeQL [#1338](https://github.com/meridane/QimaTrade-MVP/actions/runs/43418623406) : **SUCCESS**. Vercel Preview : **SUCCESS**.
- La validation complète de CI #1389 reste en attente; QA383 n'est pas présenté comme une validation runtime.


## Final validation — CI #1390 (13 novembre 2026)

- QIMA CI [#1390](https://github.com/meridane/QimaTrade-MVP/actions/runs/43418890927) completed **SUCCESS** on HEAD `365def07e18753c0053fb4f718e7bb7e98255226`.
- Verify emitted the explicit **QA382 PASS** and **QA383 PASS** markers. npm audit at the configured high threshold, TypeScript, Next.js build and **347/347 Playwright tests** completed successfully.
- The PostgreSQL 16 integration job and PostgreSQL 17.6 compatibility job both completed **SUCCESS**. Both logs emitted the explicit **QA381 passed** marker after the four-setting membership/privilege matrix and complete cleanup. The shared integration runner also completed, including the existing same-key/two-tenant runtime characterization.
- CodeQL [#1339](https://github.com/meridane/QimaTrade-MVP/actions/runs/43418890929) completed **SUCCESS**. The Vercel Preview status check for this HEAD completed **SUCCESS**.
- The prepared-transaction harness jobs that deliberately inject setup/cleanup failures retained their expected job-level `failure` outcomes; the separate blocking assertions completed **SUCCESS**. The dedicated expected-skipped job remained **SKIPPED**, with its assertion successful.
- QA383 is a static source-contract guard paired with the existing disposable PostgreSQL runtime scenario. CI #1390 completed both layers successfully; no tenant-authorization or independent-draft business policy was inferred.
