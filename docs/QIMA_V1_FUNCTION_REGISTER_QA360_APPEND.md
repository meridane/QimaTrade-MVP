# QIMA V1 Function Register — QA360 append

## QA360 — read-only numeric idempotency characterization runner audit

Date: 2026-11-12 (KST)

### Initial state checked

- Repository: meridane/QimaTrade-MVP.
- PR #26: OPEN, DRAFT, mergeable, not merged; base main, head branch fix/create-offer-status-contract.
- Initial PR HEAD: caaf78862fdac2fdb45b2eaebe94c1089e06d90b; base SHA: 0d35c13db81019867fe9929420b0a6916285fbf6.
- Comparison: 1,509 commits ahead of main, zero behind; 121 changed files.
- Human reviews: 0; inline review threads: 0.
- Latest initial checks: QIMA CI #1294 SUCCESS and CodeQL #1244 SUCCESS.
- Combined Vercel status on the initial HEAD: FAILURE with api-deployments-free-per-day; this is a deployment quota status, not evidence that the Next.js build failed.
- The eight latest branch commits were read directly from fix/create-offer-status-contract; the canonical register SHA at the start was a194fe3094849e0b6a8ae6985441322baf39f970, ending with QA359.

### Read-only audit findings

1. tests/sql/idempotency-numeric-lexical-characterization.sql contains one DO $qa315$ block and a final success SELECT. It uses local PL/pgSQL arrays and expressions only:
   - six equivalent lexical forms: 1, 1.0, 1.00, 1e0, 10e-1, and 100e-2;
   - typed PostgreSQL numeric;
   - JSONB scalar values;
   - nested JSONB objects and objects inside arrays;
   - eight FROM unnest(...) aggregation reads over local arrays.
2. The QA315 script contains no persistent table reads, DML, DDL, dynamic SQL, transaction control, or database-state mutation. It characterizes equality and textual/MD5 serialization differences; MD5 is used only as a deterministic comparison of serialized text, not as a security guarantee or approved business hash policy.
3. tests/sql/run-create-offer-integration.sh has a strict DATABASE_URL allowlist before its first psql call. It accepts only the dedicated qima_test database on loopback (localhost, 127.0.0.1, or [::1]) at port 5432. The runner itself applies fixture DDL, migrations, and runtime tests to that disposable database; it is not read-only as a whole.
4. The runner invokes idempotency-numeric-lexical-characterization.sql exactly once, after create-offer-runtime.sql and before its concurrency scenarios.
5. .github/workflows/ci.yml invokes the same runner in both the postgres-integration job (postgres:16) and the postgres17-create-offer-compatibility job (postgres:17.6). The PostgreSQL 17.6 exact-version assertion runs before the integration runner.
6. Initial CI #1294 job logs independently contained the QA315 success marker in both PostgreSQL jobs:
   - PostgreSQL 16 job 130977164960: QA315 numeric scale and exponent lexical-form characterization PASS.
   - PostgreSQL 17.6 job 130977165053: the same PASS marker.
7. The existing runner guard regression in CI #1294 passed. Its source rejects unsafe host/database/port/query and control-character URL cases before psql, and accepts only the three supported loopback URL forms.

### Change made

Added tests/sql/test-idempotency-numeric-characterization-contract.sh and wired it into the Verify job in .github/workflows/ci.yml.

The new static regression guard checks:
- URL guard appears before the first database-client invocation;
- fixture and runtime SQL precede QA315, which precedes concurrency tests;
- QA315 is invoked exactly once;
- the QA315 SQL remains a single local DO block with the six lexical forms, nested JSONB cases, and eight local-array unnest reads;
- no persistent DDL/DML, dynamic execution, transaction control, or non-local table reads are introduced into QA315 (a line-oriented guard for the current SQL layout, not a general SQL parser);
- the Verify job runs this contract test;
- both PostgreSQL 16 and PostgreSQL 17.6 jobs invoke the same guarded runner exactly once;
- PostgreSQL 17.6 version validation remains before the runner.

No SQL characterization, integration runner, application code, migration, business normalization rule, or Production configuration was changed.

### Intermediate validation and correction

