# QIMA V1 Function Register — append-only validation note

## Auth rate-limit classification regression — 22 November 2026, 07:31 KST

### Baseline inspected before change

- PR #26 is OPEN, DRAFT, not merged, and mergeable; title: `fix: align CREATE_OFFER execution statuses`; base `main`, head branch `fix/create-offer-status-contract`.
- Baseline PR HEAD: `8c9fe3ed517fd2ae702bffbd3087877dc6e7d270`; 2,231 commits ahead / 0 behind; 283 changed files (89,832 additions / 264 deletions).
- QIMA CI #1790 completed SUCCESS. Its jobs confirm the browser/build/audit/typecheck group, PostgreSQL 16, PostgreSQL 17.6, and the cleanup-contract assertion jobs all succeeded. Two job-level failures are intentional failure simulations whose separate assertion jobs succeeded; one intentionally skipped harness remained SKIPPED.
- CodeQL #1719 completed SUCCESS. Combined status for the baseline HEAD reports Vercel Preview SUCCESS.
- The canonical register was requested through GitHub Contents API in UTF-8 and base64 modes, including a line-range read. GitHub returned blob SHA `e9d2d55a34c791f86decc9eddf708c1cfad77c7d` but an empty body in each mode. To avoid overwriting a large register without its full content, this run uses an append-only companion note.

### Finding and change

- The route previously classified Auth API errors with status 0 or >=500 as service unavailable, but a Supabase Auth HTTP 429 response fell through to the generic unauthenticated response.
- A 429 from the upstream Auth service represents rate limiting, not proof that the caller's bearer token is invalid. Returning HTTP 401 with an invalid-token challenge would misclassify a transient upstream limit.
- Updated `app/api/actions/create-offer/route.ts` so Auth status 429 joins status 0 and >=500 in the generic HTTP 503 / `AUTH_SERVICE_UNAVAILABLE` path.
- Extended the existing regression test `CREATE_OFFER route maps Auth upstream outages and transport exceptions to a generic 503` to include HTTP 429. The same assertions require no `WWW-Authenticate` challenge, no private upstream error leakage, and no requests beyond `/auth/v1/user`.
- This is a narrow HTTP error-classification change; no retry behavior, database access, SQL, migration, or business status was changed.

### Work branch and commits

- Work branch: `work/qima-auth-rate-limit-429-20261122-0731`, created from baseline PR HEAD `8c9fe3ed517fd2ae702bffbd3087877dc6e7d270`.
- Route commit: `da149590e2d2fb86693444b0d2e8e6751db154ef` — `fix(create-offer): classify Auth rate limiting as unavailable`.
- Regression-test commit: `f995976fd9e70e4e96e7a9a1413a7c457f72b4d5` — `test(create-offer): cover Auth 429 rate limiting`.
- The work-branch commits were inspected with commit-workflow and combined-status queries before publication to the PR branch. No pull-request-triggered GitHub Actions run existed while the changes remained on the standalone work branch; Vercel Preview status was PENDING there.

### Validation and safety

- Baseline CI #1790 and CodeQL #1719 are successful, but they validate only the baseline HEAD and do not validate the new 429 regression.
- A fresh pull-request CI run is required after fast-forwarding the work branch to `fix/create-offer-status-contract`. No success is claimed for the new test until the resulting Verify and PostgreSQL jobs finish.
- No local tests were executed.
- No Supabase Production data, migration, secret, grant, or persistent RLS policy was accessed or changed. No production deployment, PR merge, force-push, or branch-protection change was performed.
- The regression uses a synthetic Auth 429 response and characterizes route behavior only; it does not establish a production outage or vulnerability.
