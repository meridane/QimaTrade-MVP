
# QIMA V1 Function Register — QA359 append



## QA358 — skipped/cancelled cleanup-output matrix (canonical reconciliation)

Date: 2026-11-12 (UTC)

QA358 completed the negative-output matrix for the prepared-transaction cleanup assertion. The shared assertion test retained the eight QA356 malformed-output cases and added six cases for missing or unexpected skipped/cancelled outputs. The matrix accepted the valid success, failure, and skipped contracts and rejected all 20 negative combinations.

Validation evidence:
- QIMA CI #1289: SUCCESS, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43147744342.
- CodeQL #1239: SUCCESS, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43147744350.
- Verify, dependency installation, npm audit at the high threshold, TypeScript, Next.js build, Chromium, and 347 Playwright tests: SUCCESS.
- PostgreSQL 16 integration and PostgreSQL 17.6 compatibility: SUCCESS.
- A real GitHub Actions job completed as `skipped`; its dependent `if: always()` assertion completed successfully.
- No real cancelled job was triggered; cancelled-result rejection remained a synthetic assertion test.

The detailed QA358 evidence remains in `docs/QIMA_V1_FUNCTION_REGISTER_QA358_APPEND.md`. This section reconciles that append into the canonical register. No application, SQL, migration, Supabase Production, or deployment change was made.

## QA359 — require the upstream harness job result in cleanup assertions

Date: 2026-11-12 (UTC)

### Initial repository state

