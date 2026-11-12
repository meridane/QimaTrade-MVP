#!/usr/bin/env bash
set -euo pipefail

: "${PG_SLOT_TEST_IMAGE:?PG_SLOT_TEST_IMAGE must be postgres:16 or postgres:17.6}"

case "$PG_SLOT_TEST_IMAGE" in
  postgres:16|postgres:17.6) ;;
  *)
    echo "ERROR: refusing unpinned PostgreSQL image '$PG_SLOT_TEST_IMAGE'." >&2
    exit 2
    ;;
esac

for required_command in docker psql; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "ERROR: $required_command is required for QA369 replication-slot characterization." >&2
    exit 127
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is unavailable; no replication-slot test container was created." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT_SQL="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"
TEMP_DB="qima_slot_test"
OTHER_DB="qima_slot_other"
CONTAINER_NAME="qima-qa369-slots-${GITHUB_RUN_ID:-local}-${RANDOM}-$$"
LOGICAL_SLOT_NAME="qa369_current_${RANDOM}_$$"
OTHER_LOGICAL_SLOT_NAME="qa369_other_${RANDOM}_$$"
PHYSICAL_SLOT_NAME="qa369_physical_${RANDOM}_$$"
CONTAINER_STARTED=false
PORT=""
TEMP_URL=""
OTHER_URL=""
ADMIN_URL=""

cleanup() {
  local original_status=$?
  local cleanup_status=0
  set +e

  if [[ -n "$TEMP_URL" ]]; then
    psql "$TEMP_URL" -X -v ON_ERROR_STOP=1 -c \
      "SELECT pg_drop_replication_slot('$LOGICAL_SLOT_NAME') FROM pg_replication_slots WHERE slot_name = '$LOGICAL_SLOT_NAME';" \
      >/dev/null 2>&1 || cleanup_status=1
    psql "$TEMP_URL" -X -v ON_ERROR_STOP=1 -c \
      "SELECT pg_drop_replication_slot('$PHYSICAL_SLOT_NAME') FROM pg_replication_slots WHERE slot_name = '$PHYSICAL_SLOT_NAME';" \
      >/dev/null 2>&1 || cleanup_status=1
  fi

  if [[ -n "$OTHER_URL" ]]; then
    psql "$OTHER_URL" -X -v ON_ERROR_STOP=1 -c \
      "SELECT pg_drop_replication_slot('$OTHER_LOGICAL_SLOT_NAME') FROM pg_replication_slots WHERE slot_name = '$OTHER_LOGICAL_SLOT_NAME';" \
      >/dev/null 2>&1 || cleanup_status=1
  fi

  if [[ "$CONTAINER_STARTED" == true ]]; then
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || cleanup_status=1
  fi

  if [[ "$original_status" -eq 0 && "$cleanup_status" -ne 0 ]]; then
    echo "ERROR: QA369 could not remove every disposable replication slot or test container." >&2
    original_status=1
  fi
  exit "$original_status"
}
trap cleanup EXIT

docker run --detach \
  --name "$CONTAINER_NAME" \
  --publish 127.0.0.1::5432 \
  --env POSTGRES_DB="$TEMP_DB" \
  --env POSTGRES_USER=postgres \
  --env POSTGRES_PASSWORD=qa369-disposable-only \
  "$PG_SLOT_TEST_IMAGE" \
  postgres -c wal_level=logical -c max_replication_slots=10 -c max_wal_senders=10 \
  >/dev/null
CONTAINER_STARTED=true

port_mapping="$(docker port "$CONTAINER_NAME" 5432/tcp | head -n 1)"
PORT="${port_mapping##*:}"
if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: QA369 could not determine the loopback port for its disposable PostgreSQL container." >&2
  exit 1
fi

TEMP_URL="postgresql://postgres:qa369-disposable-only@127.0.0.1:$PORT/$TEMP_DB"
OTHER_URL="postgresql://postgres:qa369-disposable-only@127.0.0.1:$PORT/$OTHER_DB"
ADMIN_URL="postgresql://postgres:qa369-disposable-only@127.0.0.1:$PORT/postgres"

ready=false
for attempt in $(seq 1 60); do
  if docker exec "$CONTAINER_NAME" pg_isready -U postgres -d "$TEMP_DB" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  echo "ERROR: QA369 disposable PostgreSQL container did not become ready." >&2
  exit 1
fi

PSQL_ADMIN=(psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1)
PSQL_TEMP=(psql "$TEMP_URL" -X -v ON_ERROR_STOP=1)
PSQL_OTHER=(psql "$OTHER_URL" -X -v ON_ERROR_STOP=1)

wal_level="$("${PSQL_TEMP[@]}" -q -A -t -c 'SHOW wal_level')"
if [[ "$wal_level" != "logical" ]]; then
  echo "ERROR: QA369 isolated server has wal_level '$wal_level'; expected logical." >&2
  exit 1
fi
max_slots="$("${PSQL_TEMP[@]}" -q -A -t -c 'SHOW max_replication_slots')"
if [[ "$max_slots" -lt 1 ]]; then
  echo "ERROR: QA369 isolated server has no logical replication slot capacity." >&2
  exit 1
