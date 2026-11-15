#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNNER" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA428 contract file is missing: $file"
done

QA428_BLOCK="$(sed -n '/^# QA428_CONCURRENT_SUCCESS_MISMATCH_BEGIN$/,/^# QA428_CONCURRENT_SUCCESS_MISMATCH_END$/p' "$RUNNER")"
[[ -n "$QA428_BLOCK" ]] || fail "QA428 concurrent success/mismatch block is missing"

while IFS= read -r required; do
  [[ -z "$required" ]] && continue
  grep -Fq -- "$required" <<< "$QA428_BLOCK" || fail "QA428 block is missing required contract text: $required"
done <<'REQUIRED'
qa428_first_sql=$(cat <<'SQL'
qa428_second_sql=$(cat <<'SQL'
fixture-qa428-concurrent-success-mismatch
p_price => 23,
p_price => 24,
SET application_name = 'qima-qa428-first';
SET application_name = 'qima-qa428-second';
qa428_first_lock_snapshot == "1|1"
qa428_lock_snapshot == "2|1|1|1"
qa428_first_status -ne 0 || qa428_second_status -eq 0
IDEMPOTENCY_KEY_REUSE
qa428_first_replay_sql=
qa428_second_replay_sql=
v_expected_first_hash
v_expected_second_hash
FROM public.idempotency_keys
FROM public.action_executions
FROM public.offers
FROM public.action_events
QA428 PASS:
REQUIRED

key_call_count="$(grep -Fc "p_idempotency_key => 'fixture-qa428-concurrent-success-mismatch'," <<< "$QA428_BLOCK" || true)"
[[ "$key_call_count" -eq 4 ]] || fail "QA428 must use the same tenant/key for first, competing, winning replay and losing replay calls exactly four times"

[[ "$(grep -Fc 'QA428 PASS:' <<< "$QA428_BLOCK" || true)" -eq 1 ]] ||
  fail "QA428 runtime marker must appear exactly once"

job_section() {
  local target="$1"
  awk -v target="$target" '
    $0 == "  " target ":" { inside = 1; next }
    inside && /^  [[:alnum:]_-]+:$/ { exit }
    inside { print }
  ' "$WORKFLOW"
}

verify_job="$(job_section verify)"
pg16_job="$(job_section postgres-integration)"
pg17_job="$(job_section postgres17-create-offer-compatibility)"

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-concurrent-success-mismatch-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute the QA428 static contract exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute the shared runtime runner exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute the shared runtime runner exactly once"

echo "QA428 static contract PASS: the successful first same-key payload must commit before the queued changed-payload request is rejected, with exact replay and single-row persistence assertions wired to PostgreSQL 16 and 17.6."