- Initial code commit f1a91dfbbf8e768a8a178ab866b219847c26c622.
- QIMA CI #1295: FAILURE, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43162249962. The new static test initially treated four IS DISTINCT FROM comparisons as non-local FROM sources. It stopped Verify before npm install/build; the PG16 and PG17.6 integration jobs completed successfully. This was a false positive in the new static guard, not a QA315 or PostgreSQL failure.
- Corrective commit 14279b562006060518c8d484cd122b525e64aa4b narrowed the scan to actual line-start FROM clauses and avoided the comparison false positive.

### Final validation

- QIMA CI #1296: SUCCESS, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43162330755.
  - Verify: QA360 PASS marker; all prior workflow and assertion guards passed.
  - PostgreSQL 16 integration: SUCCESS; job log contains QA315 numeric scale and exponent lexical-form characterization PASS.
  - PostgreSQL 17.6 compatibility: SUCCESS; server_version_num=170006 and the QA315 PASS marker are both present.
  - npm ci, npm audit at the high threshold, TypeScript, Next.js build, Chromium, and Playwright: SUCCESS; 347 Playwright tests passed in 10.9 seconds.
  - QA353/QA354 harnesses retain their expected individual failure conclusions; their independent assertions passed. The skipped harness remained skipped and its assertion passed.
  - Overall CI conclusion: SUCCESS.
- CodeQL #1246: SUCCESS, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43162330728.
- Vercel combined status for corrected code HEAD 14279b562006060518c8d484cd122b525e64aa4b: SUCCESS. This is a Preview/status check, not a Production deployment.
- CI #1295 remains recorded as the intermediate false-positive failure; CI #1296 is the final corrected validation.

### Follow-up read-only audit of QA73/QA74/QA75

The numeric replay characterization blocks in tests/sql/create-offer-runtime.sql were inspected:
- OFFER-QA-73, after IDEMPOTENCY_KEY_REUSE, asserts exactly one original idempotency row with the original hash/result, one unchanged completed execution, one original offer with its business fields, and one original ACTION_SUCCEEDED event.
- OFFER-QA-74 performs the same persisted-state checks independently for typed quantity-scale and price-scale rejections.
- OFFER-QA-75 performs the same checks for nested p_attributes numeric-scale rejection.
This is source-level characterization of the disposable fixture tests; it does not establish Production behavior or select the future numeric normalization policy.

### Commits and branch

- Work branch: work/qa360-idempotency-numeric-readonly-contract-20261112-1430.
- f1a91dfbbf8e768a8a178ab866b219847c26c622 — initial static guard and workflow wiring; exposed the IS DISTINCT FROM false positive in CI #1295.
- 14279b562006060518c8d484cd122b525e64aa4b — corrected the line-oriented FROM scan; validated by CI #1296 and CodeQL #1246.
- The work branch was fast-forwarded to fix/create-offer-status-contract with an expected-SHA check; no force update was used.
- Changed paths: .github/workflows/ci.yml, tests/sql/test-idempotency-numeric-characterization-contract.sh, docs/QIMA_V1_FUNCTION_REGISTER.md, and docs/QIMA_V1_FUNCTION_REGISTER_QA360_APPEND.md.

### Decision boundary and safety

- MKT-1.3 remains CHARACTERIZATION / DECISION REQUIRED — NOT APPROVED. No decision was made about whether numeric scales are semantically equivalent for quantities, prices, or nested JSONB fields.
- No change to the request hash, MD5 usage, idempotency key scope, retention, replay semantics, tenant ownership, or legacy draft contract was made.
- QA315 is characterization evidence from disposable PostgreSQL fixtures; it is not proof of a Production defect, incident, or vulnerability.
- The integration runner applies fixture DDL, branch migrations, and runtime tests only after its strict loopback qima_test URL guard. The QA315 SQL block itself is read-only and operates on local PL/pgSQL arrays.
- No Supabase Production data, migration, schema, SQL function, RLS policy, grant, secret, or persistent configuration was modified.
- No Production deployment, PR merge, force update, or branch-protection change was performed.

### Next step

QA361 can add a narrow static regression guard that preserves the existing post-rejection assertions in OFFER-QA-73/74/75: one original idempotency row/hash/result, one execution, one offer, and one success event after IDEMPOTENCY_KEY_REUSE. Do not change numeric normalization, request-hash compatibility, or MKT-1.2/MKT-1.3 decisions without product approval.
