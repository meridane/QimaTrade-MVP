#!/usr/bin/env bash
set -euo pipefail

: "${PG_PRIVILEGE_TEST_IMAGE:?PG_PRIVILEGE_TEST_IMAGE must be postgres:16 or postgres:17.6}"

case "$PG_PRIVILEGE_TEST_IMAGE" in
  postgres:16|postgres:17.6) ;;
  *)
    echo "ERROR: refusing unpinned PostgreSQL image '$PG_PRIVILEGE_TEST_IMAGE'." >&2
    exit 2
    ;;
esac

for required_command in docker psql; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "ERROR: $required_command is required for QA372 privilege-visibility characterization." >&2
    exit 127
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is unavailable; no QA372 test container was created." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT_SQL="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"
TEMP_DIR="$(mktemp -d)"
DB_NAME="qima_test"
RUN_ID="${GITHUB_RUN_ID:-local}"
CONTAINER_NAME="qima-qa372-privileges-$RUN_ID-$RANDOM-$$"
CONTAINER_STARTED=false
PORT=""
ADMIN_URL=""
PROBE_URL=""
MONITOR_URL=""
PROBE_ROLE="qa372_probe_$$_$RANDOM"
MONITOR_ROLE="qa372_monitor_$$_$RANDOM"
MAPPED_ROLE="qa372_mapped_$$_$RANDOM"
SERVER_NAME="qa372_server_$$_$RANDOM"
SUBSCRIPTION_NAME="qa372_subscription_$$_$RANDOM"
LOGICAL_SLOT_NAME="qa372_logical_$$_$RANDOM"
PHYSICAL_SLOT_NAME="qa372_physical_$$_$RANDOM"
LARGE_OBJECT_OID=""

cleanup() {
  local original_status=$?
  local cleanup_status=0
  set +e

  # The cluster is wholly disposable. If any assertion fails, removing this
  # container is the final cleanup boundary for every remaining SQL object.
  if [[ "$CONTAINER_STARTED" == true ]]; then
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || cleanup_status=1
  fi
  rm -rf "$TEMP_DIR" || cleanup_status=1

  if [[ "$original_status" -eq 0 && "$cleanup_status" -ne 0 ]]; then
    echo "ERROR: QA372 could not remove its disposable PostgreSQL container or temporary files." >&2
    original_status=1
  fi
  exit "$original_status"
}
trap cleanup EXIT

docker run --detach \
  --name "$CONTAINER_NAME" \
  --publish 127.0.0.1::5432 \
  --env POSTGRES_DB="$DB_NAME" \
  --env POSTGRES_USER=postgres \
  --env POSTGRES_PASSWORD=qa372-disposable-only \
  "$PG_PRIVILEGE_TEST_IMAGE" \
  postgres -c wal_level=logical -c max_replication_slots=10 -c max_wal_senders=10 \
  >/dev/null
CONTAINER_STARTED=true

port_mapping="$(docker port "$CONTAINER_NAME" 5432/tcp | head -n 1)"
PORT="$(printf '%s\n' "$port_mapping" | awk -F: '{print $NF}')"
if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: QA372 could not determine the loopback port for its disposable PostgreSQL container." >&2
  exit 1
fi

ADMIN_URL="postgresql://postgres:qa372-disposable-only@127.0.0.1:$PORT/$DB_NAME"
PROBE_URL="postgresql://$PROBE_ROLE:qa372-probe-only@127.0.0.1:$PORT/$DB_NAME"
MONITOR_URL="postgresql://$MONITOR_ROLE:qa372-monitor-only@127.0.0.1:$PORT/$DB_NAME"

ready=false
for attempt in $(seq 1 60); do
  if docker exec "$CONTAINER_NAME" pg_isready -U postgres -d "$DB_NAME" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  echo "ERROR: QA372 disposable PostgreSQL container did not become ready." >&2
  exit 1
fi

SERVER_VERSION_NUM="$(psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c 'SHOW server_version_num')"
case "$PG_PRIVILEGE_TEST_IMAGE" in
  postgres:16)
    if [[ "$SERVER_VERSION_NUM" -lt 160000 || "$SERVER_VERSION_NUM" -ge 170000 ]]; then
      echo "ERROR: QA372 postgres:16 container reported unexpected server_version_num '$SERVER_VERSION_NUM'." >&2
      exit 1
    fi
    ;;
  postgres:17.6)
    if [[ "$SERVER_VERSION_NUM" -ne 170006 ]]; then
      echo "ERROR: QA372 postgres:17.6 container reported server_version_num '$SERVER_VERSION_NUM'; expected 170006." >&2
      exit 1
    fi
    ;;
esac

psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 <<SQL >/dev/null
CREATE ROLE "$PROBE_ROLE" LOGIN PASSWORD 'qa372-probe-only'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE ROLE "$MONITOR_ROLE" LOGIN PASSWORD 'qa372-monitor-only'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE ROLE "$MAPPED_ROLE" NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT CONNECT ON DATABASE "$DB_NAME" TO "$PROBE_ROLE", "$MONITOR_ROLE";
GRANT pg_monitor TO "$MONITOR_ROLE";
CREATE EXTENSION postgres_fdw;
SQL

assert_state() {
  local url="$1"
  local expected="$2"
  local description="$3"
  local actual
  actual="$(psql "$url" -X -v ON_ERROR_STOP=1 -q -A -t \
    -v "expected_database=$DB_NAME" -f "$PREFLIGHT_SQL")"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: QA372 $description returned '$actual'; expected '$expected'." >&2
    exit 1
  fi
}

query_scalar() {
  local url="$1"
  local query="$2"
  psql "$url" -X -v ON_ERROR_STOP=1 -q -A -t -c "$query"
}

assert_state "$PROBE_URL" "empty" "baseline preflight as a non-superuser without pg_monitor"
assert_state "$MONITOR_URL" "empty" "baseline preflight as a non-superuser with pg_monitor"

# The raw catalog is intentionally restricted. The public view exposes row
# identity while masking mapping options that could contain credentials.
psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c \
  "CREATE SERVER \"$SERVER_NAME\" FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '127.0.0.1', port '1', dbname 'postgres');" >/dev/null
psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c \
  "CREATE USER MAPPING FOR \"$MAPPED_ROLE\" SERVER \"$SERVER_NAME\" OPTIONS (user 'remote-probe', password 'qa372-hidden-mapping-value');" >/dev/null

if psql "$PROBE_URL" -X -v ON_ERROR_STOP=1 -q -A -t \
  -c 'SELECT count(*) FROM pg_catalog.pg_user_mapping' \
  >"$TEMP_DIR/raw-mapping.out" 2>"$TEMP_DIR/raw-mapping.err"; then
  echo "ERROR: QA372 expected direct pg_user_mapping access to be denied to a normal role." >&2
  exit 1
fi
if ! grep -Fq "permission denied" "$TEMP_DIR/raw-mapping.err"; then
  echo "ERROR: QA372 raw pg_user_mapping query failed for an unexpected reason." >&2
  cat "$TEMP_DIR/raw-mapping.err" >&2
  exit 1
fi

mapping_view_state="$(query_scalar "$PROBE_URL" \
  "SELECT count(*)::text || '|' || count(*) FILTER (WHERE umoptions IS NULL)::text FROM pg_catalog.pg_user_mappings WHERE srvname = '$SERVER_NAME' AND usename = '$MAPPED_ROLE';")"
if [[ "$mapping_view_state" != "1|1" ]]; then
  echo "ERROR: QA372 expected the public mapping view to expose one row with masked options; observed '$mapping_view_state'." >&2
  exit 1
fi
if grep -Fq "qa372-hidden-mapping-value" "$TEMP_DIR/raw-mapping.out" "$TEMP_DIR/raw-mapping.err"; then
  echo "ERROR: QA372 mapping probe exposed its dummy password." >&2
  exit 1
fi
assert_state "$PROBE_URL" "not_empty" "non-superuser preflight with another role's user mapping"
assert_state "$MONITOR_URL" "not_empty" "pg_monitor preflight with another role's user mapping"

psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c \
  "DROP USER MAPPING FOR \"$MAPPED_ROLE\" SERVER \"$SERVER_NAME\"; DROP SERVER \"$SERVER_NAME\";" >/dev/null
assert_state "$PROBE_URL" "empty" "baseline after removing the user mapping"

# pg_subscription exposes subdbid to normal users but withholds subconninfo.
psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c \
  "CREATE SUBSCRIPTION \"$SUBSCRIPTION_NAME\" CONNECTION 'host=127.0.0.1 port=1 dbname=unused' PUBLICATION qa372_unused_publication WITH (connect = false, slot_name = NONE, enabled = false, create_slot = false, copy_data = false);" >/dev/null

subscription_count="$(query_scalar "$PROBE_URL" \
  "SELECT count(*) FROM pg_catalog.pg_subscription WHERE subdbid = (SELECT oid FROM pg_catalog.pg_database WHERE datname = current_database()) AND subname = '$SUBSCRIPTION_NAME';")"
if [[ "$subscription_count" != "1" ]]; then
  echo "ERROR: QA372 non-superuser could not see the current database subscription row." >&2
  exit 1
fi
if psql "$PROBE_URL" -X -v ON_ERROR_STOP=1 -q -A -t \
  -c "SELECT subconninfo FROM pg_catalog.pg_subscription WHERE subname = '$SUBSCRIPTION_NAME';" \
  >"$TEMP_DIR/subconninfo.out" 2>"$TEMP_DIR/subconninfo.err"; then
  echo "ERROR: QA372 expected subconninfo to remain inaccessible to a normal role." >&2
  exit 1
