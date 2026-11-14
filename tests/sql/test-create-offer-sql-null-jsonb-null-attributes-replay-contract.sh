#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
FIXTURE="$ROOT/tests/sql/fixtures/create-offer-schema.sql"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$FIXTURE" "$RUNNER" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA401 file is missing: $file"
done

[[ "$(grep -Fc "'attributes', coalesce(p_attributes, '{}'::jsonb)" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the request hash must normalize SQL NULL p_attributes to an empty JSONB object exactly once"
grep -Fq "coalesce(p_attributes,'{}'::jsonb)" "$FIXTURE" ||
  fail "the disposable create_offer_v1 fixture must persist SQL NULL attributes as an empty JSONB object"

hash_line="$(grep -nF "'attributes', coalesce(p_attributes, '{}'::jsonb)" "$MIGRATION" | cut -d: -f1)"
reuse_line="$(grep -nF 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" | cut -d: -f1)"
insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"
[[ -n "$hash_line" && -n "$reuse_line" && -n "$insert_line" ]] ||
  fail "attributes hash, mismatch guard or persistence statement is missing"
(( hash_line < reuse_line && reuse_line < insert_line )) ||
  fail "attributes must be normalized and compared before new execution persistence"

[[ "$(grep -Fc 'fixtures/create-offer-schema.sql' "$RUNNER" || true)" -eq 1 ]] ||
  fail "the isolated integration runner must load the inspected disposable schema fixture"

BLOCK="$(sed -n '/^DO \$qa401_sql_null_jsonb_null_attributes_replay\$$/,/^\$qa401_sql_null_jsonb_null_attributes_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA401 SQL NULL/JSONB literal null replay block"

for required in \
  "v_key text := 'fixture-qa401-sql-null-jsonb-null';" \
  "v_attributes jsonb := NULL::jsonb;" \
  "v_replay_attributes jsonb := 'null'::jsonb;" \
  "v_replay_error text;" \
  "coalesce(v_attributes, '{}'::jsonb) IS NOT DISTINCT FROM coalesce(v_replay_attributes, '{}'::jsonb)" \
  "coalesce(v_attributes, '{}'::jsonb)::text IS NOT DISTINCT FROM coalesce(v_replay_attributes, '{}'::jsonb)::text" \
  "jsonb_typeof(v_replay_attributes) IS DISTINCT FROM 'null'" \
  "p_attributes => v_attributes" \
  "p_attributes => v_replay_attributes" \
  "IF SQLERRM <> 'IDEMPOTENCY_KEY_REUSE' THEN" \
  "v_replay_error := SQLERRM;" \
  "v_replay_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE'" \
  "v_offer_attributes IS DISTINCT FROM '{}'::jsonb" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_idempotency_result IS DISTINCT FROM v_first_result" \
  "v_execution_input IS DISTINCT FROM v_input" \
  "v_execution_result IS DISTINCT FROM v_first_result" \
  "v_event_payload IS DISTINCT FROM v_first_result" \
  "v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count" \
  "v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count" \
  "v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count" \
  "v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count" \
  "QA401 PASS: SQL NULL normalizes to an empty object while JSONB literal null remains distinct, so replay is rejected without changing the original persisted state"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA401 runtime block is missing required assertion: $required"
done

for declaration in \
  "v_attributes jsonb :=" \
  "v_replay_attributes jsonb :=" \
  "v_replay_error text;"; do
  [[ "$(grep -Fc "$declaration" <<< "$BLOCK" || true)" -eq 1 ]] ||
    fail "QA401 must declare exactly one value for $declaration"
done

[[ "$(grep -Fc 'p_attributes => v_attributes' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA401 original SQL NULL attributes must be passed exactly once"
[[ "$(grep -Fc 'p_attributes => v_replay_attributes' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA401 JSONB literal null replay attributes must be passed exactly once"
[[ "$(grep -Fc 'DO $qa401_sql_null_jsonb_null_attributes_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA401 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa401_sql_null_jsonb_null_attributes_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA401 dollar-quoted block must close with the matching tag"
[[ "$(grep -Fc 'QA401 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA401 runtime marker must appear exactly once"

for required in \
  "v_after_first.idempotency_count <> 1" \
  "v_after_first.execution_count <> 1" \
  "v_after_first.offer_count <> 1" \
  "v_after_first.event_count <> 1"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA401 must assert exactly one original row in each scoped persistence table: $required"
done

for expression in \
  "p_tenant_id => v_tenant_id," \
  "p_idempotency_key => v_key," \
  "p_input => v_input," \
  "p_name => v_offer_name," \
  "p_demand_id => '50000000-0000-4000-8000-000000000001'," \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
  "p_provider_actor_id => '30000000-0000-4000-8000-000000000001'," \
  "p_quantity => 1::numeric," \
  "p_price => 12::numeric," \
  "p_currency => 'USD',"; do
  count="$(grep -Fc "$expression" <<< "$BLOCK" || true)"
  [[ "$count" -eq 2 ]] ||
    fail "QA401 must keep all non-attributes effective parameters identical: $expression (found $count)"
done

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA401 must remain a function-call regression followed by read-only persisted-state assertions"
fi

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-sql-null-jsonb-null-attributes-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA401 exactly once"

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

echo "QA401 static contract PASS: SQL NULL attributes normalize to an empty object while JSONB literal null remains distinct and rejects same-key replay without changing persisted state on PostgreSQL 16 and 17.6."
