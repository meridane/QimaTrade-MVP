# QIMA V1 Function Register — append-only execution supplement

Date: 2026-11-20 08:59 KST

Repository: `meridane/QimaTrade-MVP`  
Pull request: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`

## Verified starting state

- PR state: OPEN, DRAFT, not merged; GitHub reported `mergeable=true`.
- Starting PR HEAD: `03d193937d17f1c7f06b9a44b0e6265b971e04b9`.
- Base: `main`; comparison: 2,056 commits ahead, 0 behind.
- PR diff: 268 files, 86,850 additions, 261 deletions.
- Latest checks on the starting HEAD: QIMA CI #1669 SUCCESS, CodeQL #1600 SUCCESS, Vercel status SUCCESS.
- Code/test parent: `e74dcb6909eee0e0d1f37e4c344f4889f9c2cb80`; QIMA CI #1666 and CodeQL #1597 completed SUCCESS. The prior recorded Verify result for that code parent was 395/395 Playwright.

## Regression coverage added in this execution

File: `tests/e2e/create-offer-route-contract.spec.ts`

The existing test for explicit tenant selection with multiple memberships now runs both membership orders:
1. first tenant followed by second tenant;
2. second tenant followed by first tenant.

Both cases submit the same client-supplied `tenantId` and assert:
- HTTP 409;
- exact `TENANT_SELECTION_REQUIRED` JSON response;
- only Auth, profile, and membership reads occur;
- no `execute_create_offer_v1` RPC is called.

This is an order-invariance regression test for the already implemented rule that more than one distinct membership requires explicit tenant selection. It does not introduce or decide a new tenant-selection policy.

## Validation status

- No local test suite was run in this execution.
- A new QIMA CI and CodeQL run will be triggered by publishing the test commit to the PR branch; results must be recorded only after GitHub reports them.
- No application code, SQL, migrations, Supabase Production data, grants, RLS policies, secrets, or production deployment were changed.

## Registry retrieval limitation

The GitHub file-content connector returned a valid blob SHA but an empty content body for the 2.35-million-character canonical `docs/QIMA_V1_FUNCTION_REGISTER.md`, including when requesting line ranges and base64 encoding. Its PR patch was also unavailable (`patch=null`). To avoid replacing the canonical register with incomplete content, this execution is recorded in this append-only companion file. The canonical register itself was not modified.

## Next step

Verify the new Playwright run, PostgreSQL 16/17.6 jobs, CodeQL, and Preview checks for the new PR HEAD. Once full canonical register content is retrievable, fold this supplement into `docs/QIMA_V1_FUNCTION_REGISTER.md` without dropping its history.
