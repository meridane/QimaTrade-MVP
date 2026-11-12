#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"
RUNTIME="$ROOT/tests/sql/test-create-offer-database-settings-acl-runtime.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
REGISTER="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER.md"
APPENDIX="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER_QA370_APPEND.md"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

query="$(cat "$PREFLIGHT")"

for required in \
  "pg_db_role_setting" \
  "s.setdatabase = (" \
  "db.datname = current_database()" \
  "pg_default_acl"; do
  grep -Fq -- "$required" <<< "$query" ||
    fail "preflight is missing database-scoped settings/default-ACL predicate: $required"
done

if grep -Fq "s.setdatabase = 0" <<< "$query"; then
  fail "cluster-wide role settings (setdatabase=0) must not be treated as database-local residue"
fi

if ! grep -Fq $'FROM pg_default_acl\n  ) THEN' <<< "$query"; then
  fail "all current-database default ACL rows must be checked without a schema-only filter"
fi

if grep -Ein '^[[:space:]]*(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|CALL|COPY|EXECUTE|PERFORM|COMMIT|ROLLBACK|SAVEPOINT|SET|RESET)([[:space:]]|;)' <<< "$query"; then
  fail "database settings/default-ACL preflight must remain read-only"
fi

for required in \
  "ALTER DATABASE" \
  "ALTER ROLE" \
  "IN DATABASE" \
  "ALTER DEFAULT PRIVILEGES" \
  "pg_db_role_setting" \
  "pg_default_acl" \
  "setdatabase = 0" \
  "defaclnamespace" \
  "template0" \
  "qima_qa370_current" \
  "qima_qa370_other" \
  "trap cleanup EXIT"; do
  grep -Fq -- "$required" "$RUNTIME" ||
    fail "runtime characterization is missing database-settings/default-ACL behavior: $required"
done

if grep -Fq "ALTER SYSTEM" "$RUNTIME"; then
  fail "QA370 must not modify persistent PostgreSQL server configuration"
fi

if grep -Fq "DROP DATABASE qima_test" "$RUNTIME"; then
  fail "QA370 must never drop the shared qima_test service database"
fi

bash -n "$RUNTIME" || fail "QA370 runtime script has invalid Bash syntax"

static_step_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-database-settings-acl-preflight.sh' "$WORKFLOW")"
[[ "$static_step_count" -eq 1 ]] ||
  fail "QA370 static contract must run exactly once in Verify; found $static_step_count"

runtime_step_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-database-settings-acl-runtime.sh' "$WORKFLOW")"
[[ "$runtime_step_count" -eq 2 ]] ||
  fail "QA370 runtime characterization must run on PostgreSQL 16 and 17.6; found $runtime_step_count"

grep -Fq 'postgres-integration:' "$WORKFLOW" ||
  fail "PostgreSQL 16 integration job is missing"
grep -Fq 'postgres17-create-offer-compatibility:' "$WORKFLOW" ||
  fail "PostgreSQL 17.6 compatibility job is missing"

grep -Fq '### QA370 — database-scoped role settings and default ACL bootstrap state' "$REGISTER" ||
  fail "canonical function register is missing the QA370 section"
if ! grep -F 'QIMA CI #' "$APPENDIX" | grep -Fq '**SUCCESS**'; then
  fail "QA370 appendix must record a successful QIMA CI run"
fi
if ! grep -F 'CodeQL #' "$APPENDIX" | grep -Fq '**SUCCESS**'; then
  fail "QA370 appendix must record a successful CodeQL run"
fi
grep -Fq 'Vercel Preview: **SUCCESS**' "$APPENDIX" ||
  fail "QA370 appendix must record the Preview outcome"

echo "QA370 static contract PASS: current-database pg_db_role_setting rows and all database-local pg_default_acl rows are rejected; global role settings and other-database settings remain outside the current-database boundary; PostgreSQL 16/17 runtime tests and CI/CodeQL/Preview evidence are recorded."
