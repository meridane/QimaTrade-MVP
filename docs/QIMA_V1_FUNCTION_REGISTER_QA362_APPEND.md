# QIMA V1 Function Register — QA362 Append

Date: 2026-11-12 (KST)

## Initial state checked

- Repository: `meridane/QimaTrade-MVP`.
- PR #26: OPEN, DRAFT, mergeable, not merged; base `main`; head branch `fix/create-offer-status-contract`.
- Initial PR head: `efd2878bf445df68a6dd5ed459889d5cfbe461d0`; 1,517 commits in the PR and 125 changed files.
- Initial checks on that head: QIMA CI #1300 SUCCESS, CodeQL #1250 SUCCESS, and Vercel Preview status SUCCESS.
- Human reviews: 0; inline review threads: 0.
- The canonical register blob was read in full (1,659,183 characters) and ended with the QA361 record. Its pre-change blob SHA was `7bc85d713466179cf261b7a651317ef55412adcf`.

## Scope and findings

Audited fixture isolation for the existing OFFER-QA-73, OFFER-QA-74, and OFFER-QA-75 numeric replay characterization in `tests/sql/create-offer-runtime.sql`, plus the disposable integration runner and both PostgreSQL workflow jobs.

The three seed blocks intentionally share the same disposable tenant (`10000000-0000-4000-8000-000000000001`) and actor (`30000000-0000-4000-8000-000000000001`). This keeps the scenarios in the same expected tenant/actor scope; it is not a cross-tenant isolation test.

Within that shared scope, the seed blocks use four distinct idempotency keys:

1. `fixture-jsonb-numeric-scale-completed` — QA73.
2. `fixture-typed-quantity-scale-completed` — QA74 quantity.
3. `fixture-typed-price-scale-completed` — QA74 price.
4. `fixture-nested-attributes-numeric-scale-completed` — QA75.

The seed blocks declare 12 generated record/correlation identifiers using `gen_random_uuid()`: 3 in QA73, 6 in QA74, and 3 in QA75. Each seed creates its own offer, action execution, idempotency row, and success event. The matching assertion blocks scope their persisted-state reads to the same disposable tenant and use the corresponding key.

A read-only source scan found:
- none of the four keys outside the six dedicated QA73/QA74/QA75 seed/assertion blocks in `create-offer-runtime.sql`;
- no use of the four keys in `run-create-offer-integration.sh`;
- no use of the four keys in `idempotency-numeric-lexical-characterization.sql`.

The runner applies its loopback-only `qima_test` URL guard before its first PostgreSQL connection, executes `create-offer-runtime.sql` exactly once, then executes `idempotency-numeric-lexical-characterization.sql`. The workflow invokes that runner once in the PostgreSQL 16 job and once in the PostgreSQL 17.6 compatibility job; the exact PostgreSQL 17.6 version guard precedes the runner.

## Change

Added `tests/sql/test-create-offer-fixture-isolation-contract.sh` and wired it into the QIMA CI Verify job in `.github/workflows/ci.yml`.

The new source-contract test requires:
- complete QA73/QA74/QA75 seed and assertion blocks;
- exactly 3, 6, and 3 generated UUID declarations respectively;
- the intentionally shared tenant and actor constants in each seed;
- four unique idempotency keys, with each seed key used once in the action-execution seed and once in the idempotency seed;
- matching key and tenant scope in the assertion blocks;
- no reuse of those keys elsewhere in the runtime SQL, in the runner, or in the later numeric lexical characterization file;
- the runner's loopback database guard before the first fixture connection;
- one runtime fixture invocation before the numeric lexical characterization;
- exactly two workflow invocations of the runner, with the PostgreSQL 17.6 version guard before its invocation;
- execution of the new contract test in the Verify job.

The cross-file guard was added after the first successful CI cycle so the later numeric lexical characterization file is protected against future key collisions as well.

No changes were made to the runtime SQL, integration runner, fixture schema, migrations, SQL functions, idempotency behavior, numeric normalization, or business rules.

## Validation

### First code-validation cycle

- QIMA CI #1301: **SUCCESS**, https://github.com/meridane/QimaTrade-MVP/actions/runs/43176855106.
- The Verify job executed the QA362 contract and emitted:
  `QA362 PASS: QA73/QA74/QA75 share only the intended disposable tenant/actor, use four unique fixture keys and twelve generated UUIDs, have no key collisions outside their blocks, and run once on guarded PostgreSQL 16/17.6 services.`
