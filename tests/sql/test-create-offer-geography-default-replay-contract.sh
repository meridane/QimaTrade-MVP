#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$BASH_SOURCE")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
RUNTIME="$ROOT/tests/sql/create-offer-geography-default-replay.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$MIGRATION" "$RUNTIME" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA413 file is missing: $file"
done

[[ "$(grep -Fc "p_geography text DEFAULT NULL::text" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the existing function signature must declare the p_geography NULL default exactly once"

BLOCK="$(sed -n '/^DO \$qa413_geography_default_replay\$/,/^\$qa413_geography_default_replay\$;/p' "$RUNTIME")"

[[ "$(grep -Fc \"v_input jsonb := '{\\\"case\\\":\\\"qa413-geography-default-replay\\\"}'::jsonb;\" <<< \"$BLOCK\" || true)" -eq 1 ]] ||
  fail "QA413 input fixture must identify the geography-default scenario exactly once"
if grep -Fq 'qa412-market-default-replay' <<< "$BLOCK"; then
  fail "QA413 geography-default block must not reuse the QA412 market-default fixture label"
fi
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA413 market-default replay block"

FIRST_CALL="$(sed -n '/v_first_result := public.execute_create_offer_v1(/,/^  );/p' <<< "$BLOCK")"
REPLAY_CALL="$(sed -n '/v_replay_result := public.execute_create_offer_v1(/,/^  );/p' <<< "$BLOCK")"
[[ -n "$FIRST_CALL" && -n "$REPLAY_CALL" ]] || fail "QA413 must contain both the initial call and exact replay call"

[[ "$(grep -Fc 'public.execute_create_offer_v1(' <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA413 must contain exactly two CREATE_OFFER calls"
if grep -Fq 'p_geography =>' <<< "$FIRST_CALL"; then
  fail "the first QA413 call must omit p_geography so PostgreSQL applies its declared default"
fi
[[ "$(grep -Fc 'p_geography => NULL' <<< "$REPLAY_CALL" || true)" -eq 1 ]] ||
  fail "the replay must explicitly supply the declared NULL::text default exactly once"
[[ "$(grep -Fc 'p_geography =>' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "only the explicit replay call may supply p_geography"

for parameter in \
  "p_tenant_id => v_tenant_id," \
  "p_idempotency_key => v_key," \
  "p_input => v_input," \
  "p_name => v_offer_name," \
  "p_demand_id => '50000000-0000-4000-8000-000000000001'," \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
  "p_provider_actor_id => '30000000-0000-4000-8000-000000000001'," \
  "p_quantity => 1::numeric," \
  "p_price => 12::numeric," \
  "p_currency => 'USD'," \
  "p_conditions => NULL," \
  "p_market => NULL," \
  "p_attributes => '{}'::jsonb," \
  "p_documentation_status => NULL," \
  "p_lifecycle => NULL," \
  "p_offer_type => 'fixture-offer-type-stable'," \
  "p_pricing_model => 'fixture-pricing-model-stable'"; do
  count="$(grep -Fc -- "$parameter" <<< "$BLOCK" || true)"
  [[ "$count" -eq 2 ]] ||
    fail "all non-market effective parameters must remain identical across both calls: $parameter (found $count)"
done

for required in \
  "v_replay_result IS DISTINCT FROM v_first_result" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_idempotency_status IS DISTINCT FROM 'COMPLETED'" \
  "v_idempotency_result IS DISTINCT FROM v_first_result" \
  "v_execution_status IS DISTINCT FROM 'COMPLETED'" \
  "v_execution_result IS DISTINCT FROM v_first_result" \
  "v_offer_geography IS NOT NULL" \
  "v_event_payload IS DISTINCT FROM v_first_result" \
  "v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count" \
  "v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count" \
  "v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count" \
  "v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count" \
  "QA413 PASS: omitting p_geography applies the declared NULL::text default and exactly replays an explicit NULL request without duplicate persisted state"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA413 is missing a required default/replay/persisted-state assertion: $required"
done

for required in \
  "v_after_first.idempotency_count <> 1" \
  "v_after_first.execution_count <> 1" \
  "v_after_first.offer_count <> 1" \
  "v_after_first.event_count <> 1"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA413 must assert exactly one original row in each persistence table: $required"
done

[[ "$(grep -Fc 'DO $qa413_geography_default_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA413 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa413_geography_default_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA413 dollar-quoted block must close exactly once"
[[ "$(grep -Fc 'QA413 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA413 runtime marker must appear exactly once"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA413 must remain a function-call regression followed by read-only persisted-state assertions"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-geography-default-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA413 static coverage exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-geography-default-replay.sql' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute the QA413 runtime script exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-geography-default-replay.sql' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute the QA413 runtime script exactly once"

pg16_runner_line="$(grep -nF 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" | cut -d: -f1)"
pg16_test_line="$(grep -nF 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-geography-default-replay.sql' <<< "$pg16_job" | cut -d: -f1)"
pg17_runner_line="$(grep -nF 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" | cut -d: -f1)"
pg17_test_line="$(grep -nF 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-geography-default-replay.sql' <<< "$pg17_job" | cut -d: -f1)"
[[ -n "$pg16_runner_line" && -n "$pg16_test_line" && "$pg16_runner_line" -lt "$pg16_test_line" ]] ||
  fail "PostgreSQL 16 must initialize the disposable fixture before QA413"
[[ -n "$pg17_runner_line" && -n "$pg17_test_line" && "$pg17_runner_line" -lt "$pg17_test_line" ]] ||
  fail "PostgreSQL 17.6 must initialize the disposable fixture before QA413"

grep -Fq 'image: postgres:16' <<< "$pg16_job" || fail "PostgreSQL 16 service image is missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" || fail "PostgreSQL 17.6 service image is missing"
grep -Fq 'DATABASE_URL: postgresql://postgres:postgres@localhost:5432/qima_test' <<< "$pg16_job" ||
  fail "PostgreSQL 16 must use the disposable loopback database"
grep -Fq 'DATABASE_URL: postgresql://postgres:postgres@localhost:5432/qima_test' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 must use the disposable loopback database"

echo "QA413 static contract PASS: omitting p_geography applies the declared NULL::text default and exactly replays an explicit NULL request without duplicate persisted state on PostgreSQL 16 and 17.6."
