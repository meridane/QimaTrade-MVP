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

These are explicit assumptions for the isolated test model. They must not be reported as verified production properties.

## Run locally

From the repository root, with Docker Engine and the Docker Compose plugin installed:

\`\`\`sh
sh scripts/test-qima-security-fixture.sh
\`\`\`

The script fails if Docker/Compose or fixture inputs are missing. It runs both SQL files with ON_ERROR_STOP=1, then removes the uniquely named Compose project and its volume. Cleanup is checked; a cleanup failure makes the script fail.

No production migration, production credential, remote database URL, or production data is used.
