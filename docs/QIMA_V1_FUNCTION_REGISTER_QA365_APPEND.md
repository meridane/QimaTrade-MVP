# QA365 — extension-aware CREATE_OFFER bootstrap catalog objects

Date: 2026-11-12 (KST)

## Starting state

PR #26 was open, draft, and mergeable. Its branch head before QA365 was `4d03d0e1888a5e0671176f2942e962fd4006d2a5`. The canonical register ended with QA364 at blob `57fa64c39468bfc46c04d2b63afd0d1a15dd74a7`.

QA364 covered public routines and types, extension ownership, and the CREATE_OFFER bootstrap preflight. Operators, operator classes/families, collations, and publications were explicitly outside that inventory.

## Changes

- Extended `tests/sql/create-offer-bootstrap-preflight.sql` to detect non-extension-owned public operators (`pg_operator`), operator classes (`pg_opclass`), operator families (`pg_opfamily`), and collations (`pg_collation`).
- Added extension-membership exclusions for each catalog family using `pg_depend` rows with `refclassid = 'pg_extension'::regclass` and `deptype = 'e'`.
- Added publication detection through `pg_publication`. Publications are database-scoped rather than schema-scoped; any non-extension publication, including an empty publication, now means the disposable database is initialized.
- Extended `tests/sql/test-create-offer-bootstrap-catalog-runtime.sh` to install `pgcrypto`, `hstore`, and `btree_gist` in a uniquely named disposable database. The runtime test confirms that hstore-owned public operators and btree_gist-owned public operator classes/families are excluded from the empty baseline.
- Added real probes for a standalone public operator, operator family, operator class, collation, and empty database publication. Each object changes the preflight result to `not_empty`; after dropping it, the result returns to `empty`.
- Extended `tests/sql/test-create-offer-bootstrap-preflight.sh` to require all new catalogs, extension dependency filters, runtime probes, and the read-only SQL contract.
- Updated the Verify and PostgreSQL 16/17.6 workflow step descriptions to refer to catalog objects rather than only routines and types. The same runtime test remains wired into both disposable PostgreSQL jobs.

## Intermediate CI finding and correction

- QIMA CI #1311: **FAILURE** — PostgreSQL rejected the first runtime probe because `CREATE OPERATOR` requires a symbolic operator token; the initial test used an identifier-like name. This was a test-fixture syntax error, not a preflight or application failure.
- CodeQL #1261: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43205012527.
- Corrected the probe to use the valid custom operator symbol `public.===` and the matching `DROP OPERATOR` signature. The static contract now checks the corrected syntax.

## Final validation

- QIMA CI #1312: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43205413981.
  - Verify: QA365 bootstrap catalog contract passed.
  - PostgreSQL 16: extension-owned hstore operators and btree_gist operator classes/families were ignored; standalone operator, operator family, operator class, collation, and publication were rejected; the preflight returned to `empty` after each probe was dropped.
  - PostgreSQL 17.6: the same runtime marker passed.
  - Existing CREATE_OFFER integration, concurrency, repeat-run, RLS, ACL, and cleanup tests passed on both PostgreSQL versions.
  - npm ci, npm audit at the high threshold, TypeScript, Next.js build, Chromium, and Playwright succeeded; **347 Playwright tests passed in 10.3 seconds**.
  - The QA353/QA354 harnesses retain their expected individual failure conclusions; their blocking assertions succeeded. The skipped harness remains skipped and its assertion succeeded.
- CodeQL #1262: **SUCCESS** — https://github.com/meridane/QimaTrade-MVP/actions/runs/43205413801.
- Vercel combined status on corrected code HEAD `3f5cd5a9d61de2379ea1e7e8c54da98da7f1ac5e`: **SUCCESS** — https://vercel.com/bmk1/qimatrade-mvp/CsdBq2SS1USEZHTL4zCnXb8sC6Wk. This is a Preview status only; no Production deployment occurred.
- The empty-publication runtime probe emitted the expected PostgreSQL warning that `wal_level` was insufficient for logical changes. Publication catalog creation and detection succeeded; the test did not exercise logical replication or claim it was enabled.

## Commits and files

Work branch: `work/qa365-public-catalog-objects-20261112-1952`.

- `b6fa08327dab790173c265b1992d4765c0e06f98` — add operator, opclass/opfamily, collation, and publication preflight checks and runtime probes.
- `3f5cd5a9d61de2379ea1e7e8c54da98da7f1ac5e` — use a valid PostgreSQL symbolic operator token in the runtime probe and static contract.

Four unique code/workflow files changed:

1. `.github/workflows/ci.yml`
2. `tests/sql/create-offer-bootstrap-preflight.sql`
3. `tests/sql/test-create-offer-bootstrap-catalog-runtime.sh`
4. `tests/sql/test-create-offer-bootstrap-preflight.sh`

The work branch was fast-forwarded to `fix/create-offer-status-contract`; no force-push was used.

## Evidence boundary and safety

QA365 was executed only against uniquely named disposable PostgreSQL databases created from the loopback CI `qima_test` service. The preflight SQL remains read-only. The runtime test creates and removes its temporary database in an EXIT trap and fails if cleanup cannot be completed.

Extension ownership was exercised with hstore operators and btree_gist operator classes/families. No standard extension fixture was used to characterize extension-owned collations or publications; their extension-dependency exclusion is statically protected but not independently demonstrated with an extension-owned example.

The publication test created an empty publication in a disposable database. The expected `wal_level` warning does not indicate logical replication was enabled or tested.

No Supabase Production data, schema, migration, SQL function, RLS policy, grant, secret, or persistent configuration was modified. No Production deployment, PR merge, force update, or branch-protection change occurred. No vulnerability or Production incident is inferred from synthetic/disposable-database tests.

MKT-1.2 remains unapproved and MKT-1.3 remains decision-required. No idempotency retention, numeric equivalence, price precision, canonicalization, or legacy-hash policy was changed.

## Next step

QA366: review whether additional database-global or schema-scoped catalog families (for example text-search configurations/dictionaries, conversions, extended statistics, policies, or event triggers) are relevant to the fresh-bootstrap invariant. Define a finite scope before adding checks, preserve extension ownership exclusions, and validate only on disposable PostgreSQL 16 and 17.6.

## Post-publication validation of the canonical register

- QIMA CI #1313: **SUCCESS** on documentation HEAD `66e0917b9eee3d08b7b76bc1e62c4b36a1e22985` — https://github.com/meridane/QimaTrade-MVP/actions/runs/43206019436.
  - The QA365 static catalog contract passed.
  - PostgreSQL 16 and PostgreSQL 17.6 jobs completed successfully, including the QA365 runtime marker.
  - Existing CREATE_OFFER, repeat-run, concurrency, RLS, ACL, and prepared-transaction cleanup checks passed.
  - npm audit at the high threshold, TypeScript, Next.js build, Chromium, and **347 Playwright tests** passed (13.7 seconds).
  - The two deliberate QA353/QA354 harness failures and the skipped harness retained their expected conclusions; their independent assertions passed.
- CodeQL #1263: **SUCCESS** on the same documentation HEAD — https://github.com/meridane/QimaTrade-MVP/actions/runs/43206019499.
- Vercel combined status on documentation HEAD `66e0917b9eee3d08b7b76bc1e62c4b36a1e22985`: **FAILURE** due to `build-rate-limit`. The corrected code HEAD `3f5cd5a9d61de2379ea1e7e8c54da98da7f1ac5e` had a successful Preview status. No Production deployment occurred.
