#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"
RUNTIME="$ROOT/tests/sql/test-create-offer-preflight-privilege-visibility-runtime.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
REGISTER="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER.md"
APPENDIX="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER_QA372_APPEND.md"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

query="$(cat "$PREFLIGHT")"

grep -Fq "FROM pg_user_mappings um" <<< "$query" ||
  fail "preflight must use the publicly readable pg_user_mappings view"
grep -Fq "d.classid = 'pg_user_mapping'::regclass" <<< "$query" ||
  fail "preflight must retain extension-membership checks against pg_user_mapping objects"
grep -Fq "d.objid = um.umid" <<< "$query" ||
  fail "preflight must map the public view's umid to pg_depend.objid"
if grep -Eiq 'FROM[[:space:]]+pg_user_mapping([[:space:]]|$)' <<< "$query"; then
  fail "preflight must not SELECT directly from the restricted pg_user_mapping catalog"
fi
if grep -Eiq 'umoptions|subconninfo' <<< "$query"; then
  fail "preflight must not inspect user-mapping options or subscription connection strings"
fi

for required in \
  "pg_user_mapping" \
  "pg_user_mappings" \
  "permission denied" \
  "umoptions IS NULL" \
  "pg_subscription" \
  "subconninfo" \
  "pg_replication_slots" \
  "pg_largeobject_metadata" \
  "pg_monitor" \
  "NOLOGIN" \
  "wal_level=logical" \
  "PG_PRIVILEGE_TEST_IMAGE" \
  "postgres:16" \
  "postgres:17.6" \
  "trap cleanup EXIT" \
  "docker rm -f"; do
  grep -Fq -- "$required" "$RUNTIME" ||
    fail "QA372 runtime characterization is missing: $required"
done

if grep -Fq 'GRANT pg_monitor TO "$PROBE_ROLE"' "$RUNTIME"; then
  fail "QA372 baseline probe must remain a non-superuser without pg_monitor"
fi
if grep -Fq "ALTER SYSTEM" "$RUNTIME"; then
  fail "QA372 must not alter persistent server configuration"
fi

bash -n "$RUNTIME" || fail "QA372 runtime has invalid Bash syntax"

static_step_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-preflight-privilege-visibility.sh' "$WORKFLOW")"
[[ "$static_step_count" -eq 1 ]] ||
  fail "QA372 static contract must run exactly once in Verify; found $static_step_count"

runtime_step_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-preflight-privilege-visibility-runtime.sh' "$WORKFLOW")"
[[ "$runtime_step_count" -eq 2 ]] ||
  fail "QA372 runtime must run on PostgreSQL 16 and 17.6; found $runtime_step_count"

grep -Fq 'PG_PRIVILEGE_TEST_IMAGE: postgres:16' "$WORKFLOW" ||
  fail "PostgreSQL 16 privilege-visibility test image is not pinned"
grep -Fq 'PG_PRIVILEGE_TEST_IMAGE: postgres:17.6' "$WORKFLOW" ||
  fail "PostgreSQL 17.6 privilege-visibility test image is not pinned"

grep -Fq "### QA372 — non-superuser bootstrap catalog visibility" "$REGISTER" ||
  fail "canonical register is missing QA372"
grep -Fq "QA372 code-validation evidence" "$APPENDIX" ||
  fail "QA372 appendix must reserve a section for code-validation evidence"
grep -Fq "QA372 CodeQL evidence" "$APPENDIX" ||
  fail "QA372 appendix must reserve a section for CodeQL evidence"

echo "QA372 static contract PASS: the preflight uses the public user-mappings view without reading credentials, and the non-superuser runtime is wired to PostgreSQL 16 and 17.6."
