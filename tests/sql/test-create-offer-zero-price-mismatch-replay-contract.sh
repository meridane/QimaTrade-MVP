#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME="$ROOT/tests/sql/create-offer-runtime.sql"
MIGRATION="$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$RUNTIME" "$MIGRATION" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required QA392 file is missing: $file"
done

price_hash_line="$(grep -nF "'price', p_price," "$MIGRATION" | cut -d: -f1)"
reuse_line="$(grep -nF 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" | cut -d: -f1)"
reuse_error_line="$(grep -nF "RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE';" "$MIGRATION" | cut -d: -f1)"
execution_insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"

[[ "$(grep -Fc "'price', p_price," "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the complete request hash must include p_price exactly once"
[[ "$(grep -Fc 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the existing request-hash mismatch guard must remain unique"
[[ "$(grep -Fc "RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE';" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the exact IDEMPOTENCY_KEY_REUSE error must remain unique"
[[ -n "$price_hash_line" && -n "$reuse_line" && -n "$reuse_error_line" && -n "$execution_insert_line" ]] ||
  fail "request-hash, mismatch or persistence statements are missing"
(( price_hash_line < reuse_line && reuse_line < reuse_error_line && reuse_error_line < execution_insert_line )) ||
  fail "price must be hashed and mismatches rejected before new action execution persistence"

BLOCK="$(sed -n '/^DO \$qa392_zero_price_mismatch_replay\$$/,/^\$qa392_zero_price_mismatch_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA392 zero-price mismatch replay block"

for required in \
  "v_key text := 'fixture-qa392-zero-price-mismatch';" \
  "p_price => 0::numeric," \
  "p_price => 1::numeric," \
  "IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN" \
  "request_hash = v_original_hash" \
  "result = v_first_result" \
  "status = 'COMPLETED'" \
  "price = 0::numeric" \
  "FROM public.idempotency_keys" \
  "FROM public.action_executions" \
  "FROM public.offers" \
  "FROM public.action_events" \
  "v_after_replay.idempotency_count" \
  "v_after_first.idempotency_count" \
  "QA392 PASS: changing a completed zero-price request to a positive price with the same tenant/key raises IDEMPOTENCY_KEY_REUSE"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA392 runtime block is missing required assertion: $required"
done

[[ "$(grep -Fc 'p_price => 0::numeric,' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA392 must create exactly one original zero-price request"
[[ "$(grep -Fc 'p_price => 1::numeric,' <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA392 must make exactly one changed-price replay attempt"
[[ "$(grep -Fc 'DO $qa392_zero_price_mismatch_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA392 runtime block must appear exactly once"
[[ "$(grep -Fc 'QA392 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA392 runtime marker must appear exactly once"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA392 must remain a function-call regression followed by read-only persisted-state assertions"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-zero-price-mismatch-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA392 exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 shared runtime runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 shared runtime runner wiring missing"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 service image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 service image missing"

echo "QA392 PASS: a changed positive price cannot reuse a completed zero-price tenant/key request; the exact mismatch error and original four-table persisted state are protected on PostgreSQL 16 and 17.6."
