#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SQL_FILE="$ROOT/tests/sql/create-offer-runtime.sql"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$SQL_FILE" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required numeric replay contract file is missing: $file"
done

extract_replay_segments() {
  local tag="$1"
  local expected="$2"
  local actual=0
  local file

  awk -v tag="$tag" -v output_dir="$TMP_DIR" '
    $0 == "DO $" tag "$" {
      in_block = 1
      next
    }
    in_block && $0 == "$" tag "$;" {
      if (output != "") close(output)
      exit
    }
    in_block && $0 ~ /^[[:space:]]*v_error := NULL;[[:space:]]*$/ {
      if (output != "") close(output)
      segment++
      output = output_dir "/" tag "-" segment ".sql"
    }
    in_block && segment > 0 {
      print >> output
    }
    END {
      if (output != "") close(output)
      if (!in_block) exit 2
    }
  ' "$SQL_FILE" || fail "could not extract DO block $tag"

  for file in "$TMP_DIR/$tag"-*.sql; do
    [[ -f "$file" ]] || continue
    actual=$((actual + 1))
  done

  [[ "$actual" -eq "$expected" ]] ||
    fail "$tag must retain $expected replay assertion segment(s), found $actual"
}

assert_replay_segment() {
  local tag="$1"
  local label="$2"
  local file="$3"
  local replay_check_line
  local first_idempotency_line
  local count_checks

  [[ "$(grep -Fc 'public.execute_create_offer_v1(' "$file")" -eq 1 ]] ||
    fail "$label must contain exactly one replay call"
  grep -Fq 'EXCEPTION WHEN OTHERS THEN' "$file" ||
    fail "$label must capture the replay exception"
  grep -Fq 'v_error := SQLERRM;' "$file" ||
    fail "$label must retain the replay error message"
  grep -Fq "IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN" "$file" ||
    fail "$label must require IDEMPOTENCY_KEY_REUSE"

  replay_check_line="$(grep -nF "IF v_error IS DISTINCT FROM 'IDEMPOTENCY_KEY_REUSE' THEN" "$file" | head -n 1 | cut -d: -f1)"
  first_idempotency_line="$(grep -nF 'FROM public.idempotency_keys' "$file" | head -n 1 | cut -d: -f1)"
  [[ -n "$replay_check_line" && -n "$first_idempotency_line" ]] ||
    fail "$label must verify persisted state after the rejected replay"
  (( replay_check_line < first_idempotency_line )) ||
    fail "$label must check the replay error before checking persisted state"

  for table in idempotency_keys action_executions offers action_events; do
    grep -Fq "FROM public.$table" "$file" ||
      fail "$label is missing its post-replay $table assertion"
  done

  for field in request_hash execution_id result; do
    grep -Fq "$field" "$file" ||
      fail "$label idempotency assertion is missing $field"
  done

  for field in "status = 'COMPLETED'" input result object_id; do
    grep -Fq "$field" "$file" ||
      fail "$label execution assertion is missing $field"
  done

  for field in "name =" "quantity =" "price =" "currency =" "attributes ="; do
    grep -Fq "$field" "$file" ||
      fail "$label offer assertion is missing $field"
  done

  for field in "event_type = 'ACTION_SUCCEEDED'" "object_type = 'Offer'" "object_id =" "payload ="; do
    grep -Fq "$field" "$file" ||
      fail "$label success-event assertion is missing $field"
  done

  count_checks="$(grep -Ec '^[[:space:]]*IF v_count <> 1 THEN' "$file" || true)"
  [[ "$count_checks" -ge 4 ]] ||
    fail "$label must retain at least four exact-one persisted-state checks, found $count_checks"

  if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|CALL|COPY)([[:space:]]|;)'     <(sed '/^[[:space:]]*--/d' "$file"); then
    fail "$label must remain a replay call followed by read-only state assertions"
  fi
}

extract_replay_segments qa73_assert 1
extract_replay_segments qa74_assert 2
extract_replay_segments qa75_assert 1

assert_replay_segment qa73_assert "OFFER-QA-73 JSONB numeric-scale replay" "$TMP_DIR/qa73_assert-1.sql"
assert_replay_segment qa74_assert "OFFER-QA-74 typed quantity-scale replay" "$TMP_DIR/qa74_assert-1.sql"
assert_replay_segment qa74_assert "OFFER-QA-74 typed price-scale replay" "$TMP_DIR/qa74_assert-2.sql"
assert_replay_segment qa75_assert "OFFER-QA-75 nested attributes replay" "$TMP_DIR/qa75_assert-1.sql"

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"

grep -Fq 'run: bash tests/sql/test-create-offer-numeric-replay-contract.sh' <<< "$verify_job" ||
  fail "Verify job does not run the QA361 persisted-state contract test"

echo "QA361 PASS: all four rejected numeric replay paths retain exact-one idempotency, execution, offer, and ACTION_SUCCEEDED state assertions."
