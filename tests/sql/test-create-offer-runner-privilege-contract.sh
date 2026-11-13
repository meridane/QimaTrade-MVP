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
APPENDIX_QA380="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER_QA380_APPEND.md"
APPENDIX_QA381="$ROOT/docs/QIMA_V1_FUNCTION_REGISTER_QA381_APPEND.md"

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


for required in \
  "CREATE SCHEMA qa381_probe_default" \
  "CREATE SCHEMA qa381_probe_set" \
  "CREATE SCHEMA qa381_probe_inherit" \
  "CREATE SCHEMA qa381_probe_both" \
  "GRANT SELECT ON TABLE qa381_probe_default.inherit_probe TO qa381_default_target" \
  "GRANT SELECT ON TABLE qa381_probe_set.inherit_probe TO qa381_set_target" \
  "GRANT SELECT ON TABLE qa381_probe_inherit.inherit_probe TO qa381_inherit_target" \
  "GRANT SELECT ON TABLE qa381_probe_both.inherit_probe TO qa381_both_target" \
  "4|true|true" \
  "nspname LIKE 'qa381_probe_%'" \
  "DROP SCHEMA qa381_probe_default CASCADE" \
  "DROP SCHEMA qa381_probe_set CASCADE" \
  "DROP SCHEMA qa381_probe_inherit CASCADE" \
  "DROP SCHEMA qa381_probe_both CASCADE" \
  "REVOKE CONNECT ON DATABASE qima_test FROM qa381_create_role_runner"; do
  grep -Fq -- "$required" "$RUNTIME" ||
    fail "QA381 per-target ACL isolation is missing: $required"
done

qa381_revoke_connect_line="$(grep -nF 'REVOKE CONNECT ON DATABASE qima_test FROM qa381_create_role_runner' "$RUNTIME" | tail -n 1 | cut -d: -f1)"
qa381_drop_runner_line="$(grep -nF 'DROP ROLE qa381_create_role_runner' "$RUNTIME" | tail -n 1 | cut -d: -f1)"
[[ -n "$qa381_revoke_connect_line" && -n "$qa381_drop_runner_line" && "$qa381_revoke_connect_line" -lt "$qa381_drop_runner_line" ]] ||
  fail "QA381 must revoke the runner's database CONNECT grant before dropping the role"

grep -Fq 'qa381_expect_direct_select "qa381_default_target" "qa381_probe_default" "inherit_probe" "false"' "$RUNTIME" ||
  fail "QA381 default target must probe only its own object"
grep -Fq 'qa381_expect_direct_select "qa381_set_target" "qa381_probe_set" "inherit_probe" "false"' "$RUNTIME" ||
  fail "QA381 SET-only target must probe only its own object"
grep -Fq 'qa381_expect_direct_select "qa381_inherit_target" "qa381_probe_inherit" "inherit_probe" "true"' "$RUNTIME" ||
  fail "QA381 INHERIT target must probe only its own object"
grep -Fq 'qa381_expect_direct_select "qa381_both_target" "qa381_probe_both" "inherit_probe" "true"' "$RUNTIME" ||
  fail "QA381 combined target must probe only its own object"
grep -Fq "### QA381 fifth runtime correction — isolate per-target ACL probes" "$REGISTER" ||
  fail "canonical register is missing QA381 per-target ACL isolation evidence"
grep -Fq "## Fifth runtime correction — isolate per-target object ACLs" "$APPENDIX_QA381" ||
  fail "QA381 appendix is missing per-target ACL isolation evidence"

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
grep -Fq "# QA379 — indirect SET membership chain boundaries" "$APPENDIX_QA379" ||
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


for required in \
  "qa380_admin_bridge" \
  "qa380_admin_runner" \
  "true|false|true|true|false|true|false|true|false|true|false|false|true:false:false|true:false:false|true:false:false" \
  "before_qa380_admin_snapshot" \
  "after_qa380_admin_snapshot" \
  "QA380 passed" \
  "ADMIN OPTION on the bridge was not treated as ADMIN OPTION on anon or authenticated" \
  "qa381_create_role_runner" \
  "createrole_self_grant" \
  "qa381_default_target" \
  "qa381_set_target" \
  "qa381_inherit_target" \
  "qa381_both_target" \
  "set,inherit" \
  "QA381 passed"; do
  grep -Fq -- "$required" "$RUNTIME" ||
    fail "QA380 runtime characterization is missing: $required"
done
if grep -Fq "GRANT anon TO qa380_admin_runner" "$RUNTIME"; then
  fail "QA380 must not create a direct anon membership for the runner"
