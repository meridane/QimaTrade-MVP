#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must point to a disposable PostgreSQL database}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL=(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1)
PSQL_TUPLE=(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -A -t)

# This script is only intended for the ephemeral PostgreSQL service in CI.
# Never point DATABASE_URL at Supabase production.
"${PSQL[@]}" -f "$ROOT/tests/sql/fixtures/create-offer-schema.sql"
"${PSQL[@]}" -f "$ROOT/supabase/migrations/20261027090000_fix_create_offer_action_status_contract.sql"
"${PSQL[@]}" -f "$ROOT/supabase/migrations/20261027100000_restrict_direct_create_offer_rpc.sql"
"${PSQL[@]}" -f "$ROOT/tests/sql/create-offer-runtime.sql"

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
