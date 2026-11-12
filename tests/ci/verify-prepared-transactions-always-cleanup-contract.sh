#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_PATH="${1:-$ROOT/.github/workflows/ci.yml}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

if [[ ! -f "$WORKFLOW_PATH" ]]; then
  fail "workflow file not found: $WORKFLOW_PATH"
fi

extract_job() {
  local job_id="$1"
  local output="$2"
  awk -v target="  $job_id:" '
    $0 == target { capture = 1; found++ }
    capture && /^  [[:alnum:]_-]+:$/ && $0 != target { exit }
    capture { print }
    END { if (found != 1) exit 1 }
  ' "$WORKFLOW_PATH" > "$output" || fail "expected exactly one job named $job_id"
}

extract_step() {
  local job_file="$1"
  local step_name="$2"
  local output="$3"
  awk -v prefix="      - name: $step_name" '
    index($0, prefix) == 1 && !capture { capture = 1; found++ }
    capture && /^      - name: / && index($0, prefix) != 1 { exit }
    capture { print }
    END { if (found != 1) exit 1 }
  ' "$job_file" > "$output" || fail "expected exactly one step named: $step_name"
}

require_line() {
  local file="$1"
  local expected="$2"
  grep -Fqx -- "$expected" "$file" || fail "missing required workflow line: $expected"
}

forbid_line() {
  local file="$1"
  local forbidden="$2"
  if grep -Fqx -- "$forbidden" "$file"; then
    fail "unexpected workflow line: $forbidden"
  fi
}

POSTGRES_JOB="$TEMP_DIR/postgres-integration.yml"
SETUP_STEP="$TEMP_DIR/setup-step.yml"
RESTORE_STEP="$TEMP_DIR/restore-step.yml"
HARNESS_JOB="$TEMP_DIR/harness-job.yml"
HARNESS_SETUP_STEP="$TEMP_DIR/harness-setup-step.yml"
HARNESS_CLEANUP_STEP="$TEMP_DIR/harness-cleanup-step.yml"
ASSERT_JOB="$TEMP_DIR/assert-job.yml"
VERIFY_JOB="$TEMP_DIR/verify-job.yml"
VERIFY_STEP="$TEMP_DIR/verify-step.yml"
ASSERTION_TEST_STEP="$TEMP_DIR/assertion-test-step.yml"
ASSERT_CHECKOUT_STEP="$TEMP_DIR/assert-checkout-step.yml"
FAILURE_ASSERT_CHECKOUT_STEP="$TEMP_DIR/failure-assert-checkout-step.yml"

extract_job "verify" "$VERIFY_JOB"
extract_step "$VERIFY_JOB" "Verify prepared-transaction always-cleanup workflow wiring" "$VERIFY_STEP"
require_line "$VERIFY_STEP" "        run: bash tests/ci/verify-prepared-transactions-always-cleanup-contract.sh"
extract_step "$VERIFY_JOB" "Verify prepared-transaction cleanup assertions reject malformed, skipped and cancelled outcomes" "$ASSERTION_TEST_STEP"
require_line "$ASSERTION_TEST_STEP" "        run: bash tests/ci/test-prepared-transactions-cleanup-assertions.sh"

extract_job "postgres-integration" "$POSTGRES_JOB"
extract_step "$POSTGRES_JOB" "Enable prepared transactions for the disposable PostgreSQL regression" "$SETUP_STEP"
extract_step "$POSTGRES_JOB" "Restore prepared-transaction configuration and verify disposable resources" "$RESTORE_STEP"

require_line "$POSTGRES_JOB" "    timeout-minutes: 10"
require_line "$POSTGRES_JOB" "        image: postgres:16"
require_line "$POSTGRES_JOB" "          POSTGRES_DB: qima_test"
forbid_line "$POSTGRES_JOB" "    continue-on-error: true"

[[ "$(grep -Fxc '        id: enable_prepared' "$POSTGRES_JOB" || true)" -eq 1 ]] ||
  fail "the real PostgreSQL setup step must expose exactly one enable_prepared output id"
