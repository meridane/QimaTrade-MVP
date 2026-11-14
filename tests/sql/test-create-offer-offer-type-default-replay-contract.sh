#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
FIXTURE="$ROOT/tests/sql/fixtures/create-offer-schema.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$FIXTURE" "$WORKFLOW" "$RUNNER"; do
  [[ -f "$file" ]] || fail "required QA416 file is missing: $file"
done

[[ "$(grep -Fc "p_offer_type text DEFAULT NULL::text" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the existing function signature must declare the p_offer_type NULL default exactly once"
[[ "$(grep -Fc "'offerType', p_offer_type" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the effective request hash must include p_offer_type exactly once"
grep -Fq 'offer_type text' "$FIXTURE" ||
  fail "disposable offers fixture must expose offer_type text"
grep -Fq 'p_attributes, p_documentation_status, p_lifecycle, p_offer_type, p_pricing_model' "$MIGRATION" ||
  fail "p_offer_type must be forwarded to the low-level create_offer_v1 call"

hash_line="$(grep -nF "'offerType', p_offer_type" "$MIGRATION" | cut -d: -f1)"
reuse_line="$(grep -nF 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" | cut -d: -f1)"
insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"
[[ -n "$hash_line" && -n "$reuse_line" && -n "$insert_line" ]] ||
  fail "offer-type hash mapping, mismatch guard or persistence statement is missing"
(( hash_line < reuse_line && reuse_line < insert_line )) ||
  fail "p_offer_type must be hashed and compared before new execution persistence"

BLOCK="$(sed -n '/^DO \$qa416_offer_type_default_replay\$$/,/^\$qa416_offer_type_default_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA416 omitted-offer-type replay block"
[[ "$(grep -Fc 'public.execute_create_offer_v1(' <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA416 must contain exactly one initial CREATE_OFFER call and one replay"

FIRST_CALL="$(sed -n '/v_first_result := public.execute_create_offer_v1(/,/^  );/p' <<< "$BLOCK")"
REPLAY_CALL="$(sed -n '/v_replay_result := public.execute_create_offer_v1(/,/^  );/p' <<< "$BLOCK")"
[[ -n "$FIRST_CALL" && -n "$REPLAY_CALL" ]] ||
  fail "QA416 must contain both bounded CREATE_OFFER calls"
if grep -Fq 'p_offer_type =>' <<< "$FIRST_CALL"; then
  fail "the first QA416 call must omit p_offer_type so PostgreSQL applies its declared default"
fi
[[ "$(grep -Fc 'p_offer_type => NULL' <<< "$REPLAY_CALL" || true)" -eq 1 ]] ||
  fail "the QA416 replay must explicitly supply the declared NULL default exactly once"
[[ "$(grep -Fc 'p_offer_type =>' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "only the explicit QA416 replay may supply p_offer_type"

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
  "p_market => 'fixture-market-stable'," \
  "p_geography => NULL," \
  "p_attributes => '{}'::jsonb," \
  "p_documentation_status => NULL," \
  "p_lifecycle => NULL," \
  "p_pricing_model => 'fixture-pricing-model-stable'"; do
  count="$(grep -Fc -- "$parameter" <<< "$BLOCK" || true)"
  [[ "$count" -eq 2 ]] ||
    fail "all non-offer-type effective parameters must remain identical: $parameter (found $count)"
done

for required in \
  "v_replay_result IS DISTINCT FROM v_first_result" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_idempotency_status IS DISTINCT FROM 'COMPLETED'" \
  "v_idempotency_result IS DISTINCT FROM v_first_result" \
  "v_execution_status IS DISTINCT FROM 'COMPLETED'" \
  "v_execution_result IS DISTINCT FROM v_first_result" \
  "v_offer_type IS NOT NULL" \
  "v_event_payload IS DISTINCT FROM v_first_result" \
  "v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count" \
  "v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count" \
  "v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count" \
  "v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count" \
  "QA416 PASS: omitting p_offer_type applies the declared NULL::text default and exactly replays an explicit NULL request without duplicate persisted state"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA416 is missing a required default/replay/persisted-state assertion: $required"
done

for required in \
  "v_after_first.idempotency_count <> 1" \
  "v_after_first.execution_count <> 1" \
  "v_after_first.offer_count <> 1" \
  "v_after_first.event_count <> 1"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA416 must assert exactly one original row in each persistence table: $required"
done

[[ "$(grep -Fc 'DO $qa416_offer_type_default_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA416 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa416_offer_type_default_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA416 dollar-quoted block must close exactly once"
[[ "$(grep -Fc 'QA416 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA416 runtime marker must appear exactly once"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA416 must remain a function-call regression followed by read-only persisted-state assertions"
fi

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-offer-type-default-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA416 exactly once"

[[ "$(grep -Fc '      - name: Verify CREATE_OFFER omitted p_offer_type default replays explicit NULL' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must expose QA416 as its own named step, not as a duplicate run key"

pg16_job="$(awk '
  $0 == "  postgres-integration:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
pg17_job="$(awk '
  $0 == "  postgres17-create-offer-compatibility:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 integration runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 integration runner wiring missing"

echo "QA416 static contract PASS: omitting p_offer_type applies the declared NULL::text default and exactly replays an explicit NULL request without duplicate persisted state."
