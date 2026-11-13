# QA384 — CREATE_OFFER finite numeric-domain regression

Date: 2026-11-13 (KST)  
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Branch: `fix/create-offer-status-contract`  
Working branch: `work/qa384-numeric-domain-guard-20261113-2125`  
Status: **IMPLEMENTED — CI VALIDATION PENDING**

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
