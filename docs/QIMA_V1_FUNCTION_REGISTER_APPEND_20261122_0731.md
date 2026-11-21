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


### Post-publication snapshot — 22 November 2026, 07:31 KST

- The work branch was fast-forwarded to the PR head with `force=false` and an expected-old-SHA guard. The PR head is now `3a45ee8dfe852410884b9b1e5537808fe1c8b622`; PR #26 remains OPEN, DRAFT, not merged, and GitHub reports `mergeable=true`. Compare against `main`: 2,234 commits ahead / 0 behind; 284 changed files (89,866 additions / 264 deletions).
- The final PR branch was re-read: the route contains the explicit HTTP 429 service-unavailable branch and the existing Auth-outage regression loop includes `429`.
- GitHub Actions lookup for PR-triggered runs associated with the new HEAD returned no runs at the time of the final check. Therefore the new 429 case is **not yet CI-validated**. No result from baseline CI #1790 is attributed to the new code.
- Baseline CI #1790 logs were inspected: **409 Playwright passed**, TypeScript/audit/build/browser job SUCCESS, PostgreSQL 16 SUCCESS, PostgreSQL 17.6 SUCCESS, and the cleanup-contract assertion jobs SUCCESS. The two simulated cleanup/setup jobs have expected job-level FAILURE; the dedicated assertions passed. CodeQL #1719 SUCCESS.
- The new HEAD's combined status currently shows Vercel FAILURE with `api-deployments-free-per-day` / free-tier build-rate limit. This is a Preview quota issue, not a production deployment or an application test result.
- The standalone work branch and PR branch compare as identical (0 ahead / 0 behind).
- Next action: obtain a visible PR-triggered QIMA CI run for `3a45ee8d` and verify Playwright plus PostgreSQL jobs before claiming the new regression passes. If no run appears, use an authorized GitHub Actions dispatch path or repository maintainer intervention; do not rerun the old baseline and call it validation of the new code.
