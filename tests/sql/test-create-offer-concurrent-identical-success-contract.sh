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
  [[ -f "$file" ]] || fail "required QA429 contract file is missing: $file"
done

QA429_BLOCK="$(sed -n '/^# QA429_CONCURRENT_IDENTICAL_SUCCESS_BEGIN$/,/^# QA429_CONCURRENT_IDENTICAL_SUCCESS_END$/p' "$RUNNER")"
[[ -n "$QA429_BLOCK" ]] || fail "QA429 concurrent identical-success block is missing"

while IFS= read -r required; do
  [[ -z "$required" ]] && continue
  grep -Fq -- "$required" <<< "$QA429_BLOCK" || fail "QA429 block is missing required contract text: $required"
done <<'REQUIRED'
qa429_first_sql=$(cat <<'SQL'
qa429_second_sql=$(cat <<'SQL'
qa429_replay_sql=$(cat <<'SQL'
fixture-qa429-concurrent-identical-success
p_input => '{"case":"qa429-concurrent-identical-success"}'::jsonb,
p_name => 'QA429 Concurrent Identical Offer',
p_demand_id => '50000000-0000-4000-8000-000000000001',
p_product_master_id => '40000000-0000-4000-8000-000000000001',
p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
p_quantity => 3,
p_price => 23,
p_currency => 'USD'
SET application_name = 'qima-qa429-first';
SET application_name = 'qima-qa429-second';
SET application_name = 'qima-qa429-replay';
[[ "$qa429_first_lock_snapshot" == "1|1" ]]
[[ "$qa429_lock_snapshot" == "2|1|1|1" ]]
if [[ "$qa429_first_status" -ne 0 || "$qa429_second_status" -ne 0 ]]; then
cmp -s /tmp/qima-qa429-first.log /tmp/qima-qa429-second.log
cmp -s /tmp/qima-qa429-first.log /tmp/qima-qa429-stored-result.log
cmp -s /tmp/qima-qa429-first.log /tmp/qima-qa429-replay.log
v_expected_hash
FROM public.idempotency_keys
FROM public.action_executions
FROM public.offers
FROM public.action_events
QA429 PASS:
REQUIRED

for pattern in \
  "p_idempotency_key => 'fixture-qa429-concurrent-identical-success'," \
  "p_input => '{\"case\":\"qa429-concurrent-identical-success\"}'::jsonb," \
  "p_name => 'QA429 Concurrent Identical Offer'," \
  "p_price => 23,"; do
  count="$(grep -Fc -- "$pattern" <<< "$QA429_BLOCK" || true)"
  [[ "$count" -eq 3 ]] || fail "each of the three QA429 calls must use the same effective payload field: $pattern (found $count)"
done

[[ "$(grep -Fc 'cmp -s' <<< "$QA429_BLOCK" || true)" -eq 3 ]] ||
  fail "QA429 must compare both concurrent responses, the stored result, and a later exact replay"
[[ "$(grep -Fc 'QA429 PASS:' <<< "$QA429_BLOCK" || true)" -eq 1 ]] ||
  fail "QA429 runtime marker must appear exactly once"

if grep -Eiq '^[[:space:]]*(INSERT|UPDATE|DELETE|CREATE|DROP|ALTER)[[:space:]]' <<< "$QA429_BLOCK"; then
  fail "QA429 must not perform direct DML or schema/privilege changes"
fi

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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-concurrent-identical-success-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute the QA429 static contract exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute the shared runtime runner exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute the shared runtime runner exactly once"

echo "QA429 static contract PASS: identical concurrent same-key requests must both return the same committed success result, preserve one persisted record in each table, and remain exactly replayable on PostgreSQL 16 and 17.6."