- Repository: `meridane/QimaTrade-MVP`.
- PR: [#26](https://github.com/meridane/QimaTrade-MVP/pull/26), base `main`, branch `fix/create-offer-status-contract`.
- Initial PR HEAD: `7c091ccd4b7dd1381312829b74efe438cd916b4b`; base SHA: `0d35c13db81019867fe9929420b0a6916285fbf6`.
- Initial PR state: OPEN, DRAFT, mergeable, not merged; 1,506 commits ahead and zero behind; 120 changed files; no human reviews or review threads.
- Latest initial PR checks: QIMA CI #1291 SUCCESS and CodeQL #1241 SUCCESS. The initial combined Vercel status was a daily deployment-quota failure (`api-deployments-free-per-day`), not a Next.js build failure.
- Recent PR-head commits were read from `fix/create-offer-status-contract`, not inferred from default-branch commit search.

### Canonical register retrieval and QA358 reconciliation

The canonical register was fetched by Git blob SHA `199476ceb047db3b443ec9f6a2120e91d4e6df10`; the full 1,639,603-character content was retrieved. At the start of this run, the canonical register ended at QA357 even though the separate QA358 append existed. The preceding QA358 summary has now been reconciled into this canonical file immediately above.

### Finding and change

The QA353 and QA354 dependent assertion jobs previously checked step outputs but did not check the upstream harness job result. That left the assertion contract incomplete if a harness job were cancelled after publishing output values.

Two assertion jobs now pass `needs.<harness>.result` as `HARNESS_RESULT`. The shared assertion script requires `HARNESS_RESULT=success` for both QA353 and QA354, while it continues to validate `SETUP_OUTCOME`, `CLEANUP_OUTCOME`, the cleanup marker, the exact exit code, and the failure marker.

The expected value is deliberately **success**, not failure. The harness jobs use job-level `continue-on-error: true` to isolate their deliberately failing setup/cleanup steps. The actual GitHub Actions dependent-job logs showed `needs.<job>.result` as `success`, even though the corresponding harness check-run conclusion was `failure`. The step-level outcomes remain the source of truth for whether cleanup succeeded or failed.

Eight additional negative cases cover missing, cancelled, skipped, and failure job-result values for both QA353 and QA354. Together with the existing cases, the assertion matrix now accepts three valid contracts and rejects 28 negative combinations.

Files changed:
1. `.github/workflows/ci.yml` — forward each harness job's `needs.<job>.result` to its matching assertion.
2. `tests/ci/assert-prepared-transactions-cleanup-contract.sh` — require the expected job-level result for QA353 and QA354.
3. `tests/ci/test-prepared-transactions-cleanup-assertions.sh` — add eight job-result regression cases; 28 negative combinations total.
4. `tests/ci/verify-prepared-transactions-always-cleanup-contract.sh` — statically require the matching result mapping.

### Intermediate validation and correction

- Initial code commit: `94c136b9df33de28bb3ff580488a0aa50953c411`.
- QIMA CI #1292: FAILURE, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43155880026. Both new assertions initially expected `HARNESS_RESULT=failure`; actual GitHub logs showed `HARNESS_RESULT=success` for both dependent jobs because of job-level `continue-on-error`. The two assertions therefore failed. The PostgreSQL 16/17 jobs and Verify job completed successfully; the harness check-run conclusions remained the expected individual failures.
- CodeQL #1242: SUCCESS, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43155880096.
- Corrective commit: `0c4617ecc841087fd687ba7b3fb658db5172b74b`. Both valid fixtures and assertions were corrected to require `HARNESS_RESULT=success`; negative tests now reject `failure`, `cancelled`, `skipped`, and missing results.

### Final validation

- QIMA CI #1293: **SUCCESS**, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43156011331.
  - QA359 assertion matrix: PASS. The log confirms all 28 negative output/job-result combinations were rejected and the three valid contracts were accepted.
  - QA353 assertion received `HARNESS_RESULT=success`, `SETUP_OUTCOME=failure`, `CLEANUP_OUTCOME=success`, `CLEANUP_RAN=true`, and exit code 0; assertion SUCCESS.
  - QA354 assertion received `HARNESS_RESULT=success`, `SETUP_OUTCOME=failure`, `CLEANUP_OUTCOME=failure`, `CLEANUP_EXIT_CODE=52`, `CLEANUP_FAILURE_OBSERVED=true`, and no success marker; assertion SUCCESS.
  - PostgreSQL 16 integration: SUCCESS, including prepared-transaction restoration and disposable resource cleanup.
  - PostgreSQL 17.6 compatibility: SUCCESS.
  - Dependency installation, npm audit at the high threshold, TypeScript, Next.js build, Chromium installation, and browser tests: SUCCESS; **347 Playwright tests passed in 12.3 seconds**.
  - The QA353 and QA354 harness check-runs retain their expected individual `failure` conclusions; their independent blocking assertions succeed. The skipped harness remains `skipped` and its dependent assertion succeeds.
  - Overall QIMA CI conclusion: SUCCESS.
- CodeQL #1243: **SUCCESS**, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43156011327.
- Vercel combined status for corrected code HEAD `0c4617ecc841087fd687ba7b3fb658db5172b74b`: SUCCESS. This is a Preview/status check, not a Production deployment.
- Initial incorrect-expectation CI #1292 remains recorded as an intermediate failure; corrected CI #1293 is the final code validation.

### Commits and branch

- Work branch: `work/qa359-assert-harness-job-result-20261112-1333`.
- `94c136b9df33de28bb3ff580488a0aa50953c411` — initial result mapping; exposed the job-level `continue-on-error` semantics and failed CI #1292.
- `0c4617ecc841087fd687ba7b3fb658db5172b74b` — corrected assertion contract and eight regression cases; validated by CI #1293 and CodeQL #1243.
- The work branch was fast-forwarded to the PR branch with an expected-SHA check; no force update was used.

### Evidence boundary and safety

- The job-result behavior above was observed in actual GitHub Actions logs. The malformed/cancelled combinations are still shell-level contract tests; no real job cancellation was triggered.
- `HARNESS_RESULT=success` does not mean cleanup succeeded: the job-level `continue-on-error` affects the dependent job result. Cleanup success/failure remains established by the separate step outcome, exact exit code, and cleanup markers.
- The tests do not prove a Production incident or vulnerability.
- No Supabase Production data, migration, schema, SQL function, RLS policy, grant, secret, or persistent configuration was modified.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.

### Next step

Keep the independent-draft idempotency proposal MKT-1.2 and numeric canonicalization proposal MKT-1.3 unchanged until their listed product decisions are approved. A useful next technical task is a read-only audit of the existing disposable idempotency characterization runner and its PostgreSQL 16/17.6 coverage. Do not choose numeric normalization, key scope, retention, or tenant ownership on behalf of the product owner.


