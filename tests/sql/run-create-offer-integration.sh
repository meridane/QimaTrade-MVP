#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to a disposable PostgreSQL database}"

# This runner applies fixture DDL and branch migrations directly to DATABASE_URL.
# Fail closed before psql unless it is the dedicated loopback qima_test service.
if [[ ! "$DATABASE_URL" =~ ^postgres(ql)?://[^@]+@(localhost|127\.0\.0\.1|\[::1\]):5432/qima_test$ ]]; then
  echo "::error::Refusing CREATE_OFFER integration setup: DATABASE_URL must target qima_test on a loopback host at port 5432; no database connection was attempted." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL=(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1)
PSQL_TUPLE=(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t)

# QA363: inspect the disposable database before any fixture DDL/DML. A runner
# replay against an initialized database must stop after this read-only query.
preflight_sql="$ROOT/tests/sql/create-offer-bootstrap-preflight.sql"

if preflight_state="$("${PSQL_TUPLE[@]}" -v "expected_database=qima_test" -f "$preflight_sql")"; then"$("${PSQL_TUPLE[@]}" -c "$preflight_query")"; then
  :
else
  preflight_status=$?
  echo "::error::Could not inspect qima_test bootstrap state (psql exit $preflight_status); no fixture DDL/DML was attempted." >&2
  exit "$preflight_status"
fi

case "$preflight_state" in
  empty)
    echo "QA363 preflight accepted an empty qima_test database."
    ;;
  wrong_database)
    echo "::error::Refusing CREATE_OFFER integration setup: current database is not qima_test; no fixture DDL/DML was attempted." >&2
    exit 3
    ;;
  not_empty)
    echo "::error::Refusing CREATE_OFFER integration setup: qima_test already contains application relations or non-default schemas (including standalone routines and types); use a fresh disposable database; no fixture DDL/DML was attempted." >&2
    exit 3
    ;;
  *)
    echo "::error::Refusing CREATE_OFFER integration setup: qima_test preflight returned an unexpected state; no fixture DDL/DML was attempted." >&2
    exit 3
    ;;
esac

# This script is only intended for the ephemeral PostgreSQL service in CI.
# Never point DATABASE_URL at Supabase production.
"${PSQL[@]}" -f "$ROOT/tests/sql/fixtures/create-offer-schema.sql"
"${PSQL[@]}" -f "$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
"${PSQL[@]}" -f "$ROOT/supabase/migrations/20261027100000_restrict_direct_create_offer_rpc.sql"
"${PSQL[@]}" -f "$ROOT/tests/sql/create-offer-runtime.sql"
"${PSQL[@]}" -f "$ROOT/tests/sql/idempotency-numeric-lexical-characterization.sql"

# Race two first-time requests with the same tenant/key. Distinct application names
# let the observer prove that one session owns the advisory lock while the other
# is waiting for that exact lock during the fixture delay.
call_sql_a=$(cat <<'SQL'
SET application_name = 'qima-same-tenant-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-concurrent-first-insert',
  '{"case":"concurrent"}'::jsonb,
  'Concurrent Fixture Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  3,
  21,
  'USD'
);
SQL
)

call_sql_b=$(cat <<'SQL'
SET application_name = 'qima-same-tenant-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-concurrent-first-insert',
  '{"case":"concurrent"}'::jsonb,
  'Concurrent Fixture Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  3,
  21,
  'USD'
);
SQL
)

"${PSQL_TUPLE[@]}" -c "$call_sql_a" > /tmp/qima-concurrent-1.log &
pid1=$!
"${PSQL_TUPLE[@]}" -c "$call_sql_b" > /tmp/qima-concurrent-2.log &
pid2=$!

# The first session should be inside the fixture's 0.5 s pg_sleep while
# holding the tenant/key advisory lock; the second should be waiting for the
# same lock. Require both sessions and the same lock key in one observation.
lock_snapshot=""
for attempt in $(seq 1 200); do
  lock_snapshot=$("${PSQL[@]}" -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(*) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text || '|' ||
      count(*) FILTER (
        WHERE NOT l.granted
          AND a.wait_event_type = 'Lock'
          AND a.wait_event = 'advisory'
      )::text || '|' ||
      count(DISTINCT (
        l.classid::text || ':' || l.objid::text || ':' || l.objsubid::text
      ))::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN ('qima-same-tenant-a', 'qima-same-tenant-b')
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$lock_snapshot" == "2|1|1|1" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$pid1"
status1=$?
wait "$pid2"
status2=$?
set -e

if [[ "$status1" -ne 0 || "$status2" -ne 0 ]]; then
  echo "Same-tenant concurrent CREATE_OFFER calls failed (A=$status1, B=$status2)." >&2
  cat /tmp/qima-concurrent-1.log /tmp/qima-concurrent-2.log >&2
  exit 1
fi

if [[ "$lock_snapshot" != "2|1|1|1" ]]; then
  echo "Expected two same-tenant sessions with one granted and one waiting on the same advisory lock; observed '$lock_snapshot'." >&2
  cat /tmp/qima-concurrent-1.log /tmp/qima-concurrent-2.log >&2
  exit 1
fi
echo "Observed one granted and one waiting same-tenant advisory lock on the same tenant/key."
if [[ ! -s /tmp/qima-concurrent-1.log || ! -s /tmp/qima-concurrent-2.log ]]; then
  echo "Both identical concurrent CREATE_OFFER calls must return a JSONB result." >&2
  cat /tmp/qima-concurrent-1.log /tmp/qima-concurrent-2.log >&2
  exit 1
fi

if ! cmp -s /tmp/qima-concurrent-1.log /tmp/qima-concurrent-2.log; then
  echo "Identical concurrent CREATE_OFFER calls returned different results." >&2
  diff -u /tmp/qima-concurrent-1.log /tmp/qima-concurrent-2.log >&2 || true
  exit 1
fi

"${PSQL_TUPLE[@]}" -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-first-insert'
    AND status = 'COMPLETED';
" > /tmp/qima-concurrent-stored-result.log

if ! cmp -s /tmp/qima-concurrent-1.log /tmp/qima-concurrent-stored-result.log; then
  echo "Concurrent CREATE_OFFER responses do not match the stored idempotency result." >&2
  diff -u /tmp/qima-concurrent-1.log /tmp/qima-concurrent-stored-result.log >&2 || true
  exit 1
fi

"${PSQL[@]}" <<'SQL'
DO $qa62$
DECLARE
  key_rows integer;
  completed_key_rows integer;
  execution_rows integer;
  completed_execution_rows integer;
  offer_rows integer;
  event_rows integer;
BEGIN
  SELECT count(*) INTO key_rows
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-first-insert';
  IF key_rows <> 1 THEN RAISE EXCEPTION 'Expected one idempotency row for concurrent calls, got %', key_rows; END IF;

  SELECT count(*) INTO completed_key_rows
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-first-insert'
    AND status = 'COMPLETED';
  IF completed_key_rows <> 1 THEN RAISE EXCEPTION 'Expected one completed idempotency row for concurrent calls, got %', completed_key_rows; END IF;

  SELECT count(*) INTO execution_rows
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-concurrent-first-insert';
  IF execution_rows <> 1 THEN RAISE EXCEPTION 'Expected one execution for concurrent calls, got %', execution_rows; END IF;

  SELECT count(*) INTO completed_execution_rows
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-concurrent-first-insert'
    AND status = 'COMPLETED';
  IF completed_execution_rows <> 1 THEN RAISE EXCEPTION 'Expected one completed execution for concurrent calls, got %', completed_execution_rows; END IF;

  SELECT count(*) INTO offer_rows
  FROM public.offers
  WHERE name = 'Concurrent Fixture Offer';
  IF offer_rows <> 1 THEN RAISE EXCEPTION 'Expected one offer for concurrent calls, got %', offer_rows; END IF;

  SELECT count(*) INTO event_rows
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-concurrent-first-insert'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.object_id = x.object_id;
  IF event_rows <> 1 THEN RAISE EXCEPTION 'Expected one success event for concurrent calls, got %', event_rows; END IF;
END
$qa62$;
SELECT 'CREATE_OFFER identical same-tenant concurrency assertions passed' AS result;
SQL


# QA287: two first-time requests with the same tenant/key and four empty optional
# strings must contend on one advisory lock, return the same stored result, and
# create exactly one idempotency row, execution, offer, and success event.
qa287_call_a=$(cat <<'SQL'
SET application_name = 'qima-qa287-empty-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa287-empty-optional-concurrency',
  p_input => '{"case":"qa287-empty-optional-concurrency","conditions":"","market":"","geography":"","documentationStatus":""}'::jsonb,
  p_name => 'QA287 Concurrent Empty Optional Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 5,
  p_price => 28,
  p_currency => 'USD',
  p_conditions => '',
  p_market => '',
  p_geography => '',
  p_attributes => '{}'::jsonb,
  p_documentation_status => ''
);
SQL
)

qa287_call_b=$(cat <<'SQL'
SET application_name = 'qima-qa287-empty-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa287-empty-optional-concurrency',
  p_input => '{"case":"qa287-empty-optional-concurrency","conditions":"","market":"","geography":"","documentationStatus":""}'::jsonb,
  p_name => 'QA287 Concurrent Empty Optional Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 5,
  p_price => 28,
  p_currency => 'USD',
  p_conditions => '',
  p_market => '',
  p_geography => '',
  p_attributes => '{}'::jsonb,
  p_documentation_status => ''
);
SQL
)

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa287_call_a" > /tmp/qima-qa287-a.log 2>&1 &
qa287_pid_a=$!
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa287_call_b" > /tmp/qima-qa287-b.log 2>&1 &
qa287_pid_b=$!

# Observe both sessions on the same exclusive advisory lock while the fixture
# trigger holds the first transaction in pg_sleep and the other request waits.
qa287_lock_snapshot=""
for attempt in $(seq 1 200); do
  qa287_lock_snapshot=$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(*) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text || '|' ||
      count(*) FILTER (
        WHERE NOT l.granted
          AND a.wait_event_type = 'Lock'
          AND a.wait_event = 'advisory'
      )::text || '|' ||
      count(DISTINCT (
        l.classid::text || ':' || l.objid::text || ':' || l.objsubid::text
      ))::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN ('qima-qa287-empty-a', 'qima-qa287-empty-b')
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$qa287_lock_snapshot" == "2|1|1|1" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$qa287_pid_a"
qa287_status_a=$?
wait "$qa287_pid_b"
qa287_status_b=$?
set -e

if [[ "$qa287_status_a" -ne 0 || "$qa287_status_b" -ne 0 ]]; then
  echo "QA287 concurrent empty-string CREATE_OFFER calls failed (A=$qa287_status_a, B=$qa287_status_b)." >&2
  cat /tmp/qima-qa287-a.log /tmp/qima-qa287-b.log >&2
  exit 1
fi

if [[ "$qa287_lock_snapshot" != "2|1|1|1" ]]; then
  echo "QA287 expected two sessions, one granted and one waiting on the same advisory lock; observed '$qa287_lock_snapshot'." >&2
  cat /tmp/qima-qa287-a.log /tmp/qima-qa287-b.log >&2
  exit 1
fi

if [[ ! -s /tmp/qima-qa287-a.log || ! -s /tmp/qima-qa287-b.log ]]; then
  echo "QA287 both concurrent requests must return a JSONB result." >&2
  cat /tmp/qima-qa287-a.log /tmp/qima-qa287-b.log >&2
  exit 1
fi

if ! cmp -s /tmp/qima-qa287-a.log /tmp/qima-qa287-b.log; then
  echo "QA287 identical concurrent empty-string requests returned different results." >&2
  diff -u /tmp/qima-qa287-a.log /tmp/qima-qa287-b.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa287-empty-optional-concurrency'
    AND status = 'COMPLETED';
" > /tmp/qima-qa287-stored-result.log

if ! cmp -s /tmp/qima-qa287-a.log /tmp/qima-qa287-stored-result.log; then
  echo "QA287 concurrent responses do not match the single persisted idempotency result." >&2
  diff -u /tmp/qima-qa287-a.log /tmp/qima-qa287-stored-result.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa287$
DECLARE
  v_input jsonb := '{
    "case":"qa287-empty-optional-concurrency",
    "conditions":"",
    "market":"",
    "geography":"",
    "documentationStatus":""
  }'::jsonb;
  v_expected_hash text;
  v_count integer;
BEGIN
  v_expected_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'QA287 Concurrent Empty Optional Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 5::numeric,
    'price', 28::numeric,
    'currency', 'USD',
    'conditions', '',
    'market', '',
    'geography', '',
    'attributes', '{}'::jsonb,
    'documentationStatus', '',
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa287-empty-optional-concurrency'
    AND status = 'COMPLETED'
    AND request_hash = v_expected_hash;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA287 expected exactly one completed idempotency row with the exact empty-string request hash, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa287-empty-optional-concurrency'
    AND status = 'COMPLETED'
    AND input = v_input
    AND object_type = 'Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA287 expected exactly one completed execution preserving the four empty optional strings, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA287 Concurrent Empty Optional Offer'
    AND conditions = ''
    AND market = ''
    AND geography = ''
    AND documentation_status = ''
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA287 expected exactly one offer preserving all four empty optional strings, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-qa287-empty-optional-concurrency'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.object_id = x.object_id
    AND e.payload = x.result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA287 expected exactly one ACTION_SUCCEEDED event matching the persisted result, found %', v_count;
  END IF;
END
$qa287$;
SELECT 'QA287 concurrent first-time requests with four empty optional strings returned one persisted result and created no duplicates' AS result;
SQL

echo "QA287 observed one granted and one waiting advisory lock for two concurrent first-time requests with four empty optional strings; both responses matched the single stored result and exactly one offer/execution/event remained."



# QA288: two concurrent first-time requests reuse one tenant/key with different
# effective parameters. The first request must complete; the waiting second
# request must then fail with IDEMPOTENCY_KEY_REUSE without creating any rows.
qa288_call_a=$(cat <<'SQL'
SET application_name = 'qima-qa288-different-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa288-concurrent-different-payload',
  p_input => '{"case":"qa288-concurrent-different-payload","conditions":"","market":"","geography":"","documentationStatus":""}'::jsonb,
  p_name => 'QA288 Concurrent Mismatch Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 6,
  p_price => 29,
  p_currency => 'USD',
  p_conditions => '',
  p_market => '',
  p_geography => '',
  p_attributes => '{}'::jsonb,
  p_documentation_status => ''
);
SQL
)

qa288_call_b=$(cat <<'SQL'
SET application_name = 'qima-qa288-different-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa288-concurrent-different-payload',
  p_input => '{"case":"qa288-concurrent-different-payload","conditions":null,"market":"","geography":"","documentationStatus":""}'::jsonb,
  p_name => 'QA288 Concurrent Mismatch Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 6,
  p_price => 29,
  p_currency => 'USD',
  p_conditions => NULL,
  p_market => '',
  p_geography => '',
  p_attributes => '{}'::jsonb,
  p_documentation_status => ''
);
SQL
)

# Start A alone and prove it owns the transaction-scoped advisory lock while
# the fixture insert delay is active. Only then start the changed-payload waiter.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa288_call_a" > /tmp/qima-qa288-a.log 2>&1 &
qa288_pid_a=$!

qa288_first_lock_snapshot=""
for attempt in $(seq 1 200); do
  qa288_first_lock_snapshot=$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(*) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name = 'qima-qa288-different-a'
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$qa288_first_lock_snapshot" == "1|1" ]]; then
    break
  fi
  sleep 0.025
done

if [[ "$qa288_first_lock_snapshot" != "1|1" ]]; then
  set +e
  wait "$qa288_pid_a"
  qa288_status_a=$?
  set -e
  echo "QA288 first request never exposed its granted advisory lock during PgSleep (snapshot='$qa288_first_lock_snapshot', exit=$qa288_status_a)." >&2
  cat /tmp/qima-qa288-a.log >&2
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -q -A -t -c "$qa288_call_b" > /tmp/qima-qa288-b.log 2>&1 &
qa288_pid_b=$!

# Both sessions must now be observed on the same exclusive tenant/key lock:
# A owns it while sleeping; B is queued on that exact advisory lock.
qa288_lock_snapshot=""
for attempt in $(seq 1 200); do
  qa288_lock_snapshot=$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(*) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text || '|' ||
      count(*) FILTER (
        WHERE NOT l.granted
          AND a.wait_event_type = 'Lock'
          AND a.wait_event = 'advisory'
      )::text || '|' ||
      count(DISTINCT (
        l.classid::text || ':' || l.objid::text || ':' || l.objsubid::text
      ))::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN ('qima-qa288-different-a', 'qima-qa288-different-b')
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$qa288_lock_snapshot" == "2|1|1|1" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$qa288_pid_a"
qa288_status_a=$?
wait "$qa288_pid_b"
qa288_status_b=$?
set -e

if [[ "$qa288_status_a" -ne 0 || ! -s /tmp/qima-qa288-a.log ]]; then
  echo "QA288 first (empty-conditions) request should complete successfully; exit=$qa288_status_a." >&2
  cat /tmp/qima-qa288-a.log /tmp/qima-qa288-b.log >&2
  exit 1
fi

if [[ "$qa288_lock_snapshot" != "2|1|1|1" ]]; then
  echo "QA288 expected A granted and B waiting on the same advisory lock; observed '$qa288_lock_snapshot'." >&2
  cat /tmp/qima-qa288-a.log /tmp/qima-qa288-b.log >&2
  exit 1
fi

if [[ "$qa288_status_b" -eq 0 ]] || ! grep -Fq "IDEMPOTENCY_KEY_REUSE" /tmp/qima-qa288-b.log; then
  echo "QA288 changed-payload concurrent request must fail with IDEMPOTENCY_KEY_REUSE (exit=$qa288_status_b)." >&2
  cat /tmp/qima-qa288-a.log /tmp/qima-qa288-b.log >&2
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa288-concurrent-different-payload'
    AND status = 'COMPLETED';
" > /tmp/qima-qa288-stored-result.log

if ! cmp -s /tmp/qima-qa288-a.log /tmp/qima-qa288-stored-result.log; then
  echo "QA288 first successful response does not match the single stored idempotency result." >&2
  diff -u /tmp/qima-qa288-a.log /tmp/qima-qa288-stored-result.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa288$
DECLARE
  v_input jsonb := '{
    "case":"qa288-concurrent-different-payload",
    "conditions":"",
    "market":"",
    "geography":"",
    "documentationStatus":""
  }'::jsonb;
  v_expected_hash text;
  v_count integer;
BEGIN
  v_expected_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'QA288 Concurrent Mismatch Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 6::numeric,
    'price', 29::numeric,
    'currency', 'USD',
    'conditions', '',
    'market', '',
    'geography', '',
    'attributes', '{}'::jsonb,
    'documentationStatus', '',
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa288-concurrent-different-payload'
    AND status = 'COMPLETED'
    AND request_hash = v_expected_hash
    AND result IS NOT NULL
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA288 expected one completed idempotency row with the first request hash, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa288-concurrent-different-payload';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA288 expected exactly one action execution after the rejected waiter, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa288-concurrent-different-payload'
    AND status = 'COMPLETED'
    AND input = v_input
    AND object_type = 'Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA288 expected the single completed execution to preserve the first empty-conditions input, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA288 Concurrent Mismatch Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND conditions = ''
    AND market = ''
    AND geography = ''
    AND documentation_status = ''
    AND attributes = '{}'::jsonb;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA288 expected exactly one offer preserving the first request and no offer for the rejected NULL request, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-qa288-concurrent-different-payload'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.object_id = x.object_id
    AND e.payload = x.result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA288 expected exactly one ACTION_SUCCEEDED event matching the first request result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-qa288-concurrent-different-payload';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA288 rejected concurrent mismatch must not create an additional event, found %', v_count;
  END IF;
END
$qa288$;
SELECT 'QA288 concurrent changed-payload request was rejected with IDEMPOTENCY_KEY_REUSE; the first completed result and its single offer/execution/event remained intact' AS result;
SQL

echo "QA288 observed A holding and B waiting on the same tenant/key advisory lock; A completed, B received IDEMPOTENCY_KEY_REUSE, and exactly one first-request offer/execution/event remained."


# QA103: the first same-tenant request owns the advisory lock, then fails
# during offer insertion. The identical second request must wake after rollback,
# acquire the released lock, and complete with the same idempotency key.
qa103_cleanup() {
  "${PSQL[@]}" <<'SQL' >/dev/null 2>&1 || true
DROP TRIGGER IF EXISTS qa103_reject_first_offer_insert ON public.offers;
DROP FUNCTION IF EXISTS public.qa103_reject_first_offer_insert_fn();
SQL
}
trap qa103_cleanup EXIT

"${PSQL[@]}" <<'SQL'
CREATE FUNCTION public.qa103_reject_first_offer_insert_fn()
RETURNS trigger
LANGUAGE plpgsql
AS $qa103fn$
BEGIN
  IF current_setting('application_name', true) = 'qima-qa103-first' THEN
    -- Keep the first transaction's advisory lock while the second queues.
    PERFORM pg_sleep(1);
    RAISE EXCEPTION USING
      ERRCODE = '23514',
      MESSAGE = 'QA103_FORCED_FIRST_ATTEMPT_FAILURE';
  END IF;
  RETURN NEW;
END;
$qa103fn$;

CREATE TRIGGER qa103_reject_first_offer_insert
BEFORE INSERT ON public.offers
FOR EACH ROW
EXECUTE FUNCTION public.qa103_reject_first_offer_insert_fn();
SQL

qa103_first_sql=$(cat <<'SQL'
SET application_name = 'qima-qa103-first';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa103-concurrent-failure-recovery',
  '{"case":"qa103-concurrent-failure-recovery"}'::jsonb,
  'QA103 Concurrent Recovery Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  3,
  23,
  'USD'
);
SQL
)

qa103_second_sql=$(cat <<'SQL'
SET application_name = 'qima-qa103-second';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa103-concurrent-failure-recovery',
  '{"case":"qa103-concurrent-failure-recovery"}'::jsonb,
  'QA103 Concurrent Recovery Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  3,
  23,
  'USD'
);
SQL
)

# Start the first request and prove it owns the advisory lock while sleeping
# before the trigger rejects its INSERT. Only then start the identical waiter.
"${PSQL_TUPLE[@]}" -v VERBOSITY=verbose -c "$qa103_first_sql" > /tmp/qima-qa103-first.log 2>&1 &
qa103_first_pid=$!

qa103_first_lock_snapshot=""
for attempt in $(seq 1 200); do
  qa103_first_lock_snapshot=$("${PSQL[@]}" -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(*) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name = 'qima-qa103-first'
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$qa103_first_lock_snapshot" == "1|1" ]]; then
    break
  fi
  sleep 0.025
done

if [[ "$qa103_first_lock_snapshot" != "1|1" ]]; then
  set +e
  wait "$qa103_first_pid"
  qa103_first_status=$?
  set -e
  echo "QA103 first request never exposed its granted advisory lock during PgSleep (snapshot='$qa103_first_lock_snapshot', exit=$qa103_first_status)." >&2
  cat /tmp/qima-qa103-first.log >&2
  exit 1
fi

"${PSQL_TUPLE[@]}" -c "$qa103_second_sql" > /tmp/qima-qa103-second.log 2>&1 &
qa103_second_pid=$!

# Require the first request to hold the lock while the identical second
# request is demonstrably waiting for that same tenant/key lock.
qa103_lock_snapshot=""
for attempt in $(seq 1 200); do
  qa103_lock_snapshot=$("${PSQL[@]}" -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(*) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text || '|' ||
      count(*) FILTER (
        WHERE NOT l.granted
          AND a.wait_event_type = 'Lock'
          AND a.wait_event = 'advisory'
      )::text || '|' ||
      count(DISTINCT (
        l.classid::text || ':' || l.objid::text || ':' || l.objsubid::text
      ))::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN ('qima-qa103-first', 'qima-qa103-second')
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$qa103_lock_snapshot" == "2|1|1|1" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$qa103_first_pid"
qa103_first_status=$?
wait "$qa103_second_pid"
qa103_second_status=$?
set -e

if [[ "$qa103_first_status" -eq 0 || "$qa103_second_status" -ne 0 ]]; then
  echo "Expected QA103 first request to fail and queued second request to succeed (first=$qa103_first_status, second=$qa103_second_status)." >&2
  cat /tmp/qima-qa103-first.log /tmp/qima-qa103-second.log >&2
  exit 1
fi

if [[ "$qa103_lock_snapshot" != "2|1|1|1" ]]; then
  echo "Expected QA103 one granted and one waiting advisory lock for one key; observed '$qa103_lock_snapshot'." >&2
  cat /tmp/qima-qa103-first.log /tmp/qima-qa103-second.log >&2
  exit 1
fi

if ! grep -Fq "QA103_FORCED_FIRST_ATTEMPT_FAILURE" /tmp/qima-qa103-first.log ||
   ! grep -Fq "23514: QA103_FORCED_FIRST_ATTEMPT_FAILURE" /tmp/qima-qa103-first.log; then
  echo "QA103 first request did not fail with the exact synthetic SQLSTATE 23514." >&2
  cat /tmp/qima-qa103-first.log >&2
  exit 1
fi

if [[ ! -s /tmp/qima-qa103-second.log ]]; then
  echo "QA103 queued second request did not return a JSONB result." >&2
  cat /tmp/qima-qa103-second.log >&2
  exit 1
fi

echo "QA103 observed one granted and one waiting advisory lock; first request rolled back with SQLSTATE 23514 and second request succeeded."

# Remove the CI-only trigger before replay and verify that both temporary
# database objects are gone. The EXIT trap remains as a failure-safe cleanup.
"${PSQL[@]}" <<'SQL'
DROP TRIGGER qa103_reject_first_offer_insert ON public.offers;
DROP FUNCTION public.qa103_reject_first_offer_insert_fn();

DO $qa103_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgrelid = 'public.offers'::regclass
      AND tgname = 'qa103_reject_first_offer_insert'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'QA103 temporary trigger was not removed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'qa103_reject_first_offer_insert_fn'
  ) THEN
    RAISE EXCEPTION 'QA103 temporary trigger function was not removed';
  END IF;
END
$qa103_cleanup$;
SQL
trap - EXIT

qa103_replay_sql=$(cat <<'SQL'
SET application_name = 'qima-qa103-replay';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa103-concurrent-failure-recovery',
  '{"case":"qa103-concurrent-failure-recovery"}'::jsonb,
  'QA103 Concurrent Recovery Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  3,
  23,
  'USD'
);
SQL
)

"${PSQL_TUPLE[@]}" -c "$qa103_replay_sql" > /tmp/qima-qa103-replay.log
if ! cmp -s /tmp/qima-qa103-second.log /tmp/qima-qa103-replay.log; then
  echo "QA103 replay did not return the exact result produced by the queued second request." >&2
  diff -u /tmp/qima-qa103-second.log /tmp/qima-qa103-replay.log >&2 || true
  exit 1
fi

"${PSQL_TUPLE[@]}" -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa103-concurrent-failure-recovery'
    AND status = 'COMPLETED';
" > /tmp/qima-qa103-stored-result.log

if ! cmp -s /tmp/qima-qa103-replay.log /tmp/qima-qa103-stored-result.log; then
  echo "QA103 replay result does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa103-replay.log /tmp/qima-qa103-stored-result.log >&2 || true
  exit 1
fi

"${PSQL[@]}" <<'SQL'
DO $qa103$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa103-concurrent-failure-recovery'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one completed QA103 idempotency key, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa103-concurrent-failure-recovery'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one completed QA103 execution, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA103 Concurrent Recovery Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one QA103 offer after recovery, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-qa103-concurrent-failure-recovery'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.object_id = x.object_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one QA103 ACTION_SUCCEEDED event, found %', v_count;
  END IF;
END
$qa103$;
SELECT 'CREATE_OFFER queued same-tenant request recovered after first rollback and replayed without duplicates' AS result;
SQL
echo "CREATE_OFFER queued same-tenant failure-recovery assertions passed."

# QA104: the first same-key request owns the advisory lock and rolls back;
# a queued request with a different effective payload must become the winner.
qa104_cleanup() {
  "${PSQL[@]}" <<'SQL' >/dev/null 2>&1 || true
DROP TRIGGER IF EXISTS qa104_reject_first_offer_insert ON public.offers;
DROP FUNCTION IF EXISTS public.qa104_reject_first_offer_insert_fn();
SQL
}
trap qa104_cleanup EXIT

"${PSQL[@]}" <<'SQL'
CREATE FUNCTION public.qa104_reject_first_offer_insert_fn()
RETURNS trigger
LANGUAGE plpgsql
AS $qa104fn$
BEGIN
  IF current_setting('application_name', true) = 'qima-qa104-first' THEN
    -- Keep the first request's lock while the different-payload request queues.
    PERFORM pg_sleep(1);
    RAISE EXCEPTION USING
      ERRCODE = '23514',
      MESSAGE = 'QA104_FORCED_FIRST_ATTEMPT_FAILURE';
  END IF;
  RETURN NEW;
END;
$qa104fn$;

CREATE TRIGGER qa104_reject_first_offer_insert
BEFORE INSERT ON public.offers
FOR EACH ROW
EXECUTE FUNCTION public.qa104_reject_first_offer_insert_fn();
SQL

qa104_first_sql=$(cat <<'SQL'
SET application_name = 'qima-qa104-first';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa104-concurrent-payload-recovery',
  '{"case":"qa104-concurrent-payload-recovery"}'::jsonb,
  'QA104 Concurrent Payload Recovery Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  3,
  23,
  'USD'
);
SQL
)

qa104_second_sql=$(cat <<'SQL'
SET application_name = 'qima-qa104-second';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa104-concurrent-payload-recovery',
  '{"case":"qa104-concurrent-payload-recovery"}'::jsonb,
  'QA104 Concurrent Payload Recovery Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  3,
  24,
  'USD'
);
SQL
)

# Launch the first request and wait until it owns the advisory lock while the
# temporary trigger sleeps. Only then launch the different-price request.
"${PSQL_TUPLE[@]}" -v VERBOSITY=verbose -c "$qa104_first_sql" > /tmp/qima-qa104-first.log 2>&1 &
qa104_first_pid=$!