- PostgreSQL 16 and PostgreSQL 17.6 integration jobs: SUCCESS.
- npm install/audit (high threshold), TypeScript, Next.js build, Chromium, and browser tests: SUCCESS.
- Playwright: **347 passed in 9.4 seconds**.
- CodeQL #1251: **SUCCESS**, https://github.com/meridane/QimaTrade-MVP/actions/runs/43176855175.

### Final code-validation cycle, including the cross-file guard

- QIMA CI #1302: **SUCCESS**, https://github.com/meridane/QimaTrade-MVP/actions/runs/43177121302.
- Verify QA362 step: SUCCESS.
- PostgreSQL 16 integration: SUCCESS; server log identifies PostgreSQL 16.15.
- PostgreSQL 17.6 compatibility: SUCCESS; `server_version_num=170006`.
- Both PostgreSQL logs contain the QA315 numeric lexical characterization PASS marker and the existing QA73/QA74/QA75 numeric-scale characterization assertions passed.
- npm ci, high-threshold npm audit, TypeScript, Next.js build, Chromium, and Playwright: SUCCESS.
- Playwright: **347 passed in 7.9 seconds**.
- CodeQL #1252: **SUCCESS**, https://github.com/meridane/QimaTrade-MVP/actions/runs/43177121258.

The QA353 and QA354 harness jobs retain their expected individual `failure` conclusions because they deliberately simulate setup/cleanup failures; their independent blocking assertions succeeded. The skipped harness remains `skipped`, and its dependent assertion succeeded. These expected harness conclusions did not fail the overall CI workflow.

### Preview status

- Vercel combined status for final code HEAD `05ad47229178789932debe41f525f8ecc23b838f`: **failure**; the target URL reports the Vercel build-rate-limit upgrade path.
- No successful Preview is claimed for this final HEAD. The Next.js build itself passed in GitHub Actions.
- No Production deployment was performed.

## Commits and branch

Work branches:
- `work/qa362-numeric-replay-fixture-isolation-20261112-1634`
- `work/qa362-cross-file-fixture-key-guard-20261112-1640`

Commits published to the PR branch:
- `4bff247d7d52ebeed4679de65a44b6a8cd721651` — add fixture-isolation contract.
- `ce97dadf322fc1a959e369fe0b7ff520f5a7d690` — count expected keys after shifting arguments.
- `53f0df0cdd4f4d2fa65fd55e07067888b0cbf830` — wire contract into CI Verify.
- `c81eebfbe321ca4646cb068800913cf2bfbd546f` — remove a redundant argument shift.
- `05ad47229178789932debe41f525f8ecc23b838f` — guard against key reuse in the later numeric lexical characterization file.

Both work branches were fast-forwarded to the PR branch only after compare checks showed the expected ahead/behind counts. No force update was used.

## Files changed

- `.github/workflows/ci.yml`
- `tests/sql/test-create-offer-fixture-isolation-contract.sh` (new; later strengthened with the cross-file check)
- `docs/QIMA_V1_FUNCTION_REGISTER_QA362_APPEND.md`
- `docs/QIMA_V1_FUNCTION_REGISTER.md`

## Evidence boundary and safety

- QA362 is a static source-contract guard plus a read-only source audit. It is not evidence of a Production incident, vulnerability, or cross-tenant authorization defect.
- The behavioral SQL tests ran only against disposable PostgreSQL 16 and PostgreSQL 17.6 CI services.
- The shared tenant and actor are intentional fixture scope; this audit does not claim cross-tenant isolation.
- No Supabase Production data, migration, schema, SQL function, RLS policy, grant, secret, or persistent configuration was modified.
- No Production deployment, PR merge, force update, or branch-protection change occurred.
- MKT-1.2 remains unapproved and MKT-1.3 remains decision-required; no idempotency retention, numeric equivalence, precision, canonicalization, or legacy-hash policy was invented.

## Next step

QA363: inspect the CREATE_OFFER disposable integration schema/bootstrap preflight for repeatability and non-empty-database protection. Determine whether a second runner invocation against an already initialized local `qima_test` database is safely rejected before DDL/DML. Keep the loopback guard and never target Supabase Production.