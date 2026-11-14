# QIMA V1 Function Register — QA410

## QA410 — omitted p_attributes default versus explicit empty-object replay

**Status:** IMPLEMENTED — pending GitHub Actions validation on the updated PR head.  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa410-attributes-default-replay-20261114-2335`  
**Base commit:** `ee30906835416b731fa835d28b2f44b58fc66425`

## Scope

- Characterize the existing function signature default `p_attributes jsonb DEFAULT '{}'::jsonb` without changing the migration.
- The first disposable CREATE_OFFER call deliberately omits the named `p_attributes` argument while still supplying later defaulted named parameters.
- Replay the same tenant/key and all same effective arguments while explicitly supplying `p_attributes => '{}'::jsonb`.
- Require the second call to return the exact original JSON result rather than creating a second execution or offer.
- Verify the first call persisted `offers.attributes = '{}'::jsonb`, the original request hash and completed idempotency result remain unchanged, the action execution remains COMPLETED, and the original ACTION_SUCCEEDED event is preserved.
- Require exactly one idempotency row, execution, offer and success event after the initial call; require identical counts after the exact replay.
- Static coverage verifies the migration's declared default, that the first call omits `p_attributes`, that the replay supplies the empty object exactly once, that all other effective arguments are identical, and that Verify/PostgreSQL 16/PostgreSQL 17.6 execute the appropriate checks.

## Validation state

- QA409 prerequisite is CLOSED: QIMA CI [#1441](https://github.com/meridane/QimaTrade-MVP/actions/runs/43603888887) completed SUCCESS.
- Verify job `132474250490` completed SUCCESS: npm audit at the high threshold, TypeScript, Next.js build and **347/347** Playwright tests passed; QA409 static coverage passed.
- PostgreSQL 16 job `132474250538` and PostgreSQL 17.6 job `132474250463` completed SUCCESS; each complete log contains exactly one explicit `QA409 PASS` marker.
- CodeQL [#1389](https://github.com/meridane/QimaTrade-MVP/actions/runs/43603888821) and the combined Vercel status completed SUCCESS.
- QA410 static and runtime validation are pending the workflow triggered by this commit. No QA410 runtime result is claimed yet.

## Safety and decision boundaries

- Runtime validation uses only the disposable PostgreSQL 16/17.6 CI services and loopback-only `DATABASE_URL`; the SQL file invokes the existing function and performs read-only persisted-state assertions.
- The test characterizes PostgreSQL's existing function-argument default and the existing empty-object hash/persistence behavior. It does not select a new business policy or alter request-hash semantics.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization, not a finding of a Production vulnerability.
- The separate demand-to-tenant ownership model and MKT-1.1, MKT-1.2 and MKT-1.3 decisions remain subject to business approval.