qa104_first_lock_snapshot=""
for attempt in $(seq 1 200); do
  qa104_first_lock_snapshot=$("${PSQL[@]}" -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(*) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name = 'qima-qa104-first'
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$qa104_first_lock_snapshot" == "1|1" ]]; then
    break
  fi
  sleep 0.025
done

if [[ "$qa104_first_lock_snapshot" != "1|1" ]]; then
  set +e
  wait "$qa104_first_pid"
  qa104_first_status=$?
  set -e
  echo "QA104 first request never exposed its granted advisory lock during PgSleep (snapshot='$qa104_first_lock_snapshot', exit=$qa104_first_status)." >&2
  cat /tmp/qima-qa104-first.log >&2
  exit 1
fi

"${PSQL_TUPLE[@]}" -c "$qa104_second_sql" > /tmp/qima-qa104-second.log 2>&1 &
qa104_second_pid=$!

# Observe the first request holding the lock and the second request waiting
# on that exact tenant/key advisory lock before allowing the trigger to fail.
qa104_lock_snapshot=""
for attempt in $(seq 1 200); do
  qa104_lock_snapshot=$("${PSQL[@]}" -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(*) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text || '|' ||
      count(*) FILTER (
        WHERE NOT l.granted
          AND a.wait_event_type = 'Lock'
          AND a.wait_event = 'advisory'
      )::text || '|' ||
      count(DISTINCT (
        l.classid::text || ':' || l.objid::text || ':' || l.objsubid::text
      ))::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN ('qima-qa104-first', 'qima-qa104-second')
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$qa104_lock_snapshot" == "2|1|1|1" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$qa104_first_pid"
qa104_first_status=$?
wait "$qa104_second_pid"
qa104_second_status=$?
set -e

if [[ "$qa104_first_status" -eq 0 || "$qa104_second_status" -ne 0 ]]; then
  echo "Expected QA104 first request to fail and queued different-payload request to succeed (first=$qa104_first_status, second=$qa104_second_status)." >&2
  cat /tmp/qima-qa104-first.log /tmp/qima-qa104-second.log >&2
  exit 1
fi

if [[ "$qa104_lock_snapshot" != "2|1|1|1" ]]; then
  echo "Expected QA104 one granted and one waiting advisory lock for one key; observed '$qa104_lock_snapshot'." >&2
  cat /tmp/qima-qa104-first.log /tmp/qima-qa104-second.log >&2
  exit 1
fi

if ! grep -Fq "QA104_FORCED_FIRST_ATTEMPT_FAILURE" /tmp/qima-qa104-first.log ||
   ! grep -Fq "23514: QA104_FORCED_FIRST_ATTEMPT_FAILURE" /tmp/qima-qa104-first.log; then
  echo "QA104 first request did not fail with the exact synthetic SQLSTATE 23514." >&2
  cat /tmp/qima-qa104-first.log >&2
  exit 1
fi

if [[ ! -s /tmp/qima-qa104-second.log ]]; then
  echo "QA104 queued second request did not return a JSONB result." >&2
  cat /tmp/qima-qa104-second.log >&2
  exit 1
fi

echo "QA104 observed one granted and one waiting advisory lock; first payload rolled back and the queued different payload succeeded."

# Remove the CI-only trigger before replay/conflict checks and verify cleanup.
"${PSQL[@]}" <<'SQL'
DROP TRIGGER qa104_reject_first_offer_insert ON public.offers;
DROP FUNCTION public.qa104_reject_first_offer_insert_fn();

DO $qa104_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.offers'::regclass
      AND tgname = 'qa104_reject_first_offer_insert'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'QA104 temporary trigger was not removed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'qa104_reject_first_offer_insert_fn'
  ) THEN
    RAISE EXCEPTION 'QA104 temporary trigger function was not removed';
  END IF;
END
$qa104_cleanup$;
SQL
trap - EXIT

qa104_second_replay_sql=$(cat <<'SQL'
SET application_name = 'qima-qa104-second-replay';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa104-concurrent-payload-recovery',
  '{"case":"qa104-concurrent-payload-recovery"}'::jsonb,
  'QA104 Concurrent Payload Recovery Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  3,
  24,
  'USD'
);
SQL
)

"${PSQL_TUPLE[@]}" -c "$qa104_second_replay_sql" > /tmp/qima-qa104-second-replay.log
if ! cmp -s /tmp/qima-qa104-second.log /tmp/qima-qa104-second-replay.log; then
  echo "QA104 replay of the winning second payload did not return its exact original result." >&2
  diff -u /tmp/qima-qa104-second.log /tmp/qima-qa104-second-replay.log >&2 || true
  exit 1
fi

"${PSQL_TUPLE[@]}" -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa104-concurrent-payload-recovery'
    AND status = 'COMPLETED';
" > /tmp/qima-qa104-stored-result.log

if ! cmp -s /tmp/qima-qa104-second-replay.log /tmp/qima-qa104-stored-result.log; then
  echo "QA104 winning payload replay does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa104-second-replay.log /tmp/qima-qa104-stored-result.log >&2 || true
  exit 1
fi

# Replaying the first (price 23) payload against the now-completed key must
# be rejected, proving the queued second (price 24) payload owns the key.
set +e
"${PSQL_TUPLE[@]}" -v VERBOSITY=verbose -c "$qa104_first_sql" > /tmp/qima-qa104-first-payload-replay.log 2>&1
qa104_first_replay_status=$?
set -e

if [[ "$qa104_first_replay_status" -eq 0 ]] ||
   ! grep -Fq "IDEMPOTENCY_KEY_REUSE" /tmp/qima-qa104-first-payload-replay.log; then
  echo "QA104 replay of the rolled-back first payload was not rejected with IDEMPOTENCY_KEY_REUSE." >&2
  cat /tmp/qima-qa104-first-payload-replay.log >&2
  exit 1
fi

"${PSQL[@]}" <<'SQL'
DO $qa104$
DECLARE
  v_count integer;
  v_price numeric;
  v_request_hash text;
  v_expected_second_hash text;
  v_expected_first_hash text;
  v_execution_id uuid;
  v_result jsonb;
  v_offer_id uuid;
BEGIN
  v_expected_second_hash := md5(jsonb_build_object(
    'input', '{"case":"qa104-concurrent-payload-recovery"}'::jsonb,
    'name', 'QA104 Concurrent Payload Recovery Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 3,
    'price', 24,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  )::text);

  v_expected_first_hash := md5(jsonb_build_object(
    'input', '{"case":"qa104-concurrent-payload-recovery"}'::jsonb,
    'name', 'QA104 Concurrent Payload Recovery Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 3,
    'price', 23,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  )::text);

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa104-concurrent-payload-recovery';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA104 expected exactly one idempotency row, found %', v_count;
  END IF;

  SELECT request_hash, execution_id, result
  INTO v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa104-concurrent-payload-recovery'
    AND status = 'COMPLETED';

  IF v_request_hash IS DISTINCT FROM v_expected_second_hash THEN
    RAISE EXCEPTION 'QA104 stored request hash does not belong to the winning second payload';
  END IF;
  IF v_request_hash = v_expected_first_hash THEN
    RAISE EXCEPTION 'QA104 rolled-back first payload unexpectedly owns the idempotency key';
  END IF;

  v_offer_id := (v_result->>'objectId')::uuid;
  SELECT count(*), max(price) INTO v_count, v_price
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA104 Concurrent Payload Recovery Offer';
  IF v_count <> 1 OR v_price IS DISTINCT FROM 24 THEN
    RAISE EXCEPTION 'QA104 expected exactly one winning offer at price 24, found count %, price %', v_count, v_price;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA104 Concurrent Payload Recovery Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA104 expected no residual offer from the first payload, found % offers', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa104-concurrent-payload-recovery'
    AND id = v_execution_id
    AND status = 'COMPLETED'
    AND result = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA104 expected exactly one completed execution matching the winning result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-qa104-concurrent-payload-recovery'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.object_id = v_offer_id
    AND e.payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA104 expected exactly one success event matching the winning result, found %', v_count;
  END IF;
END
$qa104$;
SQL

echo "CREATE_OFFER queued different-payload recovery, winning-hash ownership, exact replay and IDEMPOTENCY_KEY_REUSE assertions passed."


# Race the same key in two tenants at once, using distinct authenticated users
# and provider actors. The fixture delay makes simultaneous advisory-lock
# ownership observable without relying on elapsed-time thresholds.
"${PSQL[@]}" <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES (
  '50000000-0000-4000-8000-000000000004',
  'Concurrent Intertenant Demand A',
  'published',
  '30000000-0000-4000-8000-000000000001'
);
SQL

call_sql_a=$(cat <<'SQL'
SET application_name = 'qima-intertenant-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-concurrent-intertenant',
  '{"case":"intertenant-concurrent"}'::jsonb,
  'Concurrent Intertenant Offer A',
  '50000000-0000-4000-8000-000000000004',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  2,
  17,
  'USD'
);
SQL
)

call_sql_b=$(cat <<'SQL'
SET application_name = 'qima-intertenant-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000002';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000002',
  'fixture-concurrent-intertenant',
  '{"case":"intertenant-concurrent"}'::jsonb,
  'Concurrent Intertenant Offer B',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000002',
  2,
  17,
  'USD'
);
SQL
)

"${PSQL_TUPLE[@]}" -c "$call_sql_a" > /tmp/qima-intertenant-a.log &
pid_a=$!
"${PSQL_TUPLE[@]}" -c "$call_sql_b" > /tmp/qima-intertenant-b.log &
pid_b=$!

# Both sessions must be inside the fixture delay while holding distinct,
# granted advisory locks. A tenant-agnostic lock would serialize these calls
# and prevent this observation.
lock_snapshot=""
for attempt in $(seq 1 200); do
  lock_snapshot=$("${PSQL[@]}" -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(DISTINCT concat(l.classid, ':', l.objid, ':', l.objsubid))
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN ('qima-intertenant-a', 'qima-intertenant-b')
      AND a.state = 'active'
      AND a.wait_event = 'PgSleep'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock'
      AND l.granted;
  " | tr -d '[:space:]')
  if [[ "$lock_snapshot" == "2|2" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$pid_a"
status_a=$?
wait "$pid_b"
status_b=$?
set -e

if [[ "$status_a" -ne 0 || "$status_b" -ne 0 ]]; then
  echo "Inter-tenant concurrent CREATE_OFFER calls failed (A=$status_a, B=$status_b)." >&2
  cat /tmp/qima-intertenant-a.log /tmp/qima-intertenant-b.log >&2
  exit 1
fi

if [[ "$lock_snapshot" != "2|2" ]]; then
  echo "Expected two distinct granted advisory locks to be held during overlapping PgSleep; observed '$lock_snapshot'." >&2
  cat /tmp/qima-intertenant-a.log /tmp/qima-intertenant-b.log >&2
  exit 1
fi
echo "Observed two distinct granted inter-tenant advisory locks concurrently."

# Replay both successful requests after the concurrent first insert. Keep psql
# in tuples-only mode so each file contains only the returned JSONB value.
# Comparing each replay to its own first result proves tenant-local replay;
# cross-comparisons ensure neither tenant receives the other tenant's result.
"${PSQL_TUPLE[@]}" -c "$call_sql_a" > /tmp/qima-intertenant-a-replay.log
"${PSQL_TUPLE[@]}" -c "$call_sql_b" > /tmp/qima-intertenant-b-replay.log

if ! cmp -s /tmp/qima-intertenant-a.log /tmp/qima-intertenant-a-replay.log; then
  echo "Tenant A replay did not return its exact original result." >&2
  diff -u /tmp/qima-intertenant-a.log /tmp/qima-intertenant-a-replay.log >&2 || true
  exit 1
fi
if ! cmp -s /tmp/qima-intertenant-b.log /tmp/qima-intertenant-b-replay.log; then
  echo "Tenant B replay did not return its exact original result." >&2
  diff -u /tmp/qima-intertenant-b.log /tmp/qima-intertenant-b-replay.log >&2 || true
  exit 1
fi
if cmp -s /tmp/qima-intertenant-a.log /tmp/qima-intertenant-b.log; then
  echo "Expected distinct tenant A and tenant B results; received identical results." >&2
  exit 1
fi
if cmp -s /tmp/qima-intertenant-a-replay.log /tmp/qima-intertenant-b.log; then
  echo "Tenant A replay unexpectedly matches tenant B's original result." >&2
  exit 1
fi
if cmp -s /tmp/qima-intertenant-b-replay.log /tmp/qima-intertenant-a.log; then
  echo "Tenant B replay unexpectedly matches tenant A's original result." >&2
  exit 1
fi
echo "CREATE_OFFER inter-tenant replay returned each tenant's exact original result."

"${PSQL[@]}" <<'SQL'
DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-concurrent-intertenant'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected one completed idempotency row per tenant, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = 'fixture-concurrent-intertenant'
      AND actor_id = '30000000-0000-4000-8000-000000000001'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000002'
      AND key = 'fixture-concurrent-intertenant'
      AND actor_id = '30000000-0000-4000-8000-000000000002'
  ) THEN
    RAISE EXCEPTION 'Expected each tenant idempotency row to retain its own actor';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-concurrent-intertenant'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected two completed inter-tenant executions, found %', v_count;
  END IF;

  SELECT count(DISTINCT actor_id) INTO v_count
  FROM public.action_executions
  WHERE idempotency_key = 'fixture-concurrent-intertenant'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected two distinct authenticated actors, found %', v_count;
  END IF;

  SELECT count(DISTINCT request_hash) INTO v_count
  FROM public.idempotency_keys
  WHERE key = 'fixture-concurrent-intertenant'
    AND tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected distinct request hashes for the distinct actor/request pairs, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'Concurrent Intertenant Offer A',
    'Concurrent Intertenant Offer B'
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected two inter-tenant offers, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'Concurrent Intertenant Offer A'
      AND demand_id = '50000000-0000-4000-8000-000000000004'
      AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'Concurrent Intertenant Offer B'
      AND demand_id = '50000000-0000-4000-8000-000000000001'
      AND provider_actor_id = '30000000-0000-4000-8000-000000000002'
  ) THEN
    RAISE EXCEPTION 'Inter-tenant offers were not created for their expected fixture actors and demands';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.idempotency_key = 'fixture-concurrent-intertenant'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.tenant_id IN (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected one success event per concurrent tenant execution, found %', v_count;
  END IF;

  SELECT count(DISTINCT e.tenant_id) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.idempotency_key = 'fixture-concurrent-intertenant'
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected success events in both tenants, found % distinct tenants', v_count;
  END IF;
END
$$;

SELECT 'CREATE_OFFER inter-tenant concurrency assertions passed' AS result;
SQL

# Race two first-time requests in the same tenant with the same idempotency
# key but different effective request hashes (only the price differs). The
# advisory lock must serialize them: one succeeds and the other is rejected.
call_sql_conflict_a=$(cat <<'SQL'
SET application_name = 'qima-same-tenant-conflict-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-concurrent-same-tenant-conflict',
  '{"case":"same-tenant-concurrent-conflict"}'::jsonb,
  'Concurrent Same-Tenant Conflict Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  2,
  20,
  'USD'
);
SQL
)

call_sql_conflict_b=$(cat <<'SQL'
SET application_name = 'qima-same-tenant-conflict-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-concurrent-same-tenant-conflict',
  '{"case":"same-tenant-concurrent-conflict"}'::jsonb,
  'Concurrent Same-Tenant Conflict Offer',
  '50000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  2,
  21,
  'USD'
);
SQL
)

"${PSQL_TUPLE[@]}" -c "$call_sql_conflict_a" > /tmp/qima-same-tenant-conflict-a.log 2>&1 &
pid_conflict_a=$!
"${PSQL_TUPLE[@]}" -c "$call_sql_conflict_b" > /tmp/qima-same-tenant-conflict-b.log 2>&1 &
pid_conflict_b=$!

# The fixture's existing 0.5 s insert delay gives the second session time to
# queue on the same advisory lock. Require one granted and one waiting session
# for one lock key, rather than inferring overlap from elapsed time.
conflict_lock_snapshot=""
for attempt in $(seq 1 200); do
  conflict_lock_snapshot=$("${PSQL[@]}" -At -c "
    SELECT
      (count(DISTINCT a.application_name) FILTER (WHERE l.granted))::text || '|' ||
      (count(DISTINCT a.application_name) FILTER (
        WHERE NOT l.granted
          AND a.wait_event_type = 'Lock'
          AND a.wait_event = 'advisory'
      ))::text || '|' ||
      count(DISTINCT concat(l.classid, ':', l.objid, ':', l.objsubid))::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN (
      'qima-same-tenant-conflict-a',
      'qima-same-tenant-conflict-b'
    )
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$conflict_lock_snapshot" == "1|1|1" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$pid_conflict_a"
status_conflict_a=$?
wait "$pid_conflict_b"
status_conflict_b=$?
set -e

if [[ "$status_conflict_a" -eq 0 && "$status_conflict_b" -ne 0 ]]; then
  success_log=/tmp/qima-same-tenant-conflict-a.log
  failure_log=/tmp/qima-same-tenant-conflict-b.log
  winner_price=20
elif [[ "$status_conflict_b" -eq 0 && "$status_conflict_a" -ne 0 ]]; then
  success_log=/tmp/qima-same-tenant-conflict-b.log
  failure_log=/tmp/qima-same-tenant-conflict-a.log
  winner_price=21
else
  echo "Expected exactly one successful same-tenant request and one rejected request (A=$status_conflict_a, B=$status_conflict_b)." >&2
  cat /tmp/qima-same-tenant-conflict-a.log /tmp/qima-same-tenant-conflict-b.log >&2
  exit 1
fi

if [[ "$conflict_lock_snapshot" != "1|1|1" ]]; then
  echo "Expected one granted and one waiting same-key advisory lock for one lock key; observed '$conflict_lock_snapshot'." >&2
  cat /tmp/qima-same-tenant-conflict-a.log /tmp/qima-same-tenant-conflict-b.log >&2
  exit 1
fi

if ! grep -Fq "IDEMPOTENCY_KEY_REUSE" "$failure_log"; then
  echo "The losing same-tenant request did not fail with IDEMPOTENCY_KEY_REUSE." >&2
  cat "$failure_log" >&2
  exit 1
fi

if [[ ! -s "$success_log" ]]; then
  echo "The successful same-tenant request did not return a result." >&2
  exit 1
fi

"${PSQL_TUPLE[@]}" -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-same-tenant-conflict'
    AND status = 'COMPLETED';
" > /tmp/qima-same-tenant-conflict-stored-result.log

if ! cmp -s "$success_log" /tmp/qima-same-tenant-conflict-stored-result.log; then
  echo "Successful same-tenant response does not match the stored idempotency result." >&2
  diff -u "$success_log" /tmp/qima-same-tenant-conflict-stored-result.log >&2 || true
  exit 1
fi

"${PSQL[@]}" <<'SQL'
DO $qa61$
DECLARE
  v_count integer;
  v_price numeric;
  v_request_hash text;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-same-tenant-conflict';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one idempotency row after conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-concurrent-same-tenant-conflict'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected one completed idempotency row after conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-concurrent-same-tenant-conflict';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one execution for the conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-concurrent-same-tenant-conflict'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one completed execution for the conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'Concurrent Same-Tenant Conflict Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one offer after conflicting concurrent requests, found %', v_count;
  END IF;

  SELECT o.price, ik.request_hash
  INTO v_price, v_request_hash
  FROM public.idempotency_keys ik
  JOIN public.offers o ON o.id = (ik.result->>'objectId')::uuid
  WHERE ik.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND ik.key = 'fixture-concurrent-same-tenant-conflict'
    AND ik.status = 'COMPLETED';

  IF v_price NOT IN (20, 21) THEN
    RAISE EXCEPTION 'Expected the winning offer price to be 20 or 21, found %', v_price;
  END IF;

  IF v_request_hash IS DISTINCT FROM md5(jsonb_build_object(
    'input', '{"case":"same-tenant-concurrent-conflict"}'::jsonb,
    'name', 'Concurrent Same-Tenant Conflict Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2,
    'price', v_price,
    'currency', 'USD',
    'conditions', NULL,
    'market', NULL,
    'geography', NULL,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL,
    'lifecycle', NULL,
    'offerType', NULL,
    'pricingModel', NULL
  )::text) THEN
    RAISE EXCEPTION 'Stored request hash does not match the winning offer price %', v_price;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-concurrent-same-tenant-conflict'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.object_id = x.object_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one success event for the winning request, found %', v_count;
  END IF;
END
$qa61$;
SQL

echo "CREATE_OFFER same-tenant concurrent conflicting-hash assertions passed (winning price: $winner_price)."


# QA105: two distinct idempotency keys in the same tenant must hold
# independent advisory locks and progress concurrently.
qa105_cleanup() {
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL' >/dev/null 2>&1 || true
DROP TRIGGER IF EXISTS qa105_delay_distinct_key_offer_insert ON public.offers;
DROP FUNCTION IF EXISTS public.qa105_delay_distinct_key_offer_insert_fn();
SQL
}
trap qa105_cleanup EXIT

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  (
    '50000000-0000-4000-8000-000000000005',
    'QA105 Distinct Key Demand A',
    'published',
    '30000000-0000-4000-8000-000000000001'
  ),
  (
    '50000000-0000-4000-8000-000000000006',
    'QA105 Distinct Key Demand B',
    'published',
    '30000000-0000-4000-8000-000000000001'
  );

CREATE FUNCTION public.qa105_delay_distinct_key_offer_insert_fn()
RETURNS trigger
LANGUAGE plpgsql
AS $qa105fn$
BEGIN
  IF current_setting('application_name', true) IN (
    'qima-qa105-distinct-key-a',
    'qima-qa105-distinct-key-b'
  ) THEN
    -- Both transactions stay inside the offer insert while their separate
    -- tenant/key advisory locks are held.
    PERFORM pg_sleep(1);
  END IF;
  RETURN NEW;
END;
$qa105fn$;

CREATE TRIGGER qa105_delay_distinct_key_offer_insert
BEFORE INSERT ON public.offers
FOR EACH ROW
EXECUTE FUNCTION public.qa105_delay_distinct_key_offer_insert_fn();
SQL

qa105_call_a=$(cat <<'SQL'
SET application_name = 'qima-qa105-distinct-key-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa105-distinct-key-a',
  '{"case":"qa105-distinct-key-a"}'::jsonb,
  'QA105 Distinct Key Offer A',
  '50000000-0000-4000-8000-000000000005',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  2,
  31,
  'USD'
);
SQL
)

qa105_call_b=$(cat <<'SQL'
SET application_name = 'qima-qa105-distinct-key-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa105-distinct-key-b',
  '{"case":"qa105-distinct-key-b"}'::jsonb,
  'QA105 Distinct Key Offer B',
  '50000000-0000-4000-8000-000000000006',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  4,
  32,
  'USD'
);
SQL
)

# Start A first and wait until it owns its advisory lock while sleeping in
# the temporary trigger. Then start B; it must acquire a different lock.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa105_call_a" > /tmp/qima-qa105-a.log 2>&1 &
qa105_pid_a=$!

qa105_first_snapshot=""
for attempt in $(seq 1 200); do
  qa105_first_snapshot=$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(DISTINCT a.application_name) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name = 'qima-qa105-distinct-key-a'
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock'
      AND l.granted;
  " | tr -d '[:space:]')
  if [[ "$qa105_first_snapshot" == "1|1" ]]; then
    break
  fi
  sleep 0.025
done

if [[ "$qa105_first_snapshot" != "1|1" ]]; then
  set +e
  wait "$qa105_pid_a"
  qa105_status_a=$?
  set -e
  echo "QA105 first request did not expose its granted advisory lock during PgSleep (snapshot='$qa105_first_snapshot', exit=$qa105_status_a)." >&2
  cat /tmp/qima-qa105-a.log >&2
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa105_call_b" > /tmp/qima-qa105-b.log 2>&1 &
qa105_pid_b=$!

# Require both same-tenant sessions to be inside PgSleep concurrently,
# each holding a granted exclusive advisory lock, with no waiter and two
# distinct lock keys. A tenant-wide lock would fail this assertion.
qa105_lock_snapshot=""
for attempt in $(seq 1 200); do
  qa105_lock_snapshot=$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(DISTINCT a.application_name) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text || '|' ||
      count(DISTINCT a.application_name) FILTER (
        WHERE NOT l.granted
          AND a.wait_event_type = 'Lock'
          AND a.wait_event = 'advisory'
      )::text || '|' ||
      count(DISTINCT (
        l.classid::text || ':' || l.objid::text || ':' || l.objsubid::text
      )) FILTER (WHERE l.granted)::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN (
      'qima-qa105-distinct-key-a',
      'qima-qa105-distinct-key-b'
    )
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$qa105_lock_snapshot" == "2|2|0|2" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$qa105_pid_a"
qa105_status_a=$?
wait "$qa105_pid_b"
qa105_status_b=$?
set -e

if [[ "$qa105_status_a" -ne 0 || "$qa105_status_b" -ne 0 ]]; then
  echo "QA105 expected both distinct-key same-tenant requests to succeed (A=$qa105_status_a, B=$qa105_status_b)." >&2
  cat /tmp/qima-qa105-a.log /tmp/qima-qa105-b.log >&2
  exit 1
fi

if [[ "$qa105_lock_snapshot" != "2|2|0|2" ]]; then
  echo "Expected two same-tenant sessions with two granted distinct advisory locks and zero waiters; observed '$qa105_lock_snapshot'." >&2
  cat /tmp/qima-qa105-a.log /tmp/qima-qa105-b.log >&2
  exit 1
fi

if [[ ! -s /tmp/qima-qa105-a.log || ! -s /tmp/qima-qa105-b.log ]]; then
  echo "QA105 both distinct-key requests must return a JSONB result." >&2
  cat /tmp/qima-qa105-a.log /tmp/qima-qa105-b.log >&2
  exit 1
fi

if cmp -s /tmp/qima-qa105-a.log /tmp/qima-qa105-b.log; then
  echo "QA105 distinct idempotency keys unexpectedly returned identical results." >&2
  exit 1
fi

echo "QA105 observed two same-tenant sessions holding two distinct granted advisory locks concurrently (2|2|0|2)."

# Remove the temporary trigger before replay checks and verify both temporary
# database objects are gone.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DROP TRIGGER qa105_delay_distinct_key_offer_insert ON public.offers;
DROP FUNCTION public.qa105_delay_distinct_key_offer_insert_fn();

DO $qa105_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.offers'::regclass
      AND tgname = 'qa105_delay_distinct_key_offer_insert'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'QA105 temporary trigger was not removed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'qa105_delay_distinct_key_offer_insert_fn'
  ) THEN
    RAISE EXCEPTION 'QA105 temporary trigger function was not removed';
  END IF;
END
$qa105_cleanup$;
SQL
trap - EXIT

# Each request must replay its own persisted result; cross-comparisons ensure
# neither key can return the other request's offer.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa105_call_a" > /tmp/qima-qa105-a-replay.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa105_call_b" > /tmp/qima-qa105-b-replay.log

if ! cmp -s /tmp/qima-qa105-a.log /tmp/qima-qa105-a-replay.log; then
  echo "QA105 key A replay did not return its exact original result." >&2
  diff -u /tmp/qima-qa105-a.log /tmp/qima-qa105-a-replay.log >&2 || true
  exit 1
fi
if ! cmp -s /tmp/qima-qa105-b.log /tmp/qima-qa105-b-replay.log; then
  echo "QA105 key B replay did not return its exact original result." >&2
  diff -u /tmp/qima-qa105-b.log /tmp/qima-qa105-b-replay.log >&2 || true
  exit 1
fi
if cmp -s /tmp/qima-qa105-a-replay.log /tmp/qima-qa105-b.log ||
   cmp -s /tmp/qima-qa105-b-replay.log /tmp/qima-qa105-a.log; then
  echo "QA105 a replay crossed the two distinct idempotency results." >&2
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa105-distinct-key-a'
    AND status = 'COMPLETED';
" > /tmp/qima-qa105-a-stored-result.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa105-distinct-key-b'
    AND status = 'COMPLETED';
" > /tmp/qima-qa105-b-stored-result.log

if ! cmp -s /tmp/qima-qa105-a-replay.log /tmp/qima-qa105-a-stored-result.log; then
  echo "QA105 key A replay did not match its persisted result." >&2
  exit 1
fi
if ! cmp -s /tmp/qima-qa105-b-replay.log /tmp/qima-qa105-b-stored-result.log; then
  echo "QA105 key B replay did not match its persisted result." >&2
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa105$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa105-distinct-key-a',
      'fixture-qa105-distinct-key-b'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA105 expected exactly two idempotency rows, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa105-distinct-key-a',
      'fixture-qa105-distinct-key-b'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA105 expected two completed idempotency rows, found %', v_count;
  END IF;

  SELECT count(DISTINCT request_hash) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa105-distinct-key-a',
      'fixture-qa105-distinct-key-b'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA105 expected two distinct request hashes, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-qa105-distinct-key-a',
      'fixture-qa105-distinct-key-b'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA105 expected two completed executions, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'QA105 Distinct Key Offer A',
    'QA105 Distinct Key Offer B'
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA105 expected two distinct offers, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'QA105 Distinct Key Offer A'
      AND demand_id = '50000000-0000-4000-8000-000000000005'
      AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
      AND quantity = 2
      AND price = 31
      AND currency = 'USD'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'QA105 Distinct Key Offer B'
      AND demand_id = '50000000-0000-4000-8000-000000000006'
      AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
      AND quantity = 4
      AND price = 32
      AND currency = 'USD'
  ) THEN
    RAISE EXCEPTION 'QA105 offers do not retain their own request parameters';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  JOIN public.idempotency_keys k
    ON k.execution_id = x.id
   AND k.tenant_id = x.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-qa105-distinct-key-a',
      'fixture-qa105-distinct-key-b'
    )
    AND x.status = 'COMPLETED'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.object_id = x.object_id
    AND e.payload = x.result
    AND x.result = k.result;
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA105 expected exactly two correctly paired success events, found %', v_count;
  END IF;
END
$qa105$;
SQL

echo "CREATE_OFFER same-tenant distinct-key concurrency, independent replay and no-cross-result assertions passed."


# QA106: different authenticated actors in one tenant must retain
# independent tenant/key advisory locks and create independent offers.
qa106_cleanup() {
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL' >/dev/null 2>&1 || true
DROP TRIGGER IF EXISTS qa106_delay_distinct_actor_offer_insert ON public.offers;
DROP FUNCTION IF EXISTS public.qa106_delay_distinct_actor_offer_insert_fn();
SQL
}
trap qa106_cleanup EXIT

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
-- User/actor C is a synthetic second member of tenant A. This fixture only
-- supplies the membership required by the RPC; it does not define product
-- tenant-selection or business authorization policy.
INSERT INTO public.dt_memberships (tenant_id, user_id, role)
VALUES (
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000003',
  'member'
);

INSERT INTO public.profiles (id, name, actor_id, auth_user_id)
VALUES (
  '30000000-0000-4000-8000-000000000003',
  'QA106 Provider C',
  '30000000-0000-4000-8000-000000000003',
  '20000000-0000-4000-8000-000000000003'
);

INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  (
    '50000000-0000-4000-8000-000000000007',
    'QA106 Different Actor Demand A',
    'published',
    '30000000-0000-4000-8000-000000000001'
  ),
  (
    '50000000-0000-4000-8000-000000000008',
    'QA106 Different Actor Demand B',
    'published',
    '30000000-0000-4000-8000-000000000003'
  );

CREATE FUNCTION public.qa106_delay_distinct_actor_offer_insert_fn()
RETURNS trigger
LANGUAGE plpgsql
AS $qa106fn$
BEGIN
  IF current_setting('application_name', true) IN (
    'qima-qa106-actor-a',
    'qima-qa106-actor-b'
  ) THEN
    -- Keep both transactions inside the offer insert while each owns
    -- its independent tenant/key advisory lock.
    PERFORM pg_sleep(1.25);
  END IF;
  RETURN NEW;
