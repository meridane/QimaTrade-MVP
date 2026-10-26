# QIMA — Isolated local security-contract fixture

Status: fixture prepared; **not yet executed**. This is not a production schema dump and does not recreate all 157 remote migrations.

## Safety
- Use only a disposable local Supabase instance (Supabase CLI + local Docker).
- File creates objects only in schema `qima_security_fixture`; do not run on production.
- Uses synthetic User A/B and Tenant A/B UUIDs.
- Does not test the actual deployed Decision Tree RPC, full multi-membership resolution, or prove production RLS behavior.
- No Supabase paid branch is needed.

## File
`supabase/fixtures/qima_security_contract.sql`

## Contracts represented
- Tenant A/B synthetic records for memberships, sessions, observations, transitions, product requests.
- RLS-enabled tables.
- Read visibility restricted by the authenticated subject and tenant membership.
- Client-side writes intentionally disabled through grants and absence of DML policies.
- These are **desired contract assumptions for a local test harness**, not claims that production currently behaves this way.

## Run locally
1. Review the SQL file.
2. Start local Supabase from the repo only after checking `supabase/config.toml` and migrations.
3. Apply this fixture explicitly to the local database only, for example through the local SQL editor or local `psql` connection.
4. Set a local JWT subject to User A/B and check SELECT visibility.
5. Confirm INSERT/UPDATE/DELETE fail for the authenticated role.
6. Record exact command, environment, output and failures. Do not say tests passed until actually executed.

Because the repository has only 15 migrations while the live project reports 157, this fixture is a limited security-contract model, not a substitute for migration reconciliation.
