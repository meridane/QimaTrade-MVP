# QIMA SECURITY — follow-up 2026-11-28

## Scope and branch
- Branch: `work/qima-security-error-boundary-20261127-0441`
- Tested code head: `ff1643edc2a4e700f18d0b6fb4d15c7e8cb5688c`
- Parent mission PR: [#27](https://github.com/meridane/QimaTrade-MVP/pull/27), OPEN / DRAFT.
- Source base: PR #26 HEAD `61002cb21aaa738a7f018794ab84bff41a2c6eb2`.

## New regression
- `tests/fixtures/mock-supabase-auth-server.mjs`: allow synthetic Auth HTTP 401 and return an `invalid_token` response for that status.
- `tests/e2e/product-request-publish-route-contract.spec.ts`: add Auth HTTP 401 to the fail-closed matrix (401, 429, 500, 502, 503, 504).
- Each case starts from a valid synthetic session and membership fixture, then requires HTTP 401 UNAUTHENTICATED with zero membership reads, zero definition RPC calls and zero publish RPC calls. Fixtures are restored in `finally`.

## Commits
- `ce2047c8d6c7fe0a1731eb0d21f0e30bb0216806` — synthetic invalid-token response.
- `ff1643edc2a4e700f18d0b6fb4d15c7e8cb5688c` — route regression for invalid Auth token.

## Validation
- Earlier snapshot `566c2f4e`: QIMA CI [run 46094838391](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094838391) SUCCESS, 461 Playwright tests, PostgreSQL 16 and 17.6 SUCCESS; CodeQL [run 46094838407](https://github.com/meridane/QimaTrade-MVP/actions/runs/46094838407) SUCCESS.
- Current final-head QIMA CI [run 46098403789](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403789): PENDING, no jobs published at the latest read. No result is claimed for the new 401 case.
- CodeQL [run 46098403749](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403749): IN PROGRESS.
- The intermediate fixture-only run [46098394680](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098394680) is separate from the final test head.
- Vercel status for the final branch snapshot reports the external `build-rate-limit` failure.

## Security interpretation
The 401 case is synthetic contract coverage. It does not establish a live Auth outage, RLS failure, cross-tenant exposure or exploitable Production vulnerability. No Production policy, grant, secret, data or schema was touched.

## Next step
Wait for the final-head Verify and CodeQL workflows to complete; inspect the exact Auth 401 Playwright result before marking this regression validated.


## CodeQL closeout update
- CodeQL [run 46098403749](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403749) for final code head `ff1643ed` completed **SUCCESS**.
- QIMA CI [run 46098403789](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403789) remains PENDING with no jobs published; the intermediate fixture-only run [46098394680](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098394680) is still IN PROGRESS. The Auth 401 matrix has no final Verify result yet.
