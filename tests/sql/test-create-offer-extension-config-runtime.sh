#!/usr/bin/env bash
set -euo pipefail

: "$PG_EXTENSION_CONFIG_TEST_IMAGE"
case "$PG_EXTENSION_CONFIG_TEST_IMAGE" in
  postgres:16|postgres:17.6) ;;
  *)
    echo "ERROR: refusing unpinned PostgreSQL image '$PG_EXTENSION_CONFIG_TEST_IMAGE'." >&2
    exit 2
    ;;
esac

for required_command in docker psql; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "ERROR: $required_command is required for QA371 extension configuration characterization." >&2
    exit 127
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is unavailable; no QA371 test container was created." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREFLIGHT_SQL="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"
TEMP_DIR="$(mktemp -d)"
TEMP_DB="qima_qa371_extension_test"
RUN_ID="$(printenv GITHUB_RUN_ID || true)"
if [[ -z "$RUN_ID" ]]; then RUN_ID="local"; fi
CONTAINER_NAME="qima-qa371-extension-$RUN_ID-$RANDOM-$$"
CONTAINER_STARTED=false
PORT=""
TEMP_URL=""

cleanup() {
  local original_status=$?
  local cleanup_status=0
  set +e

  if [[ "$CONTAINER_STARTED" == true ]]; then
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || cleanup_status=1
  fi
  rm -rf "$TEMP_DIR" || cleanup_status=1

  if [[ "$original_status" -eq 0 && "$cleanup_status" -ne 0 ]]; then
    echo "ERROR: QA371 could not remove its disposable extension test container or temporary files." >&2
    original_status=1
  fi
  exit "$original_status"
}
trap cleanup EXIT

cat > "$TEMP_DIR/qa371_config_probe.control" <<'CONTROL'
comment = 'QA371 disposable extension configuration-table probe'
default_version = '1.0'
relocatable = true
CONTROL

cat > "$TEMP_DIR/qa371_config_probe--1.0.sql" <<'SQL'
CREATE TABLE public.qa371_extension_config_probe (
  key text PRIMARY KEY,
  is_builtin boolean NOT NULL,
  value text NOT NULL
);

INSERT INTO public.qa371_extension_config_probe (key, is_builtin, value)
VALUES ('builtin', true, 'baseline');

SELECT pg_catalog.pg_extension_config_dump(
  'public.qa371_extension_config_probe'::regclass,
  'WHERE NOT is_builtin'
);
SQL

chmod 0644 "$TEMP_DIR/qa371_config_probe.control" "$TEMP_DIR/qa371_config_probe--1.0.sql"

docker run --detach --name "$CONTAINER_NAME" --publish 127.0.0.1::5432 --env POSTGRES_DB="$TEMP_DB" --env POSTGRES_USER=postgres --env POSTGRES_PASSWORD=qa371-disposable-only "$PG_EXTENSION_CONFIG_TEST_IMAGE" >/dev/null
CONTAINER_STARTED=true

port_mapping="$(docker port "$CONTAINER_NAME" 5432/tcp | head -n 1)"
PORT="$(printf '%s\n' "$port_mapping" | awk -F: '{print $NF}')"
if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: QA371 could not determine the loopback port for its disposable PostgreSQL container." >&2
  exit 1
fi

TEMP_URL="postgresql://postgres:qa371-disposable-only@127.0.0.1:$PORT/$TEMP_DB"

ready=false
for attempt in $(seq 1 60); do
  if docker exec "$CONTAINER_NAME" pg_isready -U postgres -d "$TEMP_DB" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  echo "ERROR: QA371 disposable PostgreSQL container did not become ready." >&2
  exit 1
fi

SHARE_DIR="$(docker exec "$CONTAINER_NAME" pg_config --sharedir)"
EXTENSION_DIR="$SHARE_DIR/extension"
docker cp "$TEMP_DIR/qa371_config_probe.control" "$CONTAINER_NAME:$EXTENSION_DIR/qa371_config_probe.control" >/dev/null
docker cp "$TEMP_DIR/qa371_config_probe--1.0.sql" "$CONTAINER_NAME:$EXTENSION_DIR/qa371_config_probe--1.0.sql" >/dev/null
SERVER_VERSION_NUM="$(psql "$TEMP_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c 'SHOW server_version_num')"
case "$PG_EXTENSION_CONFIG_TEST_IMAGE" in
  postgres:16)
    if [[ "$SERVER_VERSION_NUM" -lt 160000 || "$SERVER_VERSION_NUM" -ge 170000 ]]; then
      echo "ERROR: QA371 postgres:16 container reported unexpected server_version_num '$SERVER_VERSION_NUM'." >&2
      exit 1
    fi
    ;;
  postgres:17.6)
    if [[ "$SERVER_VERSION_NUM" -ne 170006 ]]; then
      echo "ERROR: QA371 postgres:17.6 container reported server_version_num '$SERVER_VERSION_NUM'; expected 170006." >&2
      exit 1
    fi
    ;;
