#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-demand-mismatch-replay.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
FIXTURE="$ROOT/tests/sql/fixtures/create-offer-schema.sql"
RUNTIME_FIXTURE="$ROOT/tests/sql/create-offer-runtime.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$FIXTURE" "$RUNTIME_FIXTURE" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA418 file is missing: $file"
done

[[ "$(grep -Fc "'demandId', p_demand_id" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the effective request hash must include p_demand_id exactly once"
grep -Fq 'demand_id uuid REFERENCES public.demands(id)' "$FIXTURE" ||
  fail "disposable offers fixture must retain its demand_id foreign key"
grep -Fq 'p_name, p_demand_id, p_product_master_id, p_provider_actor_id' "$MIGRATION" ||
  fail "p_demand_id must be forwarded to create_offer_v1"
grep -Fq "'50000000-0000-4000-8000-000000000001'" "$FIXTURE" ||
  fail "runtime fixture original demand is missing"
grep -Fq "'50000000-0000-4000-8000-000000000002'" "$RUNTIME_FIXTURE" ||
  fail "runtime fixture alternate demand is missing"
grep -Fq "'Fixture Demand Alternate'" "$RUNTIME_FIXTURE" ||
  fail "runtime fixture alternate demand name is missing"
grep -Fq "'published'" "$RUNTIME_FIXTURE" ||
  fail "runtime fixture alternate demand must be published"

hash_line="$(grep -nF "'demandId', p_demand_id" "$MIGRATION" | cut -d: -f1)"
reuse_line="$(grep -nF 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" | cut -d: -f1)"
insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"
[[ -n "$hash_line" && -n "$reuse_line" && -n "$insert_line" ]] ||
  fail "demand hash mapping, mismatch guard or persistence statement is missing"
(( hash_line < reuse_line && reuse_line < insert_line )) ||
  fail "p_demand_id must be hashed and compared before new execution persistence"

BLOCK="$(sed -n '/^DO \$qa418_demand_mismatch_replay\$$/,/^\$qa418_demand_mismatch_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA418 demand mismatch replay block"

for required in \
  "v_key text := 'fixture-qa418-demand-mismatch';" \
  "v_original_demand_id uuid := '50000000-0000-4000-8000-000000000001';" \
  "v_replay_demand_id uuid := '50000000-0000-4000-8000-000000000002';" \
  "WHERE id = v_original_demand_id AND demand_status = 'published'" \
  "WHERE id = v_replay_demand_id AND demand_status = 'published'" \
  "p_demand_id => v_original_demand_id" \
  "p_demand_id => v_replay_demand_id" \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
  "IF SQLERRM <> 'IDEMPOTENCY_KEY_REUSE' THEN" \
  "v_replay_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE'" \
  "v_demand_id IS DISTINCT FROM v_original_demand_id" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_idempotency_result IS DISTINCT FROM v_first_result" \
  "v_execution_input IS DISTINCT FROM v_input" \
  "v_execution_result IS DISTINCT FROM v_first_result" \
  "v_event_payload IS DISTINCT FROM v_first_result" \
  "v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count" \
  "v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count" \
  "v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count" \
  "v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count" \
  "QA418 PASS: changing only p_demand_id with the same tenant/idempotency key raises IDEMPOTENCY_KEY_REUSE and preserves the original hash, result, execution, offer and success event"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA418 runtime block is missing required assertion: $required"
done

for parameter in \
  "p_tenant_id => v_tenant_id," \
  "p_idempotency_key => v_key," \
  "p_input => v_input," \
  "p_name => v_offer_name," \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
  "p_provider_actor_id => '30000000-0000-4000-8000-000000000001'," \
  "p_quantity => 1::numeric," \
  "p_price => 12::numeric," \
  "p_currency => 'USD'," \
  "p_conditions => NULL," \
  "p_market => 'fixture-market-stable'," \
  "p_geography => NULL," \
  "p_attributes => '{}'::jsonb," \
  "p_documentation_status => NULL," \
  "p_lifecycle => NULL," \
  "p_offer_type => 'fixture-offer-type-stable'," \
  "p_pricing_model => 'fixture-pricing-model-stable'"; do
  count="$(grep -Fc -- "$parameter" <<< "$BLOCK" || true)"
  [[ "$count" -eq 2 ]] ||
    fail "QA418 must keep all non-demand effective parameters identical: $parameter (found $count)"
done

[[ "$(grep -Fc 'p_demand_id => v_original_demand_id' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA418 must pass the original demand exactly once"
[[ "$(grep -Fc 'p_demand_id => v_replay_demand_id' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA418 must pass the alternate demand exactly once"
[[ "$(grep -Fc 'p_demand_id =>' <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA418 must pass demand exactly once in each call"
[[ "$(grep -Fc 'DO $qa418_demand_mismatch_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA418 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa418_demand_mismatch_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA418 dollar-quoted block must close with the matching tag"
[[ "$(grep -Fc 'QA418 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA418 runtime marker must appear exactly once"

for required in \
  "v_after_first.idempotency_count <> 1" \
  "v_after_first.execution_count <> 1" \
  "v_after_first.offer_count <> 1" \
  "v_after_first.event_count <> 1"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA418 must assert exactly one original row in each persistence table: $required"
done

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA418 must remain a function-call regression followed by read-only persisted-state assertions"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-demand-mismatch-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA418 exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-demand-mismatch-replay.sql' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute QA418 exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-demand-mismatch-replay.sql' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute QA418 exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 fixture/bootstrap runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 fixture/bootstrap runner wiring missing"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 service image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 service image missing"
grep -Fq 'DATABASE_URL: postgresql://postgres:postgres@localhost:5432/qima_test' <<< "$pg16_job" ||
  fail "PostgreSQL 16 disposable loopback database URL missing"
grep -Fq 'DATABASE_URL: postgresql://postgres:postgres@localhost:5432/qima_test' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 disposable loopback database URL missing"

echo "QA418 static contract PASS: changing only p_demand_id with the same tenant/idempotency key is rejected before persistence and preserves the original state on PostgreSQL 16 and 17.6."
