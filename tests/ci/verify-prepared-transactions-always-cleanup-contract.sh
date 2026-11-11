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
require_line "$ASSERT_JOB" "    if: always()"
require_line "$ASSERT_JOB" "    needs: prepared_transactions_always_cleanup_contract"
require_line "$ASSERT_JOB" "        run: |"
require_line "$ASSERT_JOB" '          [[ "$SETUP_OUTCOME" == "failure" ]]'
require_line "$ASSERT_JOB" '          [[ "$CLEANUP_OUTCOME" == "success" ]]'
require_line "$ASSERT_JOB" '          [[ "$CLEANUP_RAN" == "true" ]]'

echo "Prepared-transaction workflow contract passed: the real PostgreSQL job has a blocking always() restoration step with both setup outputs forwarded; the isolated GitHub-runner harness intentionally fails setup, executes the real restore script under inert mocks, and a separate blocking job asserts the failed setup and successful cleanup outcomes."
