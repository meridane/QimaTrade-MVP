# QIMA — isolated local security-contract fixture

Status: wired into the QIMA CI Verify job; validation is reported only from the corresponding GitHub Actions run.

## Scope and safety

- Runs a disposable standalone PostgreSQL **17.6** Docker container. It does not start Supabase CLI and does not connect to Supabase Cloud.
- The bootstrap file creates only the local anon and authenticated roles plus a minimal auth.uid() compatibility function.
- The fixture creates objects only in the synthetic qima_security_fixture schema and uses synthetic User A/B and Tenant A/B UUIDs.
- Docker Compose uses a unique project name for each invocation, publishes no host port, and removes and checks its project-scoped container and named volume on exit.
- This is a desired-contract model, **not** a production schema dump, production migration, complete Supabase emulation, or proof of deployed RLS behavior.
- It does not test the actual deployed Decision Tree RPC, complete multi-membership resolution, production function grants, or every real table.

## Contracts represented

- Tenant A/B synthetic memberships, sessions, observations, transitions, and product requests.
- RLS-enabled tables with authenticated subject/tenant visibility, including self-only membership reads for User A and User B.
- Anonymous users have no membership read grant; authenticated users have no direct membership INSERT/UPDATE/DELETE grants.
- No direct client DML grants for the other modeled tables.
- Anonymous role has no schema/table access in this fixture.
- The `anon` and `authenticated` roles are verified as `NOLOGIN`, non-superuser, non-`CREATEDB`, non-`CREATEROLE`, non-replication and `NOBYPASSRLS`; they have no inherited role memberships and own neither the fixture schema nor its relations.
- Under SET ROLE anon, a runtime probe executes SELECT against all five fixture tables and requires insufficient_privilege; a successful zero-row query is not accepted as denial.
- Under each synthetic authenticated identity, assertions verify the exact expected row identifiers and tenant/actor ownership for memberships, sessions, observations, transitions, and product requests; the opposite tenant's fixture row must remain invisible. Count-only checks are retained as an additional cardinality assertion.
- Before changing roles, the assertion script requires exactly two seeded rows in each modeled table so the opposite-tenant visibility checks cannot pass merely because the counterpart fixture row is absent.

These are explicit assumptions for the isolated test model. They must not be reported as verified production properties.

## Run locally

From the repository root, with Docker Engine and the Docker Compose plugin installed:

\`\`\`sh
sh scripts/test-qima-security-fixture.sh
\`\`\`

The script fails if Docker/Compose or fixture inputs are missing. It runs both SQL files with ON_ERROR_STOP=1, then removes the uniquely named Compose project and its volume. Cleanup is checked; a cleanup failure makes the script fail.

No production migration, production credential, remote database URL, or production data is used.

- Under `SET ROLE authenticated`, runtime INSERT/UPDATE/DELETE probes exercise all five fixture tables (15 statements total) and require `insufficient_privilege`; a statement that completes, even if it affects zero rows, fails the fixture. The probes execute inside the outer transaction, which is rolled back.

- Under `SET ROLE authenticated`, runtime `TRUNCATE` probes cover all five fixture tables because `TRUNCATE` has a separate privilege and bypasses row-level security; every attempt must raise `insufficient_privilege`. The fixture also checks the corresponding catalog privileges, and the outer transaction is rolled back.

- A role-attribute guard verifies both client roles cannot log in, bypass RLS, become superusers, create databases or roles, replicate, inherit another role, or own fixture schema/relations. This prevents the synthetic test roles from passing row-level checks through owner or elevated-role behavior.
