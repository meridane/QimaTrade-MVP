#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
SETUP_OUTCOME="${SETUP_OUTCOME-}"
CLEANUP_OUTCOME="${CLEANUP_OUTCOME-}"
CLEANUP_RAN="${CLEANUP_RAN-}"
CLEANUP_EXIT_CODE="${CLEANUP_EXIT_CODE-}"
CLEANUP_FAILURE_OBSERVED="${CLEANUP_FAILURE_OBSERVED-}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

case "$MODE" in
  success)
    [[ "$SETUP_OUTCOME" == "failure" ]] || fail "QA353 requires SETUP_OUTCOME=failure."
    [[ "$CLEANUP_OUTCOME" == "success" ]] || fail "QA353 requires CLEANUP_OUTCOME=success."
    [[ "$CLEANUP_RAN" == "true" ]] || fail "QA353 requires CLEANUP_RAN=true."
    [[ "$CLEANUP_EXIT_CODE" == "0" ]] || fail "QA353 requires CLEANUP_EXIT_CODE=0."
    [[ "$CLEANUP_FAILURE_OBSERVED" == "false" ]] || fail "QA353 requires CLEANUP_FAILURE_OBSERVED=false."
    echo "QA353 passed: setup failed, cleanup succeeded, exit code 0 and the success marker were forwarded."
    ;;
  failure)
    [[ "$SETUP_OUTCOME" == "failure" ]] || fail "QA354 requires SETUP_OUTCOME=failure."
    [[ "$CLEANUP_OUTCOME" == "failure" ]] || fail "QA354 requires CLEANUP_OUTCOME=failure."
    [[ "$CLEANUP_EXIT_CODE" == "52" ]] || fail "QA354 requires CLEANUP_EXIT_CODE=52."
    [[ "$CLEANUP_FAILURE_OBSERVED" == "true" ]] || fail "QA354 requires CLEANUP_FAILURE_OBSERVED=true."
    [[ -z "$CLEANUP_RAN" ]] || fail "QA354 must not publish CLEANUP_RAN."
    echo "QA354 passed: cleanup failure 52 and its failure marker were forwarded without a success marker."
    ;;
  *)
    fail "mode must be either success or failure."
    ;;
esac
