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

unsafe_urls=(
  "postgresql://postgres:postgres@db.example:5432/qima_test"
  "postgresql://postgres:postgres@localhost:5432/production"
  "postgresql://postgres:postgres@localhost:5432/qima_test?sslmode=require"
  "postgresql://postgres:postgres@localhost:5433/qima_test"
  "https://postgres:postgres@localhost:5432/qima_test"
  "postgresql://postgres:postgres@localhost.evil:5432/qima_test"
  "postgresql://postgres:postgres@127.0.0.2:5432/qima_test"
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

echo "Participant self-enrollment runner URL guard regression PASS: 7 unsafe URLs rejected before psql; 3 supported loopback URLs accepted."
