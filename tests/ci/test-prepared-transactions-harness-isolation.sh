#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNTIME_SCRIPT="$ROOT/tests/ci/test-prepared-transactions-always-cleanup-runtime.sh"
RUNNER_TEMP="$(printenv RUNNER_TEMP || true)"
GITHUB_OUTPUT="$(printenv GITHUB_OUTPUT || true)"

if [[ -z "$RUNNER_TEMP" || -z "$GITHUB_OUTPUT" ]]; then
  echo "ERROR: RUNNER_TEMP and GITHUB_OUTPUT must be provided by the CI runner." >&2
  exit 1
fi
if [[ ! -f "$RUNTIME_SCRIPT" ]]; then
  echo "ERROR: the shared cleanup runtime harness was not found." >&2
  exit 1
fi

TEMP_ROOT="$(mktemp -d "$RUNNER_TEMP/qima-qa355-isolation.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
SUCCESS_DIR="$TEMP_ROOT/success-runner"
FAILURE_DIR="$TEMP_ROOT/failure-runner"
mkdir -p "$SUCCESS_DIR" "$FAILURE_DIR"

for runner_dir in "$SUCCESS_DIR" "$FAILURE_DIR"; do
  printf '10\n' > "$runner_dir/qima-prepared-cleanup-contract-state"
  : > "$runner_dir/github-output"
done

run_case() {
  local mode="$1"
  local runner_dir="$2"
  local status
  if timeout 30s env \
    RUNNER_TEMP="$runner_dir" \
    GITHUB_OUTPUT="$runner_dir/github-output" \
    SETUP_OUTCOME=failure \
    RESTORE_REQUIRED=true \
    BASELINE_MAX_PREPARED_TRANSACTIONS=0 \
    SIMULATE_RESTORE_FAILURE="$mode" \
    bash "$RUNTIME_SCRIPT" > "$runner_dir/run.log" 2>&1; then
    status=0
  else
    status="$?"
  fi
  printf '%s\n' "$status" > "$runner_dir/exit-status"
}

# Start both paths before waiting: their temporary state and output files must remain disjoint.
run_case false "$SUCCESS_DIR" &
success_pid="$!"
run_case true "$FAILURE_DIR" &
failure_pid="$!"

wait "$success_pid" || {
  echo "ERROR: the successful cleanup isolation process did not finish." >&2
  exit 1
}
wait "$failure_pid" || {
  echo "ERROR: the failing cleanup isolation process did not finish." >&2
  exit 1
}

success_status="$(cat "$SUCCESS_DIR/exit-status")"
failure_status="$(cat "$FAILURE_DIR/exit-status")"
[[ "$success_status" == "0" ]] || {
  echo "ERROR: the success path returned $success_status instead of 0." >&2
  cat "$SUCCESS_DIR/run.log" >&2
  exit 1
}
[[ "$failure_status" == "52" ]] || {
  echo "ERROR: the failure path returned $failure_status instead of 52." >&2
  cat "$FAILURE_DIR/run.log" >&2
  exit 1
}

expected_success_output="$(printf '%s\n' 'cleanup_ran=true' 'cleanup_exit_code=0' 'cleanup_failure_observed=false')"
expected_failure_output="$(printf '%s\n' 'cleanup_exit_code=52' 'cleanup_failure_observed=true')"
[[ "$(cat "$SUCCESS_DIR/github-output")" == "$expected_success_output" ]] || {
  echo "ERROR: success-path outputs were incomplete or contaminated." >&2
  cat "$SUCCESS_DIR/github-output" >&2
  exit 1
}
[[ "$(cat "$FAILURE_DIR/github-output")" == "$expected_failure_output" ]] || {
  echo "ERROR: failure-path outputs were incomplete or contaminated." >&2
  cat "$FAILURE_DIR/github-output" >&2
  exit 1
}

# The full success path reaches QA462 last. Its deliberate Docker-discovery failure
# must leave the initial configuration untouched (10); the earlier RESET succeeded.
[[ "$(cat "$SUCCESS_DIR/qima-prepared-cleanup-contract-state")" == "10" ]] || {
  echo "ERROR: the full success path did not preserve state 10 after QA462 discovery failure." >&2
  cat "$SUCCESS_DIR/run.log" >&2
  cat "$SUCCESS_DIR/qima-prepared-cleanup-contract-state" >&2
  exit 1
}
# The failure path exits during the initial cleanup after RESET, so state is 0.
[[ "$(cat "$FAILURE_DIR/qima-prepared-cleanup-contract-state")" == "0" ]] || {
  echo "ERROR: the initial cleanup-failure path did not retain state 0 after RESET." >&2
  cat "$FAILURE_DIR/run.log" >&2
  cat "$FAILURE_DIR/qima-prepared-cleanup-contract-state" >&2
  exit 1
}
grep -Fq "QA353 runtime contract passed" "$SUCCESS_DIR/run.log" || {
  echo "ERROR: the successful path did not complete the QA353 runtime contract." >&2
  cat "$SUCCESS_DIR/run.log" >&2
  exit 1
}
grep -Fq "QA462 Docker-discovery failure guard passed" "$SUCCESS_DIR/run.log" || {
  echo "ERROR: the successful path did not complete the QA462 no-mutation discovery guard." >&2
  cat "$SUCCESS_DIR/run.log" >&2
  exit 1
}
grep -Fq "QA354 runtime contract passed" "$FAILURE_DIR/run.log" || {
  echo "ERROR: the failure path did not complete the QA354 cleanup-failure contract." >&2
  cat "$FAILURE_DIR/run.log" >&2
  exit 1
}

echo "QA355 passed: concurrent cleanup paths kept separate RUNNER_TEMP and GITHUB_OUTPUT files; the full success path reached QA462 and preserved state 10 after its discovery failure, while the early RESET-failure path retained state 0 and emitted only exit 52 with cleanup_failure_observed=true."