fi
if grep -Fq "GRANT authenticated TO qa380_admin_runner" "$RUNTIME"; then
  fail "QA380 must not create a direct authenticated membership for the runner"
fi
grep -Fq "# QA380 — ADMIN OPTION is not transitive across membership" "$APPENDIX_QA380" ||
  fail "QA380 appendix is missing non-transitive ADMIN OPTION coverage"
grep -Fq "### QA380 — ADMIN OPTION does not propagate through a membership chain" "$REGISTER" ||
  fail "canonical register is missing QA380 non-transitive ADMIN OPTION coverage"

grep -Fq "# QA381 — CREATEROLE self-grant GUC semantics" "$APPENDIX_QA381" ||
  fail "QA381 appendix is missing createrole_self_grant characterization"
grep -Fq "### QA381 — CREATEROLE self-grant GUC semantics" "$REGISTER" ||
  fail "canonical register is missing QA381 createrole_self_grant characterization"
grep -Fq "QA381 validation evidence" "$APPENDIX_QA381" ||
  fail "QA381 appendix must reserve runtime validation evidence"

grep -Fq "qa381_effective_state()" "$RUNTIME" ||
  fail "QA381 must expose an effective membership-state probe"
qa381_effective_function="$(sed -n '/^qa381_effective_state()/,/^}/p' "$RUNTIME")"
grep -Fq "'SET'" <<< "$qa381_effective_function" ||
  fail "QA381 effective membership probe must inspect SET"
grep -Fq "'USAGE'" <<< "$qa381_effective_function" ||
  fail "QA381 effective membership probe must inspect INHERIT/USAGE"
if grep -Fq "has_table_privilege" <<< "$qa381_effective_function"; then
  fail "QA381 must keep object ACL behavior out of the membership-state tuple"
fi
grep -Fq "qa381_expect_direct_select()" "$RUNTIME" ||
  fail "QA381 must execute direct SELECT as the non-superuser creator"
grep -Fq 'SELECT count(*) FROM $qualified_table;' "$RUNTIME" ||
  fail "QA381 direct SELECT behavior must be exercised by SQL, not inferred from the catalog helper"

for required in \
  "REVOKE ALL ON SCHEMA qa381_probe_default FROM PUBLIC" \
  "REVOKE ALL ON TABLE qa381_probe_default.inherit_probe FROM PUBLIC" \
  "qa381_public_acl_state" \
  "aclexplode" \
  "qa381_direct_select_diagnostic()" \
  "session_user" \
  "has_schema_privilege" \
  "has_table_privilege" \
  "QA381 direct-SELECT diagnostic: database, schema, and table owner membership paths" \
  "pg_has_role('qa381_create_role_runner', d.datdba, 'USAGE')" \
  "pg_has_role('qa381_create_role_runner', n.nspowner, 'USAGE')" \
  "pg_has_role('qa381_create_role_runner', c.relowner, 'USAGE')" \
  "pg_database_owner" \
  "all direct memberships and effective member-role paths" \
  "FROM pg_auth_members m" \
  "pg_has_role('qa381_create_role_runner', r.oid, 'MEMBER')" \
  "column-level ACLs and effective SELECT" \
  "has_any_column_privilege" \
  "has_column_privilege" \
  "pg_attribute" \
  "permission denied"; do
  grep -Fq -- "$required" "$RUNTIME" ||
    fail "QA381 direct-SELECT ACL isolation/diagnostics are missing: $required"
done

qa381_public_acl_check="$(sed -n '/^qa381_public_acl_state=/,/^qa381_catalog_state()/p' "$RUNTIME")"
[[ "$(grep -Fc '(NOT EXISTS (' <<< "$qa381_public_acl_check")" -eq 2 ]] ||
  fail "QA381 PUBLIC ACL checks must parenthesize both NOT EXISTS boolean expressions"
[[ "$(grep -Fc '))::text' <<< "$qa381_public_acl_check")" -eq 2 ]] ||
  fail "QA381 PUBLIC ACL checks must cast both boolean results only after NOT EXISTS"

echo "QA373/QA374/QA375/QA376/QA377/QA378/QA379/QA380/QA381 static contract PASS: runner privilege boundaries, indirect membership, non-transitive ADMIN, and CREATEROLE self-grant GUC semantics are covered."

grep -Fq "## Fourth runtime diagnostic — trace owner and column-level privilege paths" "$APPENDIX_QA381" ||
  fail "QA381 appendix is missing owner/column-level diagnostics evidence"
grep -Fq "### QA381 fourth runtime diagnostic — trace owner and column-level privilege paths" "$REGISTER" ||
  fail "canonical register is missing QA381 owner/column-level diagnostics evidence"
