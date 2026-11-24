# QIMA function register — QA443 closeout and QA444

Date: 2026-11-25 (Asia/Seoul)

## QA443 closeout

- Parent HEAD: `bb1a2e27e50198c8d6a8b80166e5ca50e97579fc`.
- QIMA CI #1906: SUCCESS. PostgreSQL 16 integration and PostgreSQL 17.6 compatibility jobs both completed successfully. PostgreSQL 16 steps for the prepared-transaction restoration guard, setup restoration intent, setup operation, and final restoration/resource verification all concluded SUCCESS.
- Verify job: SUCCESS; dependency audit, TypeScript, Next.js production build, Chromium installation, and browser smoke-test job concluded SUCCESS. CodeQL #1834: SUCCESS.
- The prepared-transaction failure-propagation jobs concluded FAILURE by design because they deliberately simulate setup/cleanup failures; their dedicated assertion jobs concluded SUCCESS. The cleanup-skipped contract job concluded SKIPPED as expected. These are intentional negative contracts, not unexpected suite failures.
- Vercel status for the parent commit reports the account build-rate-limit URL. This is a quota/plan gate, not evidence of a compilation failure.

## QA444 — setup post-restart SHOW validation

- Scope: `tests/sql/enable-prepared-transactions-config.sh` and `tests/sql/test-prepared-transactions-config-setup.sh`.
- The setup runner now rejects a post-restart `SHOW max_prepared_transactions` result that is not a decimal integer, immediately and with a constant diagnostic. It preserves the already-published `restore_required=true` marker so the workflow's `if: always()` restoration can still run.
- The setup-test mock now distinguishes an explicitly empty `MOCK_CONFIGURED_VALUE` from an unset variable, allowing a genuine empty-result regression case.
- Six cases cover empty, non-numeric, LF, CR, TAB and SOH output. Each expects exit 1, the exact one-line diagnostic, no reflected marker, no retry sleep, and the restoration intent to remain present.
- The existing successful value `10`, psql-error path, and retry behavior for a numeric but not-yet-converged value remain unchanged.
- No workflow edit was required: the existing PostgreSQL 16 Verify step already executes `tests/sql/test-prepared-transactions-config-setup.sh` before the disposable PostgreSQL setup operation.
- Pre-publication review found that a JavaScript replacement-string token (`

## Safety and scope

- Tests use the repository's disposable PostgreSQL CI harness and mocks; they do not establish a production vulnerability.
- No Supabase Production data, migration, secret, persistent grant/RLS policy, production configuration, or production deployment was touched.
- No PR merge, force-push, or branch-protection change was performed.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` fetch returned a valid blob SHA but no file content through the connector, including line-range retrieval. It was not overwritten. This append-only companion records the QA443 closeout and QA444 work without risking the large canonical history.
`) could duplicate the suffix of the shell test fixture. The test file was reconstructed from the untouched PR-base blob, then the QA444 block was inserted with a callback replacement. The final fixture is 627 lines, contains one QA444 block and one readiness-exhaustion scenario, and each of the six malformed-value cases occurs exactly once.
- QA444 validation is pending the GitHub Actions run for the resulting PR HEAD. No local execution is claimed.

## Safety and scope

- Tests use the repository's disposable PostgreSQL CI harness and mocks; they do not establish a production vulnerability.
- No Supabase Production data, migration, secret, persistent grant/RLS policy, production configuration, or production deployment was touched.
- No PR merge, force-push, or branch-protection change was performed.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` fetch returned a valid blob SHA but no file content through the connector, including line-range retrieval. It was not overwritten. This append-only companion records the QA443 closeout and QA444 work without risking the large canonical history.

## Post-publication status — 2026-11-25

- PR #26 remains OPEN; the search for open PRs returns #26. The PR branch is 2,413 commits ahead of `main` and 0 behind; the work branch and PR branch compare 0 ahead / 0 behind after synchronization. The current comparison reports 298 changed files. No review submissions or review threads are present.
- QIMA CI #1907 (run `45471913351`) is IN PROGRESS on code/test HEAD `beea212cfe855189f4e10a3e7042c7c0d636842b`. Dependency audit, TypeScript and Next.js production build are SUCCESS; browser smoke tests remain pending. PostgreSQL 16 integration and PostgreSQL 17.6 compatibility jobs remain in progress. The PostgreSQL 16 step `Verify prepared-transaction setup records restoration intent before mutation` has not run yet, so QA444 is not yet validated by CI.
- CodeQL #1835 (run `45471913310`) is SUCCESS.
- The Vercel combined status remains FAILURE with target `https://vercel.com/bmk1?upgradeToPro=build-rate-limit`. This is the previously observed build-rate-limit gate; it is not recorded as a compile failure.
- The two expected setup/cleanup failure-propagation jobs are intentionally concluded FAILURE; their dedicated assertion jobs are SUCCESS. The cleanup-skipped contract is SKIPPED as designed.
- The canonical register fetch still returns blob SHA `0abac27a2946711df25c01c087c52a04737503ee` but empty content, including for line-range retrieval. No replacement was attempted; this companion remains append-only.