require_line "$SETUP_STEP" "        shell: bash"
require_line "$SETUP_STEP" "        run: bash tests/sql/enable-prepared-transactions-config.sh"
forbid_line "$SETUP_STEP" "        continue-on-error: true"

require_line "$RESTORE_STEP" "        if: always()"
require_line "$RESTORE_STEP" '          RESTORE_REQUIRED: ${{ steps.enable_prepared.outputs.restore_required }}'
require_line "$RESTORE_STEP" '          BASELINE_MAX_PREPARED_TRANSACTIONS: ${{ steps.enable_prepared.outputs.baseline }}'
require_line "$RESTORE_STEP" "        run: bash tests/sql/restore-prepared-transactions-config.sh"
forbid_line "$RESTORE_STEP" "        continue-on-error: true"

setup_line="$(grep -nF '      - name: Enable prepared transactions for the disposable PostgreSQL regression' "$POSTGRES_JOB" | cut -d: -f1)"
cleanup_line="$(grep -nF '      - name: Verify prepared transactions block forced disposable database cleanup' "$POSTGRES_JOB" | cut -d: -f1)"
restore_line="$(grep -nF '      - name: Restore prepared-transaction configuration and verify disposable resources' "$POSTGRES_JOB" | cut -d: -f1)"
[[ "$setup_line" -lt "$cleanup_line" && "$cleanup_line" -lt "$restore_line" ]] ||
  fail "the real restoration step must follow setup and the prepared-transaction cleanup regression"

extract_job "prepared_transactions_always_cleanup_contract" "$HARNESS_JOB"
extract_step "$HARNESS_JOB" "Simulate a partial setup failure after publishing cleanup outputs" "$HARNESS_SETUP_STEP"
extract_step "$HARNESS_JOB" "Execute actual restore script after the simulated setup failure" "$HARNESS_CLEANUP_STEP"

require_line "$HARNESS_JOB" "    continue-on-error: true"
require_line "$HARNESS_JOB" "    timeout-minutes: 5"
require_line "$HARNESS_JOB" '      setup_outcome: ${{ steps.simulated_setup.outcome }}'
require_line "$HARNESS_JOB" '      cleanup_outcome: ${{ steps.always_cleanup.outcome }}'
require_line "$HARNESS_JOB" '      cleanup_ran: ${{ steps.always_cleanup.outputs.cleanup_ran }}'
require_line "$HARNESS_JOB" '      cleanup_exit_code: ${{ steps.always_cleanup.outputs.cleanup_exit_code }}'
require_line "$HARNESS_JOB" '      cleanup_failure_observed: ${{ steps.always_cleanup.outputs.cleanup_failure_observed }}'
require_line "$HARNESS_SETUP_STEP" "        id: simulated_setup"
require_line "$HARNESS_SETUP_STEP" "          printf 'baseline=0\\nrestore_required=true\\n' >> \"\$GITHUB_OUTPUT\""
require_line "$HARNESS_SETUP_STEP" "          exit 47"
require_line "$HARNESS_CLEANUP_STEP" "        id: always_cleanup"
require_line "$HARNESS_CLEANUP_STEP" "        if: always()"
require_line "$HARNESS_CLEANUP_STEP" '          SETUP_OUTCOME: ${{ steps.simulated_setup.outcome }}'
require_line "$HARNESS_CLEANUP_STEP" '          RESTORE_REQUIRED: ${{ steps.simulated_setup.outputs.restore_required }}'
require_line "$HARNESS_CLEANUP_STEP" '          BASELINE_MAX_PREPARED_TRANSACTIONS: ${{ steps.simulated_setup.outputs.baseline }}'
require_line "$HARNESS_CLEANUP_STEP" "        run: bash tests/ci/test-prepared-transactions-always-cleanup-runtime.sh"
forbid_line "$HARNESS_CLEANUP_STEP" "        continue-on-error: true"

