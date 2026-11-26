#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"
RUNTIME="$ROOT/tests/sql/test-create-offer-replication-slot-catalog-runtime.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

query="$(cat "$PREFLIGHT")"

for required in "pg_replication_slots" "s.slot_type = 'logical'" "s.datoid" "db.datname = current_database()"; do
  grep -Fq -- "$required" <<< "$query" ||
    fail "preflight is missing database-scoped logical-slot predicate: $required"
done

if grep -Fq "s.slot_type = 'physical'" <<< "$query"; then
  fail "physical replication slots must not be attributed to a database"
fi
if grep -Fq "pg_replication_origin" <<< "$query"; then
  fail "cluster-wide replication origins must remain outside the database-local preflight"
fi
if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|CALL|COPY|EXECUTE|PERFORM|COMMIT|ROLLBACK|SAVEPOINT|SET|RESET)([[:space:]]|;)' <<< "$query"; then
  fail "replication-slot preflight must remain read-only"
fi

for required in \
  'PG_SLOT_TEST_IMAGE' \
  'postgres:16|postgres:17.6' \
  'docker info' \
  'docker run' \
  '127.0.0.1::5432' \
  'wal_level=logical' \
  'max_replication_slots=10' \
  'pg_create_logical_replication_slot' \
  'pg_create_physical_replication_slot' \
  'pg_drop_replication_slot' \
  'qima_slot_test' \
  'qima_slot_other' \
  'datoid' \
  'database' \
  'docker rm -f' \
  'trap cleanup EXIT' \
  'OTHER_DB_CREATED=false' \
  'host_ready=false' \
  "SELECT 1" \
  'docker inspect --format' \
  'docker logs --tail 80'; do
  grep -Fq -- "$required" "$RUNTIME" ||
    fail "runtime characterization is missing required isolated-slot behavior: $required"
done

grep -Fq 'if [[ "$OTHER_DB_CREATED" == true && -n "$OTHER_URL" ]]' "$RUNTIME" ||
  fail "QA369 cleanup must not connect to the other database before it has been created"

if grep -Fq 'ALTER SYSTEM' "$RUNTIME"; then
  fail "QA369 must not alter the existing PostgreSQL service configuration"
fi
if grep -Fq 'subconninfo' "$RUNTIME"; then
  fail "QA369 must not inspect subscription connection strings"
fi
bash -n "$RUNTIME" || fail "replication-slot runtime script has invalid Bash syntax"

runtime_step_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-replication-slot-catalog-runtime.sh' "$WORKFLOW")"
[[ "$runtime_step_count" -eq 2 ]] ||
  fail "replication-slot runtime characterization must run on both PostgreSQL versions; found $runtime_step_count"

static_step_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-replication-slot-preflight.sh' "$WORKFLOW")"
[[ "$static_step_count" -eq 1 ]] ||
  fail "replication-slot static contract must run exactly once in Verify; found $static_step_count"

grep -Fq 'PG_SLOT_TEST_IMAGE: postgres:16' "$WORKFLOW" ||
  fail "PostgreSQL 16 logical-slot runtime image is not pinned"
grep -Fq 'PG_SLOT_TEST_IMAGE: postgres:17.6' "$WORKFLOW" ||
  fail "PostgreSQL 17.6 logical-slot runtime image is not pinned"

echo "QA369 static contract PASS: only logical slots owned by current_database are rejected; physical and other-database slots remain outside the database-local preflight; runtime tests use isolated PostgreSQL 16 and 17.6 containers with wal_level=logical and automatic cleanup."
