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


## Intermediate Verify closeout
- The fixture-only intermediate run [46098394680](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098394680) completed its Verify job SUCCESS: dependency audit, TypeScript, production build, browser tests and the isolated QIMA security fixture all passed.
- This intermediate commit did not yet include the new Auth 401 test loop. Its result must not be used as validation of the final 401 matrix.
- The final-head run [46098403789](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403789) remains PENDING with no jobs; CodeQL [46098403749](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098403749) is SUCCESS.


## Intermediate browser-suite detail
- Verify log for job `140834990651` in run [46098394680](https://github.com/meridane/QimaTrade-MVP/actions/runs/46098394680) records **462 Playwright tests passed** and the isolated QIMA security fixture passed.
- The route matrix in that intermediate snapshot still contained Auth 429/500/502/503/504 only. It did not include HTTP 401; that case exists only in final code head `ff1643ed`, whose QIMA CI remains queued.

 
## Auth 403 follow-up — 2026-11-28

- Extended the disposable Auth fixture to return a distinct synthetic 403 access_denied response.
- Added HTTP 403 to the pre-membership Auth failure matrix: 401, 403, 429, 500, 502, 503 and 504.
- Every status must return 401 UNAUTHENTICATED before any membership read, action-definition RPC or publish RPC.
- Code commits: fixture change (parent of 9bae97ec) and https://github.com/meridane/QimaTrade-MVP/commit/9bae97ec70be9e6313c73718dd5ebab8aed6ea5a (route regression).
- The previous final code head ff1643ed is now fully validated by QIMA CI #46098403789: 463 Playwright passed, including Auth 401/429/500/502/503/504; Verify succeeded; PostgreSQL 16 48/48 and PostgreSQL 17.6 33/33 succeeded. CodeQL #46098403749 succeeded.
- New head 9bae97ec has QIMA CI #46106187513 IN PROGRESS and CodeQL #46106187493 IN PROGRESS at this checkpoint. No passing result is attributed to the new 403 case yet.
- The new 403 case is synthetic. It does not prove a live Auth outage, RLS defect, cross-tenant leak or exploitable Production vulnerability. No Production data, schema, policy, grant or secret was changed.
