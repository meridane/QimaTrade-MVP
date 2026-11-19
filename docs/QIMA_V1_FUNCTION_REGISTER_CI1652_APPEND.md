# QIMA V1 Function Register — CI #1652 append-only snapshot

Date: 2026-11-19 (KST)  
Repository: `meridane/QimaTrade-MVP`  
Pull request: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Branch: `fix/create-offer-status-contract`

## Verified state before this append

- PR #26 is OPEN, DRAFT, not merged; base branch `main`; head `7bf95d8ab0126a9fc3553d79abd0b8cdd2f73873`; 268 changed files; GitHub reports `mergeable=true` and `mergeable_state=unstable`.
- Latest branch commits:
  - `7d0e6a1aa7a0a880fb98498fd6582570a9c60144` — strengthen the FAILED idempotency replay route test to make two requests with the same key and assert exact response replay, one create, one replay, and identical RPC input.
  - `7bf95d8ab0126a9fc3553d79abd0b8cdd2f73873` — record CI #1651 and the strengthened FAILED replay route contract.
- QIMA CI [#1652](https://github.com/meridane/QimaTrade-MVP/actions/runs/44532285597) completed SUCCESS on the current head. Verify job `135588466095` completed successfully; its log reports **393 Playwright tests passed (12.6 s)**, with npm audit, TypeScript, Next.js production build and Chromium installation successful.
- PostgreSQL 16 integration job `135588466581` and PostgreSQL 17.6 job `135588466322` both completed SUCCESS, including CREATE_OFFER integration/concurrency and runner privilege characterization.
- CodeQL [#1584](https://github.com/meridane/QimaTrade-MVP/actions/runs/44532285411) completed SUCCESS. Vercel Preview status for the current head is SUCCESS: [Preview](https://vercel.com/bmk1/qimatrade-mvp/B9CCkfCRDqENGGKpSJaFTfshJjZb).
- Prepared-transaction setup-failure and cleanup-failure jobs have their expected negative conclusions; the corresponding assertion jobs succeeded. The explicitly skipped job remained skipped and was checked by its assertion job.

## Additional regression prepared after CI #1652

Working branch: `work/create-offer-running-error-redaction-20261119-2319`  
Test commit: `84b9a01884fc511485f16ebd9ae176d2cc3f3045`

File: `tests/e2e/create-offer-route-contract.spec.ts`

The new test exercises the already allowlisted SQL domain code `ACTION_ALREADY_RUNNING` while the mocked PostgREST response also contains private `details` and `hint` sentinels. It asserts the existing HTTP 400 mapping, exact public JSON body `{ error: "ACTION_ALREADY_RUNNING" }`, absence of private details/hints and SQLSTATE, no authentication challenge, the expected request sequence, and bearer forwarding.

This is a test-only change. It does not alter the API status mapping or make a new business decision. CI validation is pending until the working branch is fast-forwarded to the PR branch. No local project tests were run.

## Safety boundary

No Supabase Production data, migrations, persistent RLS policies, grants, secrets, or PostgreSQL production configuration were touched. No production deployment, PR merge, force-push, or branch-protection change was performed. Synthetic HTTP/Proxy fixtures are contract tests and do not establish a confirmed vulnerability.
