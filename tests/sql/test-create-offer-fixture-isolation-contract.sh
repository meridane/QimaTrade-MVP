#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SQL_FILE="$ROOT/tests/sql/create-offer-runtime.sql"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in "$SQL_FILE" "$RUNNER" "$WORKFLOW"; do
  [[ -f "$file" ]] || fail "required fixture-isolation file is missing: $file"
done

extract_block() {
  local tag="$1"
  local output="$2"

  awk -v tag="$tag" -v output="$output" '
    $0 == "DO $" tag "$" {
      started = 1
      print > output
      next
    }
    started {
      print > output
    }
    started && $0 == "$" tag "$;" {
      ended = 1
      exit
    }
    END {
      if (output != "") close(output)
      if (!started || !ended) exit 2
    }
  ' "$SQL_FILE" || fail "could not extract complete DO block $tag"
}

extract_block qa73_seed "$TMP_DIR/qa73_seed.sql"
extract_block qa73_assert "$TMP_DIR/qa73_assert.sql"
extract_block qa74_seed "$TMP_DIR/qa74_seed.sql"
extract_block qa74_assert "$TMP_DIR/qa74_assert.sql"
extract_block qa75_seed "$TMP_DIR/qa75_seed.sql"
extract_block qa75_assert "$TMP_DIR/qa75_assert.sql"

assert_seed() {
  local tag="$1"
  local file="$2"
  local expected_uuid_count="$3"
  shift 3
  local expected_key_count="$#"
  local actual_uuid_count
  local actual_key_count
  local key
  local key_count

  actual_uuid_count="$(grep -Ec '^[[:space:]]+[[:alnum:]_]+ uuid := gen_random_uuid\(\);$' "$file" || true)"
  [[ "$actual_uuid_count" -eq "$expected_uuid_count" ]] ||
    fail "$tag must generate $expected_uuid_count distinct record/correlation UUID values, found $actual_uuid_count"

  [[ "$(grep -Fxc '  v_tenant_id uuid := '\''10000000-0000-4000-8000-000000000001'\'';' "$file" || true)" -eq 1 ]] ||
    fail "$tag must use the shared disposable tenant fixture exactly once"
  [[ "$(grep -Fxc '  v_actor_id uuid := '\''30000000-0000-4000-8000-000000000001'\'';' "$file" || true)" -eq 1 ]] ||
    fail "$tag must use the shared disposable actor fixture exactly once"
  grep -Fq 'INSERT INTO public.action_executions(' "$file" ||
    fail "$tag must seed its own action execution"
  grep -Fq 'INSERT INTO public.idempotency_keys(' "$file" ||
    fail "$tag must seed its own idempotency record"
  grep -Fq 'INSERT INTO public.offers(' "$file" ||
    fail "$tag must seed its own offer"
  grep -Fq 'INSERT INTO public.action_events(' "$file" ||
    fail "$tag must seed its own success event"

  actual_key_count="$(grep -Eo "'fixture-[a-z0-9-]+-completed'" "$file" | tr -d "'" | sort -u | wc -l | tr -d ' ' || true)"
  [[ "$actual_key_count" -eq "$expected_key_count" ]] ||
    fail "$tag must contain exactly $expected_key_count distinct idempotency fixture key(s), found $actual_key_count"

  for key in "$@"; do
    key_count="$(grep -Fc "$key" "$file" || true)"
    [[ "$key_count" -eq 2 ]] ||
      fail "$tag must use $key exactly once for action_executions and once for idempotency_keys; found $key_count occurrences"
  done
}

assert_assertion() {
  local tag="$1"
  local file="$2"
  shift 2
  local key

  grep -Fq "WHERE tenant_id = '10000000-0000-4000-8000-000000000001'" "$file" ||
    fail "$tag must scope persisted-state assertions to the shared disposable tenant"

  for key in "$@"; do
    grep -Fq "$key" "$file" ||
      fail "$tag is missing its matching seed key $key"
  done
}

key73="fixture-jsonb-numeric-scale-completed"
key74_quantity="fixture-typed-quantity-scale-completed"
key74_price="fixture-typed-price-scale-completed"
key75="fixture-nested-attributes-numeric-scale-completed"

all_keys="$(printf '%s\n' "$key73" "$key74_quantity" "$key74_price" "$key75")"
unique_key_count="$(printf '%s\n' "$all_keys" | sort -u | wc -l | tr -d ' ')"
[[ "$unique_key_count" -eq 4 ]] ||
  fail "QA73/QA74/QA75 must define four distinct idempotency keys, found $unique_key_count"

