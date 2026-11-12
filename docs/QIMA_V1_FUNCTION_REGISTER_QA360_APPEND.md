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
6. The previous CI #1294 job logs independently contain the QA315 success marker in both PostgreSQL jobs:
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
- no persistent DDL/DML, dynamic execution, transaction control, or non-local table reads are introduced into QA315;
- the Verify job runs this contract test;
- both PostgreSQL 16 and PostgreSQL 17.6 jobs invoke the same guarded runner exactly once;
- PostgreSQL 17.6 version validation remains before the runner.

No SQL characterization, integration runner, application code, migration, business normalization rule, or Production configuration was changed.

### Validation evidence before this change

- QIMA CI #1294: SUCCESS, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43156377605.
- CodeQL #1244: SUCCESS, run https://github.com/meridane/QimaTrade-MVP/actions/runs/43156377676.
- The #1294 PostgreSQL 16 and PostgreSQL 17.6 logs both contain the QA315 PASS marker as listed above.
- Verify job: dependency installation, npm audit at the high threshold, TypeScript, Next.js build, Chromium, and browser tests were successful; 347 Playwright tests passed.
- The PG16 and PG17.6 integration jobs were successful.

### Final validation for QA360

Pending at the time this section was written. Record the actual GitHub Actions and CodeQL conclusions after the new commit; do not infer success from the prior QA315 runs.

### Commits and branch

- Work branch: work/qa360-idempotency-numeric-readonly-contract-20261112-1430.
- Parent PR HEAD: caaf78862fdac2fdb45b2eaebe94c1089e06d90b.
- The work branch is intended to be fast-forwarded to fix/create-offer-status-contract only with an expected-SHA check.
- Changed paths: .github/workflows/ci.yml, tests/sql/test-idempotency-numeric-characterization-contract.sh, docs/QIMA_V1_FUNCTION_REGISTER.md, and docs/QIMA_V1_FUNCTION_REGISTER_QA360_APPEND.md.

### Decision boundary and safety

- MKT-1.3 remains CHARACTERIZATION / DECISION REQUIRED — NOT APPROVED. No decision was made about whether numeric scales are semantically equivalent for quantities, prices, or nested JSONB fields.
- No change to the request hash, MD5 usage, idempotency key scope, retention, replay semantics, tenant ownership, or legacy draft contract was made.
- QA315 is characterization evidence from disposable PostgreSQL fixtures; it is not proof of a Production defect, incident, or vulnerability.
- No Supabase Production data, migration, schema, SQL function, RLS policy, grant, secret, or persistent configuration was modified.
- No Production deployment, PR merge, force update, or branch-protection change was performed.

### Next step

After QA360 CI and CodeQL finish, continue a read-only audit of the idempotency characterization assertions in tests/sql/create-offer-runtime.sql, focusing on whether rejected replays leave the persisted offer, execution, idempotency row, and success-event counts unchanged. Keep MKT-1.2 and MKT-1.3 unapproved until the product decisions listed in those documents are explicitly approved.
