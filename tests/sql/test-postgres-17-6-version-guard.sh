#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
  local status=0
  if bash "$VALIDATOR" "$@" >/dev/null 2>&1; then
    status=0
  else
    status=$?
  fi
  if [[ "$status" -ne 1 ]]; then
    echo "ERROR: validator expected exit 1 for invalid case: $label (received $status)" >&2
    exit 1
  fi
}

assert_rejected_with_constant_numeric_diagnostic() {
  local label="$1"
  local value="$2"
  local output
  local status=0
  local expected="::error::Expected PostgreSQL 17.6 (server_version_num=170006); received a different numeric value."

  if output="$(bash "$VALIDATOR" "$value" 2>&1)"; then
    status=0
  else
    status=$?
  fi

  if [[ "$status" -ne 1 || "$output" != "$expected" ]]; then
    echo "ERROR: validator did not emit the constant one-line numeric diagnostic for: $label (exit $status)." >&2
    exit 1
  fi
}

assert_rejected_without_reflection() {
  local label="$1"
  local value="$2"
  local output
  local status=0
  local expected="::error::Expected numeric PostgreSQL server_version_num=170006; received a non-numeric value."

  if output="$(bash "$VALIDATOR" "$value" 2>&1)"; then
    status=0
  else
    status=$?
  fi

  if [[ "$status" -ne 1 || "$output" != "$expected" ]]; then
    echo "ERROR: validator did not emit the sanitized one-line diagnostic for: $label (exit $status)." >&2
    exit 1
  fi
}

assert_rejected_with_constant_numeric_diagnostic "PostgreSQL 17.5" 170005
assert_rejected_with_constant_numeric_diagnostic "PostgreSQL 17.7" 170007
assert_rejected_with_constant_numeric_diagnostic "PostgreSQL 17.11" 170011
assert_rejected_with_constant_numeric_diagnostic "PostgreSQL 16.6" 160006
assert_rejected_with_constant_numeric_diagnostic "PostgreSQL 18.0" 180000
long_numeric="$(printf '%512s' '')"
long_numeric="${long_numeric// /9}"
assert_rejected_with_constant_numeric_diagnostic "oversized numeric server value" "$long_numeric"
assert_rejected "human-readable version" "17.6"
assert_rejected_without_reflection "non-numeric server value" "not-a-version"
assert_rejected_without_reflection "LF in server value" $'not-a-version\nqa439-injected'
assert_rejected_without_reflection "CR in server value" $'not-a-version\rqa439-injected'
assert_rejected_without_reflection "TAB in server value" $'not-a-version\tqa439-injected'
assert_rejected_without_reflection "SOH in server value" $'not-a-version\x01qa439-injected'
assert_rejected "empty server value" ""
assert_rejected "missing server value"
assert_rejected "extra positional argument" 170006 unexpected

echo "PostgreSQL 17.6 version guard regression PASS: exact 170006 accepted; 15 invalid/missing/arity cases rejected; numeric and non-numeric diagnostics sanitized."
