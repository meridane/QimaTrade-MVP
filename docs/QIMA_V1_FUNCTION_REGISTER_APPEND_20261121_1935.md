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
