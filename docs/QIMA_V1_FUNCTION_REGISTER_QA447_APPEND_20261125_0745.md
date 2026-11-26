# QIMA V1 Function Register — QA447 append-only snapshot

Date: 2026-11-25 (KST)
Repository: `meridane/QimaTrade-MVP`
PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26)
Target branch: `fix/create-offer-status-contract`

## Baseline inspected before this change

- PR #26 was OPEN / DRAFT / not merged; head `b65cfddd2194921ddc5d14622e14561ea7806468`, mergeable, with no review threads or submitted reviews.
- Latest branch commits included QA446 test changes `4cc13391` and `734b5873`, followed by the QA446 documentation/status commits through `b65cfddd`.
- QA446 code/test parent CI #1912 completed SUCCESS: Verify passed (npm audit, TypeScript, Next.js build, Chromium, 423/423 Playwright); PostgreSQL 16 and PostgreSQL 17.6 integration jobs passed, including the prepared-transaction setup/restore guards and always-cleanup restoration checks.
- CodeQL #1839 completed SUCCESS. The documentation-only HEAD CI #1913 and CodeQL #1840 also completed SUCCESS.
- The two prepared-transaction failure-propagation jobs intentionally conclude FAILURE and are asserted by separate successful contract-check jobs; the dedicated skipped-result job is intentionally SKIPPED. These are expected harness outcomes, not unexpected CI failures.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` has a valid blob SHA but the connected file reader returns empty content for this very large file. It was not replaced or truncated. This append-only companion preserves this run's evidence without risking the canonical history.

## QA447 — exact Docker argument contract in the always-cleanup runtime harness

### Changed file

`tests/ci/test-prepared-transactions-always-cleanup-runtime.sh`

The runtime harness invokes the actual restoration script with inert Docker/PostgreSQL mocks after a simulated setup failure. Its Docker mock previously checked the RESET SQL substring but did not assert the full discovery/target argument contract. QA447 adds explicit assertions for:

1. `docker ps`: exactly five arguments, with `--filter ancestor=postgres:16 --format {{.ID}}`.
2. `docker exec`: exactly eleven arguments, target ID `0123456789ab`, executable `psql`, the expected user/database/options, and the exact `ALTER SYSTEM RESET max_prepared_transactions` SQL.
3. `docker restart`: exactly two arguments and the same validated container ID `0123456789ab`.

The same mock is exercised in the normal always-cleanup path and in the intentionally failing RESET path. The latter must preserve exit code 52 and stop before restart or postcondition queries. No production database or PostgreSQL service is contacted by these mocked contract tests.

### Validation status at publication

- The QA446 baseline CI #1912 is SUCCESS, including PostgreSQL 16 and 17.6 and 423/423 Playwright. This does **not** validate the new QA447 assertions.
- A new PR-branch CI run was not yet returned by the commit-workflow-runs endpoint immediately after the QA447 code commit. Therefore QA447 is **PENDING GitHub Actions validation**; no local execution is claimed.
- No QA447 pass/fail result is inferred from QA446 or from the synthetic mock design.
- CodeQL and Vercel results for the QA447 HEAD are not yet available.

### Commit and safety boundary

- QA447 code/test commit: `9d513ed27b253b5742affcdc6ff8313c82612de5`.
- The commit was fast-forwarded to `fix/create-offer-status-contract` after comparing it with the inspected parent; no force-push was used.
- No application runtime code, SQL migration, Supabase production data, secret, grant, persistent RLS policy, production deployment, PR merge, or branch-protection rule was changed.

## Next action

Inspect the CI run for the QA447 HEAD. Confirm the `Assert prepared-transaction always-cleanup runtime contract` and `Assert prepared-transaction cleanup failures remain blocking` jobs. If the runtime harness fails, inspect the exact mock argument mismatch before changing the script. On success, record the run IDs and conclusions in the next append-only register snapshot.


## QA447 follow-up — CI-detected fixture-generation defect

The first QA447 CI attempt on code commit `9d513ed27b253b5742affcdc6ff8313c82612de5` failed in the always-cleanup mock harness before it could publish its cleanup outputs. The job log showed `Unexpected docker invocation.`; the downstream cleanup-contract assertion then correctly rejected the missing `CLEANUP_OUTCOME=success` / `CLEANUP_EXIT_CODE=52` outputs. Audit, TypeScript, build, and browser steps were skipped as a consequence of the earlier Verify failure; this was not an npm or compilation finding.

Root cause: the first generated test-file edit placed a literal `\\n` between a shell comment and the `cat <<'DOCKER'` command, so the heredoc creation command was commented out and the mock body was interpreted by the parent test script. The generated mock also contained over-escaped `printf` format strings. This was a test-fixture construction error, not evidence of an application or production vulnerability.

Correction commits:
- `ecb2cb8eb44237ee5abdd839edc1d53600a3fe11` (`fix(test): restore QA447 Docker mock heredoc boundaries`) restores the actual newline between the QA447 comment and the `cat <<'DOCKER'` command. Its subsequent CI attempt was superseded before a full validation result was available.
- Reinspection found that five `printf` formats inside the generated Docker mock still had two backslashes, which would print a literal `\\n` instead of a line terminator. Commit `fa2f765dcd99588e83a5a34c51a31d46f3a60a1c` (`fix(test): correct QA447 Docker mock newline formats`) changes those five formats to the intended single-backslash `printf '%s\\n'` form.

The final PR HEAD at this snapshot is `fa2f765dcd99588e83a5a34c51a31d46f3a60a1c` (2,434 commits ahead of `main`, 0 behind; OPEN / DRAFT / not merged). CI #1918 is PENDING and CodeQL #1845 is IN PROGRESS on that exact HEAD. The Vercel status is a rate-limit failure (`api-deployments-free-per-day`), not a compilation result. CI #1914's original fixture failure remains recorded as a failure; no passing QA447 result is inferred before #1918 completes.
