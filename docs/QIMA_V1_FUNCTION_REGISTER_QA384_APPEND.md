# QA384 — CREATE_OFFER finite numeric-domain regression

Date: 2026-11-13 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Branch: `fix/create-offer-status-contract`  
Working branch: `work/qa384-numeric-domain-guard-20261113-2125`  
Status: **TEST-SPECIFIC PASS — VERIFY + PG16/PG17 RUNTIME STEP PASS; FULL CI IN PROGRESS**

## Initial state verified

- PR #26: OPEN, DRAFT, mergeable, not merged; base `main`, head `365def07e18753c0053fb4f718e7bb7e98255226`.
- QIMA CI [#1390](https://github.com/meridane/QimaTrade-MVP/actions/runs/43418890927) completed **SUCCESS** on the current HEAD.
- Verify emitted explicit QA382 and QA383 PASS markers; npm audit at the configured high threshold, TypeScript, Next.js build and 347/347 Playwright tests passed.
- PostgreSQL 16 and 17.6 jobs both completed SUCCESS and emitted the explicit QA381 passed marker.
- CodeQL [#1339](https://github.com/meridane/QimaTrade-MVP/actions/runs/43418890929) completed SUCCESS; Vercel Preview status for the HEAD completed SUCCESS.

## Objective

Preserve the current `CREATE_OFFER` numeric-domain checks without selecting or changing numeric canonicalization policy. PostgreSQL `numeric` supports special values; the existing function explicitly rejects NULL, NaN and both infinities, requires quantity > 0, and requires price >= 0.

The existing runtime fixture covered NaN quantity, positive-Infinity quantity/price and negative price. This task fills the missing negative-Infinity quantity, NaN price and negative-Infinity price cases and verifies that rejected calls leave no idempotency, execution or offer rows.

## Changes

1. Added a QA384 disposable runtime block to `tests/sql/create-offer-runtime.sql`.
   - Exercises negative-Infinity quantity, NaN price and negative-Infinity price.
   - Requires the existing `INVALID_QUANTITY` or `INVALID_PRICE` error for each case.
   - Checks that no idempotency key, action execution or offer is persisted.
   - Emits an explicit `QA384 PASS` notice.
2. Added `tests/sql/test-create-offer-numeric-domain-contract.sh`.
   - Protects the existing exact quantity and price guard expressions in the migration source.
   - Requires the three missing runtime cases, error checks, no-side-effect assertions and success marker.
   - Requires the shared runtime fixture to execute once and both PostgreSQL 16/17.6 CI jobs to invoke the integration runner.
3. Added the new static contract to the Verify job in `.github/workflows/ci.yml`.

## Decision gates deliberately unchanged

- MKT-1.1 demand-to-tenant authorization/eligibility remains subject to an approved ownership model.
- MKT-1.2 independent legacy-draft idempotency scope, retention and browser/cross-tab semantics remain **PROPOSAL ONLY — NOT APPROVED**.
- MKT-1.3 numeric precision/scale equivalence, JSONB numeric normalization, NULL/empty semantics and hash-version compatibility remain **DECISION REQUIRED — NOT APPROVED**. QA384 only preserves the existing finite/sign domain checks; it does not choose a canonicalization rule.

## Validation

- Source review confirms the migration currently contains the exact finite/sign guards and existing runtime cases described above.
- The new Verify contract and the three new PostgreSQL runtime cases have not yet executed on the new HEAD. Do not claim QA384 PASS until Verify emits its marker and both PostgreSQL jobs emit the QA384 runtime notice.
- CI #1390 is the successful baseline on the parent HEAD, not validation of this change.

## Safety

- No migration file, application code, Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was changed.
- No Supabase Production access or write was performed.
- No Production deployment, PR merge, force update or branch-protection change was performed.


## CI #1391 — validation intermédiaire (13 novembre 2026)

- QIMA CI [#1391](https://github.com/meridane/QimaTrade-MVP/actions/runs/43425671182) is **IN PROGRESS** on HEAD `c3370c7abd5443cca271c30bac0d95ba752288e5`.
- Verify completed the new `Verify CREATE_OFFER finite numeric-domain rejection coverage` step with **SUCCESS**. The preceding numeric/hash/tenant contracts also succeeded; npm audit at the configured high threshold and TypeScript completed successfully. The Next.js build was still running; Chromium installation and Playwright had not started at the last step check.
- PostgreSQL 16 and PostgreSQL 17.6 jobs were both in progress inside the shared CREATE_OFFER integration runner. The new QA384 runtime notice had not yet been observed; do not claim runtime PASS.
- Vercel Preview Comments for this HEAD completed **SUCCESS**. CodeQL [#1340](https://github.com/meridane/QimaTrade-MVP/actions/runs/43425671102) was **IN PROGRESS**.
- The intentionally failing prepared-transaction harness jobs retained their expected job-level failure outcomes; their blocking assertions passed. The expected-skipped harness remained skipped and its assertion passed.
- This is an interim result only. QA384 remains open until Verify and both PostgreSQL jobs complete successfully on the final HEAD.


## CI #1391 — QA384 test-specific validation (13 novembre 2026)

- QIMA CI [#1391](https://github.com/meridane/QimaTrade-MVP/actions/runs/43425671182) remains **IN PROGRESS** on code HEAD `c3370c7abd5443cca271c30bac0d95ba752288e5`.
- Verify completed **SUCCESS**. Its log contains the explicit `QA384 PASS` marker from `tests/sql/test-create-offer-numeric-domain-contract.sh`; npm audit at the configured high threshold, TypeScript, Next.js build, Chromium installation and **347/347 Playwright tests** also completed successfully.
- PostgreSQL 16 `Run isolated CREATE_OFFER integration and concurrency tests` and PostgreSQL 17.6 `Run CREATE_OFFER integration and concurrency tests on PostgreSQL 17` both completed **SUCCESS**. Each step executes `tests/sql/create-offer-runtime.sql` through the shared integration runner, so the three QA384 negative-Infinity/NaN cases and their no-persisted-side-effect assertions completed without error on both versions.
- The PostgreSQL jobs were still running later QA381 privilege characterization and subsequent independent regressions; therefore the overall CI #1391 conclusion was not yet available. Do not describe the full workflow as complete.
- CodeQL [#1340](https://github.com/meridane/QimaTrade-MVP/actions/runs/43425671102) completed **SUCCESS** on the code HEAD. CodeQL [#1341](https://github.com/meridane/QimaTrade-MVP/actions/runs/43425914970) completed **SUCCESS** on the documentation HEAD `85d8099cc743f19064f0c2759381bcbec3509279`.
- Vercel Preview Comments for documentation HEAD `85d8099cc743f19064f0c2759381bcbec3509279` completed **SUCCESS**. QIMA CI [#1392](https://github.com/meridane/QimaTrade-MVP/actions/runs/43425915175) was **PENDING** for that documentation-only HEAD at the last check.
- QA384 test-specific validation is **PASS** on Verify, PostgreSQL 16 and PostgreSQL 17.6. The overall CI remains in progress because later independent jobs have not finished.
