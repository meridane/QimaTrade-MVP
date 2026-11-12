#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ASSERTION_SCRIPT="$ROOT/tests/ci/assert-prepared-transactions-cleanup-contract.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

if [[ ! -x "$ASSERTION_SCRIPT" && ! -f "$ASSERTION_SCRIPT" ]]; then
  fail "the shared cleanup assertion script was not found."
fi

env \
  SETUP_OUTCOME=failure \
  CLEANUP_OUTCOME=success \
  CLEANUP_RAN=true \
  CLEANUP_EXIT_CODE=0 \
  CLEANUP_FAILURE_OBSERVED=false \
  bash "$ASSERTION_SCRIPT" success >/dev/null

env \
  SETUP_OUTCOME=failure \
  CLEANUP_OUTCOME=failure \
  CLEANUP_RAN= \
  CLEANUP_EXIT_CODE=52 \
  CLEANUP_FAILURE_OBSERVED=true \
  bash "$ASSERTION_SCRIPT" failure >/dev/null

case_number=0
expect_rejected() {
  local label="$1"
  local mode="$2"
  shift 2
  case_number=$((case_number + 1))
  local log="$TEMP_DIR/case-$case_number.log"
  if env "$@" bash "$ASSERTION_SCRIPT" "$mode" >"$log" 2>&1; then
    fail "assertion unexpectedly accepted malformed outputs: $label"
  fi
  if ! grep -Fq "ERROR:" "$log"; then
    fail "assertion rejected $label without a deterministic ERROR diagnostic."
  fi
  printf 'PASS: rejected %s\n' "$label"
}

expect_rejected "success output missing cleanup_ran" success \
  SETUP_OUTCOME=failure CLEANUP_OUTCOME=success CLEANUP_EXIT_CODE=0 CLEANUP_FAILURE_OBSERVED=false
expect_rejected "success output missing cleanup_exit_code" success \
  SETUP_OUTCOME=failure CLEANUP_OUTCOME=success CLEANUP_RAN=true CLEANUP_FAILURE_OBSERVED=false
expect_rejected "success output incorrectly reports a cleanup failure" success \
  SETUP_OUTCOME=failure CLEANUP_OUTCOME=success CLEANUP_RAN=true CLEANUP_EXIT_CODE=0 CLEANUP_FAILURE_OBSERVED=true
expect_rejected "failure output missing cleanup_exit_code" failure \
  SETUP_OUTCOME=failure CLEANUP_OUTCOME=failure CLEANUP_RAN= CLEANUP_FAILURE_OBSERVED=true
expect_rejected "failure output has an unexpected cleanup_exit_code" failure \
  SETUP_OUTCOME=failure CLEANUP_OUTCOME=failure CLEANUP_RAN= CLEANUP_EXIT_CODE=51 CLEANUP_FAILURE_OBSERVED=true
expect_rejected "failure output missing cleanup_failure_observed" failure \
  SETUP_OUTCOME=failure CLEANUP_OUTCOME=failure CLEANUP_RAN= CLEANUP_EXIT_CODE=52
expect_rejected "failure output incorrectly publishes cleanup_ran" failure \
  SETUP_OUTCOME=failure CLEANUP_OUTCOME=failure CLEANUP_RAN=true CLEANUP_EXIT_CODE=52 CLEANUP_FAILURE_OBSERVED=true
expect_rejected "failure output reports success outcome" failure \
  SETUP_OUTCOME=failure CLEANUP_OUTCOME=success CLEANUP_RAN= CLEANUP_EXIT_CODE=52 CLEANUP_FAILURE_OBSERVED=true

echo "QA356 passed: both valid cleanup contracts were accepted and all eight malformed or incomplete output combinations were rejected."
