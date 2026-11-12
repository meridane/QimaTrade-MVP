# QA366 — schema-scoped text-search and conversion bootstrap catalog checks

Date: 2026-11-12 (Asia/Seoul)

## Starting state

- Repository: `meridane/QimaTrade-MVP`.
- PR #26: **OPEN**, **DRAFT**, not merged; base `main`.
- Initial PR head: `8e47fee4a7c95e8fbdc0a2372ec38d132c5255fe`.
- Initial comparison: 1,551 commits ahead of `main`, 0 behind, 134 changed files.
- No human reviews or review threads were present.
- Latest commits at start: `8e47fee` (QA365 post-publication validation), `66e0917` (QA365 register validation), `3f5cd5a` (QA365 operator-symbol correction), `b6fa083` (QA365 catalog checks), `4d03d0e` (QA364 canonical-register append), `7b6439d` (QA364 extension-aware preflight record).
- Canonical register blob at start: `c004748e82ebe5eabe2adc3d3845a32dce4241aa`, 1,687,181 characters.
- Initial checks: QIMA CI #1314 **SUCCESS**; CodeQL #1264 **SUCCESS**; Vercel combined status **FAILURE** with `build-rate-limit`.

## Scope decision

QA366 added explicit checks only for schema-scoped objects that can exist in `public` without an ordinary relation:

- `pg_ts_dict` — text-search dictionaries.
- `pg_ts_config` — text-search configurations.
- `pg_conversion` — encoding conversions.

Each check is limited to `public` and excludes objects with an extension-membership dependency (`pg_depend.deptype = 'e'`, referenced class `pg_extension`).

The following proposed categories were reviewed but were not given redundant direct checks:

- Extended statistics (`pg_statistic_ext`) and row-security policies (`pg_policy`) require a relation; the existing `pg_class` relation guard already rejects that database state. QA366 creates both on a disposable probe table and confirms the existing guard rejects the state.
- A normal user-defined event trigger requires an event-trigger handler routine. The existing public-routine/non-default-schema checks detect that handler before bootstrap DDL. QA366 creates a real event trigger and verifies the handler is detected; it does **not** claim that `pg_event_trigger` itself is directly enumerated.
- Extension-owned text-search configurations and conversions have static dependency-exclusion checks, but no dedicated extension fixture was available in this run to demonstrate those two extension-owned object classes independently.
- Text-search templates/parsers are not directly enumerated by QA366 and remain outside this finite scope.

## Code changes

The read-only preflight now checks `pg_ts_dict`, `pg_ts_config`, and `pg_conversion` in the public namespace. The runner's refusal diagnostic was broadened to say “application catalog objects or non-default schemas,” and the repeat-run and static contracts were updated to match.

The disposable runtime characterization was extended to:

1. Install `unaccent` alongside the existing `pgcrypto`, `hstore`, and `btree_gist` extensions.
2. Verify that the extension-owned `unaccent` text-search dictionary is registered as an extension member and does not make the extension-only baseline non-empty.
3. Create and remove a standalone public text-search dictionary; the preflight transitions `empty → not_empty → empty`.
4. Create and remove a standalone public text-search configuration; the same transition is required.
5. Resolve a built-in UTF8-to-LATIN1 conversion function from the local catalog, create a standalone public conversion using that function, and remove it; the same transition is required.
6. Create a relation with extended statistics and a policy, verify the relation guard rejects it, then drop the relation and verify the baseline returns to empty.
7. Create a public event-trigger handler function and an event trigger, verify the routine guard rejects the database state, verify the trigger exists in `pg_event_trigger`, then remove both and verify the empty baseline.

All runtime probes use a uniquely named disposable database created from the loopback CI `qima_test` service. The preflight remains read-only. The runtime test removes its temporary database in an EXIT trap and fails if cleanup fails.

## Intermediate CI result and correction

- QIMA CI #1315 on code commit `ab92ff328b9511ce0f32317f8f7c6488811f7d7b`: **FAILURE** in the Verify job.
- The static contract expected the new `pg_depend` predicates to use alias `d`, while the SQL correctly used alias `dep`. The failure was a test-contract mismatch, not a PostgreSQL runtime failure.
- The PostgreSQL 16 and PostgreSQL 17.6 jobs in #1315 completed successfully.
- The later “Enforce dependency audit result” step failed because the audit step was skipped after the earlier Verify failure; this was not an npm audit finding.
- CodeQL #1265 on `ab92ff3`: **SUCCESS**.

Correction commit: `53ae942e10f7bb1f86eaf127e379a2ede32f637c` (`fix(test): match QA366 dependency aliases in preflight contract`). The static contract now expects `dep.classid` for the three new catalog predicates.

