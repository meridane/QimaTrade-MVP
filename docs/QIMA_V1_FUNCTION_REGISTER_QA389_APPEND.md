# QA389 — CREATE_OFFER NaN quantity boundary regression

Date: 2026-11-14 (KST)
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Branch: fix/create-offer-status-contract
Working branch: work/qa389-nan-quantity-boundary-20261114-0254
Status: IMPLEMENTED — VERIFY SUCCESS; POSTGRESQL JOBS IN PROGRESS

## Initial state verified

- PR #26 is OPEN, draft and unmerged; HEAD verified before this change: 685490710046873b69563d066277f742aeb9c36f.
- The latest completed QIMA CI run on that HEAD was [#43461032639](https://github.com/meridane/QimaTrade-MVP/actions/runs/43461032639), conclusion SUCCESS.
- Verify emitted QA382 through QA388 PASS; PostgreSQL 16 and PostgreSQL 17.6 emitted QA388 PASS and QA381 passed; both jobs completed SUCCESS.
- QIMA CodeQL [#43461032644](https://github.com/meridane/QimaTrade-MVP/actions/runs/43461032644) completed SUCCESS; the Vercel Preview status check on the same HEAD completed SUCCESS.
- QA388 was confirmed CLOSED before starting QA389.

## Objective

The existing migration rejects PostgreSQL numeric NaN for p_quantity through its explicit text-domain guard. QA384 already characterizes NaN for p_price, but its matrix does not include NaN for p_quantity. QA389 adds the missing quantity-side runtime case without changing the existing domain rule.

## Changes

1. Appended one disposable PostgreSQL DO block to tests/sql/create-offer-runtime.sql.
   - Uses p_quantity = 'NaN'::numeric and a valid finite price.
   - Requires exactly INVALID_QUANTITY.
   - Compares before/after row counts for idempotency_keys, action_executions, offers and action_events.
   - Verifies that the fixture idempotency key, execution and offer remain absent.
   - Emits one explicit QA389 PASS marker.
2. Added tests/sql/test-create-offer-nan-quantity-contract.sh.
   - Requires the existing migration quantity guard and INVALID_QUANTITY error.
   - Requires the isolated NaN-quantity runtime block, exact error assertion and four-table no-side-effect checks.
   - Requires the Verify step and shared PostgreSQL 16/17.6 runtime wiring.
3. Added the QA389 static contract to the Verify job.

## Validation

- Static source checks were performed on the constructed SQL block, shell contract and workflow wiring before publication.
- QA389 remains PENDING until Verify emits QA389 PASS and both PostgreSQL 16 and PostgreSQL 17.6 jobs complete SUCCESS with the runtime marker.
- The test is a regression characterization of the existing NaN rejection rule in disposable CI databases only.

## Safety and decision boundaries

- No application code or migration was modified.
- No Supabase Production data, schema, RLS policy, grant, secret or persistent PostgreSQL setting was accessed or modified.
- No numeric canonicalization or new business acceptance rule was introduced.
- MKT-1.1 demand/tenant ownership, MKT-1.2 independent-draft idempotency semantics and MKT-1.3 numeric canonicalization remain unapproved.
- No Production deployment, PR merge, force update or branch-protection change was performed.


## Interim CI evidence — 14 November 2026

- The implementation commit is 52e7d34e1ef53c3de989fc16f1bc5be86cc95408; the PR branch and working branch were fast-forwarded to this commit.
- QIMA CI [#43477926780](https://github.com/meridane/QimaTrade-MVP/actions/runs/43477926780) is IN_PROGRESS.
- Verify completed the QA389 static contract step successfully. All preceding QA382–QA388 contract steps in the same Verify job also completed successfully.
- PostgreSQL 16 job 132066564285 is IN_PROGRESS at the shared CREATE_OFFER runtime/integration step.
- PostgreSQL 17.6 job 132066563701 is IN_PROGRESS at the shared CREATE_OFFER runtime/integration step.
- Typecheck/audit/build/browser job 132066564397 is IN_PROGRESS; the audit and preceding static checks have completed successfully.
- QIMA CodeQL [#43477926783](https://github.com/meridane/QimaTrade-MVP/actions/runs/43477926783) completed SUCCESS.
- The Vercel Preview Comments status check on this HEAD is SUCCESS; this is not a Production deployment.
- QA389 remains PENDING until the runtime marker and successful completion of both PostgreSQL jobs are confirmed.


## Validation update — 14 November 2026

- The Verify job 132066564397 completed SUCCESS on code HEAD 52e7d34e1ef53c3de989fc16f1bc5be86cc95408. Its log emitted QA389 PASS; QA382 through QA388 static contracts also passed.
- The same Verify job completed npm audit at the configured high threshold, TypeScript, Next.js production build and 347/347 Playwright tests successfully.
- PostgreSQL 16 job 132066564285 completed the shared CREATE_OFFER runtime/integration step SUCCESS, which executes tests/sql/create-offer-runtime.sql including QA389. Its later database/privilege characterization steps remain in progress.
- PostgreSQL 17.6 job 132066563701 completed the shared CREATE_OFFER runtime/integration step SUCCESS, including the same runtime file. Its later catalog/privilege characterization steps remain in progress.
- QIMA CodeQL [#43477926783](https://github.com/meridane/QimaTrade-MVP/actions/runs/43477926783) completed SUCCESS.
- QIMA CI [#43477926780](https://github.com/meridane/QimaTrade-MVP/actions/runs/43477926780) remains IN_PROGRESS because the PostgreSQL jobs have not yet completed. QA389 remains PENDING until both full jobs complete SUCCESS and their final logs are available for confirmation.
- The Vercel Preview Comments status check on code HEAD 52e7d34e1ef53c3de989fc16f1bc5be86cc95408 is SUCCESS.