extract_job "prepared_transactions_always_cleanup_assert" "$ASSERT_JOB"
extract_step "$ASSERT_JOB" "Checkout repository" "$ASSERT_CHECKOUT_STEP"
require_line "$ASSERT_CHECKOUT_STEP" "        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1"
forbid_line "$ASSERT_JOB" "    continue-on-error: true"
require_line "$ASSERT_JOB" "    if: always()"
require_line "$ASSERT_JOB" "    needs: prepared_transactions_always_cleanup_contract"
require_line "$ASSERT_JOB" '          SETUP_OUTCOME: ${{ needs.prepared_transactions_always_cleanup_contract.outputs.setup_outcome }}'
require_line "$ASSERT_JOB" '          CLEANUP_OUTCOME: ${{ needs.prepared_transactions_always_cleanup_contract.outputs.cleanup_outcome }}'
require_line "$ASSERT_JOB" '          CLEANUP_RAN: ${{ needs.prepared_transactions_always_cleanup_contract.outputs.cleanup_ran }}'
require_line "$ASSERT_JOB" '          CLEANUP_EXIT_CODE: ${{ needs.prepared_transactions_always_cleanup_contract.outputs.cleanup_exit_code }}'
require_line "$ASSERT_JOB" '          CLEANUP_FAILURE_OBSERVED: ${{ needs.prepared_transactions_always_cleanup_contract.outputs.cleanup_failure_observed }}'
require_line "$ASSERT_JOB" "        run: bash tests/ci/assert-prepared-transactions-cleanup-contract.sh success"

echo "Prepared-transaction workflow contract passed: the real PostgreSQL job has a blocking always() restoration step with both setup outputs forwarded; the isolated GitHub-runner harness intentionally fails setup, executes the real restore script under inert mocks, and a separate blocking job asserts the failed setup and successful cleanup outcomes."


FAILURE_HARNESS_JOB="$TEMP_DIR/failure-harness-job.yml"
FAILURE_HARNESS_SETUP_STEP="$TEMP_DIR/failure-harness-setup-step.yml"
FAILURE_HARNESS_CLEANUP_STEP="$TEMP_DIR/failure-harness-cleanup-step.yml"
FAILURE_ASSERT_JOB="$TEMP_DIR/failure-assert-job.yml"

extract_job "prepared_transactions_always_cleanup_failure_contract" "$FAILURE_HARNESS_JOB"
extract_step "$FAILURE_HARNESS_JOB" "Simulate a partial setup failure before cleanup" "$FAILURE_HARNESS_SETUP_STEP"
extract_step "$FAILURE_HARNESS_JOB" "Execute actual restore script and expect a cleanup failure" "$FAILURE_HARNESS_CLEANUP_STEP"

require_line "$FAILURE_HARNESS_JOB" "    continue-on-error: true"
require_line "$FAILURE_HARNESS_JOB" "    timeout-minutes: 5"
require_line "$FAILURE_HARNESS_JOB" '      cleanup_exit_code: ${{ steps.always_cleanup.outputs.cleanup_exit_code }}'
require_line "$FAILURE_HARNESS_JOB" '      cleanup_failure_observed: ${{ steps.always_cleanup.outputs.cleanup_failure_observed }}'
require_line "$FAILURE_HARNESS_SETUP_STEP" "        id: simulated_setup"
require_line "$FAILURE_HARNESS_SETUP_STEP" "          exit 47"
require_line "$FAILURE_HARNESS_CLEANUP_STEP" "        id: always_cleanup"
require_line "$FAILURE_HARNESS_CLEANUP_STEP" "        if: always()"
require_line "$FAILURE_HARNESS_CLEANUP_STEP" '          SIMULATE_RESTORE_FAILURE: "true"'
require_line "$FAILURE_HARNESS_CLEANUP_STEP" "        run: bash tests/ci/test-prepared-transactions-always-cleanup-runtime.sh"
forbid_line "$FAILURE_HARNESS_CLEANUP_STEP" "        continue-on-error: true"