esac

preflight_state() {
  psql "$TEMP_URL" -X -v ON_ERROR_STOP=1 -q -A -t -v "expected_database=$TEMP_DB" -f "$PREFLIGHT_SQL"
}

assert_state() {
  local expected="$1"
  local description="$2"
  local actual
  actual="$(preflight_state)"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: $description returned '$actual'; expected '$expected'." >&2
    exit 1
  fi
}

query_scalar() {
  local query="$1"
  psql "$TEMP_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$query"
}

assert_state "empty" "initial QA371 extension test database"

psql "$TEMP_URL" -X -v ON_ERROR_STOP=1 -c "CREATE EXTENSION qa371_config_probe WITH SCHEMA public;" >/dev/null

config_metadata="$(query_scalar "SELECT CASE WHEN e.extconfig IS NOT NULL AND array_position(e.extconfig, 'public.qa371_extension_config_probe'::regclass::oid) IS NOT NULL THEN 'present' ELSE 'missing' END || '|' || COALESCE(e.extcondition[array_position(e.extconfig, 'public.qa371_extension_config_probe'::regclass::oid)], '<null>') FROM pg_extension e WHERE e.extname = 'qa371_config_probe';")"
if [[ "$config_metadata" != "present|WHERE NOT is_builtin" ]]; then
  echo "ERROR: QA371 extension config metadata was '$config_metadata'; expected extconfig/extcondition registration." >&2
  exit 1
fi

extension_member_count="$(query_scalar "SELECT count(*) FROM pg_depend d JOIN pg_extension e ON e.oid = d.refobjid WHERE d.classid = 'pg_class'::regclass AND d.objid = 'public.qa371_extension_config_probe'::regclass AND d.refclassid = 'pg_extension'::regclass AND d.deptype = 'e' AND e.extname = 'qa371_config_probe';")"
if [[ "$extension_member_count" != "1" ]]; then
  echo "ERROR: QA371 config relation was not recorded as an extension member." >&2
  exit 1
fi

# The existing public-relation guard rejects the extension config table itself.
# The preflight does not need to interpret extcondition or execute its SQL text.
assert_state "not_empty" "extension-owned public configuration relation"

psql "$TEMP_URL" -X -v ON_ERROR_STOP=1 -c "INSERT INTO public.qa371_extension_config_probe (key, is_builtin, value) VALUES ('user-custom', false, 'custom');" >/dev/null
assert_state "not_empty" "extension configuration table with user data"

dump_output="$(docker exec "$CONTAINER_NAME" pg_dump -U postgres --data-only --dbname="$TEMP_DB")"
if ! grep -Fq $'user-custom\tf\tcustom' <<< "$dump_output"; then
  echo "ERROR: QA371 pg_dump output did not include the user row selected by extcondition." >&2
  exit 1
fi
if grep -Fq $'builtin\tt\tbaseline' <<< "$dump_output"; then
  echo "ERROR: QA371 pg_dump output included the built-in row excluded by extcondition." >&2
  exit 1
fi

psql "$TEMP_URL" -X -v ON_ERROR_STOP=1 -c "DROP EXTENSION qa371_config_probe;" >/dev/null
assert_state "empty" "baseline after dropping the extension configuration relation"

remaining_extension_count="$(query_scalar "SELECT count(*) FROM pg_extension WHERE extname = 'qa371_config_probe';")"
if [[ "$remaining_extension_count" != "0" ]]; then
  echo "ERROR: QA371 disposable extension remained after DROP EXTENSION." >&2
  exit 1
fi

echo "QA371 passed: pg_parameter_acl is characterized as cluster-wide separately; extconfig/extcondition metadata and pg_dump filtering were verified; the extension-owned public config relation was rejected by the existing relation guard and cleanup restored the empty baseline."
