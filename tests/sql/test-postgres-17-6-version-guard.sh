#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/assert-postgres-17-6-version.sh"

if [[ ! -f "$VALIDATOR" ]]; then
  echo "ERROR: PostgreSQL 17.6 version validator is missing." >&2
  exit 1
fi

output="$(bash "$VALIDATOR" 170006)"
grep -Fq "PostgreSQL 17.6 compatibility server_version_num=170006" <<< "$output"

assert_rejected() {
  local label="$1"
  shift
  if bash "$VALIDATOR" "$@" >/dev/null 2>&1; then
    echo "ERROR: validator accepted invalid case: $label" >&2
    exit 1
  fi
}

assert_rejected "PostgreSQL 17.5" 170005
assert_rejected "PostgreSQL 17.7" 170007
assert_rejected "PostgreSQL 17.11" 170011
assert_rejected "PostgreSQL 16.6" 160006
assert_rejected "PostgreSQL 18.0" 180000
assert_rejected "human-readable version" "17.6"
assert_rejected "non-numeric server value" "not-a-version"
assert_rejected "empty server value" ""
assert_rejected "missing server value"

echo "PostgreSQL 17.6 version guard regression PASS: exact 170006 accepted; 9 invalid/missing cases rejected."
