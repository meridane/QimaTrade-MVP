#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-participant-self-enrollment-regression.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/bin"
CALLS="$TEMP_DIR/psql-calls.log"
OUTPUT="$TEMP_DIR/runner-output.log"
mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_PSQL_CALLS"
echo "mock psql reached after URL validation" >&2
exit 99
PSQL
chmod +x "$MOCK_BIN/psql"

un# Missing and explicitly empty configuration must fail before psql.
assert_missing_database_url_rejected() {
  local label="$1"
  local config_case="$2"
  local runner_status

  : > "$CALLS"
  set +e
  if [[ "$config_case" == "unset" ]]; then
    PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
      bash "$RUNNER" >"$OUTPUT" 2>&1
  else
    PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env DATABASE_URL="" \
      bash "$RUNNER" >"$OUTPUT" 2>&1
  fi
  runner_status=$?
  set -e

  if [[ "$runner_status" -ne 1 ]] ||
    [[ -s "$CALLS" ]] ||
    ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT" ||
    grep -Fq "mock psql reached" "$OUTPUT" ||
    grep -Fq "postgres:postgres" "$OUTPUT"; then
    echo "ERROR: participant self-enrollment runner did not safely reject a ${label} DATABASE_URL before psql (received $runner_status)." >&2
    cat "$OUTPUT" >&2
    cat "$CALLS" >&2
    exit 1
  fi
}

assert_missing_database_url_rejected "unset" "unset"
assert_missing_database_url_rejected "empty" "empty"

safe_urls=(
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

for unsafe_url in "${unsafe_urls[@]}"; do
  : > "$CALLS"
  set +e
  PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="$unsafe_url" \
    bash "$RUNNER" >"$OUTPUT" 2>&1
  runner_status=$?
  set -e

  if [[ "$runner_status" -ne 2 ]]; then
    echo "ERROR: unsafe DATABASE_URL was not rejected with exit 2 (received $runner_status)." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
  if ! grep -Fq "Refusing participant self-enrollment regression" "$OUTPUT"; then
    echo "ERROR: unsafe DATABASE_URL failed for a reason other than the safety guard." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
  if [[ -s "$CALLS" ]] || grep -Fq "mock psql reached" "$OUTPUT"; then
    echo "ERROR: psql was invoked before an unsafe DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
  if grep -Fq "postgres:postgres" "$OUTPUT"; then
    echo "ERROR: refusal output exposed DATABASE_URL credentials." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
    if LC_ALL=C grep -q $'\r' "$OUTPUT" || LC_ALL=C grep -q $'\t' "$OUTPUT" || [[ "$(wc -l < "$OUTPUT")" -ne 1 ]]; then
      echo "ERROR: participant runner refusal output was not a single control-character-free diagnostic line." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
    if grep -Fq "qa349-injected" "$OUTPUT"; then
      echo "ERROR: participant runner refusal output reflected control-character payload content." >&2
      cat "$OUTPUT" >&2
      exit 1
    fi
done

safe_urls=(
  "postgresql://postgres:postgres@localhost:5432/qima_test"
  "postgres://postgres:postgres@127.0.0.1:5432/qima_test"
  "postgresql://postgres:postgres@[::1]:5432/qima_test"
)

for safe_url in "${safe_urls[@]}"; do
  : > "$CALLS"
  set +e
  PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="$safe_url" \
    bash "$RUNNER" >"$OUTPUT" 2>&1
  runner_status=$?
  set -e

  if [[ "$runner_status" -ne 99 || ! -s "$CALLS" ]]; then
    echo "ERROR: supported loopback DATABASE_URL did not pass validation and reach the psql stub." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
  if grep -Fq "Refusing participant self-enrollment regression" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "Participant self-enrollment runner URL guard regression PASS: ${#unsafe_urls[@]} unsafe URLs plus unset/empty DATABASE_URL rejected before psql; 3 supported loopback URLs accepted."