END;
$qa106fn$;

CREATE TRIGGER qa106_delay_distinct_actor_offer_insert
BEFORE INSERT ON public.offers
FOR EACH ROW
EXECUTE FUNCTION public.qa106_delay_distinct_actor_offer_insert_fn();
SQL

qa106_call_a=$(cat <<'SQL'
SET application_name = 'qima-qa106-actor-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa106-distinct-actor-a',
  '{"case":"qa106-distinct-actor-a"}'::jsonb,
  'QA106 Distinct Actor Offer A',
  '50000000-0000-4000-8000-000000000007',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  5,
  41,
  'USD'
);
SQL
)

qa106_call_b=$(cat <<'SQL'
SET application_name = 'qima-qa106-actor-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000003';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa106-distinct-actor-b',
  '{"case":"qa106-distinct-actor-b"}'::jsonb,
  'QA106 Distinct Actor Offer B',
  '50000000-0000-4000-8000-000000000008',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000003',
  6,
  42,
  'USD'
);
SQL
)

# Start actor A and wait until it holds its tenant/key lock while sleeping.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa106_call_a" > /tmp/qima-qa106-a.log 2>&1 &
qa106_pid_a=$!

qa106_first_snapshot=""
for attempt in $(seq 1 200); do
  qa106_first_snapshot=$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(DISTINCT a.application_name) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name = 'qima-qa106-actor-a'
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock'
      AND l.granted;
  " | tr -d '[:space:]')
  if [[ "$qa106_first_snapshot" == "1|1" ]]; then
    break
  fi
  sleep 0.025
done

if [[ "$qa106_first_snapshot" != "1|1" ]]; then
  set +e
  wait "$qa106_pid_a"
  qa106_status_a=$?
  set -e
  echo "QA106 actor A did not expose its granted advisory lock during PgSleep (snapshot='$qa106_first_snapshot', exit=$qa106_status_a)." >&2
  cat /tmp/qima-qa106-a.log >&2
  exit 1
fi

# Start actor B only after A owns its lock. B belongs to the same tenant,
# but has a different auth.uid(), provider actor, demand and idempotency key.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa106_call_b" > /tmp/qima-qa106-b.log 2>&1 &
qa106_pid_b=$!

# Both actors must now hold separate granted locks while sleeping, with no
# advisory waiter. This rejects accidental tenant-wide serialization.
qa106_lock_snapshot=""
for attempt in $(seq 1 200); do
  qa106_lock_snapshot=$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -At -c "
    SELECT
      count(DISTINCT a.application_name)::text || '|' ||
      count(DISTINCT a.application_name) FILTER (
        WHERE l.granted AND a.wait_event = 'PgSleep'
      )::text || '|' ||
      count(DISTINCT a.application_name) FILTER (
        WHERE NOT l.granted
          AND a.wait_event_type = 'Lock'
          AND a.wait_event = 'advisory'
      )::text || '|' ||
      count(DISTINCT (
        l.classid::text || ':' || l.objid::text || ':' || l.objsubid::text
      )) FILTER (WHERE l.granted)::text
    FROM pg_stat_activity a
    JOIN pg_locks l ON l.pid = a.pid
    WHERE a.application_name IN (
      'qima-qa106-actor-a',
      'qima-qa106-actor-b'
    )
      AND a.state = 'active'
      AND l.locktype = 'advisory'
      AND l.mode = 'ExclusiveLock';
  " | tr -d '[:space:]')
  if [[ "$qa106_lock_snapshot" == "2|2|0|2" ]]; then
    break
  fi
  sleep 0.025
done

set +e
wait "$qa106_pid_a"
qa106_status_a=$?
wait "$qa106_pid_b"
qa106_status_b=$?
set -e

if [[ "$qa106_status_a" -ne 0 || "$qa106_status_b" -ne 0 ]]; then
  echo "QA106 expected both different actors in one tenant to succeed (A=$qa106_status_a, B=$qa106_status_b)." >&2
  cat /tmp/qima-qa106-a.log /tmp/qima-qa106-b.log >&2
  exit 1
fi

if [[ "$qa106_lock_snapshot" != "2|2|0|2" ]]; then
  echo "Expected two same-tenant actors with two granted distinct advisory locks and zero waiters; observed '$qa106_lock_snapshot'." >&2
  cat /tmp/qima-qa106-a.log /tmp/qima-qa106-b.log >&2
  exit 1
fi

if [[ ! -s /tmp/qima-qa106-a.log || ! -s /tmp/qima-qa106-b.log ]]; then
  echo "QA106 both actor-specific requests must return a JSONB result." >&2
  cat /tmp/qima-qa106-a.log /tmp/qima-qa106-b.log >&2
  exit 1
fi

if cmp -s /tmp/qima-qa106-a.log /tmp/qima-qa106-b.log; then
  echo "QA106 different actor requests unexpectedly returned identical results." >&2
  exit 1
fi

echo "QA106 observed two different authenticated actors in one tenant holding two distinct granted advisory locks concurrently (2|2|0|2)."

# Remove the CI-only trigger before replay and verify its function is gone.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DROP TRIGGER qa106_delay_distinct_actor_offer_insert ON public.offers;
DROP FUNCTION public.qa106_delay_distinct_actor_offer_insert_fn();

DO $qa106_cleanup$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.offers'::regclass
      AND tgname = 'qa106_delay_distinct_actor_offer_insert'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'QA106 temporary trigger was not removed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'qa106_delay_distinct_actor_offer_insert_fn'
  ) THEN
    RAISE EXCEPTION 'QA106 temporary trigger function was not removed';
  END IF;
END
$qa106_cleanup$;
SQL
trap - EXIT

# Replay each request under its own authenticated identity.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa106_call_a" > /tmp/qima-qa106-a-replay.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa106_call_b" > /tmp/qima-qa106-b-replay.log

if ! cmp -s /tmp/qima-qa106-a.log /tmp/qima-qa106-a-replay.log; then
  echo "QA106 actor A replay did not return its exact original result." >&2
  diff -u /tmp/qima-qa106-a.log /tmp/qima-qa106-a-replay.log >&2 || true
  exit 1
fi
if ! cmp -s /tmp/qima-qa106-b.log /tmp/qima-qa106-b-replay.log; then
  echo "QA106 actor B replay did not return its exact original result." >&2
  diff -u /tmp/qima-qa106-b.log /tmp/qima-qa106-b-replay.log >&2 || true
  exit 1
fi
if cmp -s /tmp/qima-qa106-a-replay.log /tmp/qima-qa106-b.log ||
   cmp -s /tmp/qima-qa106-b-replay.log /tmp/qima-qa106-a.log; then
  echo "QA106 a replay crossed the two actor-specific idempotency results." >&2
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa106-distinct-actor-a'
    AND status = 'COMPLETED';
" > /tmp/qima-qa106-a-stored-result.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa106-distinct-actor-b'
    AND status = 'COMPLETED';
" > /tmp/qima-qa106-b-stored-result.log

if ! cmp -s /tmp/qima-qa106-a-replay.log /tmp/qima-qa106-a-stored-result.log; then
  echo "QA106 actor A replay did not match its persisted result." >&2
  exit 1
fi
if ! cmp -s /tmp/qima-qa106-b-replay.log /tmp/qima-qa106-b-stored-result.log; then
  echo "QA106 actor B replay did not match its persisted result." >&2
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa106$
DECLARE
  v_count integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.dt_memberships m
    JOIN public.profiles p ON p.auth_user_id = m.user_id
    WHERE m.tenant_id = '10000000-0000-4000-8000-000000000001'
      AND m.user_id = '20000000-0000-4000-8000-000000000001'
      AND p.actor_id = '30000000-0000-4000-8000-000000000001'
  ) OR NOT EXISTS (
    SELECT 1
    FROM public.dt_memberships m
    JOIN public.profiles p ON p.auth_user_id = m.user_id
    WHERE m.tenant_id = '10000000-0000-4000-8000-000000000001'
      AND m.user_id = '20000000-0000-4000-8000-000000000003'
      AND p.actor_id = '30000000-0000-4000-8000-000000000003'
  ) THEN
    RAISE EXCEPTION 'QA106 expected two distinct synthetic authenticated actors to belong to the same tenant';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa106-distinct-actor-a',
      'fixture-qa106-distinct-actor-b'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA106 expected exactly two idempotency rows, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa106-distinct-actor-a',
      'fixture-qa106-distinct-actor-b'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA106 expected two completed idempotency rows, found %', v_count;
  END IF;

  SELECT count(DISTINCT actor_id) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa106-distinct-actor-a',
      'fixture-qa106-distinct-actor-b'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA106 expected two distinct idempotency actors, found %', v_count;
  END IF;

  SELECT count(DISTINCT request_hash) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa106-distinct-actor-a',
      'fixture-qa106-distinct-actor-b'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA106 expected two distinct request hashes, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-qa106-distinct-actor-a',
      'fixture-qa106-distinct-actor-b'
    )
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA106 expected two completed executions, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.action_executions x
    JOIN public.idempotency_keys k
      ON k.execution_id = x.id
     AND k.tenant_id = x.tenant_id
    WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
      AND x.idempotency_key = 'fixture-qa106-distinct-actor-a'
      AND x.actor_id = '30000000-0000-4000-8000-000000000001'
      AND k.actor_id = x.actor_id
      AND x.result = k.result
  ) OR NOT EXISTS (
    SELECT 1
    FROM public.action_executions x
    JOIN public.idempotency_keys k
      ON k.execution_id = x.id
     AND k.tenant_id = x.tenant_id
    WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
      AND x.idempotency_key = 'fixture-qa106-distinct-actor-b'
      AND x.actor_id = '30000000-0000-4000-8000-000000000003'
      AND k.actor_id = x.actor_id
      AND x.result = k.result
  ) THEN
    RAISE EXCEPTION 'QA106 execution/idempotency actor ownership or result pairing is incorrect';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'QA106 Distinct Actor Offer A',
    'QA106 Distinct Actor Offer B'
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA106 expected exactly two actor-specific offers, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'QA106 Distinct Actor Offer A'
      AND demand_id = '50000000-0000-4000-8000-000000000007'
      AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
      AND quantity = 5 AND price = 41 AND currency = 'USD'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'QA106 Distinct Actor Offer B'
      AND demand_id = '50000000-0000-4000-8000-000000000008'
      AND provider_actor_id = '30000000-0000-4000-8000-000000000003'
      AND quantity = 6 AND price = 42 AND currency = 'USD'
  ) THEN
    RAISE EXCEPTION 'QA106 offers do not retain their own actor, demand, quantity and price';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  JOIN public.idempotency_keys k
    ON k.execution_id = x.id
   AND k.tenant_id = x.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-qa106-distinct-actor-a',
      'fixture-qa106-distinct-actor-b'
    )
    AND x.status = 'COMPLETED'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.actor_id = x.actor_id
    AND e.object_id = x.object_id
    AND e.payload = x.result
    AND x.result = k.result;
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA106 expected two correctly paired actor-specific success events, found %', v_count;
  END IF;
END
$qa106$;
SQL

echo "CREATE_OFFER same-tenant distinct-actor concurrency, independent replay and actor/result ownership assertions passed."

# QA107: characterize one tenant-scoped idempotency key reused by two
# different authenticated actors. The first actor owns the completed result;
# the second actor's valid but different request must be rejected without
# receiving the first actor's result or creating any additional rows.
"${PSQL[@]}" <<'SQL'
DO $qa107_preconditions$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.dt_memberships m
    JOIN public.profiles p ON p.auth_user_id = m.user_id
    WHERE m.tenant_id = '10000000-0000-4000-8000-000000000001'
      AND m.user_id = '20000000-0000-4000-8000-000000000001'
      AND p.actor_id = '30000000-0000-4000-8000-000000000001'
  ) OR NOT EXISTS (
    SELECT 1
    FROM public.dt_memberships m
    JOIN public.profiles p ON p.auth_user_id = m.user_id
    WHERE m.tenant_id = '10000000-0000-4000-8000-000000000001'
      AND m.user_id = '20000000-0000-4000-8000-000000000003'
      AND p.actor_id = '30000000-0000-4000-8000-000000000003'
  ) THEN
    RAISE EXCEPTION 'QA107 requires two distinct synthetic actors with membership in the same tenant';
  END IF;
END
$qa107_preconditions$;

INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES (
  '50000000-0000-4000-8000-000000000009',
  'QA107 Shared Actor Test Demand',
  'published',
  '30000000-0000-4000-8000-000000000001'
);
SQL

qa107_call_a=$(cat <<'SQL'
SET application_name = 'qima-qa107-actor-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa107-shared-tenant-key',
  '{"case":"qa107-shared-key-actor-a"}'::jsonb,
  'QA107 Shared Key Offer A',
  '50000000-0000-4000-8000-000000000009',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  7,
  43,
  'USD'
);
SQL
)

qa107_call_b=$(cat <<'SQL'
SET application_name = 'qima-qa107-actor-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000003';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa107-shared-tenant-key',
  '{"case":"qa107-shared-key-actor-a"}'::jsonb,
  'QA107 Shared Key Offer A',
  '50000000-0000-4000-8000-000000000009',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000003',
  7,
  43,
  'USD'
);
SQL
)

# Actor A completes the tenant/key pair first and becomes its persisted owner.
"${PSQL_TUPLE[@]}" -c "$qa107_call_a" > /tmp/qima-qa107-actor-a-first.log
if [[ ! -s /tmp/qima-qa107-actor-a-first.log ]]; then
  echo "QA107 first actor did not return its successful CREATE_OFFER result." >&2
  exit 1
fi

# Actor B is a valid member with a valid provider_actor_id. Every effective
# RPC parameter is identical except providerActorId, so the request hash must
# differ solely because the authenticated actor owns a different provider actor.
set +e
"${PSQL_TUPLE[@]}" -v VERBOSITY=verbose -c "$qa107_call_b" > /tmp/qima-qa107-actor-b-reuse.log 2>&1
qa107_actor_b_status=$?
set -e

if [[ "$qa107_actor_b_status" -eq 0 ]] ||
   ! grep -Fq "IDEMPOTENCY_KEY_REUSE" /tmp/qima-qa107-actor-b-reuse.log; then
  echo "QA107 second actor did not receive the expected IDEMPOTENCY_KEY_REUSE rejection." >&2
  cat /tmp/qima-qa107-actor-b-reuse.log >&2
  exit 1
fi

# The original actor must still be able to replay the exact persisted result.
"${PSQL_TUPLE[@]}" -c "$qa107_call_a" > /tmp/qima-qa107-actor-a-replay.log
if ! cmp -s /tmp/qima-qa107-actor-a-first.log /tmp/qima-qa107-actor-a-replay.log; then
  echo "QA107 original actor replay did not return the exact first result." >&2
  diff -u /tmp/qima-qa107-actor-a-first.log /tmp/qima-qa107-actor-a-replay.log >&2 || true
  exit 1
fi

"${PSQL_TUPLE[@]}" -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa107-shared-tenant-key'
    AND status = 'COMPLETED';
" > /tmp/qima-qa107-stored-result.log

if ! cmp -s /tmp/qima-qa107-actor-a-first.log /tmp/qima-qa107-stored-result.log; then
  echo "QA107 first actor result does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa107-actor-a-first.log /tmp/qima-qa107-stored-result.log >&2 || true
  exit 1
fi

"${PSQL[@]}" <<'SQL'
DO $qa107$
DECLARE
  v_count integer;
  v_actor_id uuid;
  v_request_hash text;
  v_expected_actor_a_hash text;
  v_expected_actor_b_hash text;
  v_execution_id uuid;
  v_result jsonb;
  v_offer_id uuid;
BEGIN
  v_expected_actor_a_hash := md5(jsonb_build_object(
    'input', '{"case":"qa107-shared-key-actor-a"}'::jsonb,
    'name', 'QA107 Shared Key Offer A',
    'demandId', '50000000-0000-4000-8000-000000000009'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 7::numeric,
    'price', 43::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  v_expected_actor_b_hash := md5(jsonb_build_object(
    'input', '{"case":"qa107-shared-key-actor-a"}'::jsonb,
    'name', 'QA107 Shared Key Offer A',
    'demandId', '50000000-0000-4000-8000-000000000009'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000003'::uuid,
    'quantity', 7::numeric,
    'price', 43::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', '{}'::jsonb,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  IF v_expected_actor_a_hash = v_expected_actor_b_hash THEN
    RAISE EXCEPTION 'QA107 expected actor A and actor B request hashes to differ';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa107-shared-tenant-key';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA107 expected exactly one shared tenant/key row, found %', v_count;
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa107-shared-tenant-key'
    AND status = 'COMPLETED';

  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid THEN
    RAISE EXCEPTION 'QA107 shared key owner is not the first authenticated actor';
  END IF;
  IF v_request_hash IS DISTINCT FROM v_expected_actor_a_hash THEN
    RAISE EXCEPTION 'QA107 persisted request hash does not match the first actor payload';
  END IF;
  IF v_request_hash = v_expected_actor_b_hash THEN
    RAISE EXCEPTION 'QA107 second actor request hash unexpectedly owns the shared key';
  END IF;
  IF v_result ->> 'status' IS DISTINCT FROM 'succeeded'
     OR v_result ->> 'objectType' IS DISTINCT FROM 'Offer' THEN
    RAISE EXCEPTION 'QA107 persisted result is not the first actor successful Offer result';
  END IF;

  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa107-shared-tenant-key';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA107 expected exactly one execution for the shared key, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.action_executions
    WHERE id = v_execution_id
      AND tenant_id = '10000000-0000-4000-8000-000000000001'
      AND idempotency_key = 'fixture-qa107-shared-tenant-key'
      AND actor_id = '30000000-0000-4000-8000-000000000001'
      AND status = 'COMPLETED'
      AND object_id = v_offer_id
      AND result = v_result
  ) THEN
    RAISE EXCEPTION 'QA107 execution does not preserve the first actor and result';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'QA107 Shared Key Offer A',
    'QA107 Shared Key Offer B'
  );
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA107 expected only the first actor offer to persist, found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.offers
    WHERE id = v_offer_id
      AND name = 'QA107 Shared Key Offer A'
      AND demand_id = '50000000-0000-4000-8000-000000000009'
      AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
      AND quantity = 7
      AND price = 43
      AND currency = 'USD'
  ) OR EXISTS (
    SELECT 1 FROM public.offers
    WHERE name = 'QA107 Shared Key Offer B'
  ) THEN
    RAISE EXCEPTION 'QA107 persisted offer is not exclusively the first actor offer';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-qa107-shared-tenant-key'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.actor_id = '30000000-0000-4000-8000-000000000001'
    AND e.object_id = v_offer_id
    AND e.payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA107 expected exactly one success event for the first actor, found %', v_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.action_executions
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND idempotency_key = 'fixture-qa107-shared-tenant-key'
      AND actor_id = '30000000-0000-4000-8000-000000000003'
  ) OR EXISTS (
    SELECT 1
    FROM public.action_events
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND actor_id = '30000000-0000-4000-8000-000000000003'
      AND payload = v_result
  ) THEN
    RAISE EXCEPTION 'QA107 second actor unexpectedly owns an execution or success event';
  END IF;
END
$qa107$;
SQL

echo "CREATE_OFFER same-tenant shared-key cross-actor reuse is rejected; first actor ownership, hash, result and exact replay remain intact."


# QA108: JSONB object key order must not change the effective request hash.
# The same tenant, actor, key and business values are replayed with reordered
# keys in both p_input and p_attributes. JSONB semantics should canonicalize
# the objects, preserving the hash and the exact persisted result.
"${PSQL[@]}" <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES (
  '50000000-0000-4000-8000-000000000010',
  'QA108 JSONB Canonicalization Demand',
  'published',
  '30000000-0000-4000-8000-000000000001'
);
SQL

qa108_call_a=$(cat <<'SQL'
SET application_name = 'qima-qa108-jsonb-order-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa108-jsonb-key-order',
  '{"alpha":1,"nested":{"left":"L","right":"R"},"omega":[1,2]}'::jsonb,
  'QA108 JSONB Canonicalization Offer',
  '50000000-0000-4000-8000-000000000010',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  8,
  44,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"dimensions":{"height":12,"width":7},"labels":["one","two"],"metadata":{"grade":"A","origin":"MA"}}'::jsonb
);
SQL
)

qa108_call_b=$(cat <<'SQL'
SET application_name = 'qima-qa108-jsonb-order-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa108-jsonb-key-order',
  '{"omega":[1,2],"nested":{"right":"R","left":"L"},"alpha":1}'::jsonb,
  'QA108 JSONB Canonicalization Offer',
  '50000000-0000-4000-8000-000000000010',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  8,
  44,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"metadata":{"origin":"MA","grade":"A"},"labels":["one","two"],"dimensions":{"width":7,"height":12}}'::jsonb
);
SQL
)

# The first request creates the offer. The reordered request must be treated
# as the same JSONB value and return the already-persisted result.
"${PSQL_TUPLE[@]}" -c "$qa108_call_a" > /tmp/qima-qa108-first.log
"${PSQL_TUPLE[@]}" -c "$qa108_call_b" > /tmp/qima-qa108-reordered-replay.log
if ! cmp -s /tmp/qima-qa108-first.log /tmp/qima-qa108-reordered-replay.log; then
  echo "QA108 reordered JSONB request did not return the exact persisted result." >&2
  diff -u /tmp/qima-qa108-first.log /tmp/qima-qa108-reordered-replay.log >&2 || true
  exit 1
fi

"${PSQL_TUPLE[@]}" -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa108-jsonb-key-order'
    AND status = 'COMPLETED';
" > /tmp/qima-qa108-stored-result.log
if ! cmp -s /tmp/qima-qa108-first.log /tmp/qima-qa108-stored-result.log; then
  echo "QA108 first response does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa108-first.log /tmp/qima-qa108-stored-result.log >&2 || true
  exit 1
fi

"${PSQL[@]}" <<'SQL'
DO $qa108$
DECLARE
  v_input_a jsonb := '{"alpha":1,"nested":{"left":"L","right":"R"},"omega":[1,2]}'::jsonb;
  v_input_b jsonb := '{"omega":[1,2],"nested":{"right":"R","left":"L"},"alpha":1}'::jsonb;
  v_attributes_a jsonb := '{"dimensions":{"height":12,"width":7},"labels":["one","two"],"metadata":{"grade":"A","origin":"MA"}}'::jsonb;
  v_attributes_b jsonb := '{"metadata":{"origin":"MA","grade":"A"},"labels":["one","two"],"dimensions":{"width":7,"height":12}}'::jsonb;
  v_expected_hash_a text;
  v_expected_hash_b text;
  v_request_hash text;
  v_actor_id uuid;
  v_execution_id uuid;
  v_result jsonb;
  v_execution_input jsonb;
  v_offer_attributes jsonb;
  v_offer_id uuid;
  v_count integer;
BEGIN
  IF v_input_a IS DISTINCT FROM v_input_b
     OR v_attributes_a IS DISTINCT FROM v_attributes_b THEN
    RAISE EXCEPTION 'QA108 reordered JSONB objects are not semantically equal';
  END IF;

  v_expected_hash_a := md5(jsonb_build_object(
    'input', v_input_a,
    'name', 'QA108 JSONB Canonicalization Offer',
    'demandId', '50000000-0000-4000-8000-000000000010'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 8::numeric,
    'price', 44::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', v_attributes_a,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  v_expected_hash_b := md5(jsonb_build_object(
    'input', v_input_b,
    'name', 'QA108 JSONB Canonicalization Offer',
    'demandId', '50000000-0000-4000-8000-000000000010'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 8::numeric,
    'price', 44::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', v_attributes_b,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  IF v_expected_hash_a IS DISTINCT FROM v_expected_hash_b THEN
    RAISE EXCEPTION 'QA108 equivalent JSONB key orders produced different expected request hashes';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa108-jsonb-key-order'
    AND status = 'COMPLETED';

  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM v_expected_hash_a THEN
    RAISE EXCEPTION 'QA108 persisted actor or request hash does not match the canonical JSONB request';
  END IF;

  IF v_result ->> 'status' IS DISTINCT FROM 'succeeded'
     OR v_result ->> 'objectType' IS DISTINCT FROM 'Offer' THEN
    RAISE EXCEPTION 'QA108 persisted result is not a successful Offer result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa108-jsonb-key-order';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA108 expected exactly one idempotency key, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa108-jsonb-key-order'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA108 expected exactly one completed execution, found %', v_count;
  END IF;

  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_input_a THEN
    RAISE EXCEPTION 'QA108 persisted execution input does not match the canonical JSONB value';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA108 JSONB Canonicalization Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA108 expected exactly one offer row for the canonical request, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA108 JSONB Canonicalization Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000010'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 8
    AND price = 44
    AND currency = 'USD';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA108 expected exactly one correctly attributed offer, found %', v_count;
  END IF;

  SELECT attributes INTO v_offer_attributes
  FROM public.offers
  WHERE id = v_offer_id;
  IF v_offer_attributes IS DISTINCT FROM v_attributes_a THEN
    RAISE EXCEPTION 'QA108 persisted offer attributes do not match the canonical JSONB value';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.id = v_execution_id
    AND x.idempotency_key = 'fixture-qa108-jsonb-key-order'
    AND e.event_type = 'ACTION_SUCCEEDED'
    AND e.actor_id = '30000000-0000-4000-8000-000000000001'
    AND e.object_id = v_offer_id
    AND e.payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA108 expected exactly one success event for the canonical JSONB request, found %', v_count;
  END IF;
END
$qa108$;
SQL

echo "CREATE_OFFER JSONB object key reordering preserves request hash, persisted input/attributes and exact idempotent replay."

# QA109: JSONB array element order is significant for request idempotency.
# Two isolated cases cover arrays in p_input and p_attributes. Reversing an
# array while keeping every other effective parameter unchanged must produce
# a different request hash and IDEMPOTENCY_KEY_REUSE, preserving the first
# successful result and offer.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  (
    '50000000-0000-4000-8000-000000000011',
    'QA109 Input Array Order Demand',
    'published',
    '30000000-0000-4000-8000-000000000001'
  ),
  (
    '50000000-0000-4000-8000-000000000012',
    'QA109 Attributes Array Order Demand',
    'published',
    '30000000-0000-4000-8000-000000000001'
  );
SQL

qa109_input_call_a=$(cat <<'SQL'
SET application_name = 'qima-qa109-input-array-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa109-input-array-order',
  '{"context":{"case":"input-array-order"},"steps":["A","B","C"]}'::jsonb,
  'QA109 Input Array Order Offer',
  '50000000-0000-4000-8000-000000000011',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  9,
  45,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"labels":["stable","order"],"metadata":{"source":"qa109"}}'::jsonb
);
SQL
)

qa109_input_call_b=$(cat <<'SQL'
SET application_name = 'qima-qa109-input-array-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa109-input-array-order',
  '{"steps":["C","B","A"],"context":{"case":"input-array-order"}}'::jsonb,
  'QA109 Input Array Order Offer',
  '50000000-0000-4000-8000-000000000011',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  9,
  45,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"labels":["stable","order"],"metadata":{"source":"qa109"}}'::jsonb
);
SQL
)

qa109_attributes_call_a=$(cat <<'SQL'
SET application_name = 'qima-qa109-attributes-array-a';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa109-attributes-array-order',
  '{"context":{"case":"attributes-array-order"}}'::jsonb,
  'QA109 Attributes Array Order Offer',
  '50000000-0000-4000-8000-000000000012',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  10,
  46,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"labels":["red","green","blue"],"metadata":{"source":"qa109"}}'::jsonb
);
SQL
)

qa109_attributes_call_b=$(cat <<'SQL'
SET application_name = 'qima-qa109-attributes-array-b';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa109-attributes-array-order',
  '{"context":{"case":"attributes-array-order"}}'::jsonb,
  'QA109 Attributes Array Order Offer',
  '50000000-0000-4000-8000-000000000012',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  10,
  46,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"metadata":{"source":"qa109"},"labels":["blue","green","red"]}'::jsonb
);
SQL
)

expect_qa109_idempotency_reuse() {
  local case_name="$1"
  local sql="$2"
  local log_file="$3"
  local call_status

  set +e
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -q -A -t -c "$sql" > "$log_file" 2>&1
  call_status=$?
  set -e

  if [[ "$call_status" -eq 0 ]] || ! grep -Fq "IDEMPOTENCY_KEY_REUSE" "$log_file"; then
    echo "QA109 $case_name reversed-array request was not rejected with IDEMPOTENCY_KEY_REUSE." >&2
    cat "$log_file" >&2
    exit 1
  fi
}

# Case 1: reverse only the array in p_input.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa109_input_call_a" > /tmp/qima-qa109-input-first.log
if [[ ! -s /tmp/qima-qa109-input-first.log ]]; then
  echo "QA109 p_input first request returned no result." >&2
  exit 1
fi
expect_qa109_idempotency_reuse "p_input" "$qa109_input_call_b" /tmp/qima-qa109-input-reversed.log

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa109_input_call_a" > /tmp/qima-qa109-input-replay.log
if ! cmp -s /tmp/qima-qa109-input-first.log /tmp/qima-qa109-input-replay.log; then
  echo "QA109 p_input original replay did not preserve the first result." >&2
  diff -u /tmp/qima-qa109-input-first.log /tmp/qima-qa109-input-replay.log >&2 || true
  exit 1
fi
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa109-input-array-order'
    AND status = 'COMPLETED';
" > /tmp/qima-qa109-input-stored.log
if ! cmp -s /tmp/qima-qa109-input-first.log /tmp/qima-qa109-input-stored.log; then
  echo "QA109 p_input first response differs from the persisted result." >&2
  diff -u /tmp/qima-qa109-input-first.log /tmp/qima-qa109-input-stored.log >&2 || true
  exit 1
fi

# Case 2: reverse only the array in p_attributes.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa109_attributes_call_a" > /tmp/qima-qa109-attributes-first.log
if [[ ! -s /tmp/qima-qa109-attributes-first.log ]]; then
  echo "QA109 p_attributes first request returned no result." >&2
  exit 1
fi
expect_qa109_idempotency_reuse "p_attributes" "$qa109_attributes_call_b" /tmp/qima-qa109-attributes-reversed.log

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa109_attributes_call_a" > /tmp/qima-qa109-attributes-replay.log
if ! cmp -s /tmp/qima-qa109-attributes-first.log /tmp/qima-qa109-attributes-replay.log; then
  echo "QA109 p_attributes original replay did not preserve the first result." >&2
  diff -u /tmp/qima-qa109-attributes-first.log /tmp/qima-qa109-attributes-replay.log >&2 || true
  exit 1
fi
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa109-attributes-array-order'
    AND status = 'COMPLETED';
