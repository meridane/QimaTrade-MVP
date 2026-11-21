#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-provider-actor-guard-replay.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
FIXTURE="$ROOT/tests/sql/fixtures/create-offer-schema.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$FIXTURE" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA419 file is missing: $file"
done

profile_line="$(grep -nF 'WHERE auth_user_id = v_user_id' "$MIGRATION" | cut -d: -f1)"
guard_line="$(grep -nF "IF p_provider_actor_id IS DISTINCT FROM v_actor_id THEN RAISE EXCEPTION 'INVALID_PROVIDER_ACTOR'; END IF;" "$MIGRATION" | cut -d: -f1)"
hash_line="$(grep -nF "'providerActorId', p_provider_actor_id" "$MIGRATION" | cut -d: -f1)"
lookup_line="$(grep -nF 'SELECT * INTO v_existing' "$MIGRATION" | cut -d: -f1)"
insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"
[[ -n "$profile_line" && -n "$guard_line" && -n "$hash_line" && -n "$lookup_line" && -n "$insert_line" ]] ||
  fail "provider actor profile lookup, guard, hash, idempotency lookup or persistence statement is missing"
[[ "$(grep -Fc "IF p_provider_actor_id IS DISTINCT FROM v_actor_id THEN RAISE EXCEPTION 'INVALID_PROVIDER_ACTOR'; END IF;" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "provider actor identity guard must appear exactly once"
[[ "$(grep -Fc "'providerActorId', p_provider_actor_id" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "effective request hash must include p_provider_actor_id exactly once"
(( profile_line < guard_line && guard_line < hash_line && hash_line < lookup_line && lookup_line < insert_line )) ||
  fail "authenticated actor guard must run before hashing/idempotency lookup and before persistence"

grep -Fq "'30000000-0000-4000-8000-000000000001','Fixture Provider A'" "$FIXTURE" ||
  fail "authenticated provider actor A fixture is missing"
grep -Fq "'30000000-0000-4000-8000-000000000002','Fixture Provider B'" "$FIXTURE" ||
  fail "alternate provider actor B fixture is missing"

grep -Fq "SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';" "$RUNTIME" ||
  fail "runtime must authenticate as provider actor A"
grep -Fq 'SET ROLE authenticated;' "$RUNTIME" ||
  fail "runtime must execute the wrapper as authenticated"

BLOCK="$(sed -n '/^DO \$qa419_provider_actor_guard_replay\$$/,/^\$qa419_provider_actor_guard_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA419 provider actor guard replay block"

for required in \
  "v_key text := 'fixture-qa419-provider-actor-guard-replay';" \
  "v_authenticated_actor_id uuid := '30000000-0000-4000-8000-000000000001';" \
  "v_mismatched_actor_id uuid := '30000000-0000-4000-8000-000000000002';" \
  "p_provider_actor_id => v_authenticated_actor_id," \
  "p_provider_actor_id => v_mismatched_actor_id," \
  "IF SQLERRM <> 'INVALID_PROVIDER_ACTOR' THEN" \
  "v_replay_error IS DISTINCT FROM 'INVALID_PROVIDER_ACTOR'" \
  "v_idempotency_actor_id IS DISTINCT FROM v_authenticated_actor_id" \
  "v_execution_actor_id IS DISTINCT FROM v_authenticated_actor_id" \
  "v_offer_provider_actor_id IS DISTINCT FROM v_authenticated_actor_id" \
  "v_event_actor_id IS DISTINCT FROM v_authenticated_actor_id" \
  "v_replay_hash IS DISTINCT FROM v_original_hash" \
  "v_idempotency_result IS DISTINCT FROM v_first_result" \
  "v_execution_result IS DISTINCT FROM v_first_result" \
  "v_event_payload IS DISTINCT FROM v_first_result" \
  "v_after_replay.idempotency_count IS DISTINCT FROM v_after_first.idempotency_count" \
  "v_after_replay.execution_count IS DISTINCT FROM v_after_first.execution_count" \
  "v_after_replay.offer_count IS DISTINCT FROM v_after_first.offer_count" \
  "v_after_replay.event_count IS DISTINCT FROM v_after_first.event_count" \
  "QA419 PASS: a mismatched p_provider_actor_id is rejected as INVALID_PROVIDER_ACTOR before idempotency lookup and preserves the completed original state"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA419 runtime block is missing required assertion: $required"
done

for parameter in \
  "p_tenant_id => v_tenant_id," \
  "p_idempotency_key => v_key," \
  "p_input => v_input," \
  "p_name => v_offer_name," \
  "p_demand_id => '50000000-0000-4000-8000-000000000001'," \
  "p_product_master_id => '40000000-0000-4000-8000-000000000001'," \
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
    fail "QA419 must keep all non-provider-actor parameters identical: $parameter (found $count)"
done

[[ "$(grep -Fc 'p_provider_actor_id => v_authenticated_actor_id' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA419 must pass authenticated provider actor A exactly once"
[[ "$(grep -Fc 'p_provider_actor_id => v_mismatched_actor_id' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA419 must pass alternate provider actor B exactly once"
[[ "$(grep -Fc 'p_provider_actor_id =>' <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA419 must pass provider actor exactly once in each call"
[[ "$(grep -Fc 'DO $qa419_provider_actor_guard_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA419 runtime block must appear exactly once"
[[ "$(grep -Fc '$qa419_provider_actor_guard_replay$;' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA419 dollar-quoted block must close with the matching tag"
[[ "$(grep -Fc 'QA419 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA419 runtime marker must appear exactly once"

for required in \
  "v_after_first.idempotency_count <> 1" \
  "v_after_first.execution_count <> 1" \
  "v_after_first.offer_count <> 1" \
  "v_after_first.event_count <> 1"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA419 must assert exactly one original row in each persistence table: $required"
done

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA419 must remain a function-call regression followed by read-only persisted-state assertions"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-provider-actor-guard-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA419 exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-provider-actor-guard-replay.sql' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute QA419 exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-provider-actor-guard-replay.sql' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute QA419 exactly once"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 service image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 service image missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 fixture/bootstrap runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 fixture/bootstrap runner wiring missing"

echo "QA419 static contract PASS: a mismatched provider actor is rejected before idempotency lookup and preserves the original completed state on PostgreSQL 16 and 17.6."
