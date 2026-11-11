#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MOCK_BIN="$TEMP_DIR/bin"
CALLS="$TEMP_DIR/psql-calls.log"
OUTPUT="$TEMP_DIR/runner-output.log"
mkdir -p "$MOCK_BIN"

# Any connection attempt is recorded and fails with a unique status. Unsafe URLs
# must be rejected before this stub is invoked; allowed URLs must reach it.
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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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
  if LC_ALL=C grep -q done

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: ${#unsafe_urls[@]} unsafe URL cases (including control characters), whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\nqa348-injected'
  

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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\r'
  

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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\t'
  

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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\r\nqa348-injected'
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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
\\r' "$OUTPUT" || LC_ALL=C grep -q done

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\nqa348-injected'
  

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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\r'
  

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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\t'
  

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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\r\nqa348-injected'
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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
\\t' "$OUTPUT" || [[ "$(wc -l < "$OUTPUT")" -ne 1 ]]; then
    echo "ERROR: refusal output was not a single control-character-free diagnostic line." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
  if grep -Fq "qa348-injected" "$OUTPUT"; then
    echo "ERROR: refusal output reflected control-character payload content." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\nqa348-injected'
  

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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\r'
  

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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\t'
  

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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
postgresql://postgres:postgres@localhost:5432/qima_test\r\nqa348-injected'
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
  if ! grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
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

# Missing and explicitly empty configuration must fail before the database
# client is invoked. Use an inert psql stub so this test never opens a socket.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" env -u DATABASE_URL \
  bash "$RUNNER" >"$OUTPUT" 2>&1
unset_status=$?
set -e
if [[ "$unset_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an unset DATABASE_URL did not exit 1 at the required-variable check before psql (received $unset_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: unset DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="" \
  bash "$RUNNER" >"$OUTPUT" 2>&1
empty_status=$?
set -e
if [[ "$empty_status" -ne 1 || -s "$CALLS" ]]; then
  echo "ERROR: an empty DATABASE_URL did not exit 1 at the required-variable check before psql (received $empty_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "DATABASE_URL must point to a disposable PostgreSQL database" "$OUTPUT"; then
  echo "ERROR: empty DATABASE_URL failed without the exact required-variable diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# Whitespace is non-empty, so the required-variable check passes; the strict
# loopback allowlist must still reject it before invoking the database client.
: > "$CALLS"
set +e
PATH="$MOCK_BIN:$PATH" MOCK_PSQL_CALLS="$CALLS" DATABASE_URL="   " \
  bash "$RUNNER" >"$OUTPUT" 2>&1
whitespace_status=$?
set -e
if [[ "$whitespace_status" -ne 2 || -s "$CALLS" ]]; then
  echo "ERROR: whitespace-only DATABASE_URL was not rejected with exit 2 before psql (received $whitespace_status)." >&2
  cat "$OUTPUT" >&2
  exit 1
fi
if ! grep -Fq "Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." "$OUTPUT"; then
  echo "ERROR: whitespace-only DATABASE_URL failed without the exact loopback safety diagnostic." >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# The three explicitly supported loopback forms must pass the guard. The stub
# then stops execution at the first psql call without opening a database socket.
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
  if grep -Fq "Refusing CREATE_OFFER integration setup" "$OUTPUT"; then
    echo "ERROR: a supported loopback DATABASE_URL was rejected." >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "CREATE_OFFER integration runner URL guard regression PASS: 7 unsafe URLs, whitespace-only, and 2 missing/empty configurations rejected before psql; 3 supported loopback URLs accepted."
