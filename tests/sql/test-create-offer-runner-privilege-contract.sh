#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT/tests/sql/run-create-offer-integration.sh"
FIXTURE="$ROOT/tests/sql/fixtures/create-offer-schema.sql"
RUNTIME="$ROOT/tests/sql/test-create-offer-runner-privilege-runtime.sh"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
REGISTER="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER.md"
APPENDIX="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER_QA373_APPEND.md"
APPENDIX_QA374="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER_QA374_APPEND.md"
APPENDIX_QA379="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER_QA379_APPEND.md"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for required in \
  "rolsuper" \
  "rolcreaterole" \
  "runner_database.datdba = runner_role.oid" \
  "database_owner_with_createrole" \
  "pg_auth_members" \
  "admin_option" \
  "pg_has_role(runner_role.oid, target_role.oid, 'SET')" \
  "no fixture DDL/DML was attempted" \
  "exit 4"; do
  grep -Fq -- "$required" "$RUNNER" ||
    fail "runner privilege preflight is missing: $required"
done

role_check_line="$(grep -nF 'runner_privilege_state=' "$RUNNER" | head -n 1 | cut -d: -f1)"
preflight_line="$(grep -nF 'preflight_sql=' "$RUNNER" | head -n 1 | cut -d: -f1)"
[[ -n "$role_check_line" && -n "$preflight_line" && "$role_check_line" -lt "$preflight_line" ]] ||
  fail "runner privilege preflight must execute before the catalog preflight and every fixture"

runner_guard="$(sed -n "${role_check_line},$((preflight_line - 1))p" "$RUNNER")"
grep -Fq "SELECT CASE" <<< "$runner_guard" ||
  fail "runner privilege preflight must remain a SELECT"
if grep -Eiq '^[[:space:]]*(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|GRANT|REVOKE)([[:space:]]|;)' <<< "$runner_guard"; then
  fail "runner privilege preflight must remain read-only"
fi

for required in \
  "runner_role_membership" \
  "IF NOT COALESCE(v_runner_is_superuser, false)" \
  "GRANT authenticated TO" \
  "GRANT anon TO" \
  "pg_has_role(current_user, 'authenticated', 'SET')" \
  "pg_has_role(current_user, 'anon', 'SET')"; do
  grep -Fq -- "$required" "$FIXTURE" ||
    fail "fixture is missing non-superuser SET ROLE preparation: $required"
done

for required in \
  "PG_RUNNER_PRIVILEGE_TEST_IMAGE" \
  "postgres:16" \
  "postgres:17.6" \
  "run-create-offer-integration.sh" \
  "qa373_runner" \
  "CREATEROLE" \
  "NOCREATEDB" \
  "NOSUPERUSER" \
  "NOREPLICATION" \
  "NOBYPASSRLS" \
  "Observed one granted and one waiting same-tenant advisory lock" \
  "qa373_not_owner" \
  "qa373_no_role_admin" \
  "qa373_no_createrole" \
  "qa374_admin_option_runner" \
  "WITH ADMIN TRUE, INHERIT FALSE, SET FALSE" \
  "anon:false:true:false|authenticated:false:true:false" \
  "bool_or(membership.set_option)" \
  "count(DISTINCT membership.grantor)" \
  "anon:true:2|authenticated:true:2" \
  "qa374_admin_option_non_owner" \
  "anon:false:true:false|authenticated:false:true:false" \
  "QA375 passed" \
  "qa376_partial_admin_runner" \
  "ALTER DATABASE qima_test OWNER TO qa376_partial_admin_runner" \
  "GRANT anon TO qa376_partial_admin_runner" \
  "true|true|false|false|true|false|false|true" \
  "authenticated_members.member IS NULL" \
  "before_partial_admin_snapshot" \
  "after_partial_admin_snapshot" \
  "QA376 passed" \
  "qa377_mixed_membership_runner" \
  "CREATE DATABASE qima_test OWNER qa377_mixed_membership_runner" \
  "WITH ADMIN FALSE, INHERIT FALSE, SET TRUE" \
  "WITH ADMIN TRUE, INHERIT FALSE, SET FALSE" \
  "true|false|true|true|false|true|false|true|false" \
  "anon:true:1|authenticated:true:2" \
  "QA377 passed" \
  "qa378_reverse_mixed_runner" \
  "CREATE DATABASE qima_test OWNER qa378_reverse_mixed_runner" \
  "true|false|true|false|true|false|true|false|true" \
  "anon:true:2|authenticated:true:1" \
  "QA378 passed" \
  "reverse_mixed_initial_state" \
  "reverse_mixed_after_state" \
  "reverse_mixed_grantor_state" \
  "qa379_indirect_bridge" \
  "qa379_indirect_runner" \
  "qa379_blocked_bridge" \
  "qa379_blocked_runner" \
  "true|false|true|true|true|true|false|false|true:false|true:false|true:false" \
  "true|false|true|true|false|false|false|false|false|true|true" \
  "true|true|false|false|true|false|false" \
  "QA379 indirect SET chain passed" \
  "QA379 indirect SET chain with a SET FALSE edge was rejected" \
  "indirect_positive_initial_state" \
  "indirect_positive_after_state" \
  "indirect_negative_initial_state" \
  "indirect_empty_database_snapshot" \
  "SET ROLE anon; RESET ROLE; SET ROLE authenticated; RESET ROLE;" \
  "mixed_initial_state" \
  "mixed_after_state" \
  "mixed_grantor_state" \
  "Observed one granted and one waiting same-tenant advisory lock" \
  "before_non_owner_snapshot" \
  "after_non_owner_snapshot" \
  "pg_get_userbyid(datdba)" \
  "rolname LIKE 'qa373_%' OR rolname LIKE 'qa374_%' OR rolname LIKE 'qa376_%'" \
  "QA374 passed" \
  "catalog_snapshot" \
  "docker exec -i" \
  "docker rm -f" \
  "trap cleanup EXIT"; do
  grep -Fq -- "$required" "$RUNTIME" ||
    fail "QA373 runtime characterization is missing: $required"
