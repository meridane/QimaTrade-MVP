# QA364 — extension-aware CREATE_OFFER bootstrap catalog preflight

Date: 2026-11-12 (KST)

## Starting state

PR #26 was open, draft, and mergeable. Its branch head before QA364 was `2239494c8bb7faa284bf99e6324cd486de15bcd5`. The canonical function register ended with the QA363 entry; its blob SHA was `bf7a3511d775b902fc3eaea203653c828bbeae8a`.

The QA363 preflight rejected non-default application schemas and public relations, but did not inspect standalone routines or types in `public`. That left a gap for a database containing a user-defined public function, domain, enum, range, or standalone composite type without an ordinary table/view.

## Changes

- Extracted the read-only bootstrap query into `tests/sql/create-offer-bootstrap-preflight.sql`. The runner now invokes that shared file with `-v expected_database=qima_test` after the strict loopback URL allowlist and before the first fixture or migration.
- Kept the preflight read-only. It checks the expected database name, non-default schemas, public relation kinds including composite-type relations (`relkind = 'c'`), standalone public routines in `pg_proc`, and public base/domain/enum/range/multirange types in `pg_type`.
- Excluded extension-owned routines and types using `pg_depend` membership rows referencing `pg_extension` with `deptype = 'e'`. Extension-owned composite types are also excluded from the composite relation check through their `pg_type` membership.
- Updated `tests/sql/test-create-offer-bootstrap-preflight.sh` to protect the shared SQL file, read-only shape, extension ownership filters, runner ordering, and CI wiring.
- Added `tests/sql/test-create-offer-bootstrap-catalog-runtime.sh`. It creates a uniquely named disposable database derived only from the loopback `qima_test` CI URL, installs `pgcrypto` and `hstore`, confirms their extension-owned public function/type members do not trigger rejection, then creates and drops a standalone function, enum, domain, range/multirange, and composite type and verifies each is rejected while present and the extension-only baseline returns to `empty`.
- The runtime test drops its temporary database with `DROP DATABASE ... WITH (FORCE)` in an EXIT trap and fails if cleanup cannot be completed.
- Wired the runtime characterization into both PostgreSQL 16 and PostgreSQL 17.6 jobs. The static contract remains in Verify.
- Updated the existing repeat-run guard so its psql wrapper classifies the shared `-f create-offer-bootstrap-preflight.sql` invocation as a read-only query rather than a fixture file.

## Intermediate CI finding and correction

- QIMA CI #1308: **FAILURE** — the first QA364 refactor changed the preflight invocation from `psql -c` to `psql -f`, but the existing repeat-run test wrapper classified every `-f` call as a fixture file. The second-run test therefore observed `file` instead of its expected single `query` call. The runner had already refused the initialized database before fixture execution; the failure was in the repeat-run test's call classifier, not in the preflight SQL.
- CodeQL #1258: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43198114050.
- Corrected the wrapper to recognize the shared preflight SQL path before the generic `-f` branch, and added a static assertion that this classification remains before the generic fixture-file classification.

## Final validation

- QIMA CI #1309: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43198520409.
  - Verify: QA364 static contract passed.
  - PostgreSQL 16: runtime marker confirmed extension-owned `pgcrypto` functions and `hstore` type were ignored; standalone function, enum, domain, range/multirange, and composite type were rejected.
  - PostgreSQL 17.6: the same runtime marker passed.
  - Both PostgreSQL integration jobs, including the existing CREATE_OFFER, concurrency, RLS, ACL, repeat-run, and cleanup checks, completed successfully.
  - npm ci, high-threshold npm audit, TypeScript, Next.js build, Chromium installation, and Playwright succeeded; **347 Playwright tests passed in 10.3 seconds**.
  - The QA353/QA354 harnesses retain their expected individual failure conclusions; their blocking assertions succeeded. The skipped harness remains skipped and its assertion succeeded.
- CodeQL #1259: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43198520654.
- Vercel combined status on code HEAD `650d640c70295990af2d953c451c4fc2f3f2cfc3`: **FAILURE** due to `api-deployments-free-per-day`. GitHub Actions Next.js build succeeded. No Preview success is claimed for this HEAD.

## Commits and files

Work branch: `work/qa364-public-routine-type-preflight-20261112-1905`.

Commits on the work branch, in order:

- `463833df8072be6fa895c6d4df6c996c0d3f2f52` — extract the shared preflight SQL.
- `a6497904fb164f9a558a4d4b06881e7e61071a11` — invoke the shared SQL from the runner.
- `3d9f8a6ed15c8c14cab7cb02ae624cee74dc0512` — update the static preflight contract.
- `180d40b016acc7dcc73b9523fff6ce53371bf932` — add real catalog runtime characterization.
- `72be6f3ae156178b4651d7a2a38940195b0ceefe` — harden temporary-database cleanup.
- `55130ef28d53619f344b7369e6034b4f82c7448e` — update runner diagnostics.
- `1baa2e38b2e8a1bb851abc61a05fba3fa3bb7b4a` — assert extension-aware catalog filters.
- `46e64830b4aca9183d48adc082c557a19a66619e` — align repeat-guard diagnostic.
- `bc63bc67cb0c88ad47089817610950c93edc137d` — wire PostgreSQL 16/17 runtime jobs.
- `a36c734d3654f2933336426bfe79c56a1346701b` — remove stale inline preflight invocation.
- `bddd941f940bd64544426f14c1cbce4187cd09c2` — classify the shared preflight SQL as a query in the repeat-run wrapper.
- `650d640c70295990af2d953c451c4fc2f3f2cfc3` — protect that classification order in the static contract.

Six unique code/workflow files changed:

1. `.github/workflows/ci.yml`
2. `tests/sql/create-offer-bootstrap-preflight.sql` (new)
3. `tests/sql/run-create-offer-integration.sh`
4. `tests/sql/test-create-offer-bootstrap-catalog-runtime.sh` (new)
5. `tests/sql/test-create-offer-bootstrap-preflight.sh`
6. `tests/sql/test-create-offer-integration-repeat-guard.sh`

The work branch was fast-forwarded to `fix/create-offer-status-contract`; no force-push was used.

## Evidence boundary and safety

QA364 validates only the disposable bootstrap preflight and disposable PostgreSQL CI databases. It is not a full inventory of every PostgreSQL object class: operators, operator classes, collations, publications, and other catalog object families are outside this check. The extension exclusion is based on PostgreSQL's extension membership dependency rows and is exercised with `pgcrypto` routines and the `hstore` type on both supported CI versions.

No Supabase Production data, schema, migration, SQL function, RLS policy, grant, secret, or persistent configuration was modified. No Production deployment, PR merge, force update, or branch-protection change occurred. No vulnerability or Production incident is inferred from synthetic/disposable-database tests.

MKT-1.2 remains unapproved and MKT-1.3 remains decision-required. No idempotency retention, numeric equivalence, price precision, canonicalization, or legacy-hash policy was changed.

## Next step

QA365: review whether the bootstrap preflight should also reject standalone public operators, operator classes, collations, or other user-defined catalog objects. Keep the scope explicit, distinguish extension-owned objects, and validate any added checks on disposable PostgreSQL 16 and 17.6 only.
