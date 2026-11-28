# QIMA TESTS — follow-up 2026-11-28

## Scope and branch
- Branch: `work/qima-tests-publish-runtime-20261127-0441`
- Tested code head: `175ff9f5e7cf324379e76c80830d8cd36b3733f6`
- Mission PR: [#28](https://github.com/meridane/QimaTrade-MVP/pull/28), OPEN / DRAFT.
- Source base: PR #26 HEAD `61002cb21aaa738a7f018794ab84bff41a2c6eb2`.

## New regression
- File: `tests/e2e/action-runtime-publish-product-request.spec.ts`.
- Commit: `175ff9f5e7cf324379e76c80830d8cd36b3733f6`.
- A successful HTTP 200 publish RPC response includes the valid `demandId` plus unknown `details`, `hint` and `tenant_id` fields.
- The public ActionResult must contain only the normalized request ID, demand ID and source; the synthetic internal fields must not be propagated.

This complements existing tests for empty HTTP 204, malformed/truncated JSON, 401/403/429/5xx, absent definitions, invalid UUIDs and no-retry behavior.

## Validation
- Previous snapshot `3d3041a3`: QIMA CI [run 46094833714](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094833714) SUCCESS, 461 Playwright tests, PostgreSQL 16 and 17.6 SUCCESS; CodeQL [run 46094833583](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094833583) SUCCESS.
- Current QIMA CI [run 46098391508](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098391508): IN PROGRESS. Verify is still building; PostgreSQL 16 and 17.6 jobs are active. No result is yet claimed for the new unknown-metadata test.
- CodeQL [run 46098391500](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098391500): IN PROGRESS.
- Vercel Preview: PENDING at the latest status read.

## Interpretation
The test checks response normalization and output minimization in a local synthetic HTTP server. It does not prove that a Production endpoint leaked data.

## Next step
Inspect the new test in the Verify log, then wait for PostgreSQL 16/17.6 and CodeQL conclusions.