extract_job "prepared_transactions_always_cleanup_failure_assert" "$FAILURE_ASSERT_JOB"
extract_step "$FAILURE_ASSERT_JOB" "Checkout repository" "$FAILURE_ASSERT_CHECKOUT_STEP"
require_line "$FAILURE_ASSERT_CHECKOUT_STEP" "        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1"
forbid_line "$FAILURE_ASSERT_JOB" "    continue-on-error: true"
require_line "$FAILURE_ASSERT_JOB" "    if: always()"
require_line "$FAILURE_ASSERT_JOB" "    needs: prepared_transactions_always_cleanup_failure_contract"
require_line "$FAILURE_ASSERT_JOB" '          CLEANUP_OUTCOME: ${{ needs.prepared_transactions_always_cleanup_failure_contract.outputs.cleanup_outcome }}'
require_line "$FAILURE_ASSERT_JOB" '          CLEANUP_RAN: ${{ needs.prepared_transactions_always_cleanup_failure_contract.outputs.cleanup_ran }}'
require_line "$FAILURE_ASSERT_JOB" '          CLEANUP_EXIT_CODE: ${{ needs.prepared_transactions_always_cleanup_failure_contract.outputs.cleanup_exit_code }}'
require_line "$FAILURE_ASSERT_JOB" '          CLEANUP_FAILURE_OBSERVED: ${{ needs.prepared_transactions_always_cleanup_failure_contract.outputs.cleanup_failure_observed }}'
require_line "$FAILURE_ASSERT_JOB" "        run: bash tests/ci/assert-prepared-transactions-cleanup-contract.sh failure"


SUCCESS_HARNESS_JOB="$TEMP_DIR/success-harness-job.yml"
FAILURE_HARNESS_JOB="$TEMP_DIR/failure-harness-job.yml"
SUCCESS_ASSERT_JOB="$TEMP_DIR/success-assert-job.yml"
FAILURE_ASSERT_JOB="$TEMP_DIR/failure-assert-job.yml"

extract_job "prepared_transactions_always_cleanup_contract" "$SUCCESS_HARNESS_JOB"
extract_job "prepared_transactions_always_cleanup_failure_contract" "$FAILURE_HARNESS_JOB"
extract_job "prepared_transactions_always_cleanup_assert" "$SUCCESS_ASSERT_JOB"
extract_job "prepared_transactions_always_cleanup_failure_assert" "$FAILURE_ASSERT_JOB"

# The two harnesses must be independent GitHub-hosted jobs, not serialized through needs.
require_line "$SUCCESS_HARNESS_JOB" "    runs-on: ubuntu-latest"
require_line "$FAILURE_HARNESS_JOB" "    runs-on: ubuntu-latest"
forbid_line "$SUCCESS_HARNESS_JOB" "    needs:"
forbid_line "$FAILURE_HARNESS_JOB" "    needs:"
forbid_line "$SUCCESS_HARNESS_JOB" "    needs: prepared_transactions_always_cleanup_failure_contract"
forbid_line "$FAILURE_HARNESS_JOB" "    needs: prepared_transactions_always_cleanup_contract"

# Each blocking assertion may consume only its matching harness outputs.
require_line "$SUCCESS_ASSERT_JOB" "    needs: prepared_transactions_always_cleanup_contract"
require_line "$FAILURE_ASSERT_JOB" "    needs: prepared_transactions_always_cleanup_failure_contract"
require_line "$SUCCESS_ASSERT_JOB" "    if: always()"
require_line "$FAILURE_ASSERT_JOB" "    if: always()"
forbid_line "$SUCCESS_ASSERT_JOB" "    continue-on-error: true"
forbid_line "$FAILURE_ASSERT_JOB" "    continue-on-error: true"
if grep -Fq "needs.prepared_transactions_always_cleanup_failure_contract" "$SUCCESS_ASSERT_JOB"; then
  fail "the success assertion must not read failure-harness outputs"
fi
if grep -Fq "needs.prepared_transactions_always_cleanup_contract" "$FAILURE_ASSERT_JOB"; then
  fail "the failure assertion must not read success-harness outputs"
fi

SKIPPED_HARNESS_JOB="$TEMP_DIR/skipped-harness-job.yml"
SKIPPED_ASSERT_JOB="$TEMP_DIR/skipped-assert-job.yml"
SKIPPED_ASSERT_CHECKOUT_STEP="$TEMP_DIR/skipped-assert-checkout-step.yml"
SKIPPED_ASSERT_STEP="$TEMP_DIR/skipped-assert-step.yml"