" > /tmp/qima-qa109-attributes-stored.log
if ! cmp -s /tmp/qima-qa109-attributes-first.log /tmp/qima-qa109-attributes-stored.log; then
  echo "QA109 p_attributes first response differs from the persisted result." >&2
  diff -u /tmp/qima-qa109-attributes-first.log /tmp/qima-qa109-attributes-stored.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa109$
DECLARE
  v_input_a jsonb := '{"context":{"case":"input-array-order"},"steps":["A","B","C"]}'::jsonb;
  v_input_b jsonb := '{"steps":["C","B","A"],"context":{"case":"input-array-order"}}'::jsonb;
  v_input_attributes jsonb := '{"labels":["stable","order"],"metadata":{"source":"qa109"}}'::jsonb;
  v_attributes_input jsonb := '{"context":{"case":"attributes-array-order"}}'::jsonb;
  v_attributes_a jsonb := '{"labels":["red","green","blue"],"metadata":{"source":"qa109"}}'::jsonb;
  v_attributes_b jsonb := '{"metadata":{"source":"qa109"},"labels":["blue","green","red"]}'::jsonb;
  v_input_hash_a text;
  v_input_hash_b text;
  v_attributes_hash_a text;
  v_attributes_hash_b text;
  v_request_hash text;
  v_actor_id uuid;
  v_execution_id uuid;
  v_result jsonb;
  v_offer_id uuid;
  v_execution_input jsonb;
  v_offer_attributes jsonb;
  v_count integer;
BEGIN
  IF v_input_a IS NOT DISTINCT FROM v_input_b THEN
    RAISE EXCEPTION 'QA109 reversed p_input arrays unexpectedly compare equal as JSONB';
  END IF;
  IF v_attributes_a IS NOT DISTINCT FROM v_attributes_b THEN
    RAISE EXCEPTION 'QA109 reversed p_attributes arrays unexpectedly compare equal as JSONB';
  END IF;

  v_input_hash_a := md5(jsonb_build_object(
    'input', v_input_a,
    'name', 'QA109 Input Array Order Offer',
    'demandId', '50000000-0000-4000-8000-000000000011'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 9::numeric,
    'price', 45::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', v_input_attributes,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  v_input_hash_b := md5(jsonb_build_object(
    'input', v_input_b,
    'name', 'QA109 Input Array Order Offer',
    'demandId', '50000000-0000-4000-8000-000000000011'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 9::numeric,
    'price', 45::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', v_input_attributes,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  IF v_input_hash_a = v_input_hash_b THEN
    RAISE EXCEPTION 'QA109 reversed p_input array order did not change the expected request hash';
  END IF;

  v_attributes_hash_a := md5(jsonb_build_object(
    'input', v_attributes_input,
    'name', 'QA109 Attributes Array Order Offer',
    'demandId', '50000000-0000-4000-8000-000000000012'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 10::numeric,
    'price', 46::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', v_attributes_a,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  v_attributes_hash_b := md5(jsonb_build_object(
    'input', v_attributes_input,
    'name', 'QA109 Attributes Array Order Offer',
    'demandId', '50000000-0000-4000-8000-000000000012'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 10::numeric,
    'price', 46::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', v_attributes_b,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  IF v_attributes_hash_a = v_attributes_hash_b THEN
    RAISE EXCEPTION 'QA109 reversed p_attributes array order did not change the expected request hash';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa109-input-array-order'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM v_input_hash_a
     OR v_result ->> 'status' IS DISTINCT FROM 'succeeded'
     OR v_result ->> 'objectType' IS DISTINCT FROM 'Offer' THEN
    RAISE EXCEPTION 'QA109 p_input array case did not preserve the first actor, hash and successful result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa109-input-array-order';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA109 p_input array case expected one idempotency row, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa109-input-array-order'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA109 p_input array case expected one completed execution, found %', v_count;
  END IF;
  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_input_a THEN
    RAISE EXCEPTION 'QA109 p_input array case did not preserve the first input array order';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA109 Input Array Order Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA109 p_input array case expected exactly one offer, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND demand_id = '50000000-0000-4000-8000-000000000011'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 9
    AND price = 45
    AND currency = 'USD'
    AND attributes = v_input_attributes;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA109 p_input array case offer fields or attributes differ from the first request';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA109 p_input array case expected exactly one success event, found %', v_count;
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa109-attributes-array-order'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM v_attributes_hash_a
     OR v_result ->> 'status' IS DISTINCT FROM 'succeeded'
     OR v_result ->> 'objectType' IS DISTINCT FROM 'Offer' THEN
    RAISE EXCEPTION 'QA109 p_attributes array case did not preserve the first actor, hash and successful result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa109-attributes-array-order';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA109 p_attributes array case expected one idempotency row, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa109-attributes-array-order'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA109 p_attributes array case expected one completed execution, found %', v_count;
  END IF;
  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_attributes_input THEN
    RAISE EXCEPTION 'QA109 p_attributes array case did not preserve the first input';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA109 Attributes Array Order Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA109 p_attributes array case expected exactly one offer, found %', v_count;
  END IF;
  SELECT attributes INTO v_offer_attributes
  FROM public.offers
  WHERE id = v_offer_id
    AND demand_id = '50000000-0000-4000-8000-000000000012'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 10
    AND price = 46
    AND currency = 'USD';
  IF v_offer_attributes IS DISTINCT FROM v_attributes_a THEN
    RAISE EXCEPTION 'QA109 p_attributes array case did not preserve the first attributes array order';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA109 p_attributes array case expected exactly one success event, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa109-input-array-order',
      'fixture-qa109-attributes-array-order'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA109 expected exactly two idempotency rows across isolated array cases, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-qa109-input-array-order',
      'fixture-qa109-attributes-array-order'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA109 expected exactly two executions across isolated array cases, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'QA109 Input Array Order Offer',
    'QA109 Attributes Array Order Offer'
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA109 expected exactly two offers across isolated array cases, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-qa109-input-array-order',
      'fixture-qa109-attributes-array-order'
    )
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA109 expected exactly two success events across isolated array cases, found %', v_count;
  END IF;
END
$qa109$;
SQL

echo "CREATE_OFFER JSONB array ordering in p_input and p_attributes changes request hashes, rejects same-key reversed arrays, and preserves the original results without duplicates."


# QA110: a JSONB property explicitly set to JSON null differs from an absent
# property. Cover p_input and p_attributes independently with the same
# idempotency key on each pair; the second payload must be rejected while the
# first result, hash and offer remain unchanged.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  (
    '50000000-0000-4000-8000-000000000013',
    'QA110 Input Null Versus Absent Demand',
    'published',
    '30000000-0000-4000-8000-000000000001'
  ),
  (
    '50000000-0000-4000-8000-000000000014',
    'QA110 Attributes Null Versus Absent Demand',
    'published',
    '30000000-0000-4000-8000-000000000001'
  );
SQL

qa110_input_call_present=$(cat <<'SQL'
SET application_name = 'qima-qa110-input-explicit-null';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa110-input-null-vs-absent',
  '{"context":{"case":"input-null-vs-absent"},"optional":null}'::jsonb,
  'QA110 Input Null Versus Absent Offer',
  '50000000-0000-4000-8000-000000000013',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  11,
  47,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"metadata":{"source":"qa110","stable":true}}'::jsonb
);
SQL
)

qa110_input_call_absent=$(cat <<'SQL'
SET application_name = 'qima-qa110-input-absent';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa110-input-null-vs-absent',
  '{"context":{"case":"input-null-vs-absent"}}'::jsonb,
  'QA110 Input Null Versus Absent Offer',
  '50000000-0000-4000-8000-000000000013',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  11,
  47,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"metadata":{"source":"qa110","stable":true}}'::jsonb
);
SQL
)

qa110_attributes_call_present=$(cat <<'SQL'
SET application_name = 'qima-qa110-attributes-explicit-null';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa110-attributes-null-vs-absent',
  '{"context":{"case":"attributes-null-vs-absent"}}'::jsonb,
  'QA110 Attributes Null Versus Absent Offer',
  '50000000-0000-4000-8000-000000000014',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  12,
  48,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"metadata":{"source":"qa110","stable":true},"optional":null}'::jsonb
);
SQL
)

qa110_attributes_call_absent=$(cat <<'SQL'
SET application_name = 'qima-qa110-attributes-absent';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT public.execute_create_offer_v1(
  '10000000-0000-4000-8000-000000000001',
  'fixture-qa110-attributes-null-vs-absent',
  '{"context":{"case":"attributes-null-vs-absent"}}'::jsonb,
  'QA110 Attributes Null Versus Absent Offer',
  '50000000-0000-4000-8000-000000000014',
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  12,
  48,
  'USD',
  NULL,
  NULL,
  NULL,
  '{"metadata":{"source":"qa110","stable":true}}'::jsonb
);
SQL
)

expect_qa110_idempotency_reuse() {
  local case_name="$1"
  local sql="$2"
  local log_file="$3"
  local call_status

  set +e
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -q -A -t -c "$sql" > "$log_file" 2>&1
  call_status=$?
  set -e

  if [[ "$call_status" -eq 0 ]] || ! grep -Fq "IDEMPOTENCY_KEY_REUSE" "$log_file"; then
    echo "QA110 $case_name request without the explicit-null property was not rejected with IDEMPOTENCY_KEY_REUSE." >&2
    cat "$log_file" >&2
    exit 1
  fi
}

# Case 1: p_input contains optional: JSON null; retry omits optional.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa110_input_call_present" > /tmp/qima-qa110-input-first.log
if [[ ! -s /tmp/qima-qa110-input-first.log ]]; then
  echo "QA110 p_input explicit-null request returned no result." >&2
  exit 1
fi
expect_qa110_idempotency_reuse "p_input absent-property" "$qa110_input_call_absent" /tmp/qima-qa110-input-absent.log

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa110_input_call_present" > /tmp/qima-qa110-input-replay.log
if ! cmp -s /tmp/qima-qa110-input-first.log /tmp/qima-qa110-input-replay.log; then
  echo "QA110 p_input explicit-null replay did not preserve the first result." >&2
  diff -u /tmp/qima-qa110-input-first.log /tmp/qima-qa110-input-replay.log >&2 || true
  exit 1
fi
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa110-input-null-vs-absent'
    AND status = 'COMPLETED';
" > /tmp/qima-qa110-input-stored.log
if ! cmp -s /tmp/qima-qa110-input-first.log /tmp/qima-qa110-input-stored.log; then
  echo "QA110 p_input explicit-null response differs from the persisted result." >&2
  diff -u /tmp/qima-qa110-input-first.log /tmp/qima-qa110-input-stored.log >&2 || true
  exit 1
fi

# Case 2: p_attributes contains optional: JSON null; retry omits optional.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa110_attributes_call_present" > /tmp/qima-qa110-attributes-first.log
if [[ ! -s /tmp/qima-qa110-attributes-first.log ]]; then
  echo "QA110 p_attributes explicit-null request returned no result." >&2
  exit 1
fi
expect_qa110_idempotency_reuse "p_attributes absent-property" "$qa110_attributes_call_absent" /tmp/qima-qa110-attributes-absent.log

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "$qa110_attributes_call_present" > /tmp/qima-qa110-attributes-replay.log
if ! cmp -s /tmp/qima-qa110-attributes-first.log /tmp/qima-qa110-attributes-replay.log; then
  echo "QA110 p_attributes explicit-null replay did not preserve the first result." >&2
  diff -u /tmp/qima-qa110-attributes-first.log /tmp/qima-qa110-attributes-replay.log >&2 || true
  exit 1
fi
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa110-attributes-null-vs-absent'
    AND status = 'COMPLETED';
" > /tmp/qima-qa110-attributes-stored.log
if ! cmp -s /tmp/qima-qa110-attributes-first.log /tmp/qima-qa110-attributes-stored.log; then
  echo "QA110 p_attributes explicit-null response differs from the persisted result." >&2
  diff -u /tmp/qima-qa110-attributes-first.log /tmp/qima-qa110-attributes-stored.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa110$
DECLARE
  v_input_a jsonb := '{"context":{"case":"input-null-vs-absent"},"optional":null}'::jsonb;
  v_input_b jsonb := '{"context":{"case":"input-null-vs-absent"}}'::jsonb;
  v_input_attributes jsonb := '{"metadata":{"source":"qa110","stable":true}}'::jsonb;
  v_attributes_input jsonb := '{"context":{"case":"attributes-null-vs-absent"}}'::jsonb;
  v_attributes_a jsonb := '{"metadata":{"source":"qa110","stable":true},"optional":null}'::jsonb;
  v_attributes_b jsonb := '{"metadata":{"source":"qa110","stable":true}}'::jsonb;
  v_input_hash_a text;
  v_input_hash_b text;
  v_attributes_hash_a text;
  v_attributes_hash_b text;
  v_actor_id uuid;
  v_request_hash text;
  v_execution_id uuid;
  v_result jsonb;
  v_offer_id uuid;
  v_execution_input jsonb;
  v_offer_attributes jsonb;
  v_count integer;
BEGIN
  IF NOT (v_input_a ? 'optional')
     OR jsonb_typeof(v_input_a -> 'optional') IS DISTINCT FROM 'null' THEN
    RAISE EXCEPTION 'QA110 p_input explicit JSON null property was not preserved';
  END IF;
  IF v_input_b ? 'optional' OR (v_input_b -> 'optional') IS NOT NULL THEN
    RAISE EXCEPTION 'QA110 p_input absent property unexpectedly exists';
  END IF;
  IF v_input_a IS NOT DISTINCT FROM v_input_b THEN
    RAISE EXCEPTION 'QA110 p_input explicit JSON null unexpectedly equals absent property';
  END IF;

  IF NOT (v_attributes_a ? 'optional')
     OR jsonb_typeof(v_attributes_a -> 'optional') IS DISTINCT FROM 'null' THEN
    RAISE EXCEPTION 'QA110 p_attributes explicit JSON null property was not preserved';
  END IF;
  IF v_attributes_b ? 'optional' OR (v_attributes_b -> 'optional') IS NOT NULL THEN
    RAISE EXCEPTION 'QA110 p_attributes absent property unexpectedly exists';
  END IF;
  IF v_attributes_a IS NOT DISTINCT FROM v_attributes_b THEN
    RAISE EXCEPTION 'QA110 p_attributes explicit JSON null unexpectedly equals absent property';
  END IF;

  v_input_hash_a := md5(jsonb_build_object(
    'input', v_input_a,
    'name', 'QA110 Input Null Versus Absent Offer',
    'demandId', '50000000-0000-4000-8000-000000000013'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 11::numeric,
    'price', 47::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(v_input_attributes, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  v_input_hash_b := md5(jsonb_build_object(
    'input', v_input_b,
    'name', 'QA110 Input Null Versus Absent Offer',
    'demandId', '50000000-0000-4000-8000-000000000013'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 11::numeric,
    'price', 47::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(v_input_attributes, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  IF v_input_hash_a = v_input_hash_b THEN
    RAISE EXCEPTION 'QA110 p_input explicit null versus absent did not change the expected request hash';
  END IF;

  v_attributes_hash_a := md5(jsonb_build_object(
    'input', v_attributes_input,
    'name', 'QA110 Attributes Null Versus Absent Offer',
    'demandId', '50000000-0000-4000-8000-000000000014'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 12::numeric,
    'price', 48::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(v_attributes_a, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  v_attributes_hash_b := md5(jsonb_build_object(
    'input', v_attributes_input,
    'name', 'QA110 Attributes Null Versus Absent Offer',
    'demandId', '50000000-0000-4000-8000-000000000014'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 12::numeric,
    'price', 48::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(v_attributes_b, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  IF v_attributes_hash_a = v_attributes_hash_b THEN
    RAISE EXCEPTION 'QA110 p_attributes explicit null versus absent did not change the expected request hash';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa110-input-null-vs-absent'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM v_input_hash_a
     OR v_result ->> 'status' IS DISTINCT FROM 'succeeded'
     OR v_result ->> 'objectType' IS DISTINCT FROM 'Offer' THEN
    RAISE EXCEPTION 'QA110 p_input case did not preserve the first actor, hash and successful result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa110-input-null-vs-absent';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA110 p_input case expected one idempotency row, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa110-input-null-vs-absent'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA110 p_input case expected one completed execution, found %', v_count;
  END IF;
  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_input_a THEN
    RAISE EXCEPTION 'QA110 p_input explicit null was not preserved in action_executions.input';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA110 Input Null Versus Absent Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA110 p_input case expected exactly one offer, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND demand_id = '50000000-0000-4000-8000-000000000013'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 11
    AND price = 47
    AND currency = 'USD'
    AND attributes = v_input_attributes;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA110 p_input offer fields or stable attributes differ from the first request';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA110 p_input case expected exactly one success event, found %', v_count;
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa110-attributes-null-vs-absent'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM v_attributes_hash_a
     OR v_result ->> 'status' IS DISTINCT FROM 'succeeded'
     OR v_result ->> 'objectType' IS DISTINCT FROM 'Offer' THEN
    RAISE EXCEPTION 'QA110 p_attributes case did not preserve the first actor, hash and successful result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa110-attributes-null-vs-absent';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA110 p_attributes case expected one idempotency row, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa110-attributes-null-vs-absent'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA110 p_attributes case expected one completed execution, found %', v_count;
  END IF;
  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_attributes_input THEN
    RAISE EXCEPTION 'QA110 p_attributes case did not preserve the first input';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA110 Attributes Null Versus Absent Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA110 p_attributes case expected exactly one offer, found %', v_count;
  END IF;
  SELECT attributes INTO v_offer_attributes
  FROM public.offers
  WHERE id = v_offer_id
    AND demand_id = '50000000-0000-4000-8000-000000000014'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 12
    AND price = 48
    AND currency = 'USD';
  IF v_offer_attributes IS DISTINCT FROM v_attributes_a THEN
    RAISE EXCEPTION 'QA110 p_attributes explicit null was not preserved in offers.attributes';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA110 p_attributes case expected exactly one success event, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa110-input-null-vs-absent',
      'fixture-qa110-attributes-null-vs-absent'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA110 expected exactly two idempotency rows across isolated cases, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-qa110-input-null-vs-absent',
      'fixture-qa110-attributes-null-vs-absent'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA110 expected exactly two executions across isolated cases, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'QA110 Input Null Versus Absent Offer',
    'QA110 Attributes Null Versus Absent Offer'
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA110 expected exactly two offers across isolated cases, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-qa110-input-null-vs-absent',
      'fixture-qa110-attributes-null-vs-absent'
    )
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA110 expected exactly two success events across isolated cases, found %', v_count;
  END IF;
END
$qa110$;
SQL

echo "CREATE_OFFER distinguishes JSONB properties explicitly set to null from absent properties in p_input and p_attributes, rejects same-key changed payloads, and preserves the first results without duplicates."


# QA111: characterize JSONB numeric scale in p_input and p_attributes.
# Compare 1, 1.0 and 1.00 at the JSONB equality, ::text and request-hash
# layers, then make the second same-key call follow the hash outcome observed
# by PostgreSQL. The first result must remain the sole persisted result.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  (
    '50000000-0000-4000-8000-000000000017',
    'QA111 Input Numeric Scale Demand',
    'published',
    '30000000-0000-4000-8000-000000000001'
  ),
  (
    '50000000-0000-4000-8000-000000000018',
    'QA111 Attributes Numeric Scale Demand',
    'published',
    '30000000-0000-4000-8000-000000000001'
  );
SQL

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
SET application_name = 'qima-qa111-numeric-scale';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa111$
DECLARE
  v_input_integer jsonb := '{"context":{"case":"numeric-scale-input"},"measurement":{"value":1}}'::jsonb;
  v_input_decimal jsonb := '{"context":{"case":"numeric-scale-input"},"measurement":{"value":1.0}}'::jsonb;
  v_input_scale2 jsonb := '{"context":{"case":"numeric-scale-input"},"measurement":{"value":1.00}}'::jsonb;
  v_input_attributes jsonb := '{"metadata":{"source":"qa111-input"}}'::jsonb;
  v_attributes_input jsonb := '{"context":{"case":"numeric-scale-attributes"}}'::jsonb;
  v_attributes_decimal jsonb := '{"metadata":{"source":"qa111-attributes"},"measurement":{"value":1.0}}'::jsonb;
  v_attributes_scale2 jsonb := '{"metadata":{"source":"qa111-attributes"},"measurement":{"value":1.00}}'::jsonb;
  v_input_hash_integer text;
  v_input_hash_decimal text;
  v_input_hash_scale2 text;
  v_attributes_hash_decimal text;
  v_attributes_hash_scale2 text;
  v_first_result jsonb;
  v_retry_result jsonb;
  v_replay_result jsonb;
  v_retry_error text;
  v_actor_id uuid;
  v_request_hash text;
  v_execution_id uuid;
  v_result jsonb;
  v_offer_id uuid;
  v_execution_input jsonb;
  v_offer_attributes jsonb;
  v_count integer;
BEGIN
  v_input_hash_integer := md5(jsonb_build_object(
    'input', v_input_integer,
    'name', 'QA111 Input Numeric Scale Offer',
    'demandId', '50000000-0000-4000-8000-000000000017'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 13::numeric,
    'price', 49::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', v_input_attributes,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  v_input_hash_decimal := md5(jsonb_build_object(
    'input', v_input_decimal,
    'name', 'QA111 Input Numeric Scale Offer',
    'demandId', '50000000-0000-4000-8000-000000000017'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 13::numeric,
    'price', 49::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', v_input_attributes,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  v_input_hash_scale2 := md5(jsonb_build_object(
    'input', v_input_scale2,
    'name', 'QA111 Input Numeric Scale Offer',
    'demandId', '50000000-0000-4000-8000-000000000017'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 13::numeric,
    'price', 49::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', v_input_attributes,
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  v_attributes_hash_decimal := md5(jsonb_build_object(
    'input', v_attributes_input,
    'name', 'QA111 Attributes Numeric Scale Offer',
    'demandId', '50000000-0000-4000-8000-000000000018'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 14::numeric,
    'price', 50::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(v_attributes_decimal, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);
  v_attributes_hash_scale2 := md5(jsonb_build_object(
    'input', v_attributes_input,
    'name', 'QA111 Attributes Numeric Scale Offer',
    'demandId', '50000000-0000-4000-8000-000000000018'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 14::numeric,
    'price', 50::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(v_attributes_scale2, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  )::text);

  IF v_input_integer IS DISTINCT FROM v_input_decimal
     OR v_input_integer IS DISTINCT FROM v_input_scale2 THEN
    RAISE EXCEPTION 'QA111 p_input numeric JSONB values 1, 1.0 and 1.00 were not semantically equal';
  END IF;
  IF v_input_integer::text = v_input_decimal::text
     OR v_input_integer::text = v_input_scale2::text
     OR v_input_decimal::text = v_input_scale2::text THEN
    RAISE EXCEPTION 'QA111 p_input numeric scale was not preserved in JSONB text output';
  END IF;
  IF v_input_hash_integer = v_input_hash_decimal
     OR v_input_hash_integer = v_input_hash_scale2 THEN
    RAISE EXCEPTION 'QA111 p_input numeric scale did not produce distinct request hashes';
  END IF;

  IF v_attributes_decimal IS DISTINCT FROM v_attributes_scale2 THEN
    RAISE EXCEPTION 'QA111 p_attributes numeric JSONB values 1.0 and 1.00 were not semantically equal';
  END IF;
  IF v_attributes_decimal::text = v_attributes_scale2::text THEN
    RAISE EXCEPTION 'QA111 p_attributes numeric scale was not preserved in JSONB text output';
  END IF;
  IF v_attributes_hash_decimal = v_attributes_hash_scale2 THEN
    RAISE EXCEPTION 'QA111 p_attributes numeric scale did not produce distinct request hashes';
  END IF;

  RAISE NOTICE 'QA111 p_input 1 vs 1.0: jsonb_equal=%, text_equal=%, hash_equal=%; 1 vs 1.00: jsonb_equal=%, text_equal=%, hash_equal=%; representations=[%, %, %]',
    v_input_integer = v_input_decimal,
    v_input_integer::text = v_input_decimal::text,
    v_input_hash_integer = v_input_hash_decimal,
    v_input_integer = v_input_scale2,
    v_input_integer::text = v_input_scale2::text,
    v_input_hash_integer = v_input_hash_scale2,
    v_input_integer::text,
    v_input_decimal::text,
    v_input_scale2::text;
  RAISE NOTICE 'QA111 p_attributes 1.0 vs 1.00: jsonb_equal=%, text_equal=%, hash_equal=%; representations=[%, %]',
    v_attributes_decimal = v_attributes_scale2,
    v_attributes_decimal::text = v_attributes_scale2::text,
    v_attributes_hash_decimal = v_attributes_hash_scale2,
    v_attributes_decimal::text,
    v_attributes_scale2::text;

  v_first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa111-input-numeric-scale',
    v_input_integer,
    'QA111 Input Numeric Scale Offer',
    '50000000-0000-4000-8000-000000000017',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    13,
    49,
    'USD',
    NULL,
    NULL,
    NULL,
    v_input_attributes
  );
  IF v_first_result ->> 'status' IS DISTINCT FROM 'succeeded' THEN
    RAISE EXCEPTION 'QA111 p_input integer-scale first request did not succeed: %', v_first_result;
  END IF;

  v_retry_result := NULL;
  v_retry_error := NULL;
  BEGIN
    v_retry_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-qa111-input-numeric-scale',
      v_input_decimal,
      'QA111 Input Numeric Scale Offer',
      '50000000-0000-4000-8000-000000000017',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      13,
      49,
      'USD',
      NULL,
      NULL,
      NULL,
      v_input_attributes
    );
  EXCEPTION WHEN OTHERS THEN
    v_retry_error := SQLERRM;
  END;

  IF v_input_hash_integer = v_input_hash_decimal THEN
    IF v_retry_error IS NOT NULL OR v_retry_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'QA111 p_input retry did not replay when its calculated request hash was equal; error=% result=%', v_retry_error, v_retry_result;
    END IF;
  ELSE
    IF v_retry_error IS NULL OR position('IDEMPOTENCY_KEY_REUSE' IN v_retry_error) = 0 THEN
      RAISE EXCEPTION 'QA111 p_input retry did not reject the changed hash; error=% result=%', v_retry_error, v_retry_result;
    END IF;
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa111-input-numeric-scale',
    v_input_integer,
    'QA111 Input Numeric Scale Offer',
    '50000000-0000-4000-8000-000000000017',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    13,
    49,
    'USD',
    NULL,
    NULL,
    NULL,
    v_input_attributes
  );
  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA111 p_input original replay did not preserve the first result';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa111-input-numeric-scale'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM v_input_hash_integer
     OR v_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA111 p_input did not preserve the first actor, request hash and result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa111-input-numeric-scale';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA111 p_input expected one idempotency row, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa111-input-numeric-scale'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA111 p_input expected one completed execution, found %', v_count;
  END IF;
  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_input_integer
     OR v_execution_input::text IS DISTINCT FROM v_input_integer::text THEN
    RAISE EXCEPTION 'QA111 p_input did not preserve the first numeric representation in action_executions.input';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA111 Input Numeric Scale Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA111 p_input expected exactly one offer, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND demand_id = '50000000-0000-4000-8000-000000000017'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 13
    AND price = 49
    AND currency = 'USD'
    AND attributes = v_input_attributes;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA111 p_input offer fields or stable attributes differ from the first request';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA111 p_input expected exactly one success event, found %', v_count;
  END IF;

  v_first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa111-attributes-numeric-scale',
    v_attributes_input,
    'QA111 Attributes Numeric Scale Offer',
    '50000000-0000-4000-8000-000000000018',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    14,
    50,
    'USD',
    NULL,
    NULL,
    NULL,
    v_attributes_decimal
  );
  IF v_first_result ->> 'status' IS DISTINCT FROM 'succeeded' THEN
    RAISE EXCEPTION 'QA111 p_attributes decimal-scale first request did not succeed: %', v_first_result;
  END IF;

  v_retry_result := NULL;
  v_retry_error := NULL;
  BEGIN
    v_retry_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-qa111-attributes-numeric-scale',
      v_attributes_input,
      'QA111 Attributes Numeric Scale Offer',
      '50000000-0000-4000-8000-000000000018',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      14,
      50,
      'USD',
      NULL,
      NULL,
      NULL,
      v_attributes_scale2
    );
  EXCEPTION WHEN OTHERS THEN
    v_retry_error := SQLERRM;
  END;

  IF v_attributes_hash_decimal = v_attributes_hash_scale2 THEN
    IF v_retry_error IS NOT NULL OR v_retry_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'QA111 p_attributes retry did not replay when its calculated request hash was equal; error=% result=%', v_retry_error, v_retry_result;
    END IF;
  ELSE
    IF v_retry_error IS NULL OR position('IDEMPOTENCY_KEY_REUSE' IN v_retry_error) = 0 THEN
      RAISE EXCEPTION 'QA111 p_attributes retry did not reject the changed hash; error=% result=%', v_retry_error, v_retry_result;
    END IF;
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa111-attributes-numeric-scale',
    v_attributes_input,
    'QA111 Attributes Numeric Scale Offer',
    '50000000-0000-4000-8000-000000000018',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    14,
    50,
    'USD',
    NULL,
    NULL,
    NULL,
    v_attributes_decimal
  );
  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA111 p_attributes original replay did not preserve the first result';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa111-attributes-numeric-scale'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM v_attributes_hash_decimal
     OR v_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA111 p_attributes did not preserve the first actor, request hash and result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa111-attributes-numeric-scale';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA111 p_attributes expected one idempotency row, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa111-attributes-numeric-scale'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA111 p_attributes expected one completed execution, found %', v_count;
  END IF;
  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_attributes_input THEN
    RAISE EXCEPTION 'QA111 p_attributes did not preserve the stable action input';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA111 Attributes Numeric Scale Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA111 p_attributes expected exactly one offer, found %', v_count;
  END IF;
  SELECT attributes INTO v_offer_attributes
  FROM public.offers
  WHERE id = v_offer_id
    AND demand_id = '50000000-0000-4000-8000-000000000018'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 14
    AND price = 50
    AND currency = 'USD';
  IF v_offer_attributes IS DISTINCT FROM v_attributes_decimal
     OR v_offer_attributes::text IS DISTINCT FROM v_attributes_decimal::text THEN
    RAISE EXCEPTION 'QA111 p_attributes did not preserve the first numeric representation in offers.attributes';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA111 p_attributes expected exactly one success event, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa111-input-numeric-scale',
      'fixture-qa111-attributes-numeric-scale'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA111 expected exactly two idempotency rows across isolated cases, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-qa111-input-numeric-scale',
      'fixture-qa111-attributes-numeric-scale'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA111 expected exactly two executions across isolated cases, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'QA111 Input Numeric Scale Offer',
    'QA111 Attributes Numeric Scale Offer'
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA111 expected exactly two offers across isolated cases, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-qa111-input-numeric-scale',
      'fixture-qa111-attributes-numeric-scale'
    )
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA111 expected exactly two success events across isolated cases, found %', v_count;
  END IF;
END
$qa111$;
SQL

echo "CREATE_OFFER QA111 records PostgreSQL JSONB numeric-scale equality, text representation and request-hash behavior in p_input and p_attributes; same-key retries follow the calculated hash and preserve the first result without duplicates."

# QA112: characterize numeric scale in the SQL parameters p_quantity and p_price.
# The migration hashes jsonb_build_object(... )::text. Compare numeric equality,
# JSONB equality/text, and the complete request hash before exercising same-key
# retries. Keep quantity and price cases isolated so only one numeric parameter
# changes in each retry.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  (
    '50000000-0000-4000-8000-000000000019',
    'QA112 Quantity Numeric Scale Demand',
    'published',
    '30000000-0000-4000-8000-000000000001'
  ),
  (
    '50000000-0000-4000-8000-000000000020',
    'QA112 Price Numeric Scale Demand',
    'published',
    '30000000-0000-4000-8000-000000000001'
  );
SQL

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
SET application_name = 'qima-qa112-numeric-parameters';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa112$
DECLARE
  v_quantity_integer numeric := 13::numeric;
  v_quantity_decimal numeric := 13.0::numeric;
  v_quantity_stable_price numeric := 49::numeric;
  v_price_stable_quantity numeric := 14::numeric;
  v_price_integer numeric := 49::numeric;
  v_price_scale2 numeric := 49.00::numeric;

  v_input_quantity jsonb := '{"context":{"case":"qa112-quantity-parameter-scale"}}'::jsonb;
  v_attributes_quantity jsonb := '{"metadata":{"source":"qa112-quantity"}}'::jsonb;
  v_input_price jsonb := '{"context":{"case":"qa112-price-parameter-scale"}}'::jsonb;
  v_attributes_price jsonb := '{"metadata":{"source":"qa112-price"}}'::jsonb;

  v_quantity_hash_integer jsonb;
  v_quantity_hash_decimal jsonb;
  v_price_hash_integer jsonb;
  v_price_hash_scale2 jsonb;

  v_first_result jsonb;
  v_retry_result jsonb;
  v_replay_result jsonb;
  v_retry_error text;
  v_actor_id uuid;
  v_request_hash text;
  v_execution_id uuid;
  v_result jsonb;
  v_offer_id uuid;
  v_execution_input jsonb;
  v_offer_attributes jsonb;
  v_stored_quantity numeric;
  v_stored_price numeric;
  v_count integer;
BEGIN
  -- p_quantity: PostgreSQL numeric equality and JSONB equality should be true,
  -- while the numeric/JSONB text representation may preserve the decimal scale.
  IF v_quantity_integer <> v_quantity_decimal THEN
    RAISE EXCEPTION 'QA112 p_quantity numeric values 13 and 13.0 are not equal';
  END IF;
  IF v_quantity_integer::text = v_quantity_decimal::text THEN
    RAISE EXCEPTION 'QA112 p_quantity numeric text unexpectedly erased the 13.0 scale';
  END IF;

  v_quantity_hash_integer := jsonb_build_object(
    'input', v_input_quantity,
    'name', 'QA112 Quantity Numeric Scale Offer',
    'demandId', '50000000-0000-4000-8000-000000000019'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', v_quantity_integer,
    'price', v_quantity_stable_price,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(v_attributes_quantity, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  );
  v_quantity_hash_decimal := jsonb_set(
    v_quantity_hash_integer,
    '{quantity}',
    to_jsonb(v_quantity_decimal),
    false
  );
  IF v_quantity_hash_integer IS DISTINCT FROM v_quantity_hash_decimal THEN
    RAISE EXCEPTION 'QA112 p_quantity JSONB payloads 13 and 13.0 unexpectedly differ';
  END IF;
  IF v_quantity_hash_integer::text = v_quantity_hash_decimal::text THEN
    RAISE EXCEPTION 'QA112 p_quantity JSONB text unexpectedly erased the decimal scale';
  END IF;
  IF md5(v_quantity_hash_integer::text) = md5(v_quantity_hash_decimal::text) THEN
    RAISE EXCEPTION 'QA112 p_quantity complete request hashes unexpectedly match';
  END IF;
  RAISE NOTICE 'QA112 p_quantity: numeric_equal=t jsonb_equal=t text_equal=f hash_equal=f';

  -- p_price: isolate 49 versus 49.00 while every other effective parameter,
  -- including p_quantity, remains unchanged.
  IF v_price_integer <> v_price_scale2 THEN
    RAISE EXCEPTION 'QA112 p_price numeric values 49 and 49.00 are not equal';
  END IF;
  IF v_price_integer::text = v_price_scale2::text THEN
    RAISE EXCEPTION 'QA112 p_price numeric text unexpectedly erased the 49.00 scale';
  END IF;

  v_price_hash_integer := jsonb_build_object(
    'input', v_input_price,
    'name', 'QA112 Price Numeric Scale Offer',
    'demandId', '50000000-0000-4000-8000-000000000020'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', v_price_stable_quantity,
    'price', v_price_integer,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(v_attributes_price, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  );
  v_price_hash_scale2 := jsonb_set(
    v_price_hash_integer,
    '{price}',
    to_jsonb(v_price_scale2),
    false
  );
  IF v_price_hash_integer IS DISTINCT FROM v_price_hash_scale2 THEN
    RAISE EXCEPTION 'QA112 p_price JSONB payloads 49 and 49.00 unexpectedly differ';
  END IF;
  IF v_price_hash_integer::text = v_price_hash_scale2::text THEN
    RAISE EXCEPTION 'QA112 p_price JSONB text unexpectedly erased the decimal scale';
  END IF;
  IF md5(v_price_hash_integer::text) = md5(v_price_hash_scale2::text) THEN
    RAISE EXCEPTION 'QA112 p_price complete request hashes unexpectedly match';
  END IF;
  RAISE NOTICE 'QA112 p_price: numeric_equal=t jsonb_equal=t text_equal=f hash_equal=f';

  -- First call and changed-scale retry for p_quantity.
  v_first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa112-quantity-scale',
    v_input_quantity,
    'QA112 Quantity Numeric Scale Offer',
    '50000000-0000-4000-8000-000000000019',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    v_quantity_integer,
    v_quantity_stable_price,
    'USD',
    NULL,
    NULL,
    NULL,
    v_attributes_quantity
  );
  IF v_first_result ->> 'status' IS DISTINCT FROM 'succeeded' THEN
    RAISE EXCEPTION 'QA112 p_quantity first request did not succeed: %', v_first_result;
  END IF;

  v_retry_result := NULL;
  v_retry_error := NULL;
  BEGIN
    v_retry_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-qa112-quantity-scale',
      v_input_quantity,
      'QA112 Quantity Numeric Scale Offer',
      '50000000-0000-4000-8000-000000000019',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      v_quantity_decimal,
      v_quantity_stable_price,
      'USD',
      NULL,
      NULL,
      NULL,
      v_attributes_quantity
    );
  EXCEPTION WHEN OTHERS THEN
    v_retry_error := SQLERRM;
  END;
  IF v_retry_error IS NULL
     OR position('IDEMPOTENCY_KEY_REUSE' IN v_retry_error) = 0 THEN
    RAISE EXCEPTION 'QA112 p_quantity changed-scale retry was not rejected with IDEMPOTENCY_KEY_REUSE; error=% result=%', v_retry_error, v_retry_result;
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa112-quantity-scale',
    v_input_quantity,
    'QA112 Quantity Numeric Scale Offer',
    '50000000-0000-4000-8000-000000000019',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    v_quantity_integer,
    v_quantity_stable_price,
    'USD',
    NULL,
    NULL,
    NULL,
    v_attributes_quantity
  );
  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA112 p_quantity original replay did not preserve the first result';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa112-quantity-scale'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM md5(v_quantity_hash_integer::text)
     OR v_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA112 p_quantity did not preserve the first actor, request hash and result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa112-quantity-scale';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA112 p_quantity expected one idempotency row, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa112-quantity-scale'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA112 p_quantity expected one completed execution, found %', v_count;
  END IF;
  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_input_quantity THEN
    RAISE EXCEPTION 'QA112 p_quantity action execution input differs from the first request';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA112 Quantity Numeric Scale Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA112 p_quantity expected exactly one offer, found %', v_count;
  END IF;
  SELECT quantity, price
  INTO v_stored_quantity, v_stored_price
  FROM public.offers
  WHERE id = v_offer_id
    AND demand_id = '50000000-0000-4000-8000-000000000019'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND currency = 'USD'
    AND attributes = v_attributes_quantity;
  IF v_stored_quantity IS DISTINCT FROM v_quantity_integer
     OR v_stored_quantity::text IS DISTINCT FROM v_quantity_integer::text
     OR v_stored_price IS DISTINCT FROM v_quantity_stable_price
     OR v_stored_price::text IS DISTINCT FROM v_quantity_stable_price::text THEN
    RAISE EXCEPTION 'QA112 p_quantity stored offer did not preserve the first quantity/price representations';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA112 p_quantity expected exactly one success event, found %', v_count;
  END IF;

  -- First call and changed-scale retry for p_price.
  v_first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa112-price-scale',
    v_input_price,
    'QA112 Price Numeric Scale Offer',
    '50000000-0000-4000-8000-000000000020',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    v_price_stable_quantity,
    v_price_integer,
    'USD',
    NULL,
    NULL,
    NULL,
    v_attributes_price
  );
  IF v_first_result ->> 'status' IS DISTINCT FROM 'succeeded' THEN
    RAISE EXCEPTION 'QA112 p_price first request did not succeed: %', v_first_result;
  END IF;

  v_retry_result := NULL;
  v_retry_error := NULL;
  BEGIN
    v_retry_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-qa112-price-scale',
      v_input_price,
      'QA112 Price Numeric Scale Offer',
      '50000000-0000-4000-8000-000000000020',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      v_price_stable_quantity,
      v_price_scale2,
      'USD',
      NULL,
      NULL,
      NULL,
      v_attributes_price
    );
  EXCEPTION WHEN OTHERS THEN
    v_retry_error := SQLERRM;
  END;
  IF v_retry_error IS NULL
     OR position('IDEMPOTENCY_KEY_REUSE' IN v_retry_error) = 0 THEN
    RAISE EXCEPTION 'QA112 p_price changed-scale retry was not rejected with IDEMPOTENCY_KEY_REUSE; error=% result=%', v_retry_error, v_retry_result;
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa112-price-scale',
    v_input_price,
    'QA112 Price Numeric Scale Offer',
    '50000000-0000-4000-8000-000000000020',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    v_price_stable_quantity,
    v_price_integer,
    'USD',
    NULL,
    NULL,
    NULL,
    v_attributes_price
  );
  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA112 p_price original replay did not preserve the first result';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa112-price-scale'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM md5(v_price_hash_integer::text)
     OR v_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA112 p_price did not preserve the first actor, request hash and result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa112-price-scale';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA112 p_price expected one idempotency row, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa112-price-scale'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA112 p_price expected one completed execution, found %', v_count;
  END IF;
  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_input_price THEN
    RAISE EXCEPTION 'QA112 p_price action execution input differs from the first request';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA112 Price Numeric Scale Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA112 p_price expected exactly one offer, found %', v_count;
  END IF;
  SELECT quantity, price
  INTO v_stored_quantity, v_stored_price
  FROM public.offers
  WHERE id = v_offer_id
    AND demand_id = '50000000-0000-4000-8000-000000000020'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND currency = 'USD'
    AND attributes = v_attributes_price;
  IF v_stored_quantity IS DISTINCT FROM v_price_stable_quantity
     OR v_stored_quantity::text IS DISTINCT FROM v_price_stable_quantity::text
     OR v_stored_price IS DISTINCT FROM v_price_integer
     OR v_stored_price::text IS DISTINCT FROM v_price_integer::text THEN
    RAISE EXCEPTION 'QA112 p_price stored offer did not preserve the first quantity/price representations';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA112 p_price expected exactly one success event, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa112-quantity-scale',
      'fixture-qa112-price-scale'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA112 expected exactly two idempotency rows, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-qa112-quantity-scale',
      'fixture-qa112-price-scale'
    );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA112 expected exactly two executions, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'QA112 Quantity Numeric Scale Offer',
    'QA112 Price Numeric Scale Offer'
  );
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA112 expected exactly two offers, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-qa112-quantity-scale',
      'fixture-qa112-price-scale'
    )
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA112 expected exactly two success events, found %', v_count;
  END IF;
