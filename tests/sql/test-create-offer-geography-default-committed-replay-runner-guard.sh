#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-create-offer-geography-default-committed-replay.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/bin"
CALLS="$TEMP_DIR/psql-calls.log"
ARGS="$TEMP_DIR/psql-args.log"
OUTPUT="$TEMP_DIR/runner-output.log"
EXPECTED_ARGS="$TEMP_DIR/expected-args.log"
EXPECTED_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qima_test"
mkdir -p "$MOCK_BIN"

# This stub never opens a socket. Unsafe inputs must stop before it; the exact
# supported URL must reach it once and with the runner's fixed argument vector.
cat > "$MOCK_BIN/psql" <<'PSQL'
#!/usr/bin/env bash
set -euo pipefail
printf 'called\n' >> "$MOCK_PSQL_CALLS"
printf '%s\n' "$@" > "$MOCK_PSQL_ARGS"
printf 'mock psql reached\n' >&2
exit 99
PSQL
chmod +x "$MOCK_BIN/psql"

assert_rejected() {
  local label="$1"
  local expected_message="$2"
  shift 2
  : > "$CALLS"
  : > "$ARGS"
  set +e
  PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" MOCK_PSQL_ARGS="$ARGS" \
    "$@" bash "$RUNNER" >"$OUTPUT" 2>&1
  local runner_status=$?
  set -e

  if [[ "$runner_status" -ne 1 || -s "$CALLS" || -s "$ARGS" ]]; then
    echo "ERROR: QA427 runner did not reject $label before psql with exit 1 (received $runner_status)." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
  if ! grep -Fq "$expected_message" "$OUTPUT"; then
    echo "ERROR: QA427 runner rejected $label without its expected generic diagnostic." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
  if grep -Fq "postgres:postgres" "$OUTPUT" ||
     grep -Fq "qa436-credential-injected" "$OUTPUT"; then
    echo "ERROR: QA427 runner refusal output exposed connection credentials or input markers." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
  if [[ "$expected_message" == "QA427 requires the disposable loopback qima_test database." ]] &&
     { LC_ALL=C grep -q '[[:cntrl:]]' "$OUTPUT" || [[ "$(wc -l < "$OUTPUT")" -ne 1 ]]; }; then
    echo "ERROR: QA427 runner refusal output was not one control-character-free line." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
}

assert_rejected "unset DATABASE_URL" "DATABASE_URL: DATABASE_URL is required" env -u DATABASE_URL
assert_rejected "empty DATABASE_URL" "DATABASE_URL: DATABASE_URL is required" env DATABASE_URL=

unsafe_urls=(
  "postgresql://postgres:postgres@db.example:5432/qima_test"
  "postgresql://postgres:postgres@localhost:5432/production"
  "postgresql://postgres:postgres@localhost:5432/qima_test?sslmode=require"
  "postgresql://postgres:postgres@localhost:5433/qima_test"
  "https://postgres:postgres@localhost:5432/qima_test"
  "postgresql://postgres:postgres@localhost.evil:5432/qima_test"
  "postgresql://postgres:postgres@127.0.0.1:5432/qima_test"
  "postgresql://postgres:postgres@[::1]:5432/qima_test"
  "postgresql://postgres:postgres@localhost:5432/qima_test/"
  "   "
  $'postgresql://post\nqa436-credential-injectedgres:postgres@localhost:5432/qima_test'
  $'postgresql://postgres:pass\rqa436-credential-injected@localhost:5432/qima_test'
  $'postgresql://postgres:pass\tqa436-credential-injected@localhost:5432/qima_test'
  $'postgresql://po\x01qa436-credential-injected:postgres@localhost:5432/qima_test'
  $'postgresql://postgres:postgres@localhost:5432/qima_test\nqa436-credential-injected'
)

for unsafe_url in "${unsafe_urls[@]}"; do
  assert_rejected "unsafe DATABASE_URL" \
    "QA427 requires the disposable loopback qima_test database." \
    env "DATABASE_URL=$unsafe_url"
done

# The exact documented disposable URL is the only accepted form. The inert
# stub returns 99 after recording the call, so the runner exits without a
# database connection or any fixture SQL being executed.
: > "$CALLS"
: > "$ARGS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" MOCK_PSQL_ARGS="$ARGS" \
  DATABASE_URL="$EXPECTED_DATABASE_URL" bash "$RUNNER" >"$OUTPUT" 2>&1
safe_status=$?
set -e

printf '%s\n' "$EXPECTED_DATABASE_URL" "-X" "-v" "ON_ERROR_STOP=1" > "$EXPECTED_ARGS"
if [[ "$safe_status" -ne 1 || "$(wc -l < "$CALLS")" -ne 1 ]] ||
   ! grep -Fq "mock psql reached" "$OUTPUT" ||
   ! cmp -s "$EXPECTED_ARGS" "$ARGS"; then
  echo "ERROR: exact QA427 disposable URL did not reach the inert psql stub exactly once with the expected argument vector." >&2
  cat "$OUTPUT" >&2
  cat "$ARGS" >&2
  exit 1
fi
if grep -Fq "QA427 requires the disposable loopback qima_test database." "$OUTPUT"; then
  echo "ERROR: exact QA427 disposable URL was rejected by the URL guard." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

echo "QA436 PASS: unset/empty and 15 unsafe DATABASE_URL forms were rejected before psql; the exact disposable URL reached only the inert stub once with the expected argument vector."