fi

"${PSQL_ADMIN[@]}" -c "CREATE DATABASE \"$OTHER_DB\";" >/dev/null

preflight_state() {
  local url="$1"
  local expected_database="$2"
  psql "$url" -X -v ON_ERROR_STOP=1 -q -A -t \
    -v "expected_database=$expected_database" \
    -f "$PREFLIGHT_SQL"
}

assert_state() {
  local url="$1"
  local expected_database="$2"
  local expected="$3"
  local description="$4"
  local actual
  actual="$(preflight_state "$url" "$expected_database")"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: $description returned '$actual'; expected '$expected'." >&2
    exit 1
  fi
}

query_scalar() {
  local url="$1"
  local query="$2"
  psql "$url" -X -v ON_ERROR_STOP=1 -q -A -t -c "$query"
}

assert_state "$TEMP_URL" "$TEMP_DB" "empty" "initial logical-slot test database"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "initial other logical-slot test database"

# Physical slots are cluster-wide and have no database OID. They must not
# cause either database-local preflight to reject an otherwise empty database.
"${PSQL_TEMP[@]}" -q -c \
  "SELECT slot_name FROM pg_create_physical_replication_slot('$PHYSICAL_SLOT_NAME');" \
  >/dev/null
physical_details="$(query_scalar "$TEMP_URL" \
  "SELECT slot_type || '|' || COALESCE(database::text, '<null>') || '|' || COALESCE(datoid::text, '<null>') FROM pg_replication_slots WHERE slot_name = '$PHYSICAL_SLOT_NAME';")"
if [[ "$physical_details" != "physical|<null>|<null>" ]]; then
  echo "ERROR: QA369 physical slot had unexpected database ownership metadata '$physical_details'." >&2
  exit 1
fi
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "physical cluster-wide slot in current database"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "physical cluster-wide slot in another database"
"${PSQL_TEMP[@]}" -c "SELECT pg_drop_replication_slot('$PHYSICAL_SLOT_NAME');" >/dev/null

# A logical slot belongs to the database in which it is created.
"${PSQL_TEMP[@]}" -q -c \
  "SELECT slot_name FROM pg_create_logical_replication_slot('$LOGICAL_SLOT_NAME', 'pgoutput');" \
  >/dev/null
logical_details="$(query_scalar "$TEMP_URL" \
  "SELECT s.slot_type || '|' || COALESCE(s.database::text, '<null>') || '|' || CASE WHEN s.datoid = db.oid THEN 'matches' ELSE 'mismatch' END FROM pg_replication_slots s JOIN pg_database db ON db.datname = current_database() WHERE s.slot_name = '$LOGICAL_SLOT_NAME';")"
if [[ "$logical_details" != "logical|$TEMP_DB|matches" ]]; then
  echo "ERROR: QA369 current-database logical slot had unexpected ownership metadata '$logical_details'." >&2
  exit 1
fi
assert_state "$TEMP_URL" "$TEMP_DB" "not_empty" "logical slot owned by current database"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "logical slot owned by another database"
"${PSQL_TEMP[@]}" -c "SELECT pg_drop_replication_slot('$LOGICAL_SLOT_NAME');" >/dev/null
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "baseline after dropping current-database logical slot"

# A logical slot for another database is visible cluster-wide but must not
# poison the current database's bootstrap check.
"${PSQL_OTHER[@]}" -q -c \
  "SELECT slot_name FROM pg_create_logical_replication_slot('$OTHER_LOGICAL_SLOT_NAME', 'pgoutput');" \
  >/dev/null
other_logical_details="$(query_scalar "$OTHER_URL" \
  "SELECT s.slot_type || '|' || COALESCE(s.database::text, '<null>') || '|' || CASE WHEN s.datoid = db.oid THEN 'matches' ELSE 'mismatch' END FROM pg_replication_slots s JOIN pg_database db ON db.datname = current_database() WHERE s.slot_name = '$OTHER_LOGICAL_SLOT_NAME';")"
if [[ "$other_logical_details" != "logical|$OTHER_DB|matches" ]]; then
  echo "ERROR: QA369 other-database logical slot had unexpected ownership metadata '$other_logical_details'." >&2
  exit 1
fi
assert_state "$TEMP_URL" "$TEMP_DB" "empty" "logical slot owned by another database"
assert_state "$OTHER_URL" "$OTHER_DB" "not_empty" "logical slot in its owning database"
"${PSQL_OTHER[@]}" -c "SELECT pg_drop_replication_slot('$OTHER_LOGICAL_SLOT_NAME');" >/dev/null

assert_state "$TEMP_URL" "$TEMP_DB" "empty" "final current-database baseline"
assert_state "$OTHER_URL" "$OTHER_DB" "empty" "final other-database baseline"

echo "QA369 passed: logical slots owned by the current database were detected; logical slots in another database and cluster-wide physical slots did not affect the current database; all slots and the isolated PostgreSQL container were removed."