done

if grep -Fq "ALTER SYSTEM" "$RUNTIME"; then
  fail "QA373 must not alter persistent PostgreSQL configuration"
fi
if grep -Eiq 'postgres(ql)?://[^[:space:]]*(production|supabase)' "$RUNTIME"; then
  fail "QA373 runtime must not contain a Production/Supabase connection URL"
fi
bash -n "$RUNNER" || fail "CREATE_OFFER runner has invalid Bash syntax"
bash -n "$RUNTIME" || fail "QA373 runtime has invalid Bash syntax"

static_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-runner-privilege-contract.sh' "$WORKFLOW")"
[[ "$static_count" -eq 1 ]] || fail "QA373 static contract must run exactly once in Verify"
runtime_count="$(grep -Fc 'run: bash tests/sql/test-create-offer-runner-privilege-runtime.sh' "$WORKFLOW")"
[[ "$runtime_count" -eq 2 ]] || fail "QA373 runtime must run on PostgreSQL 16 and 17.6"
grep -Fq 'PG_RUNNER_PRIVILEGE_TEST_IMAGE: postgres:16' "$WORKFLOW" ||
  fail "PostgreSQL 16 QA373 image is not pinned"
grep -Fq 'PG_RUNNER_PRIVILEGE_TEST_IMAGE: postgres:17.6' "$WORKFLOW" ||
  fail "PostgreSQL 17.6 QA373 image is not pinned"

grep -Fq "### QA373 — full CREATE_OFFER runner write-privilege contract" "$REGISTER" ||
  fail "canonical register is missing QA373"
grep -Fq "QA373 code-validation evidence" "$APPENDIX" ||
  fail "QA373 appendix must reserve code-validation evidence"
grep -Fq "QA373 CodeQL evidence" "$APPENDIX" ||
  fail "QA373 appendix must reserve CodeQL evidence"

grep -Fq "## QA374 — ADMIN OPTION-only runner membership path" "$APPENDIX_QA374" ||
  fail "QA374 appendix is missing its scope"
grep -Fq "QA374 code-validation evidence" "$APPENDIX_QA374" ||
  fail "QA374 appendix must reserve code-validation evidence"
grep -Fq "QA374 CodeQL evidence" "$APPENDIX_QA374" ||
  fail "QA374 appendix must reserve CodeQL evidence"
grep -Fq "### QA374 — ADMIN OPTION-only CREATE_OFFER runner membership path" "$REGISTER" ||
  fail "canonical register is missing QA374"
grep -Fq "## QA375 — ADMIN OPTION does not bypass database ownership" "$APPENDIX_QA374" ||
  fail "QA374 appendix is missing QA375 ownership-boundary coverage"
grep -Fq "### QA375 — ADMIN OPTION does not bypass database ownership" "$REGISTER" ||
  fail "canonical register is missing QA375 ownership-boundary coverage"
grep -Fq "## QA376 — ADMIN OPTION must cover every existing client role" "$APPENDIX_QA374" ||
  fail "QA374 appendix is missing QA376 partial-membership coverage"
grep -Fq "## QA377 — mixed SET and ADMIN OPTION membership path" "$APPENDIX_QA374" ||
  fail "QA374 appendix is missing QA377 mixed-membership coverage"
grep -Fq "## QA378 — reverse mixed SET and ADMIN OPTION membership path" "$APPENDIX_QA374" ||
  fail "QA374 appendix is missing QA378 reverse mixed-membership coverage"
grep -Fq "### QA376 — ADMIN OPTION must cover every existing client role" "$REGISTER" ||
  fail "canonical register is missing QA376 partial-membership coverage"
grep -Fq "### QA377 — mixed SET and ADMIN OPTION membership path" "$REGISTER" ||
  fail "canonical register is missing QA377 mixed-membership coverage"
grep -Fq "### QA378 — reverse mixed SET and ADMIN OPTION membership path" "$REGISTER" ||
  fail "canonical register is missing QA378 reverse mixed-membership coverage"
grep -Fq "## QA379 — indirect SET membership chain boundaries" "$APPENDIX_QA379" ||
  fail "QA379 appendix is missing indirect SET-chain coverage"
grep -Fq "### QA379 — indirect SET membership chain boundaries" "$REGISTER" ||
  fail "canonical register is missing QA379 indirect SET-chain coverage"
if grep -Fq "GRANT anon TO qa379_indirect_runner" "$RUNTIME"; then
  fail "QA379 positive path must remain indirect rather than creating a direct anon membership"
fi
if grep -Fq "GRANT authenticated TO qa379_indirect_runner" "$RUNTIME"; then
  fail "QA379 positive path must remain indirect rather than creating a direct authenticated membership"
fi
if grep -Fq "GRANT authenticated TO qa376_partial_admin_runner" "$RUNTIME"; then
  fail "QA376 must not grant the missing authenticated ADMIN OPTION membership"
fi

echo "QA373/QA374/QA375/QA376/QA377/QA378/QA379 static contract PASS: the runner fails closed on unsupported roles, rejects non-owners and partial administration, accepts both mixed SET/ADMIN OPTION directions, and recognizes only complete transitive SET-enabled membership chains."
