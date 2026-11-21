# QIMA V1 Function Register — append-only update

## Auth UUID version compatibility — 22 November 2026, 03:19 KST

### Baseline verified before change

- PR #26 is OPEN, DRAFT, not merged, and mergeable at the time of inspection.
- Base branch: `main`; head branch: `fix/create-offer-status-contract`.
- Previous PR HEAD: `4215cbaeb2f4a4cd9e97e3cfc0727202ce99af90`; 2,218 commits ahead / 0 behind; 281 changed files.
- QIMA CI #1780 completed SUCCESS. Verify reported 407 Playwright tests passed, npm audit reported 1 moderate / 0 high / 0 critical, TypeScript and production build passed, the local QIMA security-contract fixture passed, and PostgreSQL 16 plus 17.6 integration jobs passed.
- CodeQL #1709 completed SUCCESS. Vercel Preview status on the previous HEAD was SUCCESS.
- CI #1780 is a validation of the previous HEAD only; it does not validate the regression added below.

### Change

- Added a Playwright regression in `tests/e2e/create-offer-route-contract.spec.ts` for canonical UUID text values with version-1 and version-7 version nibbles.
- The test verifies both values pass the route's UUID shape guard, proceed through the expected Auth/profile/membership/action-definition/CREATE_OFFER request sequence, and are used unchanged in the profile and membership filters.
- This guards against accidentally tightening the route's UUID syntax check to UUIDv4 only. PostgreSQL's UUID type stores 128-bit UUID values without restricting the version nibble; the test is a route-contract regression, not a claim about a production Supabase identity or vulnerability.
- No application route, SQL, migration, Supabase production data, secrets, grants, or persistent RLS policies were changed.

### Validation status after publication

- The new test has not yet been executed by GitHub Actions at the time of this note.
- The previous successful result (407 Playwright passed, PostgreSQL 16/17.6 SUCCESS) remains a baseline only.
- New CI and CodeQL checks must be read from the new PR HEAD before reporting a result.
- No local test run was performed.

### Safety boundary

- All UUIDs are synthetic fixtures.
- No production Supabase connection or write was performed.
- No production deployment, PR merge, force-push, or branch-protection change was performed.
