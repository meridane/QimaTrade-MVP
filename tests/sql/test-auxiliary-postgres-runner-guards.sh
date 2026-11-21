#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/bin"
CALLS="$TEMP_DIR/psql-calls.log"
OUTPUT="$TEMP_DIR/runner-output.log"
mkdir -p "$MOCK_BIN"

# The stub records only that a connection was attempted; it never opens a socket
# and deliberately returns a unique status so allowed URLs stop before DDL.
cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail
printf 'called\n' >> "$MOCK_PSQL_CALLS"
exit 99
PSQL
chmod +x "$MOCK_BIN/psql"

unsafe_urls=(
  "postgresql://postgres:postgres@db.example:5432/qima_test"
  "postgresql://postgres:postgres@localhost:5432/production"
  "postgresql://postgres:postgres@localhost:5432/qima_test?sslmode=require"
  "postgresql://postgres:postgres@localhost:5433/qima_test"
  "https://postgres:postgres@localhost:5432/qima_test"
  "postgresql://postgres:postgres@localhost.evil:5432/qima_test"
  "postgresql://postgres:postgres@127.0.0.2:5432/qima_test"
  $'postgresql://postgres:postgres@localhost:5432/qima_test\nqa349-injected'
  $'postgresql://postgres:postgres@localhost:5432/qima_test\r'
  $'postgresql://postgres:postgres@localhost:5432/qima_test\t'
  $'postgresql://postgres:postgres@localhost:5432/qima_test\r\nqa349-injected'
)

safe_urls=(
  "postgresql://postgres:postgres@localhost:5432/qima_test"
  "postgres://postgres:postgres@127.0.0.1:5432/qima_test"
  "postgresql://postgres:postgres@[::1]:5432/qima_test"
)

check_runner() {
  local runner_name="$1"
  local expected_guard="$2"
  local runner="$ROOT/tests/sql/$runner_name"
  local unsafe_url
  local safe_url
  local runner_status

  for unsafe_url in "${unsafe_urls[@]}"; do
    : > "$CALLS"
    set +e
    PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="$unsafe_url" \
      bash "$runner" >"$OUTPUT" 2>&1
    runner_status=$?
    set -e

    if [[ "$runner_status" -ne 2 ]]; then
      echo "ERROR: $runner_name did not reject an unsafe DATABASE_URL with exit 2 (received $runner_status)." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
    if ! grep -Fq "$expected_guard" "$OUTPUT"; then
      echo "ERROR: $runner_name rejected an unsafe URL for an unexpected reason." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
    if [[ -s "$CALLS" ]]; then
      echo "ERROR: $runner_name invoked psql before rejecting an unsafe URL." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
    if grep -Fq "postgres:postgres" "$OUTPUT"; then
      echo "ERROR: $runner_name exposed DATABASE_URL credentials in its refusal output." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
    if LC_ALL=C grep -q $'\r' "$OUTPUT" || LC_ALL=C grep -q $'\t' "$OUTPUT" || [[ "$(wc -l < "$OUTPUT")" -ne 1 ]]; then
      echo "ERROR: auxiliary runner refusal output was not a single control-character-free diagnostic line." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
    if grep -Fq "qa349-injected" "$OUTPUT"; then
      echo "ERROR: auxiliary runner refusal output reflected control-character payload content." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
  done

  # Missing configuration must also fail before the database client is called.
  : > "$CALLS"
  set +e
  PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
    bash "$runner" >"$OUTPUT" 2>&1
  runner_status=$?
  set -e
  if [[ "$runner_status" -eq 0 || -s "$CALLS" ]]; then
    echo "ERROR: $runner_name did not fail closed when DATABASE_URL was missing." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi

  # Supported loopback URLs must pass the guard and reach only the inert stub.
  for safe_url in "${safe_urls[@]}"; do
    : > "$CALLS"
    set +e
    PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="$safe_url" \
      bash "$runner" >"$OUTPUT" 2>&1
    runner_status=$?
    set -e

    if [[ "$runner_status" -ne 99 || ! -s "$CALLS" ]]; then
      echo "ERROR: $runner_name rejected a supported loopback URL or failed before the psql stub." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
    if grep -Fq "$expected_guard" "$OUTPUT"; then
      echo "ERROR: $runner_name rejected a supported loopback URL." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
  done
}

check_runner "run-create-offer-wrapper-owner-regression.sh" "Refusing wrapper-owner regression"
check_runner "run-function-execute-acl-regression.sh" "Refusing ACL regression setup"

echo "Auxiliary PostgreSQL runner URL guard regression PASS: 2 runners; 7 unsafe URLs and missing DATABASE_URL rejected before psql; 3 supported loopback URLs accepted per runner."
