#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREFLIGHT="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"
SETTINGS_RUNTIME="$ROOT/tests/sql/test-create-offer-database-settings-acl-runtime.sh"
EXTENSION_RUNTIME="$ROOT/tests/sql/test-create-offer-extension-config-runtime.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
REGISTER="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER.md"
APPENDIX="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER_QA371_APPEND.md"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

query="$(cat "$PREFLIGHT")"

grep -Fq "pg_parameter_acl is shared cluster-wide" <<< "$query" ||
  fail "preflight must document why shared pg_parameter_acl is not database-scoped"
if grep -Eiq 'FROM[[:space:]]+pg_parameter_acl' <<< "$query"; then
  fail "cluster-wide pg_parameter_acl must not be used as a database-local preflight predicate"
fi

grep -Fq "Extension configuration tables registered in pg_extension.extconfig" <<< "$query" ||
  fail "preflight must document that extension config relations are already covered"
grep -Fq "extcondition is pg_dump row-filter" <<< "$query" ||
  fail "preflight must document extcondition as dump metadata rather than a dynamic preflight predicate"
grep -Fq "pg_catalog or information_schema remain uncharacterized" <<< "$query" ||
  fail "preflight must state the uncharacterized system-schema extension-config boundary"
if grep -Fq 'unnest(e.extconfig)' <<< "$query" || grep -Fq 'extcondition[' <<< "$query"; then
  fail "preflight must not dynamically inspect extension configuration filters"
fi

for required in \
  "GRANT SET ON PARAMETER work_mem" \
  "REVOKE SET ON PARAMETER work_mem" \
  "pg_parameter_acl" \
  "aclexplode" \
  "has_parameter_privilege" \
  "cluster-wide parameter ACL must not poison current database" \
  "cluster-wide parameter ACL must not poison comparison database"; do
  grep -Fq -- "$required" "$SETTINGS_RUNTIME" ||
    fail "QA371 parameter ACL runtime is missing: $required"
done

for required in \
  "PG_EXTENSION_CONFIG_TEST_IMAGE" \
  "SHOW server_version_num" \
  "170006" \
  "postgres:16" \
  "postgres:17.6" \
  "pg_extension_config_dump" \
  "extconfig" \
  "extcondition" \
  "WHERE NOT is_builtin" \
  "pg_dump" \
  "DROP EXTENSION qa371_config_probe" \
  "public-relation guard" \
  "trap cleanup EXIT" \
  "docker rm -f"; do
  grep -Fq -- "$required" "$EXTENSION_RUNTIME" ||
    fail "QA371 extension configuration runtime is missing: $required"
done

if grep -Fq "ALTER SYSTEM" "$SETTINGS_RUNTIME" "$EXTENSION_RUNTIME"; then
  fail "QA371 must not modify persistent PostgreSQL server configuration"
fi

bash -n "$SETTINGS_RUNTIME" || fail "QA370/QA371 settings runtime has invalid Bash syntax"
bash -n "$EXTENSION_RUNTIME" || fail "QA371 extension runtime has invalid Bash syntax"

static_step_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-parameter-acl-extension-config-preflight.sh' "$WORKFLOW")"
[[ "$static_step_count" -eq 1 ]] ||
  fail "QA371 static contract must run exactly once in Verify; found $static_step_count"

extension_runtime_step_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-extension-config-runtime.sh' "$WORKFLOW")"
[[ "$extension_runtime_step_count" -eq 2 ]] ||
  fail "QA371 extension configuration runtime must run on PostgreSQL 16 and 17.6; found $extension_runtime_step_count"

grep -Fq 'PG_EXTENSION_CONFIG_TEST_IMAGE: postgres:16' "$WORKFLOW" ||
  fail "PostgreSQL 16 extension configuration test image is not pinned"
grep -Fq 'PG_EXTENSION_CONFIG_TEST_IMAGE: postgres:17.6' "$WORKFLOW" ||
  fail "PostgreSQL 17.6 extension configuration test image is not pinned"

grep -Fq "### QA371 — cluster-wide parameter ACL and extension configuration tables" "$REGISTER" ||
  fail "canonical function register is missing QA371"
grep -Fq "QIMA CI #1334 on code HEAD" "$APPENDIX" ||
  fail "QA371 appendix must record the successful code-validation CI run"
grep -Fq "CodeQL #1284: **SUCCESS**" "$APPENDIX" ||
  fail "QA371 appendix must record CodeQL evidence"
grep -Fq "Vercel: **RATE LIMITED**" "$APPENDIX" ||
  fail "QA371 appendix must preserve the Vercel limitation"

echo "QA371 static contract PASS: shared parameter ACLs are characterized without database-local rejection; extension config metadata is verified while the existing relation/schema guards remain responsible for rejecting configuration relations."