assert_seed qa73_seed "$TMP_DIR/qa73_seed.sql" 3 "$key73"
assert_seed qa74_seed "$TMP_DIR/qa74_seed.sql" 6 "$key74_quantity" "$key74_price"
assert_seed qa75_seed "$TMP_DIR/qa75_seed.sql" 3 "$key75"

assert_assertion qa73_assert "$TMP_DIR/qa73_assert.sql" "$key73"
assert_assertion qa74_assert "$TMP_DIR/qa74_assert.sql" "$key74_quantity" "$key74_price"
assert_assertion qa75_assert "$TMP_DIR/qa75_assert.sql" "$key75"

for key in "$key73" "$key74_quantity" "$key74_price" "$key75"; do
  runtime_count="$(grep -Fo "$key" "$SQL_FILE" | wc -l | tr -d ' ')"
  dedicated_count=0
  for block_file in "$TMP_DIR"/qa73_seed.sql "$TMP_DIR"/qa73_assert.sql \
                    "$TMP_DIR"/qa74_seed.sql "$TMP_DIR"/qa74_assert.sql \
                    "$TMP_DIR"/qa75_seed.sql "$TMP_DIR"/qa75_assert.sql; do
    block_count="$(grep -Fo "$key" "$block_file" | wc -l | tr -d ' ' || true)"
    dedicated_count=$((dedicated_count + block_count))
  done
  [[ "$runtime_count" -eq "$dedicated_count" ]] ||
    fail "$key is reused outside its dedicated QA73/QA74/QA75 seed/assertion blocks"
  if grep -Fq "$key" "$RUNNER"; then
    fail "$key must not collide with a runner-level idempotency key"
  fi
done

runtime_call_line="$(grep -nF -m 1 'create-offer-runtime.sql' "$RUNNER" | cut -d: -f1)"
numeric_call_line="$(grep -nF -m 1 'idempotency-numeric-lexical-characterization.sql' "$RUNNER" | cut -d: -f1)"
guard_line="$(grep -nF -m 1 'if [[ ! "$DATABASE_URL"' "$RUNNER" | cut -d: -f1)"
first_fixture_call_line="$(grep -nF -m 1 'create-offer-schema.sql' "$RUNNER" | cut -d: -f1)"

[[ -n "$runtime_call_line" && -n "$numeric_call_line" && -n "$guard_line" && -n "$first_fixture_call_line" ]] ||
  fail "runner must retain the loopback database guard and both fixture calls"
[[ "$runtime_call_line" -lt "$numeric_call_line" ]] ||
  fail "runtime fixture must execute before the numeric lexical characterization"
[[ "$guard_line" -lt "$first_fixture_call_line" ]] ||
  fail "loopback qima_test guard must execute before the first PostgreSQL connection"
[[ "$(grep -Fc 'create-offer-runtime.sql' "$RUNNER")" -eq 1 ]] ||
  fail "runner must execute create-offer-runtime.sql exactly once"

workflow_runner_count="$(grep -Fc 'run: bash tests/sql/run-create-offer-integration.sh' "$WORKFLOW")"
[[ "$workflow_runner_count" -eq 2 ]] ||
  fail "workflow must run the isolated integration runner exactly once on PostgreSQL 16 and once on PostgreSQL 17.6"

pg17_job="$(awk '
  $0 == "  postgres17-create-offer-compatibility:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
pg17_guard_line="$(grep -nF 'assert-postgres-17-6-version.sh' <<< "$pg17_job" | cut -d: -f1)"
pg17_runner_line="$(grep -nF 'run: bash tests/sql/run-create-offer-integration.sh' <<< "$pg17_job" | cut -d: -f1)"
[[ -n "$pg17_guard_line" && -n "$pg17_runner_line" && "$pg17_guard_line" -lt "$pg17_runner_line" ]] ||
  fail "PostgreSQL 17.6 version guard must precede the integration runner"

verify_job="$(awk '
  $0 == "  verify:" { inside = 1; next }
  inside && /^  [[:alnum:]_-]+:$/ { exit }
  inside { print }
' "$WORKFLOW")"
grep -Fq 'run: bash tests/sql/test-create-offer-fixture-isolation-contract.sh' <<< "$verify_job" ||
  fail "Verify job does not run the QA362 fixture-isolation contract"

echo "QA362 PASS: QA73/QA74/QA75 share only the intended disposable tenant/actor, use four unique fixture keys and twelve generated UUIDs, have no key collisions outside their blocks, and run once on guarded PostgreSQL 16/17.6 services."
