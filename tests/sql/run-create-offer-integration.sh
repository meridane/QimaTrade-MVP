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
   ! grep -Fq "SQL state: 23514" /tmp/qima-qa103-first.log; then
  echo "QA103 first request did not fail with the exact synthetic CHECK-style SQLSTATE 23514." >&2
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