## Final code validation

- QIMA CI #1316 on `53ae942e10f7bb1f86eaf127e379a2ede32f637c`: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43211932273.
  - QA366 static bootstrap catalog contract: **PASS**.
  - PostgreSQL 16 CREATE_OFFER integration, repeat-run guard, and QA366 runtime catalog characterization: **SUCCESS**.
  - PostgreSQL 17.6 CREATE_OFFER integration, repeat-run guard, and QA366 runtime catalog characterization: **SUCCESS**.
  - Existing CREATE_OFFER concurrency, RLS, ACL, migration cleanup, and prepared-transaction checks completed with their expected outcomes.
  - npm audit at the high threshold: **SUCCESS**.
  - TypeScript: **SUCCESS**.
  - Next.js production build: **SUCCESS**.
  - Chromium installation: **SUCCESS**.
  - Playwright: **347 passed in 13.8 seconds**.
  - The QA353/QA354 harness jobs retain their intentional individual `failure` conclusions; their independent blocking assertions passed. The skipped harness remains `skipped` and its assertion passed.
- CodeQL #1266 on the corrected code HEAD: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43211932200.
- Vercel combined status on corrected code HEAD: **FAILURE** due to `build-rate-limit`. The successful GitHub Actions Next.js build is not represented as a Vercel Preview. No Production deployment occurred.

## Commits and files

Work branch: `work/qa366-text-search-conversion-bootstrap-20261112-2040`.

- `ab92ff3` — extend the preflight and runtime/static catalog contracts.
- `53ae942` — correct the static dependency-alias expectations after CI #1315.

Five unique code files changed:

1. `tests/sql/create-offer-bootstrap-preflight.sql`
2. `tests/sql/test-create-offer-bootstrap-catalog-runtime.sh`
3. `tests/sql/test-create-offer-bootstrap-preflight.sh`
4. `tests/sql/run-create-offer-integration.sh`
5. `tests/sql/test-create-offer-integration-repeat-guard.sh`

The work branch was fast-forwarded to `fix/create-offer-status-contract` with an expected-head check. No force update was used.

## Evidence boundary and safety

The extension-owned dictionary exclusion was demonstrated with `unaccent`. The extension-owned configuration and conversion exclusions were statically protected but not independently runtime-demonstrated. Extended statistics and policies were shown to be covered by the existing relation guard. The event-trigger probe demonstrated routine-handler coverage, not a direct event-trigger catalog check.

No Supabase Production data, schema, migration, SQL function, RLS policy, grant, secret, or persistent configuration was modified. No Production deployment, PR merge, force update, or branch-protection change occurred. No vulnerability or Production incident is inferred from disposable-database characterization.

MKT-1.2 remains unapproved and MKT-1.3 remains decision-required. No idempotency retention, numeric equivalence, price precision, canonicalization, or legacy-hash policy was changed.

## Next step

QA367: assess a finite, evidence-based scope for other independent database-local objects (for example large objects and foreign-data wrappers/servers). Do not add catalog predicates merely to maximize catalog coverage; identify whether each object can exist without already being caught by the current relation/routine/type/schema checks, preserve extension ownership exclusions, and validate only on disposable PostgreSQL 16 and 17.6.


## Post-publication validation of the QA366 register

- QIMA CI #1317: **SUCCESS** on documentation HEAD `750eda3fec5cde3626ef2e137601a31cab2e20a9` — https://github.com/meridane/QimaTrade-MVP/actions/runs/43212452757.
  - QA366 static bootstrap catalog contract: **PASS**.
  - PostgreSQL 16 and PostgreSQL 17.6 CREATE_OFFER integration, repeat-run guard, and QA366 runtime catalog characterization: **SUCCESS**.
  - Existing concurrency, RLS, ACL, migration cleanup, and prepared-transaction checks completed with their expected outcomes.
  - npm audit at the high threshold, TypeScript, Next.js production build, and Chromium installation: **SUCCESS**.
  - Playwright: **347 passed in 12.6 seconds**.
  - The deliberate QA353/QA354 harness failures and skipped harness retained their expected conclusions; independent blocking assertions passed.
- CodeQL #1267: **SUCCESS** on the same documentation HEAD — https://github.com/meridane/QimaTrade-MVP/actions/runs/43212452759.
- Vercel combined status on documentation HEAD `750eda3fec5cde3626ef2e137601a31cab2e20a9`: **FAILURE** due to `build-rate-limit`. The GitHub Actions Next.js build succeeded; no Vercel Preview is claimed for this HEAD. No Production deployment occurred.
