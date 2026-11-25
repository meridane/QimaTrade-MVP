# QIMA Function Register — QA463 append-only update

Date: 2026-11-25 (KST)

## Scope

This note records the follow-up to QA462 and the correction to the parallel cleanup-harness isolation test. It is a CI/test-harness change only.

## Baseline PR and checks

- Pull request #26 remains OPEN and DRAFT, not merged: https://github.com/meridane/QimaTrade-MVP/pull/26
- Base branch: `main`; head branch: `fix/create-offer-status-contract`.
- Baseline head before QA463: `67836b38a0083d7a95d1d72718ac22f6c8960f1b`.
- GitHub reported `mergeable=true`; compare reported 2,490 commits ahead and 0 behind; 303 changed files; no submitted reviews and no review threads.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` was read at the branch head. The GitHub contents reader returned an empty body with Blob SHA `cb3400116d33fb81650982600064454783aba218`; no replacement of that large canonical file was attempted.

## QA462 result and CI #1972

- QIMA CI #1972: https://github.com/meridane/QimaTrade-MVP/actions/runs/45617316543 — overall FAILURE.
- The runtime cleanup harness log explicitly printed: `QA462 Docker-discovery failure guard passed: docker ps exit 78 was preserved and all readiness, configuration, restart, and SQL operations were blocked.`
- The independent assertion job for the prepared-transaction runtime contract completed SUCCESS.
- PostgreSQL 16 integration and PostgreSQL 17.6 compatibility jobs both completed SUCCESS.
- The Verify job failed at `bash tests/ci/test-prepared-transactions-harness-isolation.sh`.
- The subsequent dependency-audit step was SKIPPED because the Verify job had already failed. The audit-enforcement step then failed because `AUDIT_OUTCOME=skipped`; no npm audit report was produced. This run does not establish an npm vulnerability finding.
- CodeQL #1899 completed SUCCESS: https://github.com/meridane/QimaTrade-MVP/actions/runs/45617316601

## QA463 — root cause and correction

The isolation test previously expected the success runner's final state file to equal `0`. That expectation became stale when QA462 was added as the final scenario in the full runtime harness:

1. The earlier normal cleanup performs RESET and leaves the mock state at `0`.
2. QA462 then deliberately resets the state to `10` before simulating `docker ps` exit 78.
3. Docker discovery fails before any RESET or later operation, so QA462 correctly preserves `10`.
4. Therefore the full successful harness must finish with state `10`, not `0`.
5. The separate failure runner exits earlier during its initial simulated cleanup failure, after RESET has set the state to `0`.

The previous isolation test had a bare final state assertion, so this mismatch caused an unlabelled exit 1 even though the QA462 runtime contract itself passed.

Correction published on the work branch in commit [e8d993069b17b6b133c7d352b99e5d843d629993](https://github.com/meridane/QimaTrade-MVP/commit/e8d993069b17b6b133c7d352b99e5d843d629993):

- Expect state `10` after the full success-path harness, with a diagnostic that explains the QA462 no-mutation case.
- Expect state `0` after the early RESET-failure path.
- Require the success log to contain the QA353 and QA462 completion markers.
- Require the failure log to contain the QA354 marker.
- Print the relevant log/state on assertion failure rather than exiting silently.

## Validation status

- QA462 runtime: PASS in CI #1972.
- QA462 independent runtime assertion: PASS.
- PostgreSQL 16 integration: PASS in CI #1972.
- PostgreSQL 17.6 compatibility: PASS in CI #1972.
- QA463 corrected isolation assertion: awaiting a new GitHub Actions run after the work-branch commit is fast-forwarded to the PR branch.
- Full Verify, npm audit, TypeScript, build, Playwright and CodeQL for the corrected head: pending.
- No local test execution is claimed.

## Safety

- No Supabase Production data or migrations were changed.
- No production secrets, persistent grants, RLS policies, or production PostgreSQL settings were changed.
- No Production deployment, PR merge, force-push, or branch-protection change was performed.
- These are synthetic CI contracts and do not establish a production vulnerability.


## Post-push CI #1973 snapshot

- The QA463 correction was fast-forwarded to `fix/create-offer-status-contract`; current PR head at this snapshot is `09d11fa9fa5a3822e981bb11cba69369d394bc0a`.
- QIMA CI #1973: https://github.com/meridane/QimaTrade-MVP/actions/runs/45628925855 has started on the updated PR head.
- Verify step `Verify parallel prepared-transaction cleanup harness isolation` completed **SUCCESS**. This is the direct regression check for the QA463 correction.
- Dependency security audit completed **SUCCESS**; TypeScript check completed **SUCCESS**.
- Production build completed its preceding checks and was still running at this snapshot; Chromium/Playwright were pending or progressing.
- PostgreSQL 16 integration and PostgreSQL 17.6 compatibility jobs were both **IN PROGRESS**. The runtime contract assertion jobs and skipped-result assertion job were **SUCCESS**; the two expected-failure harness jobs and one expected-skipped job retain their intentional conclusions.
- CodeQL #1900: https://github.com/meridane/QimaTrade-MVP/actions/runs/45628925439 was **IN PROGRESS**.
- No final CI #1973 or CodeQL #1900 conclusion is claimed in this snapshot.


## Validation progression — 2026-11-25 22:58 KST

- CodeQL #1900 completed **SUCCESS**: https://github.com/meridane/QimaTrade-MVP/actions/runs/45628925439
- Vercel Preview for the PR head completed **SUCCESS**: https://vercel.com/bmk1/qimatrade-mvp/3e1GCoPxRZdVrwXiUVZQm7L4Zjfj
- In QIMA CI #1973, dependency audit, TypeScript, production build, Chromium installation, workflow wiring, cleanup assertion validation, and the QA463 parallel-isolation step are **SUCCESS**.
- Playwright browser smoke tests remain **IN PROGRESS**.
- PostgreSQL 16 integration and PostgreSQL 17.6 compatibility remain **IN PROGRESS**; no failures were reported at this snapshot.
- QA462 runtime and its independent assertion remain successful in this run; the expected-failure and expected-skipped job conclusions are intentional and their assertion jobs succeeded.
- CI #1973 remains **IN PROGRESS**; no overall success is claimed.


## Verify job closeout — CI #1973

- The `Typecheck, audit, build and browser tests` job completed **SUCCESS**.
- Browser suite: **423 passed (35.7s)**.
- npm dependency audit: **SUCCESS**.
- TypeScript check: **SUCCESS**.
- Production build: **SUCCESS**.
- Chromium installation: **SUCCESS**.
- Isolated QIMA security-contract fixture: **SUCCESS**.
- The parallel cleanup-harness isolation test printed the explicit QA355 success line. It confirms the full success path reached QA462 and preserved state `10`, while the early RESET-failure path retained state `0`.
- The QA462 runtime job log in CI #1973 printed the expected Docker-discovery guard success marker. Its independent assertion job completed **SUCCESS**.
- CodeQL #1900 and the Vercel Preview for the PR code/test head completed **SUCCESS**.
- PostgreSQL 16 and PostgreSQL 17.6 integration jobs remained **IN PROGRESS** at this closeout; overall CI #1973 is not yet complete.
