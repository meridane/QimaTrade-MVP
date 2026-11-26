# QIMA — Participant self-enrollment regression implementation

**Date:** 2026-10-28  
**Branch:** `fix/create-offer-status-contract`

## Changes added
- `tests/sql/participant-self-enrollment-regression.sql`: disposable PostgreSQL fixture that reproduces the unconditional self-membership shortcut, swaps to a tightened synthetic policy contract, and asserts denied self-enrollment, subsequent read isolation, a valid request-owner path, trusted transaction-party assignment, and admin behavior.
- `tests/sql/run-participant-self-enrollment-regression.sh`: isolated fixture runner requiring `DATABASE_URL`.
- `.github/workflows/ci.yml`: runs the new fixture in the existing PostgreSQL 16 integration job.

## Important scope boundary
This fixture models the policy shape observed in the live catalog. It is **synthetic** and does not apply a migration, insert rows, or attempt unauthorized reads against production Supabase. The trusted transaction-party assignment function is a fixture model, not a recommendation to deploy that function as-is.

## Validation gate
The new test is not marked passed until its CI step succeeds. After that, inspect the actual conversation and transaction creation workflows and reconcile the fixture with the exact live table grants, helper functions, RLS policies, and supported API paths before preparing any production migration. Preserve legitimate first-time conversation and transaction creation flows.

## Existing CI snapshot before adding this fixture
At commit `4f27462b5c17ad2c52bbed81d5cb56bec6aa5964`, CREATE_OFFER and legacy messages SQL regression jobs passed, CodeQL passed, and TypeScript plus production build passed; Playwright browser installation was still running. The new fixture has not yet been validated at that snapshot.
