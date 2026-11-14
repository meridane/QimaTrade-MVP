#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
SETUP_OUTCOME="${SETUP_OUTCOME-}"
CLEANUP_OUTCOME="${CLEANUP_OUTCOME-}"
CLEANUP_RAN="${CLEANUP_RAN-}"
CLEANUP_EXIT_CODE="${CLEANUP_EXIT_CODE-}"
CLEANUP_FAILURE_OBSERVED="${CLEANUP_FAILURE_OBSERVED-}"
HARNESS_RESULT="${HARNESS_RESULT-}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

case "$MODE" in
  success)
    [[ "$HARNESS_RESULT" == "success" ]] || fail "QA353 requires HARNESS_RESULT=success after job-level continue-on-error."
    [[ "$SETUP_OUTCOME" == "failure" ]] || fail "QA353 requires SETUP_OUTCOME=failure."
    [[ "$CLEANUP_OUTCOME" == "success" ]] || fail "QA353 requires CLEANUP_OUTCOME=success."
    [[ "$CLEANUP_RAN" == "true" ]] || fail "QA353 requires CLEANUP_RAN=true."
    [[ "$CLEANUP_EXIT_CODE" == "0" ]] || fail "QA353 requires CLEANUP_EXIT_CODE=0."
    [[ "$CLEANUP_FAILURE_OBSERVED" == "false" ]] || fail "QA353 requires CLEANUP_FAILURE_OBSERVED=false."
    echo "QA353 passed: setup failed, cleanup succeeded, exit code 0 and the success marker were forwarded."
    ;;
  failure)
    [[ "$HARNESS_RESULT" == "success" ]] || fail "QA354 requires HARNESS_RESULT=success after job-level continue-on-error."
    [[ "$SETUP_OUTCOME" == "failure" ]] || fail "QA354 requires SETUP_OUTCOME=failure."
    [[ "$CLEANUP_OUTCOME" == "failure" ]] || fail "QA354 requires CLEANUP_OUTCOME=failure."
    [[ "$CLEANUP_EXIT_CODE" == "52" ]] || fail "QA354 requires CLEANUP_EXIT_CODE=52."
    [[ "$CLEANUP_FAILURE_OBSERVED" == "true" ]] || fail "QA354 requires CLEANUP_FAILURE_OBSERVED=true."
    [[ -z "$CLEANUP_RAN" ]] || fail "QA354 must not publish CLEANUP_RAN."
    echo "QA354 passed: cleanup failure 52 and its failure marker were forwarded without a success marker."
    ;;
  skipped)
    [[ "$HARNESS_RESULT" == "skipped" ]] || fail "QA357 requires HARNESS_RESULT=skipped."
    [[ -z "$SETUP_OUTCOME" ]] || fail "QA357 skipped harness must not expose SETUP_OUTCOME."
    [[ -z "$CLEANUP_OUTCOME" ]] || fail "QA357 skipped harness must not expose CLEANUP_OUTCOME."
    [[ -z "$CLEANUP_RAN" ]] || fail "QA357 skipped harness must not expose CLEANUP_RAN."
    [[ -z "$CLEANUP_EXIT_CODE" ]] || fail "QA357 skipped harness must not expose CLEANUP_EXIT_CODE."
    [[ -z "$CLEANUP_FAILURE_OBSERVED" ]] || fail "QA357 skipped harness must not expose CLEANUP_FAILURE_OBSERVED."
    echo "QA357 passed: skipped harness exposed no cleanup outputs and was not treated as success."
    ;;
  cancelled)
    [[ "$HARNESS_RESULT" == "cancelled" ]] || fail "QA357 requires HARNESS_RESULT=cancelled."
    fail "QA357 rejects a cancelled harness; cancellation cannot satisfy a cleanup contract."
    ;;
  *)
    fail "mode must be success, failure, skipped or cancelled."
    ;;
esac
