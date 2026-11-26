# QIMA V1 Function Register — append-only validation note

## Canonical UUID text-shape regression — 22 November 2026, 04:59 KST

### Baseline inspected before change

- PR #26 is OPEN, DRAFT, not merged, and mergeable; base `main`, head branch `fix/create-offer-status-contract`.
- Baseline HEAD: `517a8f7089eb2cb531f0afe9422916dd7f56a9b2`; 2,220 commits ahead / 0 behind; 282 changed files (89,643 additions / 264 deletions).
- QIMA CI #1781 completed SUCCESS. Its browser job reports **408 Playwright tests passed**; npm audit reports 1 moderate, 0 high, 0 critical; TypeScript, Next.js production build, and the local QIMA security-contract fixture passed. PostgreSQL 16 and 17.6 integration jobs both completed SUCCESS.
- CodeQL #1709 completed SUCCESS. The combined GitHub status for the baseline HEAD reports Vercel Preview SUCCESS.
- The canonical register was read through its Git blob because the Contents response returned an empty UTF-8 body. Blob SHA: `5a7063a8d628e0de3962dd372b3eb9f1d9d525f7`. Its complete content was retrieved; no canonical file was overwritten.

### Change

- Extended `tests/e2e/create-offer-route-contract.spec.ts`:
  - Added an uppercase canonical UUID to the accepted Auth user-id fixtures, protecting the case-insensitive UUID grammar.
  - Added malformed UUID text fixtures for surrounding whitespace, missing hyphens, braces, an incorrect group length, and a non-hex character.
  - All malformed values must fail closed with HTTP 503 / `AUTH_SERVICE_UNAVAILABLE` before any profile or membership lookup.
  - The accepted uppercase UUID must traverse the expected Auth/profile/membership/action-definition/CREATE_OFFER sequence and remain visible in the exact profile and membership filters used by the route.
- No application route, SQL, migration, Supabase production data, secret, grant, or persistent RLS policy was changed.

### Validation status

- Baseline CI #1781 and CodeQL #1709 are successful, but they validate the parent HEAD only.
- The new uppercase and malformed-shape fixtures have not yet been run by GitHub Actions. A new PR validation is expected after this change is advanced to the PR branch.
- No local tests were executed.

### Safety boundary

- UUID values are synthetic fixtures.
- No Supabase Production connection or write was performed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.

### Post-publication CI snapshot — 22 November 2026, 05:00 KST

- Test commit: `4408791307bdc3213710d08722da910501a4b329`; documentation HEAD before this snapshot: `d9b3a47ed54b3d7d11d674b794fe05e3997c4928`.
- QIMA CI run [44944014584](https://github.com/meridane/QimaTrade-MVP/actions/runs/44944014584) is **IN PROGRESS** on the new PR HEAD. At the last job-step inspection, npm audit and TypeScript were **SUCCESS**, the production build was **IN PROGRESS**, and Playwright plus the QIMA fixture were **PENDING**. PostgreSQL 16 and PostgreSQL 17.6 integration jobs were still **IN PROGRESS**.
- The two prepared-transaction failure harness jobs have their expected job-level **FAILURE** outcomes; the separate assertions that verify cleanup and preserve the failure are **SUCCESS**. The deliberately skipped harness remains **SKIPPED**.
- CodeQL run [44944014559](https://github.com/meridane/QimaTrade-MVP/actions/runs/44944014559) is **IN PROGRESS**.
- Vercel Preview combined status for the new PR HEAD is **PENDING**.
- No Playwright or PostgreSQL success is claimed for the newly added UUID cases until these jobs finish.
- This snapshot is documentation-only; it does not change the test code or production behavior.