extract_job "prepared_transactions_cleanup_skipped_contract" "$SKIPPED_HARNESS_JOB"
require_line "$SKIPPED_HARNESS_JOB" "    runs-on: ubuntu-latest"
require_line "$SKIPPED_HARNESS_JOB" '    if: ${{ false }}'
forbid_line "$SKIPPED_HARNESS_JOB" "    continue-on-error: true"
require_line "$SKIPPED_HARNESS_JOB" '      setup_outcome: ${{ steps.never_run.outputs.setup_outcome }}'
require_line "$SKIPPED_HARNESS_JOB" '      cleanup_outcome: ${{ steps.never_run.outputs.cleanup_outcome }}'
require_line "$SKIPPED_HARNESS_JOB" '      cleanup_ran: ${{ steps.never_run.outputs.cleanup_ran }}'
require_line "$SKIPPED_HARNESS_JOB" '      cleanup_exit_code: ${{ steps.never_run.outputs.cleanup_exit_code }}'
require_line "$SKIPPED_HARNESS_JOB" '      cleanup_failure_observed: ${{ steps.never_run.outputs.cleanup_failure_observed }}'

extract_job "prepared_transactions_cleanup_skipped_assert" "$SKIPPED_ASSERT_JOB"
require_line "$SKIPPED_ASSERT_JOB" "    if: always()"
require_line "$SKIPPED_ASSERT_JOB" "    needs: prepared_transactions_cleanup_skipped_contract"
forbid_line "$SKIPPED_ASSERT_JOB" "    continue-on-error: true"
extract_step "$SKIPPED_ASSERT_JOB" "Checkout repository" "$SKIPPED_ASSERT_CHECKOUT_STEP"
require_line "$SKIPPED_ASSERT_CHECKOUT_STEP" "        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1"
extract_step "$SKIPPED_ASSERT_JOB" "Assert skipped harness has no cleanup outputs" "$SKIPPED_ASSERT_STEP"
require_line "$SKIPPED_ASSERT_STEP" '          HARNESS_RESULT: ${{ needs.prepared_transactions_cleanup_skipped_contract.result }}'
require_line "$SKIPPED_ASSERT_STEP" '          SETUP_OUTCOME: ${{ needs.prepared_transactions_cleanup_skipped_contract.outputs.setup_outcome }}'
require_line "$SKIPPED_ASSERT_STEP" '          CLEANUP_OUTCOME: ${{ needs.prepared_transactions_cleanup_skipped_contract.outputs.cleanup_outcome }}'
require_line "$SKIPPED_ASSERT_STEP" '          CLEANUP_RAN: ${{ needs.prepared_transactions_cleanup_skipped_contract.outputs.cleanup_ran }}'
require_line "$SKIPPED_ASSERT_STEP" '          CLEANUP_EXIT_CODE: ${{ needs.prepared_transactions_cleanup_skipped_contract.outputs.cleanup_exit_code }}'
require_line "$SKIPPED_ASSERT_STEP" '          CLEANUP_FAILURE_OBSERVED: ${{ needs.prepared_transactions_cleanup_skipped_contract.outputs.cleanup_failure_observed }}'
require_line "$SKIPPED_ASSERT_STEP" "        run: bash tests/ci/assert-prepared-transactions-cleanup-contract.sh skipped"

grep -Fq 'cancelled harness cannot be accepted with fabricated success outputs' "$ROOT/tests/ci/test-prepared-transactions-cleanup-assertions.sh" ||
  fail "the cancelled-result regression case is missing"
grep -Fq 'cancelled harness cannot be accepted with fabricated failure outputs' "$ROOT/tests/ci/test-prepared-transactions-cleanup-assertions.sh" ||
  fail "the cancelled-result failure-output regression case is missing"

echo "Prepared-transaction workflow contract passed: success/failure harnesses remain isolated; a real skipped job is observed by an always() blocking assertion; cancelled outcomes are rejected by the shared contract tests; the real PostgreSQL restore remains blocking."
