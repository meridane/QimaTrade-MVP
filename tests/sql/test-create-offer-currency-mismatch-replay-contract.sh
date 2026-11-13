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
  [[ -f "$file" ]] || fail "required QA394 file is missing: $file"
done

currency_hash_line="$(grep -nF "'currency', p_currency," "$MIGRATION" | cut -d: -f1)"
reuse_line="$(grep -nF 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" | cut -d: -f1)"
reuse_error_line="$(grep -nF "RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE';" "$MIGRATION" | cut -d: -f1)"
execution_insert_line="$(grep -nF 'INSERT INTO public.action_executions(' "$MIGRATION" | cut -d: -f1)"

[[ "$(grep -Fc "'currency', p_currency," "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the complete request hash must include p_currency exactly once"
[[ "$(grep -Fc "p_currency NOT IN ('USD', 'EUR', 'KRW', 'MAD', 'CNY')" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the existing currency domain must continue to allow both USD and EUR"
[[ "$(grep -Fc 'IF v_existing.request_hash <> v_hash THEN' "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the existing request-hash mismatch guard must remain unique"
[[ "$(grep -Fc "RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSE';" "$MIGRATION" || true)" -eq 1 ]] ||
  fail "the exact IDEMPOTENCY_KEY_REUSE error must remain unique"
[[ -n "$currency_hash_line" && -n "$reuse_line" && -n "$reuse_error_line" && -n "$execution_insert_line" ]] ||
  fail "currency hash, mismatch guard or persistence statements are missing"
(( currency_hash_line < reuse_line && reuse_line < reuse_error_line && reuse_error_line < execution_insert_line )) ||
  fail "currency must be hashed and mismatches rejected before new action execution persistence"

BLOCK="$(sed -n '/^DO \$qa394_currency_mismatch_replay\$$/,/^\$qa394_currency_mismatch_replay\$;/p' "$RUNTIME")"
[[ -n "$BLOCK" ]] || fail "runtime is missing the QA394 currency mismatch replay block"

for required in \
  "v_key text := 'fixture-qa394-currency-mismatch';" \
  "p_quantity => 1::numeric," \
  "p_price => 12::numeric," \
  "p_currency => 'USD'," \
  "p_currency => 'EUR'," \
  "IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN" \
  "request_hash = v_original_hash" \
  "result = v_first_result" \
  "status = 'COMPLETED'" \
  "quantity = 1::numeric" \
  "price = 12::numeric" \
  "currency = 'USD'" \
  "FROM public.idempotency_keys" \
  "FROM public.action_executions" \
  "FROM public.offers" \
  "FROM public.action_events" \
  "v_after_replay.idempotency_count" \
  "v_after_first.idempotency_count" \
  "QA394 PASS: changing a completed USD request to EUR with the same tenant/key raises IDEMPOTENCY_KEY_REUSE"; do
  grep -Fq -- "$required" <<< "$BLOCK" ||
    fail "QA394 runtime block is missing required assertion: $required"
done

[[ "$(grep -Fc "p_quantity => 1::numeric," <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA394 must keep quantity identical in both calls"
[[ "$(grep -Fc "p_price => 12::numeric," <<< "$BLOCK" || true)" -eq 2 ]] ||
  fail "QA394 must keep price identical in both calls"
[[ "$(grep -Fc "p_currency => 'USD'," <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA394 must have exactly one original USD call"
[[ "$(grep -Fc "p_currency => 'EUR'," <<< "$BLOCK" || true)" -eq 1 ]] ||
  fail "QA394 must have exactly one changed EUR replay"
[[ "$(grep -Fc 'DO $qa394_currency_mismatch_replay$' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA394 runtime block must appear exactly once"
[[ "$(grep -Fc 'QA394 PASS:' "$RUNTIME" || true)" -eq 1 ]] ||
  fail "QA394 runtime marker must appear exactly once"

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)([[:space:]]|;)' \
  <(sed '/^[[:space:]]*--/d' <<< "$BLOCK"); then
  fail "QA394 must remain a function-call regression followed by read-only persisted-state assertions"
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

[[ "$(grep -Fc 'run: bash tests/sql/test-create-offer-currency-mismatch-replay-contract.sh' <<< "$verify_job" || true)" -eq 1 ]] ||
  fail "Verify must execute QA394 exactly once"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg16_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 16 shared runtime runner wiring missing"
[[ "$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" || true)" -eq 1 ]] ||
  fail "PostgreSQL 17.6 shared runtime runner wiring missing"
grep -Fq 'image: postgres:16' <<< "$pg16_job" ||
  fail "PostgreSQL 16 service image missing"
grep -Fq 'image: postgres:17.6' <<< "$pg17_job" ||
  fail "PostgreSQL 17.6 service image missing"

echo "QA394 PASS: changing a completed USD request to EUR cannot reuse the same tenant/key; the exact mismatch error and original four-table persisted state are protected on PostgreSQL 16 and 17.6."
