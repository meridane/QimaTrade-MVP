# QIMA V1 function register — append-only execution snapshot

Date: 21 November 2026, 19:35 KST  
Repository: `meridane/QimaTrade-MVP`  
Pull request: [#26 — fix: align CREATE_OFFER execution statuses](https://github.com/meridane/QimaTrade-MVP/pull/26)  
Target branch: `fix/create-offer-status-contract`

## Verified state before this task

- PR #26 is open and unmerged. The PR body still contains older historical snapshots; the branch comparison is the authoritative current count.
- PR HEAD before this task: `7205c06d520b4af1af4b19e06df7e49530809b4a`.
- `main...fix/create-offer-status-contract`: 2,176 commits ahead, 0 behind; 279 changed files.
- Latest commit `7205c06d` is documentation-only and corrects the pull-request path-filter interpretation in the canonical register.
- QIMA CI [#1762](https://github.com/meridane/QimaTrade-MVP/actions/runs/44891344626): **SUCCESS**. Verify job passed npm audit, TypeScript, Next.js production build, Chromium and **404/404 Playwright tests**. The isolated QIMA fixture printed `PASS: local QIMA security-contract fixture assertions completed.`; the Compose container, network and named volume were removed. PostgreSQL 16.16 and 17.6 compatibility jobs both completed **SUCCESS**.
- CodeQL [#1692](https://github.com/meridane/QimaTrade-MVP/actions/runs/44891344620): **SUCCESS**.
- Vercel Preview status is **FAILURE** with the free-tier `build-rate-limit` target. This is separate from GitHub Actions and is not treated as a code-test failure.

## Next regression added — client role attributes and ownership

The current fixture already verifies:
- anonymous SELECT is denied on all five synthetic tables;
- authenticated INSERT/UPDATE/DELETE and TRUNCATE are denied on all five tables;
- exact User A/User B row visibility and opposite-tenant exclusion.

This follow-up adds a precondition guard for the two client roles:
- both `anon` and `authenticated` must exist and remain NOLOGIN;
- neither may be SUPERUSER, CREATEDB, CREATEROLE, REPLICATION or BYPASSRLS;
- neither may inherit another role through `pg_auth_members`;
- neither may own the fixture schema or any fixture relation.

These checks protect the meaning of the RLS assertions: a client role must not pass or evade the modeled policy checks because it owns the tested objects or inherits elevated PostgreSQL attributes.

## Current validation boundary

- The new role-attribute assertions are **pending** the next PR-triggered QIMA CI run; no pass is claimed yet.
- The prior CI #1762 results validate the existing TRUNCATE and DML fixture, not this new role-attribute block.
- All identities, roles, schema and rows are synthetic in a disposable standalone PostgreSQL container. This is not a production schema dump and does not prove deployed Supabase Production grants, RLS policies or exploitability.
- No local PostgreSQL test was run in this execution.
- No Supabase Production data, migration, secret, grant or persistent RLS policy was changed. No Production deployment, PR merge, force-push or protection-rule change occurred.

## Canonical register handling

The GitHub file reader returned a valid blob SHA but an empty content payload for the very large `docs/QIMA_V1_FUNCTION_REGISTER.md` (both UTF-8 and base64 reads). Replacing that file without its complete contents would risk destroying its history. This snapshot is therefore stored as a clearly named append-only companion; the canonical register was not overwritten.


### Static review correction before PR validation

- A pre-publication SQL review caught that the first draft nested a `DO` block inside the fixture's initial `DO` block, which is invalid PL/pgSQL. The role-attribute checks have been inlined into the existing block with explicit declarations and a distinct outer dollar-quote tag. The intermediate draft commit is present only as an earlier ancestor in the fast-forwarded work-branch history; it was corrected before the final PR HEAD was published, and no CI result is attributed to the intermediate commit.
- The documentation typo around the `insufficient_privilege` SQLSTATE has also been corrected. The next CI run is the first execution of the corrected role-attribute assertions.


### Post-push validation state — 21 November 2026, 19:35 KST

- The corrected role-attribute guard was fast-forwarded to PR #26. Final HEAD: `30d99d17bdffa7c8e48899ef77c6d168c501fd0b`; work branch and PR branch compare identical (0 ahead / 0 behind).
- The work branch contains six commits after parent `7205c06d`: `7bc737d2` (initial role-guard draft), `cd86061f` (fixture documentation), `e8619274` (initial register append), `7bf18e05` (inline PL/pgSQL correction), `7b81c300` (SQLSTATE wording correction), and `30d99d17` (review-history correction). The initial draft is not the final tree; the final SQL has one outer `DO $qima_initial$` block and no nested `DO` block.
- QIMA CI [#1763](https://github.com/meridane/QimaTrade-MVP/actions/runs/44895316455) is **IN PROGRESS**. At the latest inspection, Verify and both PostgreSQL compatibility jobs are running; the role-attribute assertions have not yet produced a final result.
- CodeQL [#1693](https://github.com/meridane/QimaTrade-MVP/actions/runs/44895316434) is **IN PROGRESS**. Vercel remains **FAILURE** with the free-tier `build-rate-limit` target.
- No local PostgreSQL test was run. No Supabase Production data, migration, secret, grant or persistent RLS policy was changed. No Production deployment, merge, force-push or protection-rule change occurred.


### Documentation-head workflow follow-up — 21 November 2026, 19:36 KST

- The register-append commit `f0de958f` is documentation-only and does not change the SQL fixture. Because the pull request still contains non-documentation changes, the cumulative PR path filter triggered another validation pair.
- QIMA CI [#1764](https://github.com/meridane/QimaTrade-MVP/actions/runs/44895390696) is **PENDING** at this inspection; no jobs have been published yet. CodeQL [#1694](https://github.com/meridane/QimaTrade-MVP/actions/runs/44895390713) is **IN PROGRESS**.
- QIMA CI [#1763](https://github.com/meridane/QimaTrade-MVP/actions/runs/44895316455) remains **IN PROGRESS** on the SQL-changing parent `30d99d17`; Verify and PostgreSQL 16/17.6 jobs are still running. This is the first run that can validate the new role-attribute guard.
- No result is inferred from the pending #1764 run, and no pass is claimed for the role-attribute assertions until #1763 reaches its fixture step and completes.


### Schema CREATE boundary regression — 21 November 2026, 21:08 KST

- Added catalog assertions that `anon` has neither schema `USAGE` nor `CREATE`, while `authenticated` retains `USAGE` but has no `CREATE` on `qima_security_fixture`.
- Added runtime `CREATE TABLE` probes under both client roles. Each statement must raise `insufficient_privilege`; if either DDL statement succeeds, the fixture raises an uncaught assertion exception. The surrounding transaction rolls back all fixture-test changes.
- The change is limited to the disposable synthetic fixture. It does not alter production grants, policies, migrations, data or credentials.
- Static source checks confirm exactly two runtime CREATE TABLE probes and the authenticated USAGE precondition. PostgreSQL execution and regression status remain pending the next PR CI run.


### Post-push validation state — 21 November 2026, 21:08 KST

- Final code/test HEAD `a5c7c277` adds two runtime `CREATE TABLE` denial probes to the disposable fixture; the documentation and append-only register follow-ups are included through HEAD `eeac041c`.
- QIMA CI [#1766](https://github.com/meridane/QimaTrade-MVP/actions/runs/44902581876) is **IN PROGRESS**. At inspection, the Verify job is running its dependency audit; TypeScript, build, Playwright and the isolated QIMA fixture have not yet completed. The PostgreSQL 16 and 17.6 compatibility jobs are running.
- CodeQL [#1696](https://github.com/meridane/QimaTrade-MVP/actions/runs/44902581846) is **IN PROGRESS**. Vercel Preview is **PENDING** for the exact HEAD.
- The prior HEAD `9814c99f` is validated by QIMA CI [#1765](https://github.com/meridane/QimaTrade-MVP/actions/runs/44895423434): Verify **404/404 Playwright**, npm audit, TypeScript, Next.js build and the isolated QIMA fixture succeeded; PostgreSQL 16 and 17.6 compatibility jobs succeeded. CodeQL [#1695](https://github.com/meridane/QimaTrade-MVP/actions/runs/44895423397) succeeded. Those results do not validate the new schema-CREATE probes.
- The canonical `docs/QIMA_V1_FUNCTION_REGISTER.md` still returns an empty content payload despite a valid blob SHA. It was not overwritten; this append-only companion preserves the new record without risking loss of the canonical file history.
- No local PostgreSQL execution was performed. The new SQL has static source checks only; the runtime assertions remain pending CI. No Supabase Production data, migration, secret, grant or persistent RLS policy was changed. No Production deployment, merge, force-push or protection-rule change occurred.


### Local auth.uid() empty-claim fallback regression — 21 November 2026, 21:25 KST

- Code review found that the local compatibility shim applied `NULLIF(..., '')` after `COALESCE`. An empty `request.jwt.claim.sub` therefore masked a valid `sub` in `request.jwt.claims`.
- The shim now normalizes each source with `NULLIF` before `COALESCE`, preserving the legacy-claim preference while correctly falling back to the JSON claims setting.
- Added three runtime assertions: a non-empty legacy subject wins over a different JSON subject; an empty legacy subject falls back to the JSON subject; and no subject in either source returns NULL.
- Scope is limited to the disposable local fixture and its test script. No production auth function, migration, grant, RLS policy or data was changed.

### Validation and dependency maintenance findings — 21 November 2026, 21:25 KST

- QIMA CI [#1766](https://github.com/meridane/QimaTrade-MVP/actions/runs/44902581876) completed the Verify job successfully: **404/404 Playwright tests**, npm audit, TypeScript, Next.js build and the isolated security fixture all passed. Both PostgreSQL compatibility jobs (16 and 17.6) completed successfully. The expected-failure prepared-transaction harness jobs are intentionally non-successful and their separate assertion jobs passed.
- QIMA CI [#1767](https://github.com/meridane/QimaTrade-MVP/actions/runs/44902646496) Verify also passed **404/404 Playwright tests**; PostgreSQL integration and 17.6 compatibility jobs were still in progress at the latest inspection. CodeQL [#1697](https://github.com/meridane/QimaTrade-MVP/actions/runs/44902646502) completed successfully.
- The npm audit artifact from #1766 reports one **moderate** direct `next` finding, with zero high and zero critical findings. The locked version is Next.js 15.5.28; the report identifies GHSA-7qx7-33qx-rqx2, GHSA-f3mh-rxg3-f5g2 and GHSA-pc58-hwjq-p385, with `fixAvailable: true`. This is advisory/version-range evidence, not proof that the application is exploitable.
- The official Next.js 15.5.29 release (3 November 2026) lists fixes for these three advisories: [release notes](https://github.com/vercel/next.js/releases/tag/v15.5.29) and [November 2026 security release](https://nextjs.org/blog/november-2026-security-release).
- The dependency update was not retained: the current execution container cannot reach the npm registry, and the repository's autonomous workflow instructions prohibit modifying `.github/workflows/**`. The temporary workflow/manifest experiment was fully reverted; `package.json`, `package-lock.json` and workflow files have no net change from this attempt. The lockfile was not hand-edited and no integrity hashes were invented. A reproducible Next.js 15.5.29 lockfile update remains the next dependency-maintenance task when an approved registry-backed lockfile generation path is available.
- On the pre-change PR HEAD `d3c4f465`, QIMA CI [#1769](https://github.com/meridane/QimaTrade-MVP/actions/runs/44903458078) was pending and CodeQL [#1699](https://github.com/meridane/QimaTrade-MVP/actions/runs/44903458105) was queued. The new auth.uid() assertions remain pending validation on the next PR-triggered CI run.
- All RLS identities and claims remain synthetic in the disposable PostgreSQL fixture. No local PostgreSQL execution was performed in this task. No Supabase Production data, migration, secret, grant, persistent RLS policy or deployment was touched; no merge, force-push or protection-rule change occurred.