END
$qa112$;
SQL

echo "CREATE_OFFER QA112 characterizes numeric scale in p_quantity and p_price: equal numeric values retain distinct JSONB text/hash representations, changed-scale same-key retries are rejected, and the first result persists without duplicates."


# QA113: SQL NULL, explicit empty JSONB, and the p_attributes default.
# The production migration coalesces p_attributes to '{}' in both the request
# hash and the create_offer_v1 call. Verify explicit SQL NULL, explicit {},
# and an omitted p_attributes argument (the declared default) all replay the
# same completed request without creating duplicate records.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES (
  '50000000-0000-4000-8000-000000000021',
  'QA113 Attributes Null Default Demand',
  'published',
  '30000000-0000-4000-8000-000000000001'
);
SQL

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
SET application_name = 'qima-qa113-attributes-null-default';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa113$
DECLARE
  v_input jsonb := '{"context":{"case":"qa113-attributes-null-default"}}'::jsonb;
  v_hash_null jsonb;
  v_hash_empty jsonb;
  v_first_result jsonb;
  v_explicit_empty_result jsonb;
  v_omitted_default_result jsonb;
  v_actor_id uuid;
  v_request_hash text;
  v_execution_id uuid;
  v_result jsonb;
  v_offer_id uuid;
  v_execution_input jsonb;
  v_offer_attributes jsonb;
  v_stored_quantity numeric;
  v_stored_price numeric;
  v_count integer;
BEGIN
  -- Reproduce every effective request-hash field from the migration. Only
  -- p_attributes differs at the SQL boundary; both sides are normalized by
  -- coalesce(..., '{}'::jsonb) before the request JSONB is hashed.
  v_hash_null := jsonb_build_object(
    'input', v_input,
    'name', 'QA113 Attributes Null Default Offer',
    'demandId', '50000000-0000-4000-8000-000000000021'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 15::numeric,
    'price', 55::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(NULL::jsonb, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  );
  v_hash_empty := jsonb_build_object(
    'input', v_input,
    'name', 'QA113 Attributes Null Default Offer',
    'demandId', '50000000-0000-4000-8000-000000000021'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 15::numeric,
    'price', 55::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce('{}'::jsonb, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  );

  IF coalesce(NULL::jsonb, '{}'::jsonb) IS DISTINCT FROM '{}'::jsonb THEN
    RAISE EXCEPTION 'QA113 SQL NULL attributes did not normalize to an empty JSONB object';
  END IF;
  IF v_hash_null IS DISTINCT FROM v_hash_empty
     OR v_hash_null::text IS DISTINCT FROM v_hash_empty::text
     OR md5(v_hash_null::text) IS DISTINCT FROM md5(v_hash_empty::text) THEN
    RAISE EXCEPTION 'QA113 SQL NULL and explicit empty attributes produced different request hashes';
  END IF;
  RAISE NOTICE 'QA113 hash: sql_null_equal_to_empty=t text_equal=t hash_equal=t';

  -- First request explicitly passes SQL NULL as p_attributes (14th argument).
  v_first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa113-attributes-null-default',
    v_input,
    'QA113 Attributes Null Default Offer',
    '50000000-0000-4000-8000-000000000021',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    15::numeric,
    55::numeric,
    'USD',
    NULL,
    NULL,
    NULL,
    NULL::jsonb
  );
  IF v_first_result ->> 'status' IS DISTINCT FROM 'succeeded' THEN
    RAISE EXCEPTION 'QA113 explicit SQL NULL first request did not succeed: %', v_first_result;
  END IF;

  -- Explicit '{}' must be the same effective request and therefore a replay.
  v_explicit_empty_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa113-attributes-null-default',
    v_input,
    'QA113 Attributes Null Default Offer',
    '50000000-0000-4000-8000-000000000021',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    15::numeric,
    55::numeric,
    'USD',
    NULL,
    NULL,
    NULL,
    '{}'::jsonb
  );
  IF v_explicit_empty_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA113 explicit empty JSONB retry did not replay the SQL NULL first result';
  END IF;

  -- Omit p_attributes entirely. It is the 14th argument and has a declared
  -- '{}'::jsonb default; the call supplies only the first 13 arguments.
  v_omitted_default_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa113-attributes-null-default',
    v_input,
    'QA113 Attributes Null Default Offer',
    '50000000-0000-4000-8000-000000000021',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    15::numeric,
    55::numeric,
    'USD',
    NULL,
    NULL,
    NULL
  );
  IF v_omitted_default_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA113 omitted p_attributes default did not replay the SQL NULL first result';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa113-attributes-null-default'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM md5(v_hash_null::text)
     OR v_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA113 did not preserve the first actor, normalized request hash and result';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT input INTO v_execution_input
  FROM public.action_executions
  WHERE id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa113-attributes-null-default'
    AND status = 'COMPLETED'
    AND result = v_result;
  IF v_execution_input IS DISTINCT FROM v_input THEN
    RAISE EXCEPTION 'QA113 action execution input differs from the first request';
  END IF;

  SELECT attributes, quantity, price
  INTO v_offer_attributes, v_stored_quantity, v_stored_price
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA113 Attributes Null Default Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000021'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND currency = 'USD';
  IF v_offer_attributes IS DISTINCT FROM '{}'::jsonb
     OR v_offer_attributes::text IS DISTINCT FROM '{}'::text
     OR v_stored_quantity IS DISTINCT FROM 15::numeric
     OR v_stored_price IS DISTINCT FROM 55::numeric THEN
    RAISE EXCEPTION 'QA113 offer did not persist normalized empty attributes and original business values';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa113-attributes-null-default';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA113 expected exactly one idempotency row, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa113-attributes-null-default'
    AND status = 'COMPLETED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA113 expected exactly one completed execution, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA113 Attributes Null Default Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA113 expected exactly one offer, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE execution_id = v_execution_id
    AND tenant_id = '10000000-0000-4000-8000-000000000001'
    AND event_type = 'ACTION_SUCCEEDED'
    AND actor_id = '30000000-0000-4000-8000-000000000001'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA113 expected exactly one success event, found %', v_count;
  END IF;

  RAISE NOTICE 'QA113 RPC: explicit SQL NULL, explicit {}, and omitted default all replay one result; stored attributes={}';
END
$qa113$;
SQL

echo "CREATE_OFFER QA113 confirms p_attributes SQL NULL, explicit empty JSONB and the omitted '{}' default share one normalized request hash and replay result; one offer, execution and success event persist."


# QA114: JSONB scalar null is distinct from SQL NULL and the empty object.
# coalesce(p_attributes, '{}'::jsonb) only replaces SQL NULL. A non-SQL-NULL
# JSONB scalar 'null' remains JSON null in the request hash and in the fixture
# insert. Exercise both ownership directions with separate keys: SQL NULL first
# then scalar JSON null, and scalar JSON null first then SQL NULL.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  ('50000000-0000-4000-8000-000000000022','QA114 SQL Null First Demand','published','30000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000023','QA114 JSONB Scalar Null First Demand','published','30000000-0000-4000-8000-000000000001');
SQL

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
SET application_name = 'qima-qa114-jsonb-scalar-null';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa114$
DECLARE
  v_input_sql_null jsonb := '{"context":{"case":"qa114-sql-null-first"}}'::jsonb;
  v_input_json_null jsonb := '{"context":{"case":"qa114-jsonb-scalar-null-first"}}'::jsonb;
  v_hash_sql_null jsonb;
  v_hash_json_null jsonb;
  v_hash_sql_null_second jsonb;
  v_hash_json_null_first jsonb;
  v_first_result jsonb;
  v_retry_result jsonb;
  v_replay_result jsonb;
  v_retry_error text;
  v_actor_id uuid;
  v_request_hash text;
  v_execution_id uuid;
  v_result jsonb;
  v_offer_id uuid;
  v_offer_attributes jsonb;
  v_count integer;
BEGIN
  -- Reproduce every effective hash field from the migration for both
  -- representations. SQL NULL is coalesced to {}, while JSONB scalar null
  -- remains a non-SQL-NULL JSONB value.
  v_hash_sql_null := jsonb_build_object(
    'input', v_input_sql_null,
    'name', 'QA114 SQL Null First Offer',
    'demandId', '50000000-0000-4000-8000-000000000022'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 16::numeric,
    'price', 56::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(NULL::jsonb, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  );
  v_hash_json_null := jsonb_build_object(
    'input', v_input_sql_null,
    'name', 'QA114 SQL Null First Offer',
    'demandId', '50000000-0000-4000-8000-000000000022'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 16::numeric,
    'price', 56::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce('null'::jsonb, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  );

  -- Build the second direction's own expected hashes: its input, name and
  -- demand intentionally differ from direction A, so the persisted first hash
  -- must be compared against this complete payload rather than direction A's.
  v_hash_sql_null_second := jsonb_build_object(
    'input', v_input_json_null,
    'name', 'QA114 JSONB Scalar Null First Offer',
    'demandId', '50000000-0000-4000-8000-000000000023'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 17::numeric,
    'price', 57::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce(NULL::jsonb, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  );
  v_hash_json_null_first := jsonb_build_object(
    'input', v_input_json_null,
    'name', 'QA114 JSONB Scalar Null First Offer',
    'demandId', '50000000-0000-4000-8000-000000000023'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 17::numeric,
    'price', 57::numeric,
    'currency', 'USD',
    'conditions', NULL::text,
    'market', NULL::text,
    'geography', NULL::text,
    'attributes', coalesce('null'::jsonb, '{}'::jsonb),
    'documentationStatus', NULL::text,
    'lifecycle', NULL::text,
    'offerType', NULL::text,
    'pricingModel', NULL::text
  );

  IF v_hash_sql_null_second IS NOT DISTINCT FROM v_hash_json_null_first
     OR md5(v_hash_sql_null_second::text) IS NOT DISTINCT FROM md5(v_hash_json_null_first::text) THEN
    RAISE EXCEPTION 'QA114 second direction SQL NULL and JSONB scalar null unexpectedly produced the same request hash';
  END IF;

  IF coalesce(NULL::jsonb, '{}'::jsonb) IS DISTINCT FROM '{}'::jsonb THEN
    RAISE EXCEPTION 'QA114 SQL NULL did not normalize to an empty JSONB object';
  END IF;
  IF 'null'::jsonb IS NULL OR jsonb_typeof('null'::jsonb) IS DISTINCT FROM 'null' THEN
    RAISE EXCEPTION 'QA114 JSONB scalar null was incorrectly treated as SQL NULL';
  END IF;
  IF coalesce('null'::jsonb, '{}'::jsonb) IS DISTINCT FROM 'null'::jsonb THEN
    RAISE EXCEPTION 'QA114 COALESCE unexpectedly replaced JSONB scalar null';
  END IF;
  IF v_hash_sql_null IS NOT DISTINCT FROM v_hash_json_null
     OR v_hash_sql_null::text IS NOT DISTINCT FROM v_hash_json_null::text
     OR md5(v_hash_sql_null::text) IS NOT DISTINCT FROM md5(v_hash_json_null::text) THEN
    RAISE EXCEPTION 'QA114 SQL NULL and JSONB scalar null unexpectedly produced the same request hash';
  END IF;
  RAISE NOTICE 'QA114 hash: sql_null_normalizes_to_empty=t jsonb_scalar_null_is_non_sql_null=t text_equal=f hash_equal=f';

  -- Direction A: SQL NULL owns the key; JSONB scalar null must be rejected.
  v_first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa114-sql-null-first',
    v_input_sql_null,
    'QA114 SQL Null First Offer',
    '50000000-0000-4000-8000-000000000022',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    16::numeric,
    56::numeric,
    'USD',
    NULL,
    NULL,
    NULL,
    NULL::jsonb
  );
  IF v_first_result ->> 'status' IS DISTINCT FROM 'succeeded' THEN
    RAISE EXCEPTION 'QA114 SQL NULL first request did not succeed: %', v_first_result;
  END IF;

  v_retry_result := NULL;
  v_retry_error := NULL;
  BEGIN
    v_retry_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-qa114-sql-null-first',
      v_input_sql_null,
      'QA114 SQL Null First Offer',
      '50000000-0000-4000-8000-000000000022',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      16::numeric,
      56::numeric,
      'USD',
      NULL,
      NULL,
      NULL,
      'null'::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    v_retry_error := SQLERRM;
  END;
  IF v_retry_error IS NULL
     OR position('IDEMPOTENCY_KEY_REUSE' IN v_retry_error) = 0 THEN
    RAISE EXCEPTION 'QA114 SQL NULL to JSONB scalar null retry was not rejected; error=% result=%', v_retry_error, v_retry_result;
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa114-sql-null-first',
    v_input_sql_null,
    'QA114 SQL Null First Offer',
    '50000000-0000-4000-8000-000000000022',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    16::numeric,
    56::numeric,
    'USD',
    NULL,
    NULL,
    NULL,
    NULL::jsonb
  );
  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA114 SQL NULL original replay did not preserve the first result';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa114-sql-null-first'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM md5(v_hash_sql_null::text)
     OR v_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA114 SQL NULL first owner/hash/result was not preserved';
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT attributes INTO v_offer_attributes
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA114 SQL Null First Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000022'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001';
  IF v_offer_attributes IS DISTINCT FROM '{}'::jsonb
     OR v_offer_attributes::text IS DISTINCT FROM '{}'::text THEN
    RAISE EXCEPTION 'QA114 SQL NULL first offer did not persist normalized {} attributes';
  END IF;

  -- Direction B: JSONB scalar null owns a separate key; SQL NULL must be rejected.
  v_first_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa114-jsonb-scalar-null-first',
    v_input_json_null,
    'QA114 JSONB Scalar Null First Offer',
    '50000000-0000-4000-8000-000000000023',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    17::numeric,
    57::numeric,
    'USD',
    NULL,
    NULL,
    NULL,
    'null'::jsonb
  );
  IF v_first_result ->> 'status' IS DISTINCT FROM 'succeeded' THEN
    RAISE EXCEPTION 'QA114 JSONB scalar null first request did not succeed: %', v_first_result;
  END IF;

  v_retry_result := NULL;
  v_retry_error := NULL;
  BEGIN
    v_retry_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-qa114-jsonb-scalar-null-first',
      v_input_json_null,
      'QA114 JSONB Scalar Null First Offer',
      '50000000-0000-4000-8000-000000000023',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      17::numeric,
      57::numeric,
      'USD',
      NULL,
      NULL,
      NULL,
      NULL::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    v_retry_error := SQLERRM;
  END;
  IF v_retry_error IS NULL
     OR position('IDEMPOTENCY_KEY_REUSE' IN v_retry_error) = 0 THEN
    RAISE EXCEPTION 'QA114 JSONB scalar null to SQL NULL retry was not rejected; error=% result=%', v_retry_error, v_retry_result;
  END IF;

  v_replay_result := public.execute_create_offer_v1(
    '10000000-0000-4000-8000-000000000001',
    'fixture-qa114-jsonb-scalar-null-first',
    v_input_json_null,
    'QA114 JSONB Scalar Null First Offer',
    '50000000-0000-4000-8000-000000000023',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    17::numeric,
    57::numeric,
    'USD',
    NULL,
    NULL,
    NULL,
    'null'::jsonb
  );
  IF v_replay_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA114 JSONB scalar null original replay did not preserve the first result';
  END IF;

  SELECT actor_id, request_hash, execution_id, result
  INTO v_actor_id, v_request_hash, v_execution_id, v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa114-jsonb-scalar-null-first'
    AND status = 'COMPLETED';
  IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
     OR v_request_hash IS DISTINCT FROM md5(v_hash_json_null_first::text)
     OR v_result IS DISTINCT FROM v_first_result THEN
    RAISE EXCEPTION 'QA114 JSONB scalar null first owner/hash/result was not preserved; actor=% hash=% expected_hash=% result_matches=%', v_actor_id, v_request_hash, md5(v_hash_json_null_first::text), v_result IS NOT DISTINCT FROM v_first_result;
  END IF;
  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT attributes INTO v_offer_attributes
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA114 JSONB Scalar Null First Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000023'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001';
  IF v_offer_attributes IS NULL
     OR v_offer_attributes IS DISTINCT FROM 'null'::jsonb
     OR jsonb_typeof(v_offer_attributes) IS DISTINCT FROM 'null'
     OR v_offer_attributes::text IS DISTINCT FROM 'null' THEN
    RAISE EXCEPTION 'QA114 JSONB scalar null first offer did not persist a JSONB null scalar';
  END IF;

  -- Assert exactly one key, execution, offer and success event per direction.
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN ('fixture-qa114-sql-null-first','fixture-qa114-jsonb-scalar-null-first');
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA114 expected exactly two idempotency rows, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN ('fixture-qa114-sql-null-first','fixture-qa114-jsonb-scalar-null-first')
    AND status = 'COMPLETED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA114 expected exactly two completed executions, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN ('QA114 SQL Null First Offer','QA114 JSONB Scalar Null First Offer');
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA114 expected exactly two offers, found %', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN ('fixture-qa114-sql-null-first','fixture-qa114-jsonb-scalar-null-first')
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'QA114 expected exactly two success events, found %', v_count;
  END IF;

  RAISE NOTICE 'QA114 RPC: SQL NULL and JSONB scalar null have distinct hashes; each first payload retains its own exact replay and persisted attributes without duplicates';
END
$qa114$;
SQL

echo "CREATE_OFFER QA114 confirms SQL NULL is coalesced to {}, while JSONB scalar null remains distinct in the hash and offers.attributes; both ownership directions reject changed same-key retries and preserve one original result without duplicates."



# QA115: characterize top-level JSONB shapes for p_input at the authenticated RPC.
# SQL NULL is rejected by the existing guard. JSONB scalar null, arrays and
# objects are non-SQL-NULL values; record whether each is accepted, hashed,
# stored in action_executions.input, and replayed without duplicate records.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  ('50000000-0000-4000-8000-000000000024','QA115 SQL NULL Input Rejected Demand','published','30000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000025','QA115 JSONB Scalar Null Input Demand','published','30000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000026','QA115 JSONB Array Input Demand','published','30000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000027','QA115 JSONB Object Input Demand','published','30000000-0000-4000-8000-000000000001');
SQL

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
SET application_name = 'qima-qa115-input-jsonb-shapes';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa115$
DECLARE
  v_case record;
  v_hash jsonb;
  v_first_result jsonb;
  v_replay_result jsonb;
  v_sql_null_result jsonb;
  v_sql_null_error text;
  v_actor_id uuid;
  v_request_hash text;
  v_execution_id uuid;
  v_result jsonb;
  v_stored_input jsonb;
  v_stored_attributes jsonb;
  v_offer_id uuid;
  v_count integer;
