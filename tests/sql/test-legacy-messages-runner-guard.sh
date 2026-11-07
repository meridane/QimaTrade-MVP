#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-legacy-messages-rls-regression.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
OUTPUT="$TEMP_DIR/runner-output.log"

# If the runner reaches psql for an unsafe URL, this stub makes the test fail.
cat > "$TEMP_DIR/psql" <<'PSQL'
#!/usr/bin/env bash
echo "psql must not be invoked for a rejected DATABASE_URL" >&2
exit 99
PSQL
chmod +x "$TEMP_DIR/psql"

unsafe_urls=(
  "postgresql://postgres:postgres@db.example:5432/qima_test"
  "postgresql://postgres:postgres@localhost:5432/production"
  "postgresql://postgres:postgres@localhost:5432/qima_test?sslmode=require"
)

for unsafe_url in "${unsafe_urls[@]}"; do
  if PATH="$TEMP_DIR:$PATH" DATABASE_URL="$unsafe_url" bash "$RUNNER" >"$OUTPUT" 2>&1; then
    echo "ERROR: migration runner accepted an unsafe DATABASE_URL" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi

  if ! grep -Fq "Refusing to run destructive migration fixture" "$OUTPUT"; then
    echo "ERROR: migration runner failed for a reason other than the URL safety guard" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi

  if grep -Fq "psql must not be invoked" "$OUTPUT"; then
    echo "ERROR: migration runner invoked psql before rejecting an unsafe URL" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

echo "Disposable PostgreSQL URL guard rejected remote, non-test, and query-bearing URLs before psql."