fi
if ! grep -Fq "permission denied" "$TEMP_DIR/subconninfo.err"; then
  echo "ERROR: QA372 subconninfo query failed for an unexpected reason." >&2
  cat "$TEMP_DIR/subconninfo.err" >&2
  exit 1
fi
assert_state "$PROBE_URL" "not_empty" "non-superuser preflight with a current-database subscription"
assert_state "$MONITOR_URL" "not_empty" "pg_monitor preflight with a current-database subscription"
psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c "DROP SUBSCRIPTION \"$SUBSCRIPTION_NAME\";" >/dev/null
assert_state "$PROBE_URL" "empty" "baseline after dropping the subscription"

# Replication-slot visibility is checked without granting pg_monitor.
psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c \
  "SELECT pg_create_physical_replication_slot('$PHYSICAL_SLOT_NAME');" >/dev/null
physical_visible="$(query_scalar "$PROBE_URL" \
  "SELECT count(*) FROM pg_catalog.pg_replication_slots WHERE slot_name = '$PHYSICAL_SLOT_NAME' AND slot_type = 'physical' AND datoid IS NULL;")"
if [[ "$physical_visible" != "1" ]]; then
  echo "ERROR: QA372 non-superuser could not see the physical replication slot row." >&2
  exit 1
fi
assert_state "$PROBE_URL" "empty" "non-superuser preflight with only a physical slot"
assert_state "$MONITOR_URL" "empty" "pg_monitor preflight with only a physical slot"

psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c \
  "SELECT pg_create_logical_replication_slot('$LOGICAL_SLOT_NAME', 'pgoutput');" >/dev/null
logical_visible="$(query_scalar "$PROBE_URL" \
  "SELECT count(*) FROM pg_catalog.pg_replication_slots WHERE slot_name = '$LOGICAL_SLOT_NAME' AND slot_type = 'logical' AND datoid = (SELECT oid FROM pg_catalog.pg_database WHERE datname = current_database());")"
if [[ "$logical_visible" != "1" ]]; then
  echo "ERROR: QA372 non-superuser could not see the logical replication slot row." >&2
  exit 1
fi
assert_state "$PROBE_URL" "not_empty" "non-superuser preflight with a current-database logical slot"
assert_state "$MONITOR_URL" "not_empty" "pg_monitor preflight with a current-database logical slot"

psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c \
  "SELECT pg_drop_replication_slot('$LOGICAL_SLOT_NAME'); SELECT pg_drop_replication_slot('$PHYSICAL_SLOT_NAME');" >/dev/null
assert_state "$PROBE_URL" "empty" "baseline after dropping replication slots"

# Large-object metadata is visible even when the object is owned by another role.
LARGE_OBJECT_OID="$(psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c 'SELECT lo_create(0)')"
if [[ !"$LARGE_OBJECT_OID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: QA372 could not create its disposable large object." >&2
  exit 1
fi
psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c \
  "ALTER LARGE OBJECT $LARGE_OBJECT_OID OWNER TO \"$MAPPED_ROLE\";" >/dev/null
large_object_count="$(query_scalar "$PROBE_URL" \
  "SELECT count(*) FROM pg_catalog.pg_largeobject_metadata WHERE oid = $LARGE_OBJECT_OID;")"
if [[ "$large_object_count" != "1" ]]; then
  echo "ERROR: QA372 non-superuser could not see large-object metadata owned by another role." >&2
  exit 1
fi
assert_state "$PROBE_URL" "not_empty" "non-superuser preflight with another role's large object"
assert_state "$MONITOR_URL" "not_empty" "pg_monitor preflight with another role's large object"

psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c "SELECT lo_unlink($LARGE_OBJECT_OID);" >/dev/null
LARGE_OBJECT_OID=""
assert_state "$PROBE_URL" "empty" "final empty baseline after removing all catalog probes"
assert_state "$MONITOR_URL" "empty" "final pg_monitor empty baseline"

psql "$ADMIN_URL" -X -v ON_ERROR_STOP=1 -c \
  "DROP EXTENSION postgres_fdw; DROP ROLE \"$PROBE_ROLE\", \"$MONITOR_ROLE\", \"$MAPPED_ROLE\";" >/dev/null
remaining_roles="$(query_scalar "$ADMIN_URL" \
  "SELECT count(*) FROM pg_catalog.pg_roles WHERE rolname IN ('$PROBE_ROLE', '$MONITOR_ROLE', '$MAPPED_ROLE');")"
if [[ "$remaining_roles" != "0" ]]; then
  echo "ERROR: QA372 disposable probe roles remained after cleanup." >&2
  exit 1
fi
assert_state "$ADMIN_URL" "empty" "final superuser baseline after dropping extensions and probe roles"

echo "QA372 passed: non-superuser and pg_monitor probes saw current-database subscriptions, logical slots, large-object metadata, and public user-mapping rows without exposing mapping options or subscription connection strings; physical slots remained database-neutral; disposable objects and roles were removed before the test container was destroyed."