BEGIN
  -- SQL NULL is rejected before an idempotency or execution row is created.
  v_sql_null_result := NULL;
  v_sql_null_error := NULL;
  BEGIN
    v_sql_null_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      'fixture-qa115-sql-null-input',
      NULL::jsonb,
      'QA115 SQL NULL Input Rejected Offer',
      '50000000-0000-4000-8000-000000000024',
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      18::numeric,
      58::numeric,
      'USD',
      NULL,
      NULL,
      NULL,
      NULL::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    v_sql_null_error := SQLERRM;
  END;

  IF v_sql_null_error IS NULL
     OR position('ACTION_INPUT_REQUIRED' IN v_sql_null_error) = 0 THEN
    RAISE EXCEPTION 'QA115 SQL NULL p_input was not rejected with ACTION_INPUT_REQUIRED; error=% result=%', v_sql_null_error, v_sql_null_result;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa115-sql-null-input';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA115 SQL NULL p_input unexpectedly created % idempotency rows', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa115-sql-null-input';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA115 SQL NULL p_input unexpectedly created % executions', v_count;
  END IF;
  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA115 SQL NULL Input Rejected Offer';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA115 SQL NULL p_input unexpectedly created an offer';
  END IF;

  RAISE NOTICE 'QA115 SQL NULL input: ACTION_INPUT_REQUIRED; no idempotency, execution or offer rows';

  -- The RPC guard checks SQL NULL, not the JSONB top-level type. Exercise
  -- scalar JSON null, an array and an object independently with exact replays.
  FOR v_case IN
    SELECT *
    FROM (VALUES
      (
        'scalar-null'::text,
        'QA115 JSONB Scalar Null Input Offer'::text,
        '50000000-0000-4000-8000-000000000025'::uuid,
        'null'::jsonb,
        'null'::text,
        18::numeric,
        58::numeric,
        'fixture-qa115-input-scalar-null'::text
      ),
      (
        'array'::text,
        'QA115 JSONB Array Input Offer'::text,
        '50000000-0000-4000-8000-000000000026'::uuid,
        '["qa115","array",1]'::jsonb,
        'array'::text,
        19::numeric,
        59::numeric,
        'fixture-qa115-input-array'::text
      ),
      (
        'object'::text,
        'QA115 JSONB Object Input Offer'::text,
        '50000000-0000-4000-8000-000000000027'::uuid,
        '{"context":{"case":"qa115-object"},"source":"rpc-shape"}'::jsonb,
        'object'::text,
        20::numeric,
        60::numeric,
        'fixture-qa115-input-object'::text
      )
    ) AS cases(case_name, offer_name, demand_id, input_value, expected_type, quantity, price, idempotency_key)
  LOOP
    v_hash := jsonb_build_object(
      'input', v_case.input_value,
      'name', v_case.offer_name,
      'demandId', v_case.demand_id,
      'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
      'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
      'quantity', v_case.quantity,
      'price', v_case.price,
      'currency', 'USD',
      'conditions', NULL::text,
      'market', NULL::text,
      'geography', NULL::text,
      'attributes', coalesce(NULL::jsonb, '{}'::jsonb),
      'documentationStatus', NULL::text,
      'lifecycle', NULL::text,
      'offerType', NULL::text,
      'pricingModel', NULL::text
    );

    v_first_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      v_case.idempotency_key,
      v_case.input_value,
      v_case.offer_name,
      v_case.demand_id,
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      v_case.quantity,
      v_case.price,
      'USD',
      NULL,
      NULL,
      NULL,
      NULL::jsonb
    );
    IF v_first_result ->> 'status' IS DISTINCT FROM 'succeeded' THEN
      RAISE EXCEPTION 'QA115 % first request was not accepted: %', v_case.case_name, v_first_result;
    END IF;

    v_replay_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      v_case.idempotency_key,
      v_case.input_value,
      v_case.offer_name,
      v_case.demand_id,
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      v_case.quantity,
      v_case.price,
      'USD',
      NULL,
      NULL,
      NULL,
      NULL::jsonb
    );
    IF v_replay_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'QA115 % exact replay did not return the first result', v_case.case_name;
    END IF;

    SELECT actor_id, request_hash, execution_id, result
    INTO v_actor_id, v_request_hash, v_execution_id, v_result
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_case.idempotency_key
      AND status = 'COMPLETED';
    IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
       OR v_request_hash IS DISTINCT FROM md5(v_hash::text)
       OR v_result IS DISTINCT FROM v_first_result
       OR v_execution_id IS NULL THEN
      RAISE EXCEPTION 'QA115 % owner/hash/result was not preserved', v_case.case_name;
    END IF;

    SELECT input INTO v_stored_input
    FROM public.action_executions
    WHERE id = v_execution_id
      AND tenant_id = '10000000-0000-4000-8000-000000000001'
      AND actor_id = '30000000-0000-4000-8000-000000000001'
      AND idempotency_key = v_case.idempotency_key
      AND status = 'COMPLETED'
      AND result = v_first_result;
    IF v_stored_input IS NULL
       OR v_stored_input IS DISTINCT FROM v_case.input_value
       OR jsonb_typeof(v_stored_input) IS DISTINCT FROM v_case.expected_type
       OR v_stored_input::text IS DISTINCT FROM v_case.input_value::text THEN
      RAISE EXCEPTION 'QA115 % input shape was not persisted exactly; expected type %, stored %, expected %, stored text %',
        v_case.case_name, v_case.expected_type, jsonb_typeof(v_stored_input), v_case.input_value::text, v_stored_input::text;
    END IF;

    v_offer_id := (v_first_result ->> 'objectId')::uuid;
    SELECT attributes INTO v_stored_attributes
    FROM public.offers
    WHERE id = v_offer_id
      AND name = v_case.offer_name
      AND demand_id = v_case.demand_id
      AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
      AND quantity = v_case.quantity
      AND price = v_case.price
      AND currency = 'USD';
    IF v_stored_attributes IS DISTINCT FROM '{}'::jsonb THEN
      RAISE EXCEPTION 'QA115 % offer did not persist the expected empty attributes', v_case.case_name;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_events e
    JOIN public.action_executions x
      ON x.id = e.execution_id
     AND x.tenant_id = e.tenant_id
    WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
      AND x.idempotency_key = v_case.idempotency_key
      AND e.event_type = 'ACTION_SUCCEEDED'
      AND e.actor_id = '30000000-0000-4000-8000-000000000001'
      AND e.object_id = v_offer_id
      AND e.payload = v_first_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'QA115 % expected exactly one success event, found %', v_case.case_name, v_count;
    END IF;

    RAISE NOTICE 'QA115 % accepted and persisted as JSONB type %, exact replay preserved', v_case.case_name, v_case.expected_type;
  END LOOP;

  -- SQL NULL creates no record; the three non-SQL-NULL shapes each create
  -- exactly one key, execution, offer and success event.
  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa115-input-scalar-null',
      'fixture-qa115-input-array',
      'fixture-qa115-input-object'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA115 expected exactly three idempotency rows, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-qa115-input-scalar-null',
      'fixture-qa115-input-array',
      'fixture-qa115-input-object'
    )
    AND status = 'COMPLETED';
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA115 expected exactly three completed executions, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'QA115 JSONB Scalar Null Input Offer',
    'QA115 JSONB Array Input Offer',
    'QA115 JSONB Object Input Offer'
  );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA115 expected exactly three offers, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-qa115-input-scalar-null',
      'fixture-qa115-input-array',
      'fixture-qa115-input-object'
    )
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA115 expected exactly three success events, found %', v_count;
  END IF;

  RAISE NOTICE 'QA115 RPC: SQL NULL p_input is rejected; JSONB scalar null, array and object are accepted, hashed, persisted and exactly replayed without duplicates';
END
$qa115$;
SQL

echo "CREATE_OFFER QA115 confirms SQL NULL p_input is rejected before persistence, while JSONB scalar null, array and object are accepted by the authenticated RPC and retain their exact stored shapes and replay results without duplicates."


# QA116: characterize top-level JSONB shapes for p_attributes at the authenticated RPC.
# QA113/QA114 already cover SQL NULL, {}, and JSONB scalar null. This test adds
# arrays and JSONB string/number/boolean scalars, verifying the complete request
# hash, stored offers.attributes value, exact replay, and one success event.
# The HTTP route normalizes non-object attributes to {}, while this RPC test
# records the behavior of the authenticated SQL contract without changing it.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.demands (id, name, demand_status, requester_actor_id)
VALUES
  ('50000000-0000-4000-8000-000000000028','QA116 JSONB Array Attributes Demand','published','30000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000029','QA116 JSONB String Attributes Demand','published','30000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000030','QA116 JSONB Number Attributes Demand','published','30000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000031','QA116 JSONB Boolean Attributes Demand','published','30000000-0000-4000-8000-000000000001');
SQL

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
SET application_name = 'qima-qa116-attributes-jsonb-shapes';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

DO $qa116$
DECLARE
  v_case record;
  v_input jsonb := '{"source":"qa116","case":"attributes-top-level-shape"}'::jsonb;
  v_hash jsonb;
  v_first_result jsonb;
  v_replay_result jsonb;
  v_actor_id uuid;
  v_request_hash text;
  v_execution_id uuid;
  v_result jsonb;
  v_stored_input jsonb;
  v_stored_attributes jsonb;
  v_offer_id uuid;
  v_count integer;
BEGIN
  FOR v_case IN
    SELECT *
    FROM (VALUES
      (
        'array'::text,
        'QA116 JSONB Array Attributes Offer'::text,
        '50000000-0000-4000-8000-000000000028'::uuid,
        '["attribute-a","attribute-b"]'::jsonb,
        'array'::text,
        21::numeric,
        61::numeric,
        'fixture-qa116-attributes-array'::text
      ),
      (
        'string'::text,
        'QA116 JSONB String Attributes Offer'::text,
        '50000000-0000-4000-8000-000000000029'::uuid,
        '"qa116-string"'::jsonb,
        'string'::text,
        22::numeric,
        62::numeric,
        'fixture-qa116-attributes-string'::text
      ),
      (
        'number'::text,
        'QA116 JSONB Number Attributes Offer'::text,
        '50000000-0000-4000-8000-000000000030'::uuid,
        '42'::jsonb,
        'number'::text,
        23::numeric,
        63::numeric,
        'fixture-qa116-attributes-number'::text
      ),
      (
        'boolean'::text,
        'QA116 JSONB Boolean Attributes Offer'::text,
        '50000000-0000-4000-8000-000000000031'::uuid,
        'true'::jsonb,
        'boolean'::text,
        24::numeric,
        64::numeric,
        'fixture-qa116-attributes-boolean'::text
      )
    ) AS cases(case_name, offer_name, demand_id, attributes_value, expected_type, quantity, price, idempotency_key)
  LOOP
    v_hash := jsonb_build_object(
      'input', v_input,
      'name', v_case.offer_name,
      'demandId', v_case.demand_id,
      'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
      'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
      'quantity', v_case.quantity,
      'price', v_case.price,
      'currency', 'USD',
      'conditions', NULL::text,
      'market', NULL::text,
      'geography', NULL::text,
      'attributes', coalesce(v_case.attributes_value, '{}'::jsonb),
      'documentationStatus', NULL::text,
      'lifecycle', NULL::text,
      'offerType', NULL::text,
      'pricingModel', NULL::text
    );

    v_first_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      v_case.idempotency_key,
      v_input,
      v_case.offer_name,
      v_case.demand_id,
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      v_case.quantity,
      v_case.price,
      'USD',
      NULL,
      NULL,
      NULL,
      v_case.attributes_value
    );
    IF v_first_result ->> 'status' IS DISTINCT FROM 'succeeded' THEN
      RAISE EXCEPTION 'QA116 % attributes first request was not accepted: %', v_case.case_name, v_first_result;
    END IF;

    v_replay_result := public.execute_create_offer_v1(
      '10000000-0000-4000-8000-000000000001',
      v_case.idempotency_key,
      v_input,
      v_case.offer_name,
      v_case.demand_id,
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      v_case.quantity,
      v_case.price,
      'USD',
      NULL,
      NULL,
      NULL,
      v_case.attributes_value
    );
    IF v_replay_result IS DISTINCT FROM v_first_result THEN
      RAISE EXCEPTION 'QA116 % exact replay did not return the first result', v_case.case_name;
    END IF;

    SELECT actor_id, request_hash, execution_id, result
    INTO v_actor_id, v_request_hash, v_execution_id, v_result
    FROM public.idempotency_keys
    WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
      AND key = v_case.idempotency_key
      AND status = 'COMPLETED';
    IF v_actor_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid
       OR v_request_hash IS DISTINCT FROM md5(v_hash::text)
       OR v_result IS DISTINCT FROM v_first_result
       OR v_execution_id IS NULL THEN
      RAISE EXCEPTION 'QA116 % owner/hash/result was not preserved', v_case.case_name;
    END IF;

    SELECT input INTO v_stored_input
    FROM public.action_executions
    WHERE id = v_execution_id
      AND tenant_id = '10000000-0000-4000-8000-000000000001'
      AND actor_id = '30000000-0000-4000-8000-000000000001'
      AND idempotency_key = v_case.idempotency_key
      AND status = 'COMPLETED'
      AND result = v_first_result;
    IF v_stored_input IS DISTINCT FROM v_input
       OR jsonb_typeof(v_stored_input) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'QA116 % action execution input was not preserved', v_case.case_name;
    END IF;

    v_offer_id := (v_first_result ->> 'objectId')::uuid;
    SELECT attributes INTO v_stored_attributes
    FROM public.offers
    WHERE id = v_offer_id
      AND name = v_case.offer_name
      AND demand_id = v_case.demand_id
      AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
      AND quantity = v_case.quantity
      AND price = v_case.price
      AND currency = 'USD';
    IF v_stored_attributes IS NULL
       OR v_stored_attributes IS DISTINCT FROM v_case.attributes_value
       OR jsonb_typeof(v_stored_attributes) IS DISTINCT FROM v_case.expected_type
       OR v_stored_attributes::text IS DISTINCT FROM v_case.attributes_value::text THEN
      RAISE EXCEPTION 'QA116 % attributes shape was not persisted exactly; expected type %, stored type %, expected %, stored %',
        v_case.case_name, v_case.expected_type, jsonb_typeof(v_stored_attributes),
        v_case.attributes_value::text, v_stored_attributes::text;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.action_events e
    JOIN public.action_executions x
      ON x.id = e.execution_id
     AND x.tenant_id = e.tenant_id
    WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
      AND x.idempotency_key = v_case.idempotency_key
      AND e.event_type = 'ACTION_SUCCEEDED'
      AND e.actor_id = '30000000-0000-4000-8000-000000000001'
      AND e.object_id = v_offer_id
      AND e.payload = v_first_result;
    IF v_count <> 1 THEN
      RAISE EXCEPTION 'QA116 % expected exactly one success event, found %', v_case.case_name, v_count;
    END IF;

    RAISE NOTICE 'QA116 % attributes accepted and persisted as JSONB type %, exact replay preserved',
      v_case.case_name, v_case.expected_type;
  END LOOP;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa116-attributes-array',
      'fixture-qa116-attributes-string',
      'fixture-qa116-attributes-number',
      'fixture-qa116-attributes-boolean'
    )
    AND status = 'COMPLETED';
  IF v_count <> 4 THEN
    RAISE EXCEPTION 'QA116 expected exactly four completed idempotency rows, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-qa116-attributes-array',
      'fixture-qa116-attributes-string',
      'fixture-qa116-attributes-number',
      'fixture-qa116-attributes-boolean'
    )
    AND status = 'COMPLETED';
  IF v_count <> 4 THEN
    RAISE EXCEPTION 'QA116 expected exactly four completed executions, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name IN (
    'QA116 JSONB Array Attributes Offer',
    'QA116 JSONB String Attributes Offer',
    'QA116 JSONB Number Attributes Offer',
    'QA116 JSONB Boolean Attributes Offer'
  );
  IF v_count <> 4 THEN
    RAISE EXCEPTION 'QA116 expected exactly four offers, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key IN (
      'fixture-qa116-attributes-array',
      'fixture-qa116-attributes-string',
      'fixture-qa116-attributes-number',
      'fixture-qa116-attributes-boolean'
    )
    AND e.event_type = 'ACTION_SUCCEEDED';
  IF v_count <> 4 THEN
    RAISE EXCEPTION 'QA116 expected exactly four success events, found %', v_count;
  END IF;

  RAISE NOTICE 'QA116 RPC: JSONB array, string, number and boolean attributes are accepted by the CI fixture, hashed, persisted with exact shapes and replayed without duplicates';
END
$qa116$;
SQL

echo "CREATE_OFFER QA116 characterizes JSONB array/string/number/boolean p_attributes at the authenticated RPC fixture: each shape is hashed, persisted, exactly replayed and represented by one offer/event."


# QA298: create an offer in one committed PostgreSQL transaction, then replay
# the exact request from a second independent transaction. The second response
# must equal the persisted JSONB result and must not create duplicate rows.
qa298_call_first=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa298-first-transaction';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa298-cross-transaction-replay',
  p_input => '{"case":"qa298-cross-transaction-replay"}'::jsonb,
  p_name => 'QA298 Cross Transaction Replay Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 7,
  p_price => 31.5,
  p_currency => 'EUR',
  p_conditions => 'cross-transaction',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"source":"qa298"}'::jsonb,
  p_documentation_status => 'verified'
);
COMMIT;
SQL
)

qa298_call_replay=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa298-replay-transaction';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa298-cross-transaction-replay',
  p_input => '{"case":"qa298-cross-transaction-replay"}'::jsonb,
  p_name => 'QA298 Cross Transaction Replay Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 7,
  p_price => 31.5,
  p_currency => 'EUR',
  p_conditions => 'cross-transaction',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"source":"qa298"}'::jsonb,
  p_documentation_status => 'verified'
);
COMMIT;
SQL
)

# Each psql process owns a separate explicit transaction. Capture the transaction
# ID beside the JSONB result so the test proves the replay happened after commit.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F $'\t' \
  -c "$qa298_call_first" > /tmp/qima-qa298-first.log 2>&1
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F $'\t' \
  -c "$qa298_call_replay" > /tmp/qima-qa298-replay.log 2>&1

qa298_first_rows=$(wc -l < /tmp/qima-qa298-first.log | tr -d '[:space:]')
qa298_replay_rows=$(wc -l < /tmp/qima-qa298-replay.log | tr -d '[:space:]')
if [[ "$qa298_first_rows" != "1" || "$qa298_replay_rows" != "1" ]]; then
  echo "QA298 expected one transaction/result row from each independent psql process." >&2
  cat /tmp/qima-qa298-first.log /tmp/qima-qa298-replay.log >&2
  exit 1
fi

IFS=$'\t' read -r qa298_first_txid qa298_first_result < /tmp/qima-qa298-first.log
IFS=$'\t' read -r qa298_replay_txid qa298_replay_result < /tmp/qima-qa298-replay.log
if [[ ! "$qa298_first_txid" =~ ^[0-9]+$ ||
      ! "$qa298_replay_txid" =~ ^[0-9]+$ ||
      "$qa298_first_txid" == "$qa298_replay_txid" ]]; then
  echo "QA298 expected distinct committed PostgreSQL transaction IDs; first='$qa298_first_txid', replay='$qa298_replay_txid'." >&2
  cat /tmp/qima-qa298-first.log /tmp/qima-qa298-replay.log >&2
  exit 1
fi

if [[ -z "$qa298_first_result" || "$qa298_first_result" != "$qa298_replay_result" ]]; then
  echo "QA298 independent-transaction replay did not return the exact first JSONB result." >&2
  diff -u /tmp/qima-qa298-first.log /tmp/qima-qa298-replay.log >&2 || true
  exit 1
fi

printf '%s\n' "$qa298_replay_result" > /tmp/qima-qa298-replay-result.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED';
" > /tmp/qima-qa298-stored-result.log
if ! cmp -s /tmp/qima-qa298-replay-result.log /tmp/qima-qa298-stored-result.log; then
  echo "QA298 second-transaction response does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa298-replay-result.log /tmp/qima-qa298-stored-result.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa298$
DECLARE
  v_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_count integer;
BEGIN
  SELECT result INTO v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED';

  IF NOT FOUND OR jsonb_typeof(v_result) IS DISTINCT FROM 'object'
     OR v_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_result->>'objectType' IS DISTINCT FROM 'Offer'
     OR nullif(v_result->>'executionId', '') IS NULL
     OR nullif(v_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA298 expected one completed object-shaped success result, got %',
      coalesce(v_result::text, '<missing>');
  END IF;

  v_execution_id := (v_result->>'executionId')::uuid;
  v_offer_id := (v_result->>'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA298 expected exactly one completed idempotency row, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND result = v_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA298 expected exactly one completed execution matching the replay result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA298 Cross Transaction Replay Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 7
    AND price = 31.5
    AND currency = 'EUR'
    AND conditions = 'cross-transaction'
    AND market = 'QA'
    AND geography = 'KR'
    AND attributes = '{"source":"qa298"}'::jsonb
    AND documentation_status = 'verified';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA298 expected exactly one offer preserving the original request, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA298 expected exactly one success event matching the persisted result, found %', v_count;
  END IF;
END
$qa298$;
SELECT 'QA298 cross-transaction replay returned the exact persisted JSONB result from a distinct committed transaction and left one idempotency row, execution, offer, and success event' AS result;
SQL

echo "QA298 committed first-time CREATE_OFFER in one PostgreSQL transaction; a second independent transaction replayed the identical JSONB result and persisted exactly one idempotency row, execution, offer, and success event."


# QA299: after QA298 commits a successful request, a second independent
# transaction reuses the same tenant/key with a changed effective payload.
# It must fail with IDEMPOTENCY_KEY_REUSE and leave the committed result intact.
qa299_changed_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa299-changed-payload-transaction';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current();
SELECT public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa298-cross-transaction-replay',
  p_input => '{"case":"qa298-cross-transaction-replay","price":32.0,"conditions":"cross-transaction-modified"}'::jsonb,
  p_name => 'QA298 Cross Transaction Replay Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 7,
  p_price => 32.0,
  p_currency => 'EUR',
  p_conditions => 'cross-transaction-modified',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"source":"qa298"}'::jsonb,
  p_documentation_status => 'verified'
);
COMMIT;
SQL
)

# Capture the committed request hash before attempting the changed payload.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT request_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED';
" > /tmp/qima-qa299-original-hash.log
qa299_hash_rows=$(wc -l < /tmp/qima-qa299-original-hash.log | tr -d '[:space:]')
if [[ "$qa299_hash_rows" != "1" || ! -s /tmp/qima-qa299-original-hash.log ]]; then
  echo "QA299 expected exactly one committed request hash before the changed-payload attempt." >&2
  cat /tmp/qima-qa299-original-hash.log >&2
  exit 1
fi

set +e
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -q -A -t \
  -c "$qa299_changed_call" > /tmp/qima-qa299-changed.log 2>&1
qa299_changed_status=$?
set -e

qa299_changed_txid=$(sed -n '1p' /tmp/qima-qa299-changed.log | tr -d '[:space:]')
if [[ "$qa299_changed_status" -eq 0 ]] ||
   ! grep -Fq "IDEMPOTENCY_KEY_REUSE" /tmp/qima-qa299-changed.log; then
  echo "QA299 changed payload after a committed success must fail with IDEMPOTENCY_KEY_REUSE (exit=$qa299_changed_status)." >&2
  cat /tmp/qima-qa299-changed.log >&2
  exit 1
fi

if [[ ! "$qa299_changed_txid" =~ ^[0-9]+$ ||
      "$qa299_changed_txid" == "$qa298_first_txid" ]]; then
  echo "QA299 expected the rejected changed-payload attempt to run in a distinct PostgreSQL transaction; first='$qa298_first_txid', changed='$qa299_changed_txid'." >&2
  cat /tmp/qima-qa299-changed.log >&2
  exit 1
fi

# The rejected transaction must not replace the committed JSONB result or hash.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED';
" > /tmp/qima-qa299-stored-result.log
if ! cmp -s /tmp/qima-qa298-stored-result.log /tmp/qima-qa299-stored-result.log; then
  echo "QA299 rejected changed payload altered the committed idempotency result." >&2
  diff -u /tmp/qima-qa298-stored-result.log /tmp/qima-qa299-stored-result.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT request_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED';
" > /tmp/qima-qa299-current-hash.log
if ! cmp -s /tmp/qima-qa299-original-hash.log /tmp/qima-qa299-current-hash.log; then
  echo "QA299 rejected changed payload altered the committed request hash." >&2
  diff -u /tmp/qima-qa299-original-hash.log /tmp/qima-qa299-current-hash.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa299$
DECLARE
  v_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_count integer;
BEGIN
  SELECT result INTO v_result
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED';

  IF NOT FOUND OR jsonb_typeof(v_result) IS DISTINCT FROM 'object'
     OR v_result->>'status' IS DISTINCT FROM 'succeeded'
     OR v_result->>'objectType' IS DISTINCT FROM 'Offer'
     OR nullif(v_result->>'executionId', '') IS NULL
     OR nullif(v_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA299 expected the original committed object-shaped success result to remain intact, got %',
      coalesce(v_result::text, '<missing>');
  END IF;

  v_execution_id := (v_result->>'executionId')::uuid;
  v_offer_id := (v_result->>'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA299 expected exactly one unchanged completed idempotency row, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa298-cross-transaction-replay';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA299 expected exactly one execution after the changed-payload rejection, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-qa298-cross-transaction-replay'
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND input = '{"case":"qa298-cross-transaction-replay"}'::jsonb
    AND result = v_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA299 expected the original completed execution/input/result to remain unchanged, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA298 Cross Transaction Replay Offer';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA299 expected exactly one offer after changed-payload rejection, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA298 Cross Transaction Replay Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 7
    AND price = 31.5
    AND currency = 'EUR'
    AND conditions = 'cross-transaction'
    AND market = 'QA'
    AND geography = 'KR'
    AND attributes = '{"source":"qa298"}'::jsonb
    AND documentation_status = 'verified';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA299 expected the original offer fields to remain unchanged, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA298 Cross Transaction Replay Offer'
    AND price = 32.0;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA299 rejected changed payload must not create or mutate an offer to the changed price, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA299 expected exactly one unchanged ACTION_SUCCEEDED event, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-qa298-cross-transaction-replay';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA299 rejected changed payload must not create an additional event, found %', v_count;
  END IF;
END
$qa299$;
SELECT 'QA299 changed payload after a committed CREATE_OFFER was rejected with IDEMPOTENCY_KEY_REUSE in a distinct transaction; original hash/result/offer/execution/event remained unchanged with no duplicates' AS result;
SQL

echo "QA299 rejected a changed effective payload after QA298 committed the original request; the second transaction received IDEMPOTENCY_KEY_REUSE and left the original idempotency hash/result and single offer/execution/success event unchanged."

# QA308: JSONB object-key order is not a business-payload change. Exercise the
# same idempotency key from two committed PostgreSQL transactions, changing only
# the order of top-level and nested keys in p_input and p_attributes.
qa308_first_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa308-jsonb-key-order-first';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa308-jsonb-key-order-replay',
  p_input => '{"alpha":1,"nested":{"left":"L","right":"R"},"omega":2}'::jsonb,
  p_name => 'QA308 JSONB Key Order Replay Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 3,
  p_price => 17.25,
  p_currency => 'USD',
  p_conditions => 'qa308-jsonb-key-order',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"a":1,"nested":{"x":1,"y":2},"z":3}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

qa308_replay_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa308-jsonb-key-order-replay';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa308-jsonb-key-order-replay',
  p_input => '{"omega":2,"nested":{"right":"R","left":"L"},"alpha":1}'::jsonb,
  p_name => 'QA308 JSONB Key Order Replay Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 3,
  p_price => 17.25,
  p_currency => 'USD',
  p_conditions => 'qa308-jsonb-key-order',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"z":3,"nested":{"y":2,"x":1},"a":1}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

# Each call runs in its own committed transaction. PostgreSQL JSONB canonicalizes
# object key order recursively, so both complete request hashes must be identical.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa308_first_call" > /tmp/qima-qa308-first.log 2>&1
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa308_replay_call" > /tmp/qima-qa308-replay.log 2>&1

qa308_first_rows=$(wc -l < /tmp/qima-qa308-first.log | tr -d '[:space:]')
qa308_replay_rows=$(wc -l < /tmp/qima-qa308-replay.log | tr -d '[:space:]')
if [[ "$qa308_first_rows" != "1" || "$qa308_replay_rows" != "1" ]]; then
  echo "QA308 expected one transaction/result row from each independent psql process." >&2
  cat /tmp/qima-qa308-first.log /tmp/qima-qa308-replay.log >&2
  exit 1
fi

IFS='|' read -r qa308_first_txid qa308_first_result < /tmp/qima-qa308-first.log
IFS='|' read -r qa308_replay_txid qa308_replay_result < /tmp/qima-qa308-replay.log
if [[ ! "$qa308_first_txid" =~ ^[0-9]+$ ||
      ! "$qa308_replay_txid" =~ ^[0-9]+$ ||
      "$qa308_first_txid" == "$qa308_replay_txid" ]]; then
  echo "QA308 expected distinct committed PostgreSQL transaction IDs; first='$qa308_first_txid', replay='$qa308_replay_txid'." >&2
  cat /tmp/qima-qa308-first.log /tmp/qima-qa308-replay.log >&2
  exit 1
fi

if [[ -z "$qa308_first_result" || "$qa308_first_result" != "$qa308_replay_result" ]]; then
  echo "QA308 reordered JSONB object keys changed the persisted idempotency result." >&2
  diff -u /tmp/qima-qa308-first.log /tmp/qima-qa308-replay.log >&2 || true
  exit 1
fi

printf '%s\n' "$qa308_replay_result" > /tmp/qima-qa308-replay-result.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa308-jsonb-key-order-replay'
    AND status = 'COMPLETED';
" > /tmp/qima-qa308-stored-result.log
if ! cmp -s /tmp/qima-qa308-replay-result.log /tmp/qima-qa308-stored-result.log; then
  echo "QA308 replay result does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa308-replay-result.log /tmp/qima-qa308-stored-result.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa308$
DECLARE
  v_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_request_hash text;
  v_expected_hash text;
  v_count integer;
