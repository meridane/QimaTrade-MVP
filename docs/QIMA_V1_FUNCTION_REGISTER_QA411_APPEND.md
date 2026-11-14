# QIMA V1 Function Register — QA411

## QA411 — omitted p_conditions default versus explicit NULL replay

**Status:** IMPLEMENTED — pending GitHub Actions validation on the updated PR head.  
**Target:** PR #26, branch `fix/create-offer-status-contract`  
**Working branch:** `work/qa411-conditions-default-replay-20261115-0034`  
**Base commit:** `15f8e14421a9eebecc1c3735b4b87af39b9418e4`

## Scope

- Characterize the existing function signature default `p_conditions text DEFAULT NULL::text` without changing the migration.
- The first disposable CREATE_OFFER call deliberately omits the named `p_conditions` argument while supplying later defaulted named parameters.
- Both calls explicitly keep `p_attributes => '{}'::jsonb` and all other effective business parameters identical.
- Replay the same tenant/key with `p_conditions => NULL` supplied explicitly.
- Require the replay to return the exact original JSON result and preserve the original request hash, completed idempotency result, action execution, offer and ACTION_SUCCEEDED event.
- Verify `offers.conditions IS NULL` after the initial call and after replay.
- Require exactly one idempotency row, execution, offer and success event after the initial call, with identical counts after replay.
- Static coverage verifies the declared migration default, actual omission in the first call, explicit NULL in the replay, all other parameters unchanged, and Verify/PostgreSQL 16/PostgreSQL 17.6 workflow hooks.

## Validation state

- Runtime and static validation are pending the workflow triggered by this QA411 commit.
- QA410 prerequisite is CLOSED: QIMA CI [#1442](https://github.com/meridane/QimaTrade-MVP/actions/runs/43606074353) completed SUCCESS with both explicit runtime markers.
- The QA411 SQL test is a disposable-fixture function-call regression followed only by read-only persisted-state assertions.

## Safety and decision boundaries

- Runtime validation uses only disposable PostgreSQL 16/17.6 CI services and loopback-only `DATABASE_URL`.
- No Supabase Production data, schema, RLS policy, grants, secrets or persistent PostgreSQL settings are accessed or modified.
- No Production deployment, PR merge, force-push or branch-protection change is performed.
- This is a regression characterization of PostgreSQL's existing argument default, not a finding of a Production vulnerability.
- The separate demand-to-tenant ownership model and MKT-1.1, MKT-1.2 and MKT-1.3 decisions remain subject to business approval.
