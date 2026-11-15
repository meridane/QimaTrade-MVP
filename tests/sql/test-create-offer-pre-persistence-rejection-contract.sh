#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
SQL="$ROOT/tests/sql/create-offer-pre-persistence-rejection.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$MIGRATION" "$SQL" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA421 file is missing: $file"
done

line_of() {
  local needle="$1"
  local line
  line="$(grep -nF -- "$needle" "$MIGRATION" | head -n1 | cut -d: -f1 || true)"
  [[ -n "$line" ]] || fail "migration is missing required pre-persistence guard: $needle"
  printf '%s\n' "$line"
}

provider_guard_line="$(line_of "IF p_provider_actor_id IS DISTINCT FROM v_actor_id THEN RAISE EXCEPTION 'INVALID_PROVIDER_ACTOR'; END IF;")"
quantity_guard_line="$(line_of "IF p_quantity IS NULL OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR p_quantity <= 0 THEN")"
demand_guard_line="$(line_of "IF NOT EXISTS (SELECT 1 FROM public.demands WHERE id = p_demand_id) THEN")"
hash_line="$(line_of "v_hash := md5(jsonb_build_object(")"
lock_line="$(line_of "PERFORM pg_advisory_xact_lock(")"
insert_line="$(line_of "INSERT INTO public.action_executions(")"

(( provider_guard_line < hash_line && quantity_guard_line < hash_line && demand_guard_line < hash_line && hash_line < lock_line && lock_line < insert_line )) ||
  fail "provider, quantity and demand validation must precede hash, idempotency lock and persistence"

for required in \
  "p_idempotency_key => 'qa421-provider-actor-mismatch'" \
  "p_idempotency_key => 'qa421-invalid-quantity'" \
  "p_idempotency_key => 'qa421-missing-demand'" \
  "IF v_message IS DISTINCT FROM 'INVALID_PROVIDER_ACTOR' THEN" \
  "IF v_message IS DISTINCT FROM 'INVALID_QUANTITY' THEN" \
  "IF v_message IS DISTINCT FROM 'DEMAND_NOT_FOUND' THEN" \
  "(SELECT count(*) FROM public.idempotency_keys)" \
  "(SELECT count(*) FROM public.action_executions)" \
  "(SELECT count(*) FROM public.offers)" \
  "(SELECT count(*) FROM public.action_events)" \
  "v_before.idempotency_count" \
  "v_before.execution_count" \
  "v_before.offer_count" \
  "v_before.event_count" \
  "v_after.idempotency_count" \
  "v_after.execution_count" \
  "v_after.offer_count" \
  "v_after.event_count" \
  "IS DISTINCT FROM ROW(" \
  "QA421 PASS: provider-actor, quantity and missing-demand validation failures leave all four persistence tables unchanged"; do
  grep -Fq -- "$required" "$SQL" || fail "QA421 SQL is missing required case/assertion: $required"
done

for key in qa421-provider-actor-mismatch qa421-invalid-quantity qa421-missing-demand; do
  [[ "$(grep -Fc "$key" "$SQL" || true)" -ge 2 ]] || fail "QA421 must check both the rejected call and its absent persisted key: $key"
done

[[ "$(grep -Fc 'QA421 PASS:' "$SQL" || true)" -eq 1 ]] || fail "QA421 runtime marker must appear exactly once"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' "$SQL"; then
  fail "QA421 SQL must use the RPC and read-only assertions, not direct DML or schema changes"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-pre-persistence-rejection-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA421 static contract exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-pre-persistence-rejection.sql' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 must execute QA421 runtime exactly once"
[[ "$(grep -Fc 'run: psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/create-offer-pre-persistence-rejection.sql' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 must execute QA421 runtime exactly once"
grep -Fq 'image: postgres:16' <<< "$pg16_job" || fail "PostgreSQL 16 service image is missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" || fail "PostgreSQL 17.6 service image is missing"

echo "QA421 static contract PASS: pre-persistence validation failures are rejected before hash/idempotency writes and preserve all four persistence tables on PostgreSQL 16 and 17.6."