BEGIN
  SELECT result, execution_id, request_hash
  INTO v_result, v_execution_id, v_request_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa308-jsonb-key-order-replay'
    AND status = 'COMPLETED';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QA308 expected one completed idempotency result';
  END IF;
  IF jsonb_typeof(v_result) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'QA308 expected the stored result to be a JSONB object';
  END IF;

  v_offer_id := (v_result->>'objectId')::uuid;
  v_expected_hash := md5(jsonb_build_object(
    'input', '{"alpha":1,"nested":{"left":"L","right":"R"},"omega":2}'::jsonb,
    'name', 'QA308 JSONB Key Order Replay Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 3,
    'price', 17.25,
    'currency', 'USD',
    'conditions', 'qa308-jsonb-key-order',
    'market', 'QA',
    'geography', 'KR',
    'attributes', '{"a":1,"nested":{"x":1,"y":2},"z":3}'::jsonb,
    'documentationStatus', 'verified',
    'lifecycle', 'draft',
    'offerType', 'supplier_offer',
    'pricingModel', 'fixed'
  )::text);

  IF v_request_hash <> v_expected_hash THEN
    RAISE EXCEPTION 'QA308 stored request hash does not match the canonical JSONB payload';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa308-jsonb-key-order-replay'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_result
    AND request_hash = v_expected_hash;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA308 expected exactly one canonical completed idempotency row, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-qa308-jsonb-key-order-replay'
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND input = '{"alpha":1,"nested":{"left":"L","right":"R"},"omega":2}'::jsonb
    AND result = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA308 expected exactly one completed execution with canonical JSONB input, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA308 JSONB Key Order Replay Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 3
    AND price = 17.25
    AND currency = 'USD'
    AND conditions = 'qa308-jsonb-key-order'
    AND market = 'QA'
    AND geography = 'KR'
    AND attributes = '{"a":1,"nested":{"x":1,"y":2},"z":3}'::jsonb
    AND documentation_status = 'verified'
    AND lifecycle = 'draft'
    AND offer_type = 'supplier_offer'
    AND pricing_model = 'fixed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA308 expected exactly one offer preserving the canonical JSONB attributes, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA308 expected exactly one success event matching the replay result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa308-jsonb-key-order-replay';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA308 replay created duplicate idempotency rows: %', v_count;
  END IF;
END
$qa308$;
SELECT 'QA308 JSONB key order was canonicalized recursively; a distinct committed transaction replayed the exact result with one idempotency row, execution, offer, and success event' AS result;
SQL

echo "QA308 confirmed that reordering top-level and nested JSONB object keys does not change the complete CREATE_OFFER request hash; a second committed PostgreSQL transaction replayed the exact persisted result without duplicates."


# QA309: JSONB array order is significant for idempotency. Unlike object keys,
# array positions are part of the effective payload: reordering top-level and
# nested arrays with the same tenant/key must be rejected after the first
# transaction commits, without changing its hash, result, offer or event.
qa309_first_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa309-jsonb-array-order-first';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa309-jsonb-array-order',
  p_input => '{"case":"qa309-jsonb-array-order","tags":["red","blue"],"nested":{"values":[1,2]}}'::jsonb,
  p_name => 'QA309 JSONB Array Order Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 2,
  p_price => 21.0,
  p_currency => 'USD',
  p_conditions => 'qa309-jsonb-array-order',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"tags":["red","blue"],"nested":{"values":[1,2]}}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

qa309_changed_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa309-jsonb-array-order-changed';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current();
SELECT public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa309-jsonb-array-order',
  p_input => '{"case":"qa309-jsonb-array-order","tags":["blue","red"],"nested":{"values":[2,1]}}'::jsonb,
  p_name => 'QA309 JSONB Array Order Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 2,
  p_price => 21.0,
  p_currency => 'USD',
  p_conditions => 'qa309-jsonb-array-order',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"tags":["blue","red"],"nested":{"values":[2,1]}}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa309_first_call" > /tmp/qima-qa309-first.log 2>&1
qa309_first_rows=$(wc -l < /tmp/qima-qa309-first.log | tr -d '[:space:]')
if [[ "$qa309_first_rows" != "1" ]]; then
  echo "QA309 expected one committed first-transaction/result row." >&2
  cat /tmp/qima-qa309-first.log >&2
  exit 1
fi
IFS='|' read -r qa309_first_txid qa309_first_result < /tmp/qima-qa309-first.log
if [[ ! "$qa309_first_txid" =~ ^[0-9]+$ || -z "$qa309_first_result" ]]; then
  echo "QA309 first transaction did not return a valid transaction ID and result." >&2
  cat /tmp/qima-qa309-first.log >&2
  exit 1
fi

printf '%s\n' "$qa309_first_result" > /tmp/qima-qa309-original-result.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT request_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa309-jsonb-array-order'
    AND status = 'COMPLETED';
" > /tmp/qima-qa309-original-hash.log
qa309_hash_rows=$(wc -l < /tmp/qima-qa309-original-hash.log | tr -d '[:space:]')
if [[ "$qa309_hash_rows" != "1" || ! -s /tmp/qima-qa309-original-hash.log ]]; then
  echo "QA309 expected exactly one committed request hash before changing array order." >&2
  cat /tmp/qima-qa309-original-hash.log >&2
  exit 1
fi

set +e
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -q -A -t \
  -c "$qa309_changed_call" > /tmp/qima-qa309-changed.log 2>&1
qa309_changed_status=$?
set -e

qa309_changed_txid=$(sed -n '1p' /tmp/qima-qa309-changed.log | tr -d '[:space:]')
if [[ "$qa309_changed_status" -eq 0 ]] ||
   ! grep -Fq "IDEMPOTENCY_KEY_REUSE" /tmp/qima-qa309-changed.log; then
  echo "QA309 changed JSONB array order must fail with IDEMPOTENCY_KEY_REUSE (exit=$qa309_changed_status)." >&2
  cat /tmp/qima-qa309-changed.log >&2
  exit 1
fi
if [[ ! "$qa309_changed_txid" =~ ^[0-9]+$ ||
      "$qa309_changed_txid" == "$qa309_first_txid" ]]; then
  echo "QA309 expected the changed-array attempt in a distinct transaction; first='$qa309_first_txid', changed='$qa309_changed_txid'." >&2
  cat /tmp/qima-qa309-changed.log >&2
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa309-jsonb-array-order'
    AND status = 'COMPLETED';
" > /tmp/qima-qa309-current-result.log
if ! cmp -s /tmp/qima-qa309-original-result.log /tmp/qima-qa309-current-result.log; then
  echo "QA309 changed-array rejection altered the committed idempotency result." >&2
  diff -u /tmp/qima-qa309-original-result.log /tmp/qima-qa309-current-result.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT request_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa309-jsonb-array-order'
    AND status = 'COMPLETED';
" > /tmp/qima-qa309-current-hash.log
if ! cmp -s /tmp/qima-qa309-original-hash.log /tmp/qima-qa309-current-hash.log; then
  echo "QA309 changed-array rejection altered the committed request hash." >&2
  diff -u /tmp/qima-qa309-original-hash.log /tmp/qima-qa309-current-hash.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa309$
DECLARE
  v_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_request_hash text;
  v_expected_hash text;
  v_count integer;
BEGIN
  SELECT result, execution_id, request_hash
  INTO v_result, v_execution_id, v_request_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa309-jsonb-array-order'
    AND status = 'COMPLETED';

  IF NOT FOUND OR jsonb_typeof(v_result) IS DISTINCT FROM 'object'
     OR v_result->>'status' IS DISTINCT FROM 'succeeded'
     OR nullif(v_result->>'executionId', '') IS NULL
     OR nullif(v_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA309 expected the original committed success result to remain intact, got %',
      coalesce(v_result::text, '<missing>');
  END IF;

  v_execution_id := (v_result->>'executionId')::uuid;
  v_offer_id := (v_result->>'objectId')::uuid;
  v_expected_hash := md5(jsonb_build_object(
    'input', '{"case":"qa309-jsonb-array-order","tags":["red","blue"],"nested":{"values":[1,2]}}'::jsonb,
    'name', 'QA309 JSONB Array Order Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 2,
    'price', 21.0,
    'currency', 'USD',
    'conditions', 'qa309-jsonb-array-order',
    'market', 'QA',
    'geography', 'KR',
    'attributes', '{"tags":["red","blue"],"nested":{"values":[1,2]}}'::jsonb,
    'documentationStatus', 'verified',
    'lifecycle', 'draft',
    'offerType', 'supplier_offer',
    'pricingModel', 'fixed'
  )::text);

  IF v_request_hash <> v_expected_hash THEN
    RAISE EXCEPTION 'QA309 stored request hash does not match the original ordered-array payload';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa309-jsonb-array-order'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_result
    AND request_hash = v_expected_hash;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA309 expected exactly one unchanged completed idempotency row, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa309-jsonb-array-order';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA309 expected exactly one execution after changed-array rejection, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-qa309-jsonb-array-order'
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND input = '{"case":"qa309-jsonb-array-order","tags":["red","blue"],"nested":{"values":[1,2]}}'::jsonb
    AND result = v_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA309 expected the original completed execution/input/result to remain unchanged, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA309 JSONB Array Order Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 2
    AND price = 21.0
    AND currency = 'USD'
    AND conditions = 'qa309-jsonb-array-order'
    AND market = 'QA'
    AND geography = 'KR'
    AND attributes = '{"tags":["red","blue"],"nested":{"values":[1,2]}}'::jsonb
    AND documentation_status = 'verified'
    AND lifecycle = 'draft'
    AND offer_type = 'supplier_offer'
    AND pricing_model = 'fixed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA309 expected exactly one offer preserving the original ordered arrays, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE name = 'QA309 JSONB Array Order Offer'
    AND attributes = '{"tags":["blue","red"],"nested":{"values":[2,1]}}'::jsonb;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'QA309 rejected changed arrays must not create or mutate an offer, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA309 expected exactly one unchanged ACTION_SUCCEEDED event, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events e
  JOIN public.action_executions x
    ON x.id = e.execution_id
   AND x.tenant_id = e.tenant_id
  WHERE x.tenant_id = '10000000-0000-4000-8000-000000000001'
    AND x.idempotency_key = 'fixture-qa309-jsonb-array-order';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA309 changed-array rejection must not create an additional event, found %', v_count;
  END IF;
END
$qa309$;
SELECT 'QA309 JSONB array order remains significant at top-level and nested paths; a changed-array request was rejected in a distinct committed transaction with IDEMPOTENCY_KEY_REUSE and the original hash/result/offer/execution/event remained unchanged' AS result;
SQL

echo "QA309 confirmed that changing top-level and nested JSONB array order changes the effective CREATE_OFFER payload; the distinct transaction was rejected with IDEMPOTENCY_KEY_REUSE and left the original committed state unchanged."

echo "QA310: characterize numeric-scale differences in the effective CREATE_OFFER idempotency hash."
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
-- QA310 is a characterization test, not a decision to normalize numeric scale.
-- PostgreSQL JSONB equality treats 1 and 1.0 as equal, while jsonb::text may
-- preserve their display scale. The current request hash is built from that text.
CREATE TEMP TABLE qa310_first_results (
  label text PRIMARY KEY,
  result jsonb NOT NULL,
  request_hash text,
  execution_id uuid,
  offer_id uuid
);
GRANT SELECT, INSERT, UPDATE ON qa310_first_results TO authenticated;

SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;

-- Commit three first-time requests independently. Each retry below changes only
-- one numeric representation: nested p_input JSONB, p_price, or p_quantity.

INSERT INTO qa310_first_results (label, result)
VALUES (
  'input-scale',
  public.execute_create_offer_v1(
    p_tenant_id => '10000000-0000-4000-8000-000000000001',
    p_idempotency_key => 'fixture-qa310-input-numeric-scale',
    p_input => '{"case":"qa310-input-numeric-scale","value":1}'::jsonb,
    p_name => 'QA310 Input Numeric Scale Offer',
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
    p_quantity => 2::numeric,
    p_price => 21::numeric,
    p_currency => 'USD',
    p_conditions => 'qa310-numeric-scale',
    p_market => 'QA',
    p_geography => 'KR',
    p_attributes => '{}'::jsonb,
    p_documentation_status => 'verified',
    p_lifecycle => 'draft',
    p_offer_type => 'supplier_offer',
    p_pricing_model => 'fixed'
  )
);
UPDATE qa310_first_results q
SET request_hash = i.request_hash,
    execution_id = i.execution_id,
    offer_id = (q.result->>'objectId')::uuid
FROM public.idempotency_keys i
WHERE q.label = 'input-scale'
  AND i.tenant_id = '10000000-0000-4000-8000-000000000001'
  AND i.key = 'fixture-qa310-input-numeric-scale';


INSERT INTO qa310_first_results (label, result)
VALUES (
  'price-scale',
  public.execute_create_offer_v1(
    p_tenant_id => '10000000-0000-4000-8000-000000000001',
    p_idempotency_key => 'fixture-qa310-price-numeric-scale',
    p_input => '{"case":"qa310-price-numeric-scale"}'::jsonb,
    p_name => 'QA310 Price Numeric Scale Offer',
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
    p_quantity => 2::numeric,
    p_price => 21::numeric,
    p_currency => 'USD',
    p_conditions => 'qa310-numeric-scale',
    p_market => 'QA',
    p_geography => 'KR',
    p_attributes => '{}'::jsonb,
    p_documentation_status => 'verified',
    p_lifecycle => 'draft',
    p_offer_type => 'supplier_offer',
    p_pricing_model => 'fixed'
  )
);
UPDATE qa310_first_results q
SET request_hash = i.request_hash,
    execution_id = i.execution_id,
    offer_id = (q.result->>'objectId')::uuid
FROM public.idempotency_keys i
WHERE q.label = 'price-scale'
  AND i.tenant_id = '10000000-0000-4000-8000-000000000001'
  AND i.key = 'fixture-qa310-price-numeric-scale';


INSERT INTO qa310_first_results (label, result)
VALUES (
  'quantity-scale',
  public.execute_create_offer_v1(
    p_tenant_id => '10000000-0000-4000-8000-000000000001',
    p_idempotency_key => 'fixture-qa310-quantity-numeric-scale',
    p_input => '{"case":"qa310-quantity-numeric-scale"}'::jsonb,
    p_name => 'QA310 Quantity Numeric Scale Offer',
    p_demand_id => '50000000-0000-4000-8000-000000000001',
    p_product_master_id => '40000000-0000-4000-8000-000000000001',
    p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
    p_quantity => 2::numeric,
    p_price => 21::numeric,
    p_currency => 'USD',
    p_conditions => 'qa310-numeric-scale',
    p_market => 'QA',
    p_geography => 'KR',
    p_attributes => '{}'::jsonb,
    p_documentation_status => 'verified',
    p_lifecycle => 'draft',
    p_offer_type => 'supplier_offer',
    p_pricing_model => 'fixed'
  )
);
UPDATE qa310_first_results q
SET request_hash = i.request_hash,
    execution_id = i.execution_id,
    offer_id = (q.result->>'objectId')::uuid
FROM public.idempotency_keys i
WHERE q.label = 'quantity-scale'
  AND i.tenant_id = '10000000-0000-4000-8000-000000000001'
  AND i.key = 'fixture-qa310-quantity-numeric-scale';

DO $qa310$
DECLARE
  v_error text;
  v_count integer;
BEGIN

  SELECT count(*) INTO v_count
  FROM qa310_first_results
  WHERE request_hash IS NOT NULL
    AND execution_id IS NOT NULL
    AND offer_id IS NOT NULL;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA310 expected three committed first-attempt snapshots, found %', v_count;
  END IF;

  IF '{"value":1}'::jsonb IS DISTINCT FROM '{"value":1.0}'::jsonb THEN
    RAISE EXCEPTION 'QA310 expected PostgreSQL JSONB equality to treat 1 and 1.0 as equal';
  END IF;
  IF ('{"value":1}'::jsonb)::text = ('{"value":1.0}'::jsonb)::text THEN
    RAISE EXCEPTION 'QA310 expected JSONB text to preserve the numeric display-scale distinction';
  END IF;

  IF md5(jsonb_build_object(
       'input', '{"value":1}'::jsonb,
       'price', 21::numeric,
       'quantity', 2::numeric
     )::text)
     = md5(jsonb_build_object(
       'input', '{"value":1.0}'::jsonb,
       'price', 21::numeric,
       'quantity', 2::numeric
     )::text) THEN
    RAISE EXCEPTION 'QA310 expected the input numeric-scale representation to affect the current hash';
  END IF;

  IF md5(jsonb_build_object(
       'input', '{"case":"price-scale"}'::jsonb,
       'price', 21::numeric,
       'quantity', 2::numeric
     )::text)
     = md5(jsonb_build_object(
       'input', '{"case":"price-scale"}'::jsonb,
       'price', 21.0::numeric,
       'quantity', 2::numeric
     )::text) THEN
    RAISE EXCEPTION 'QA310 expected the price numeric-scale representation to affect the current hash';
  END IF;

  IF md5(jsonb_build_object(
       'input', '{"case":"quantity-scale"}'::jsonb,
       'price', 21::numeric,
       'quantity', 2::numeric
     )::text)
     = md5(jsonb_build_object(
       'input', '{"case":"quantity-scale"}'::jsonb,
       'price', 21::numeric,
       'quantity', 2.0::numeric
     )::text) THEN
    RAISE EXCEPTION 'QA310 expected the quantity numeric-scale representation to affect the current hash';
  END IF;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-qa310-input-numeric-scale',
      p_input => '{"case":"qa310-input-numeric-scale","value":1.0}'::jsonb,
      p_name => 'QA310 Input Numeric Scale Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2::numeric,
      p_price => 21::numeric,
      p_currency => 'USD',
      p_conditions => 'qa310-numeric-scale',
      p_market => 'QA',
      p_geography => 'KR',
      p_attributes => '{}'::jsonb,
      p_documentation_status => 'verified',
      p_lifecycle => 'draft',
      p_offer_type => 'supplier_offer',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'QA310 expected IDEMPOTENCY_KEY_REUSE for input numeric scale';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'QA310 input numeric-scale retry returned unexpected error: %', v_error;
    END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-qa310-price-numeric-scale',
      p_input => '{"case":"qa310-price-numeric-scale"}'::jsonb,
      p_name => 'QA310 Price Numeric Scale Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2::numeric,
      p_price => 21.0::numeric,
      p_currency => 'USD',
      p_conditions => 'qa310-numeric-scale',
      p_market => 'QA',
      p_geography => 'KR',
      p_attributes => '{}'::jsonb,
      p_documentation_status => 'verified',
      p_lifecycle => 'draft',
      p_offer_type => 'supplier_offer',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'QA310 expected IDEMPOTENCY_KEY_REUSE for price numeric scale';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'QA310 price numeric-scale retry returned unexpected error: %', v_error;
    END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-qa310-quantity-numeric-scale',
      p_input => '{"case":"qa310-quantity-numeric-scale"}'::jsonb,
      p_name => 'QA310 Quantity Numeric Scale Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 2.0::numeric,
      p_price => 21::numeric,
      p_currency => 'USD',
      p_conditions => 'qa310-numeric-scale',
      p_market => 'QA',
      p_geography => 'KR',
      p_attributes => '{}'::jsonb,
      p_documentation_status => 'verified',
      p_lifecycle => 'draft',
      p_offer_type => 'supplier_offer',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'QA310 expected IDEMPOTENCY_KEY_REUSE for quantity numeric scale';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'QA310 quantity numeric-scale retry returned unexpected error: %', v_error;
    END IF;
  END;

  SELECT count(*) INTO v_count
  FROM qa310_first_results q
  JOIN public.idempotency_keys i
    ON i.tenant_id = '10000000-0000-4000-8000-000000000001'
   AND i.key = CASE q.label
     WHEN 'input-scale' THEN 'fixture-qa310-input-numeric-scale'
     WHEN 'price-scale' THEN 'fixture-qa310-price-numeric-scale'
     WHEN 'quantity-scale' THEN 'fixture-qa310-quantity-numeric-scale'
   END
   AND i.status = 'COMPLETED'
   AND i.request_hash = q.request_hash
   AND i.execution_id = q.execution_id
   AND i.result = q.result;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA310 expected all three original idempotency rows/hashes/results to remain unchanged, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM qa310_first_results q
  JOIN public.action_executions x
    ON x.tenant_id = '10000000-0000-4000-8000-000000000001'
   AND x.id = q.execution_id
   AND x.status = 'COMPLETED'
   AND x.object_id = q.offer_id
   AND x.result = q.result;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA310 expected exactly three unchanged completed executions, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM qa310_first_results q
  JOIN public.offers o ON o.id = q.offer_id
  WHERE o.price = 21::numeric
    AND o.quantity = 2::numeric;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA310 expected exactly three original offers with unchanged numeric values, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM qa310_first_results q
  JOIN public.action_events e
    ON e.tenant_id = '10000000-0000-4000-8000-000000000001'
   AND e.execution_id = q.execution_id
   AND e.event_type = 'ACTION_SUCCEEDED'
   AND e.object_id = q.offer_id
   AND e.payload = q.result;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA310 expected exactly three unchanged success events, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key IN (
      'fixture-qa310-input-numeric-scale',
      'fixture-qa310-price-numeric-scale',
      'fixture-qa310-quantity-numeric-scale'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA310 expected exactly three idempotency rows, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key IN (
      'fixture-qa310-input-numeric-scale',
      'fixture-qa310-price-numeric-scale',
      'fixture-qa310-quantity-numeric-scale'
    );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA310 expected exactly three executions, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id IN (SELECT offer_id FROM qa310_first_results);
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'QA310 expected exactly three offers, found %', v_count;
  END IF;
END
$qa310$;
SELECT 'QA310 characterized numeric scale: JSONB 1 and 1.0 compare equal, but the current text-based request hash distinguishes p_input, price, and quantity scale; changed-scale retries were rejected and original records remained unchanged' AS result;
SQL


# QA311: duplicate keys in JSON object input are collapsed by PostgreSQL JSONB
# using the last value. A request containing duplicate top-level and nested
# keys in both p_input and p_attributes must replay identically to the
# equivalent canonical JSONB objects with those duplicate keys removed.
qa311_first_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa311-jsonb-duplicate-keys-first';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa311-jsonb-duplicate-keys',
  p_input => '{"case":"qa311-jsonb-duplicate-keys","sku":"legacy","sku":"final","nested":{"state":"old","state":"current"}}'::jsonb,
  p_name => 'QA311 JSONB Duplicate Keys Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 4,
  p_price => 18.5,
  p_currency => 'USD',
  p_conditions => 'qa311-jsonb-duplicate-keys',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"grade":"legacy","grade":"A","nested":{"verified":false,"verified":true}}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

qa311_replay_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa311-jsonb-duplicate-keys-replay';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa311-jsonb-duplicate-keys',
  p_input => '{"case":"qa311-jsonb-duplicate-keys","sku":"final","nested":{"state":"current"}}'::jsonb,
  p_name => 'QA311 JSONB Duplicate Keys Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 4,
  p_price => 18.5,
  p_currency => 'USD',
  p_conditions => 'qa311-jsonb-duplicate-keys',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"grade":"A","nested":{"verified":true}}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

# Both requests execute in independent committed transactions. JSONB parsing
# keeps the last occurrence of a duplicate object key, including nested keys.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa311_first_call" > /tmp/qima-qa311-first.log 2>&1
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa311_replay_call" > /tmp/qima-qa311-replay.log 2>&1

qa311_first_rows=$(wc -l < /tmp/qima-qa311-first.log | tr -d '[:space:]')
qa311_replay_rows=$(wc -l < /tmp/qima-qa311-replay.log | tr -d '[:space:]')
if [[ "$qa311_first_rows" != "1" || "$qa311_replay_rows" != "1" ]]; then
  echo "QA311 expected one transaction/result row from each independent psql process." >&2
  cat /tmp/qima-qa311-first.log /tmp/qima-qa311-replay.log >&2
  exit 1
fi

IFS='|' read -r qa311_first_txid qa311_first_result < /tmp/qima-qa311-first.log
IFS='|' read -r qa311_replay_txid qa311_replay_result < /tmp/qima-qa311-replay.log
if [[ ! "$qa311_first_txid" =~ ^[0-9]+$ ||
      ! "$qa311_replay_txid" =~ ^[0-9]+$ ||
      "$qa311_first_txid" == "$qa311_replay_txid" ]]; then
  echo "QA311 expected distinct committed PostgreSQL transaction IDs; first='$qa311_first_txid', replay='$qa311_replay_txid'." >&2
  cat /tmp/qima-qa311-first.log /tmp/qima-qa311-replay.log >&2
  exit 1
fi

if [[ -z "$qa311_first_result" || "$qa311_first_result" != "$qa311_replay_result" ]]; then
  echo "QA311 duplicate-key and canonical JSONB requests did not replay the same result." >&2
  diff -u /tmp/qima-qa311-first.log /tmp/qima-qa311-replay.log >&2 || true
  exit 1
fi

printf '%s\n' "$qa311_replay_result" > /tmp/qima-qa311-replay-result.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa311-jsonb-duplicate-keys'
    AND status = 'COMPLETED';
" > /tmp/qima-qa311-stored-result.log
if ! cmp -s /tmp/qima-qa311-replay-result.log /tmp/qima-qa311-stored-result.log; then
  echo "QA311 replay result does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa311-replay-result.log /tmp/qima-qa311-stored-result.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa311$
DECLARE
  v_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_request_hash text;
  v_expected_hash text;
  v_input jsonb := '{"case":"qa311-jsonb-duplicate-keys","sku":"final","nested":{"state":"current"}}'::jsonb;
  v_attributes jsonb := '{"grade":"A","nested":{"verified":true}}'::jsonb;
  v_count integer;
BEGIN
  IF '{"case":"qa311-jsonb-duplicate-keys","sku":"legacy","sku":"final","nested":{"state":"old","state":"current"}}'::jsonb
       IS DISTINCT FROM v_input THEN
    RAISE EXCEPTION 'QA311 duplicate top-level/nested p_input keys did not collapse to their last values';
  END IF;
  IF '{"grade":"legacy","grade":"A","nested":{"verified":false,"verified":true}}'::jsonb
       IS DISTINCT FROM v_attributes THEN
    RAISE EXCEPTION 'QA311 duplicate top-level/nested p_attributes keys did not collapse to their last values';
  END IF;

  SELECT result, execution_id, request_hash
  INTO v_result, v_execution_id, v_request_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa311-jsonb-duplicate-keys'
    AND status = 'COMPLETED';

  IF NOT FOUND OR jsonb_typeof(v_result) IS DISTINCT FROM 'object'
     OR v_result->>'status' IS DISTINCT FROM 'succeeded'
     OR nullif(v_result->>'executionId', '') IS NULL
     OR nullif(v_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA311 expected the original committed success result, got %',
      coalesce(v_result::text, '<missing>');
  END IF;

  v_offer_id := (v_result->>'objectId')::uuid;
  v_expected_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'QA311 JSONB Duplicate Keys Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 4,
    'price', 18.5,
    'currency', 'USD',
    'conditions', 'qa311-jsonb-duplicate-keys',
    'market', 'QA',
    'geography', 'KR',
    'attributes', v_attributes,
    'documentationStatus', 'verified',
    'lifecycle', 'draft',
    'offerType', 'supplier_offer',
    'pricingModel', 'fixed'
  )::text);

  IF v_request_hash <> v_expected_hash THEN
    RAISE EXCEPTION 'QA311 stored request hash does not match canonical JSONB after duplicate-key collapse';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa311-jsonb-duplicate-keys'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_result
    AND request_hash = v_expected_hash;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA311 expected exactly one unchanged completed idempotency row, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-qa311-jsonb-duplicate-keys'
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND input = v_input
    AND result = v_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA311 expected one completed execution with canonical JSONB input, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA311 JSONB Duplicate Keys Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 4
    AND price = 18.5
    AND currency = 'USD'
    AND conditions = 'qa311-jsonb-duplicate-keys'
    AND market = 'QA'
    AND geography = 'KR'
    AND attributes = v_attributes
    AND documentation_status = 'verified'
    AND lifecycle = 'draft'
    AND offer_type = 'supplier_offer'
    AND pricing_model = 'fixed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA311 expected one offer preserving canonical JSONB attributes, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA311 expected exactly one success event matching the original result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa311-jsonb-duplicate-keys';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA311 replay created duplicate idempotency rows: %', v_count;
  END IF;
END
$qa311$;
SELECT 'QA311 JSONB duplicate top-level and nested object keys collapsed to the last values; a distinct committed transaction replayed the canonical result with one idempotency row, execution, offer, and success event' AS result;
SQL

echo "QA311 confirmed that duplicate top-level and nested JSON object keys in p_input and p_attributes collapse to PostgreSQL JSONB's last-value representation; a second committed transaction replayed the exact result without duplicates."


# QA312: duplicate keys inside JSON objects contained in JSONB arrays are
# collapsed by PostgreSQL JSONB using the last value. A request containing
# duplicate keys at array-object and nested-object paths in p_input and
# p_attributes must replay identically to the equivalent canonical arrays.
qa312_first_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa312-jsonb-duplicate-keys-first';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa312-jsonb-duplicate-keys',
  p_input => '{"case":"qa312-jsonb-array-object-duplicate-keys","items":[{"sku":"legacy","sku":"final","meta":{"state":"old","state":"current"}},{"position":2,"label":"second"}]}'::jsonb,
  p_name => 'QA312 JSONB Duplicate Keys Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 4,
  p_price => 18.5,
  p_currency => 'USD',
  p_conditions => 'qa312-jsonb-duplicate-keys',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"labels":[{"grade":"legacy","grade":"A","flags":{"verified":false,"verified":true}},{"grade":"B"}]}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

qa312_replay_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa312-jsonb-duplicate-keys-replay';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa312-jsonb-duplicate-keys',
  p_input => '{"case":"qa312-jsonb-array-object-duplicate-keys","items":[{"sku":"final","meta":{"state":"current"}},{"position":2,"label":"second"}]}'::jsonb,
  p_name => 'QA312 JSONB Duplicate Keys Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 4,
  p_price => 18.5,
  p_currency => 'USD',
  p_conditions => 'qa312-jsonb-duplicate-keys',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"labels":[{"grade":"A","flags":{"verified":true}},{"grade":"B"}]}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

# Both requests execute in independent committed transactions. JSONB parsing
# keeps the last occurrence of a duplicate object key, including nested keys.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa312_first_call" > /tmp/qima-qa312-first.log 2>&1
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa312_replay_call" > /tmp/qima-qa312-replay.log 2>&1

qa312_first_rows=$(wc -l < /tmp/qima-qa312-first.log | tr -d '[:space:]')
qa312_replay_rows=$(wc -l < /tmp/qima-qa312-replay.log | tr -d '[:space:]')
if [[ "$qa312_first_rows" != "1" || "$qa312_replay_rows" != "1" ]]; then
  echo "QA312 expected one transaction/result row from each independent psql process." >&2
  cat /tmp/qima-qa312-first.log /tmp/qima-qa312-replay.log >&2
  exit 1
fi

IFS='|' read -r qa312_first_txid qa312_first_result < /tmp/qima-qa312-first.log
IFS='|' read -r qa312_replay_txid qa312_replay_result < /tmp/qima-qa312-replay.log
if [[ ! "$qa312_first_txid" =~ ^[0-9]+$ ||
      ! "$qa312_replay_txid" =~ ^[0-9]+$ ||
      "$qa312_first_txid" == "$qa312_replay_txid" ]]; then
  echo "QA312 expected distinct committed PostgreSQL transaction IDs; first='$qa312_first_txid', replay='$qa312_replay_txid'." >&2
  cat /tmp/qima-qa312-first.log /tmp/qima-qa312-replay.log >&2
  exit 1
fi

if [[ -z "$qa312_first_result" || "$qa312_first_result" != "$qa312_replay_result" ]]; then
  echo "QA312 duplicate-key and canonical JSONB requests did not replay the same result." >&2
  diff -u /tmp/qima-qa312-first.log /tmp/qima-qa312-replay.log >&2 || true
  exit 1
fi

printf '%s\n' "$qa312_replay_result" > /tmp/qima-qa312-replay-result.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa312-jsonb-duplicate-keys'
    AND status = 'COMPLETED';
" > /tmp/qima-qa312-stored-result.log
if ! cmp -s /tmp/qima-qa312-replay-result.log /tmp/qima-qa312-stored-result.log; then
  echo "QA312 replay result does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa312-replay-result.log /tmp/qima-qa312-stored-result.log >&2 || true
  exit 1
fi

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa312$
DECLARE
  v_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_request_hash text;
  v_expected_hash text;
  v_input jsonb := '{"case":"qa312-jsonb-array-object-duplicate-keys","items":[{"sku":"final","meta":{"state":"current"}},{"position":2,"label":"second"}]}'::jsonb;
  v_attributes jsonb := '{"labels":[{"grade":"A","flags":{"verified":true}},{"grade":"B"}]}'::jsonb;
  v_count integer;
BEGIN
  IF '{"case":"qa312-jsonb-array-object-duplicate-keys","items":[{"sku":"legacy","sku":"final","meta":{"state":"old","state":"current"}},{"position":2,"label":"second"}]}'::jsonb
       IS DISTINCT FROM v_input THEN
    RAISE EXCEPTION 'QA312 duplicate top-level/nested p_input keys did not collapse to their last values';
  END IF;
  IF '{"labels":[{"grade":"legacy","grade":"A","flags":{"verified":false,"verified":true}},{"grade":"B"}]}'::jsonb
       IS DISTINCT FROM v_attributes THEN
    RAISE EXCEPTION 'QA312 duplicate keys inside p_attributes array objects did not collapse to their last values';
  END IF;

  IF jsonb_array_length(v_input->'items') IS DISTINCT FROM 2
     OR v_input #>> '{items,0,sku}' IS DISTINCT FROM 'final'
     OR v_input #>> '{items,0,meta,state}' IS DISTINCT FROM 'current'
     OR v_input #>> '{items,1,position}' IS DISTINCT FROM '2'
     OR v_input #>> '{items,1,label}' IS DISTINCT FROM 'second'
     OR jsonb_array_length(v_attributes->'labels') IS DISTINCT FROM 2
     OR v_attributes #>> '{labels,0,grade}' IS DISTINCT FROM 'A'
     OR v_attributes #>> '{labels,0,flags,verified}' IS DISTINCT FROM 'true'
     OR v_attributes #>> '{labels,1,grade}' IS DISTINCT FROM 'B' THEN
    RAISE EXCEPTION 'QA312 expected duplicate keys to collapse inside array objects while preserving array order and nested values';
  END IF;

  SELECT result, execution_id, request_hash
  INTO v_result, v_execution_id, v_request_hash
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa312-jsonb-duplicate-keys'
    AND status = 'COMPLETED';

  IF NOT FOUND OR jsonb_typeof(v_result) IS DISTINCT FROM 'object'
     OR v_result->>'status' IS DISTINCT FROM 'succeeded'
     OR nullif(v_result->>'executionId', '') IS NULL
     OR nullif(v_result->>'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA312 expected the original committed success result, got %',
      coalesce(v_result::text, '<missing>');
  END IF;

  v_offer_id := (v_result->>'objectId')::uuid;
  v_expected_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'QA312 JSONB Duplicate Keys Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 4,
    'price', 18.5,
    'currency', 'USD',
    'conditions', 'qa312-jsonb-duplicate-keys',
    'market', 'QA',
    'geography', 'KR',
    'attributes', v_attributes,
    'documentationStatus', 'verified',
    'lifecycle', 'draft',
    'offerType', 'supplier_offer',
    'pricingModel', 'fixed'
  )::text);

  IF v_request_hash <> v_expected_hash THEN
    RAISE EXCEPTION 'QA312 stored request hash does not match canonical JSONB after duplicate-key collapse';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa312-jsonb-duplicate-keys'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND result = v_result
    AND request_hash = v_expected_hash;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA312 expected exactly one unchanged completed idempotency row, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-qa312-jsonb-duplicate-keys'
    AND status = 'COMPLETED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND input = v_input
    AND result = v_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA312 expected one completed execution with canonical JSONB input, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA312 JSONB Duplicate Keys Offer'
    AND demand_id = '50000000-0000-4000-8000-000000000001'
    AND product_master_id = '40000000-0000-4000-8000-000000000001'
    AND provider_actor_id = '30000000-0000-4000-8000-000000000001'
    AND quantity = 4
    AND price = 18.5
    AND currency = 'USD'
    AND conditions = 'qa312-jsonb-duplicate-keys'
    AND market = 'QA'
    AND geography = 'KR'
    AND attributes = v_attributes
    AND documentation_status = 'verified'
    AND lifecycle = 'draft'
    AND offer_type = 'supplier_offer'
    AND pricing_model = 'fixed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA312 expected one offer preserving canonical JSONB attributes, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA312 expected exactly one success event matching the original result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa312-jsonb-duplicate-keys';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA312 replay created duplicate idempotency rows: %', v_count;
  END IF;
END
$qa312$;
SELECT 'QA312 JSONB duplicate keys inside array objects collapsed to the last values; a distinct committed transaction replayed the canonical result with one idempotency row, execution, offer, and success event' AS result;
SQL

echo "QA312 confirmed that duplicate JSON object keys inside arrays in p_input and p_attributes collapse to PostgreSQL JSONB's last-value representation; a second committed transaction replayed the exact result without duplicates."




# QA313: duplicate object keys whose final values are JSON null must collapse
# to the canonical explicit-null representation. An equivalent explicit-null
# retry replays; omitting the same properties is a changed payload and must be
# rejected without replacing the original idempotency result.
qa313_first_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa313-duplicate-null-first';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa313-jsonb-duplicate-null',
  p_input => '{"case":"qa313-jsonb-duplicate-null","optional":"legacy","optional":null,"nested":{"state":"old","state":null}}'::jsonb,
  p_name => 'QA313 JSONB Duplicate Null Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 4,
  p_price => 19.25,
  p_currency => 'USD',
  p_conditions => 'qa313-jsonb-duplicate-null',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"label":"legacy","label":null,"metadata":{"verified":false,"verified":null}}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

qa313_replay_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa313-duplicate-null-replay';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa313-jsonb-duplicate-null',
  p_input => '{"case":"qa313-jsonb-duplicate-null","optional":null,"nested":{"state":null}}'::jsonb,
  p_name => 'QA313 JSONB Duplicate Null Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 4,
  p_price => 19.25,
  p_currency => 'USD',
  p_conditions => 'qa313-jsonb-duplicate-null',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"label":null,"metadata":{"verified":null}}'::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

# The first and canonical explicit-null requests run in separate committed
# PostgreSQL transactions. Their transaction IDs must differ while their
# returned result payloads remain byte-for-byte identical.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa313_first_call" > /tmp/qima-qa313-first.log 2>&1
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa313_replay_call" > /tmp/qima-qa313-replay.log 2>&1

qa313_first_rows=$(wc -l < /tmp/qima-qa313-first.log | tr -d '[:space:]')
qa313_replay_rows=$(wc -l < /tmp/qima-qa313-replay.log | tr -d '[:space:]')
if [[ "$qa313_first_rows" != "1" || "$qa313_replay_rows" != "1" ]]; then
  echo "QA313 expected one transaction/result row from each independent psql process." >&2
  cat /tmp/qima-qa313-first.log /tmp/qima-qa313-replay.log >&2
  exit 1
fi

IFS='|' read -r qa313_first_txid qa313_first_result < /tmp/qima-qa313-first.log
IFS='|' read -r qa313_replay_txid qa313_replay_result < /tmp/qima-qa313-replay.log
if [[ ! "$qa313_first_txid" =~ ^[0-9]+$ ||
      ! "$qa313_replay_txid" =~ ^[0-9]+$ ||
      "$qa313_first_txid" == "$qa313_replay_txid" ]]; then
  echo "QA313 expected distinct committed PostgreSQL transaction IDs; first='$qa313_first_txid', replay='$qa313_replay_txid'." >&2
  cat /tmp/qima-qa313-first.log /tmp/qima-qa313-replay.log >&2
  exit 1
fi

if [[ -z "$qa313_first_result" || "$qa313_first_result" != "$qa313_replay_result" ]]; then
  echo "QA313 duplicate-key and canonical explicit-null requests did not replay the same result." >&2
  diff -u /tmp/qima-qa313-first.log /tmp/qima-qa313-replay.log >&2 || true
  exit 1
fi

printf '%s\n' "$qa313_replay_result" > /tmp/qima-qa313-replay-result.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa313-jsonb-duplicate-null'
    AND status = 'COMPLETED';
" > /tmp/qima-qa313-stored-result.log
if ! cmp -s /tmp/qima-qa313-replay-result.log /tmp/qima-qa313-stored-result.log; then
  echo "QA313 replay result does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa313-replay-result.log /tmp/qima-qa313-stored-result.log >&2 || true
  exit 1
fi

# Changed-payload retries execute in a fresh authenticated session. This keeps
# the RPC's JWT/role preconditions identical to the first-time and replay calls.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
DO $qa313_reject$
DECLARE
  v_error text;
BEGIN
  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-qa313-jsonb-duplicate-null',
      p_input => '{"case":"qa313-jsonb-duplicate-null","nested":{}}'::jsonb,
      p_name => 'QA313 JSONB Duplicate Null Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 4,
      p_price => 19.25,
      p_currency => 'USD',
      p_conditions => 'qa313-jsonb-duplicate-null',
      p_market => 'QA',
      p_geography => 'KR',
      p_attributes => '{"label":null,"metadata":{"verified":null}}'::jsonb,
      p_documentation_status => 'verified',
      p_lifecycle => 'draft',
      p_offer_type => 'supplier_offer',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'QA313 expected IDEMPOTENCY_KEY_REUSE for absent p_input properties';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'QA313 absent p_input retry returned unexpected error: %', v_error;
    END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-qa313-jsonb-duplicate-null',
      p_input => '{"case":"qa313-jsonb-duplicate-null","optional":null,"nested":{"state":null}}'::jsonb,
      p_name => 'QA313 JSONB Duplicate Null Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 4,
      p_price => 19.25,
      p_currency => 'USD',
      p_conditions => 'qa313-jsonb-duplicate-null',
      p_market => 'QA',
      p_geography => 'KR',
      p_attributes => '{"metadata":{}}'::jsonb,
      p_documentation_status => 'verified',
      p_lifecycle => 'draft',
      p_offer_type => 'supplier_offer',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'QA313 expected IDEMPOTENCY_KEY_REUSE for absent p_attributes properties';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'QA313 absent p_attributes retry returned unexpected error: %', v_error;
    END IF;
  END;
END
$qa313_reject$;
SQL

psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa313$
DECLARE
  v_input jsonb := '{"case":"qa313-jsonb-duplicate-null","optional":null,"nested":{"state":null}}'::jsonb;
  v_input_absent jsonb := '{"case":"qa313-jsonb-duplicate-null","nested":{}}'::jsonb;
  v_attributes jsonb := '{"label":null,"metadata":{"verified":null}}'::jsonb;
  v_attributes_absent jsonb := '{"metadata":{}}'::jsonb;
  v_expected_hash text;
  v_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_count integer;
BEGIN
  IF '{"case":"qa313-jsonb-duplicate-null","optional":"legacy","optional":null,"nested":{"state":"old","state":null}}'::jsonb
       IS DISTINCT FROM v_input THEN
    RAISE EXCEPTION 'QA313 duplicate p_input keys ending in JSON null did not collapse to the canonical explicit-null object';
  END IF;
  IF '{"label":"legacy","label":null,"metadata":{"verified":false,"verified":null}}'::jsonb
       IS DISTINCT FROM v_attributes THEN
    RAISE EXCEPTION 'QA313 duplicate p_attributes keys ending in JSON null did not collapse to the canonical explicit-null object';
  END IF;

  IF NOT (v_input ? 'optional')
     OR jsonb_typeof(v_input -> 'optional') IS DISTINCT FROM 'null'
     OR jsonb_typeof(v_input #> '{nested,state}') IS DISTINCT FROM 'null'
     OR NOT (v_attributes ? 'label')
     OR jsonb_typeof(v_attributes -> 'label') IS DISTINCT FROM 'null'
     OR jsonb_typeof(v_attributes #> '{metadata,verified}') IS DISTINCT FROM 'null' THEN
    RAISE EXCEPTION 'QA313 expected final duplicate-key JSON null values to remain present as explicit JSON null properties';
  END IF;

  IF v_input_absent ? 'optional'
     OR v_input_absent #> '{nested,state}' IS NOT NULL
     OR v_attributes_absent ? 'label'
     OR v_attributes_absent #> '{metadata,verified}' IS NOT NULL THEN
    RAISE EXCEPTION 'QA313 absent-property controls unexpectedly contain explicit-null properties';
  END IF;

  v_expected_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'QA313 JSONB Duplicate Null Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 4,
    'price', 19.25,
    'currency', 'USD',
    'conditions', 'qa313-jsonb-duplicate-null',
    'market', 'QA',
    'geography', 'KR',
    'attributes', v_attributes,
    'documentationStatus', 'verified',
    'lifecycle', 'draft',
    'offerType', 'supplier_offer',
    'pricingModel', 'fixed'
  )::text);

  SELECT result, execution_id
  INTO v_result, v_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa313-jsonb-duplicate-null'
    AND status = 'COMPLETED';

  IF NOT FOUND
     OR v_result ->> 'status' IS DISTINCT FROM 'succeeded'
     OR nullif(v_result ->> 'executionId', '') IS NULL
     OR nullif(v_result ->> 'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA313 expected the original completed success result, got %', coalesce(v_result::text, '<missing>');
  END IF;

  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa313-jsonb-duplicate-null'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_expected_hash
    AND result = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA313 expected one unchanged completed idempotency row with the explicit-null hash/result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-qa313-jsonb-duplicate-null'
    AND status = 'COMPLETED'
    AND input = v_input
    AND result = v_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA313 expected one completed execution preserving explicit-null input, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA313 JSONB Duplicate Null Offer'
    AND quantity = 4
    AND price = 19.25
    AND currency = 'USD'
    AND conditions = 'qa313-jsonb-duplicate-null'
    AND market = 'QA'
    AND geography = 'KR'
    AND attributes = v_attributes
    AND documentation_status = 'verified'
    AND lifecycle = 'draft'
    AND offer_type = 'supplier_offer'
    AND pricing_model = 'fixed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA313 expected one original offer preserving explicit-null attributes, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA313 expected one success event matching the original result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa313-jsonb-duplicate-null';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA313 retries created duplicate idempotency rows: %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa313-jsonb-duplicate-null';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA313 retries created duplicate executions: %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA313 retries changed the original offer count: %', v_count;
  END IF;
END
$qa313$;
SELECT 'QA313 duplicate keys ending in JSON null replay as canonical explicit-null properties; same-key retries omitting those properties are rejected and the original idempotency result, execution, offer, and success event remain unchanged' AS result;
SQL

echo "QA313 confirmed that duplicate JSON object keys ending in JSON null collapse to explicit-null properties in p_input and p_attributes; canonical explicit-null replay succeeds, absent-property retries are rejected, and original records remain unchanged."


# QA314: duplicate JSON keys ending in JSON null inside JSONB array objects.
# Canonical explicit-null array objects replay; omitting those object properties
# changes the effective payload and must be rejected without mutating the
# original idempotency result, execution, offer, or success event.
qa314_first_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa314-array-duplicate-null-first';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa314-array-duplicate-null',
  p_input => '{"case":"qa314-array-duplicate-null","items":[{"sku":"legacy","sku":null,"meta":{"state":"old","state":null}},{"sku":"second","position":2}]}'::jsonb,
  p_name => 'QA314 JSONB Array Duplicate Null Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 5,
  p_price => 20.25,
  p_currency => 'USD',
  p_conditions => 'qa314-array-duplicate-null',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"labels":[{"name":"legacy","name":null,"metadata":{"verified":false,"verified":null}},{"name":"second","rank":2}]} '::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

qa314_replay_call=$(cat <<'SQL'
BEGIN;
SET application_name = 'qima-qa314-array-duplicate-null-replay';
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT txid_current(), public.execute_create_offer_v1(
  p_tenant_id => '10000000-0000-4000-8000-000000000001',
  p_idempotency_key => 'fixture-qa314-array-duplicate-null',
  p_input => '{"case":"qa314-array-duplicate-null","items":[{"sku":null,"meta":{"state":null}},{"sku":"second","position":2}]}'::jsonb,
  p_name => 'QA314 JSONB Array Duplicate Null Offer',
  p_demand_id => '50000000-0000-4000-8000-000000000001',
  p_product_master_id => '40000000-0000-4000-8000-000000000001',
  p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
  p_quantity => 5,
  p_price => 20.25,
  p_currency => 'USD',
  p_conditions => 'qa314-array-duplicate-null',
  p_market => 'QA',
  p_geography => 'KR',
  p_attributes => '{"labels":[{"name":null,"metadata":{"verified":null}},{"name":"second","rank":2}]} '::jsonb,
  p_documentation_status => 'verified',
  p_lifecycle => 'draft',
  p_offer_type => 'supplier_offer',
  p_pricing_model => 'fixed'
);
COMMIT;
SQL
)

# Execute first and canonical replay in separate committed PostgreSQL sessions.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa314_first_call" > /tmp/qima-qa314-first.log 2>&1
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -F '|' -c "$qa314_replay_call" > /tmp/qima-qa314-replay.log 2>&1

qa314_first_rows=$(wc -l < /tmp/qima-qa314-first.log | tr -d '[:space:]')
qa314_replay_rows=$(wc -l < /tmp/qima-qa314-replay.log | tr -d '[:space:]')
if [[ "$qa314_first_rows" != "1" || "$qa314_replay_rows" != "1" ]]; then
  echo "QA314 expected one transaction/result row from each independent psql process." >&2
  cat /tmp/qima-qa314-first.log /tmp/qima-qa314-replay.log >&2
  exit 1
fi

IFS='|' read -r qa314_first_txid qa314_first_result < /tmp/qima-qa314-first.log
IFS='|' read -r qa314_replay_txid qa314_replay_result < /tmp/qima-qa314-replay.log
if [[ ! "$qa314_first_txid" =~ ^[0-9]+$ ||
      ! "$qa314_replay_txid" =~ ^[0-9]+$ ||
      "$qa314_first_txid" == "$qa314_replay_txid" ]]; then
  echo "QA314 expected distinct committed PostgreSQL transaction IDs; first='$qa314_first_txid', replay='$qa314_replay_txid'." >&2
  cat /tmp/qima-qa314-first.log /tmp/qima-qa314-replay.log >&2
  exit 1
fi
if [[ -z "$qa314_first_result" || "$qa314_first_result" != "$qa314_replay_result" ]]; then
  echo "QA314 duplicate-key and canonical explicit-null array objects did not replay the same result." >&2
  diff -u /tmp/qima-qa314-first.log /tmp/qima-qa314-replay.log >&2 || true
  exit 1
fi

printf '%s\n' "$qa314_replay_result" > /tmp/qima-qa314-replay-result.log
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t -c "
  SELECT result::text
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa314-array-duplicate-null'
    AND status = 'COMPLETED';
" > /tmp/qima-qa314-stored-result.log
if ! cmp -s /tmp/qima-qa314-replay-result.log /tmp/qima-qa314-stored-result.log; then
  echo "QA314 replay result does not match the persisted idempotency result." >&2
  diff -u /tmp/qima-qa314-replay-result.log /tmp/qima-qa314-stored-result.log >&2 || true
  exit 1
fi

# Changed-payload retries run as authenticated in a fresh session, matching
# the RPC preconditions of the first creation and canonical replay.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
SET request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
DO $qa314_reject$
DECLARE
  v_error text;
BEGIN
  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-qa314-array-duplicate-null',
      p_input => '{"case":"qa314-array-duplicate-null","items":[{"meta":{"state":null}},{"sku":"second","position":2}]}'::jsonb,
      p_name => 'QA314 JSONB Array Duplicate Null Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 5,
      p_price => 20.25,
      p_currency => 'USD',
      p_conditions => 'qa314-array-duplicate-null',
      p_market => 'QA',
      p_geography => 'KR',
      p_attributes => '{"labels":[{"name":null,"metadata":{"verified":null}},{"name":"second","rank":2}]} '::jsonb,
      p_documentation_status => 'verified',
      p_lifecycle => 'draft',
      p_offer_type => 'supplier_offer',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'QA314 expected IDEMPOTENCY_KEY_REUSE when the first array object p_input property is absent';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'QA314 absent p_input array property returned unexpected error: %', v_error;
    END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-qa314-array-duplicate-null',
      p_input => '{"case":"qa314-array-duplicate-null","items":[{"sku":null,"meta":{"state":null}},{"sku":"second","position":2}]}'::jsonb,
      p_name => 'QA314 JSONB Array Duplicate Null Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 5,
      p_price => 20.25,
      p_currency => 'USD',
      p_conditions => 'qa314-array-duplicate-null',
      p_market => 'QA',
      p_geography => 'KR',
      p_attributes => '{"labels":[{"metadata":{"verified":null}},{"name":"second","rank":2}]} '::jsonb,
      p_documentation_status => 'verified',
      p_lifecycle => 'draft',
      p_offer_type => 'supplier_offer',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'QA314 expected IDEMPOTENCY_KEY_REUSE when the first array object p_attributes property is absent';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'QA314 absent p_attributes array property returned unexpected error: %', v_error;
    END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-qa314-array-duplicate-null',
      p_input => '{"case":"qa314-array-duplicate-null","items":[{"sku":null,"meta":{}},{"sku":"second","position":2}]}'::jsonb,
      p_name => 'QA314 JSONB Array Duplicate Null Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 5,
      p_price => 20.25,
      p_currency => 'USD',
      p_conditions => 'qa314-array-duplicate-null',
      p_market => 'QA',
      p_geography => 'KR',
      p_attributes => '{"labels":[{"name":null,"metadata":{"verified":null}},{"name":"second","rank":2}]} '::jsonb,
      p_documentation_status => 'verified',
      p_lifecycle => 'draft',
      p_offer_type => 'supplier_offer',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'QA314 expected IDEMPOTENCY_KEY_REUSE when the nested p_input array-object property is absent';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'QA314 absent nested p_input array property returned unexpected error: %', v_error;
    END IF;
  END;

  BEGIN
    PERFORM public.execute_create_offer_v1(
      p_tenant_id => '10000000-0000-4000-8000-000000000001',
      p_idempotency_key => 'fixture-qa314-array-duplicate-null',
      p_input => '{"case":"qa314-array-duplicate-null","items":[{"sku":null,"meta":{"state":null}},{"sku":"second","position":2}]}'::jsonb,
      p_name => 'QA314 JSONB Array Duplicate Null Offer',
      p_demand_id => '50000000-0000-4000-8000-000000000001',
      p_product_master_id => '40000000-0000-4000-8000-000000000001',
      p_provider_actor_id => '30000000-0000-4000-8000-000000000001',
      p_quantity => 5,
      p_price => 20.25,
      p_currency => 'USD',
      p_conditions => 'qa314-array-duplicate-null',
      p_market => 'QA',
      p_geography => 'KR',
      p_attributes => '{"labels":[{"name":null,"metadata":{}},{"name":"second","rank":2}]} '::jsonb,
      p_documentation_status => 'verified',
      p_lifecycle => 'draft',
      p_offer_type => 'supplier_offer',
      p_pricing_model => 'fixed'
    );
    RAISE EXCEPTION 'QA314 expected IDEMPOTENCY_KEY_REUSE when the nested p_attributes array-object property is absent';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'IDEMPOTENCY_KEY_REUSE' THEN
      RAISE EXCEPTION 'QA314 absent nested p_attributes array property returned unexpected error: %', v_error;
    END IF;
  END;

END
$qa314_reject$;
SQL

# Verify JSONB canonicalization, array order, the persisted hash/result, and
# exactly one idempotency row, execution, offer, and success event.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $qa314$
DECLARE
  v_input jsonb := '{"case":"qa314-array-duplicate-null","items":[{"sku":null,"meta":{"state":null}},{"sku":"second","position":2}]}'::jsonb;
  v_input_absent jsonb := '{"case":"qa314-array-duplicate-null","items":[{"meta":{"state":null}},{"sku":"second","position":2}]}'::jsonb;
  v_input_nested_absent jsonb := '{"case":"qa314-array-duplicate-null","items":[{"sku":null,"meta":{}},{"sku":"second","position":2}]}'::jsonb;
  v_attributes jsonb := '{"labels":[{"name":null,"metadata":{"verified":null}},{"name":"second","rank":2}]}'::jsonb;
  v_attributes_absent jsonb := '{"labels":[{"metadata":{"verified":null}},{"name":"second","rank":2}]}'::jsonb;
  v_attributes_nested_absent jsonb := '{"labels":[{"name":null,"metadata":{}},{"name":"second","rank":2}]}'::jsonb;
  v_expected_hash text;
  v_result jsonb;
  v_execution_id uuid;
  v_offer_id uuid;
  v_count integer;
BEGIN
  IF '{"case":"qa314-array-duplicate-null","items":[{"sku":"legacy","sku":null,"meta":{"state":"old","state":null}},{"sku":"second","position":2}]}'::jsonb
       IS DISTINCT FROM v_input THEN
    RAISE EXCEPTION 'QA314 duplicate keys ending in JSON null inside p_input array objects did not collapse to canonical explicit-null values';
  END IF;
  IF '{"labels":[{"name":"legacy","name":null,"metadata":{"verified":false,"verified":null}},{"name":"second","rank":2}]}'::jsonb
       IS DISTINCT FROM v_attributes THEN
    RAISE EXCEPTION 'QA314 duplicate keys ending in JSON null inside p_attributes array objects did not collapse to canonical explicit-null values';
  END IF;

  IF jsonb_array_length(v_input -> 'items') <> 2
     OR jsonb_typeof(v_input #> '{items,0,sku}') IS DISTINCT FROM 'null'
     OR jsonb_typeof(v_input #> '{items,0,meta,state}') IS DISTINCT FROM 'null'
     OR v_input #>> '{items,1,sku}' IS DISTINCT FROM 'second'
     OR (v_input #>> '{items,1,position}')::integer <> 2
     OR jsonb_array_length(v_attributes -> 'labels') <> 2
     OR jsonb_typeof(v_attributes #> '{labels,0,name}') IS DISTINCT FROM 'null'
     OR jsonb_typeof(v_attributes #> '{labels,0,metadata,verified}') IS DISTINCT FROM 'null'
     OR v_attributes #>> '{labels,1,name}' IS DISTINCT FROM 'second'
     OR (v_attributes #>> '{labels,1,rank}')::integer <> 2 THEN
    RAISE EXCEPTION 'QA314 expected explicit-null object properties and original array order to be preserved';
  END IF;

  IF (v_input_absent #> '{items,0,sku}') IS NOT NULL
     OR (v_attributes_absent #> '{labels,0,name}') IS NOT NULL
     OR (v_input_nested_absent #> '{items,0,meta,state}') IS NOT NULL
     OR (v_attributes_nested_absent #> '{labels,0,metadata,verified}') IS NOT NULL THEN
    RAISE EXCEPTION 'QA314 absent-property controls unexpectedly contain the explicit-null array properties';
  END IF;

  v_expected_hash := md5(jsonb_build_object(
    'input', v_input,
    'name', 'QA314 JSONB Array Duplicate Null Offer',
    'demandId', '50000000-0000-4000-8000-000000000001'::uuid,
    'productMasterId', '40000000-0000-4000-8000-000000000001'::uuid,
    'providerActorId', '30000000-0000-4000-8000-000000000001'::uuid,
    'quantity', 5,
    'price', 20.25,
    'currency', 'USD',
    'conditions', 'qa314-array-duplicate-null',
    'market', 'QA',
    'geography', 'KR',
    'attributes', v_attributes,
    'documentationStatus', 'verified',
    'lifecycle', 'draft',
    'offerType', 'supplier_offer',
    'pricingModel', 'fixed'
  )::text);

  SELECT result, execution_id
  INTO v_result, v_execution_id
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa314-array-duplicate-null'
    AND status = 'COMPLETED';

  IF NOT FOUND
     OR v_result ->> 'status' IS DISTINCT FROM 'succeeded'
     OR nullif(v_result ->> 'executionId', '') IS NULL
     OR nullif(v_result ->> 'objectId', '') IS NULL THEN
    RAISE EXCEPTION 'QA314 expected the original completed success result, got %', coalesce(v_result::text, '<missing>');
  END IF;

  v_offer_id := (v_result ->> 'objectId')::uuid;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa314-array-duplicate-null'
    AND status = 'COMPLETED'
    AND execution_id = v_execution_id
    AND request_hash = v_expected_hash
    AND result = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA314 expected one unchanged completed idempotency row with the explicit-null array hash/result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND id = v_execution_id
    AND idempotency_key = 'fixture-qa314-array-duplicate-null'
    AND status = 'COMPLETED'
    AND input = v_input
    AND result = v_result
    AND completed_at IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA314 expected one completed execution preserving canonical array input, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.offers
  WHERE id = v_offer_id
    AND name = 'QA314 JSONB Array Duplicate Null Offer'
    AND quantity = 5
    AND price = 20.25
    AND currency = 'USD'
    AND conditions = 'qa314-array-duplicate-null'
    AND market = 'QA'
    AND geography = 'KR'
    AND attributes = v_attributes
    AND documentation_status = 'verified'
    AND lifecycle = 'draft'
    AND offer_type = 'supplier_offer'
    AND pricing_model = 'fixed';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA314 expected one original offer preserving canonical array attributes, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_events
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND execution_id = v_execution_id
    AND event_type = 'ACTION_SUCCEEDED'
    AND object_type = 'Offer'
    AND object_id = v_offer_id
    AND payload = v_result;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA314 expected one success event matching the original result, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.idempotency_keys
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND key = 'fixture-qa314-array-duplicate-null';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA314 retries created duplicate idempotency rows: %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.action_executions
  WHERE tenant_id = '10000000-0000-4000-8000-000000000001'
    AND idempotency_key = 'fixture-qa314-array-duplicate-null';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'QA314 retries created duplicate executions: %', v_count;
  END IF;
END
$qa314$;
SELECT 'QA314 duplicate keys ending in JSON null inside p_input and p_attributes array objects replay as canonical explicit-null objects; absent-property retries are rejected, array order and original records remain unchanged' AS result;
SQL

echo "QA314 confirmed duplicate JSON keys ending in JSON null inside array objects in p_input and p_attributes; canonical explicit-null replay succeeded, absent-property retries were rejected, array order and original records were preserved."
