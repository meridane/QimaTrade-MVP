-- Isolated synthetic regression test for the legacy public.messages RLS predicate.
-- This does not connect to Supabase and intentionally uses a dedicated schema.
-- Run only in a disposable PostgreSQL database.

CREATE SCHEMA IF NOT EXISTS qima_legacy_test;
GRANT USAGE ON SCHEMA qima_legacy_test TO PUBLIC;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qima_test_authenticated') THEN
    CREATE ROLE qima_test_authenticated NOLOGIN;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION qima_legacy_test.current_user_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('qima_legacy_test.uid', true), '')::uuid
$$;

CREATE TABLE IF NOT EXISTS qima_legacy_test.profiles (
  auth_user_id uuid PRIMARY KEY,
  actor_id uuid UNIQUE NOT NULL
);
CREATE TABLE IF NOT EXISTS qima_legacy_test.demands (
  id uuid PRIMARY KEY,
  requester_actor_id uuid NOT NULL
);
CREATE TABLE IF NOT EXISTS qima_legacy_test.offers (
  id uuid PRIMARY KEY,
  demand_id uuid NOT NULL REFERENCES qima_legacy_test.demands(id),
  provider_actor_id uuid NOT NULL
);
CREATE TABLE IF NOT EXISTS qima_legacy_test.messages (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  demand_id uuid NOT NULL REFERENCES qima_legacy_test.demands(id),
  offer_id uuid NULL REFERENCES qima_legacy_test.offers(id),
  sender_actor_id uuid NOT NULL,
  body text NOT NULL
);

TRUNCATE qima_legacy_test.messages, qima_legacy_test.offers,
  qima_legacy_test.demands, qima_legacy_test.profiles RESTART IDENTITY;

INSERT INTO qima_legacy_test.profiles VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','33333333-3333-4333-8333-333333333333');

INSERT INTO qima_legacy_test.demands VALUES
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','11111111-1111-4111-8111-111111111111'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','22222222-2222-4222-8222-222222222222');

INSERT INTO qima_legacy_test.offers VALUES
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','dddddddd-dddd-4ddd-8ddd-dddddddddddd','33333333-3333-4333-8333-333333333333'),
 ('99999999-9999-4999-8999-999999999999','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','33333333-3333-4333-8333-333333333333');

-- Baseline reproduces the unsafe "sender actor is enough" shortcut.
CREATE OR REPLACE FUNCTION qima_legacy_test.is_message_participant(
  p_demand_id uuid, p_offer_id uuid, p_sender_actor_id uuid DEFAULT NULL
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = qima_legacy_test, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM qima_legacy_test.profiles p
    WHERE p.auth_user_id = qima_legacy_test.current_user_id()
      AND p.actor_id = p_sender_actor_id
  )
  OR EXISTS (
    SELECT 1 FROM qima_legacy_test.profiles p
    JOIN qima_legacy_test.demands d ON d.id = p_demand_id
    WHERE p.auth_user_id = qima_legacy_test.current_user_id()
      AND d.requester_actor_id = p.actor_id
  )
  OR EXISTS (
    SELECT 1 FROM qima_legacy_test.profiles p
    JOIN qima_legacy_test.offers o ON o.id = p_offer_id
    WHERE p.auth_user_id = qima_legacy_test.current_user_id()
      AND o.provider_actor_id = p.actor_id
  );
$$;

ALTER TABLE qima_legacy_test.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS messages_insert_participants ON qima_legacy_test.messages;
DROP POLICY IF EXISTS messages_select_participants ON qima_legacy_test.messages;
CREATE POLICY messages_insert_participants ON qima_legacy_test.messages
  FOR INSERT TO qima_test_authenticated
  WITH CHECK (
    qima_legacy_test.is_message_participant(demand_id, offer_id, sender_actor_id)
    AND sender_actor_id = (
      SELECT actor_id FROM qima_legacy_test.profiles
      WHERE auth_user_id = qima_legacy_test.current_user_id()
    )
  );
CREATE POLICY messages_select_participants ON qima_legacy_test.messages
  FOR SELECT TO qima_test_authenticated
  USING (qima_legacy_test.is_message_participant(demand_id, offer_id, sender_actor_id));

GRANT SELECT, INSERT ON qima_legacy_test.messages TO qima_test_authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA qima_legacy_test TO qima_test_authenticated;
GRANT EXECUTE ON FUNCTION qima_legacy_test.current_user_id() TO qima_test_authenticated;
GRANT EXECUTE ON FUNCTION qima_legacy_test.is_message_participant(uuid, uuid, uuid) TO qima_test_authenticated;
GRANT SELECT ON qima_legacy_test.profiles, qima_legacy_test.demands, qima_legacy_test.offers TO qima_test_authenticated;

-- Baseline proof: unrelated user B can insert into demand A by claiming their own sender actor.
SET qima_legacy_test.uid = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
SET ROLE qima_test_authenticated;
INSERT INTO qima_legacy_test.messages(demand_id, offer_id, sender_actor_id, body)
VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
        '22222222-2222-4222-8222-222222222222',
        'baseline vulnerability reproduction');
RESET ROLE;
DO $$
BEGIN
  IF (SELECT count(*) FROM qima_legacy_test.messages) <> 1 THEN
    RAISE EXCEPTION 'Expected baseline vulnerable insert to reproduce';
  END IF;
END $$;
TRUNCATE qima_legacy_test.messages RESTART IDENTITY;

-- Proposed safe predicate: exact demand/offer pairing and participant ownership.
CREATE OR REPLACE FUNCTION qima_legacy_test.is_message_participant(
  p_demand_id uuid, p_offer_id uuid, p_sender_actor_id uuid DEFAULT NULL
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = qima_legacy_test, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1
    FROM qima_legacy_test.profiles p
    JOIN qima_legacy_test.demands d ON d.id = p_demand_id
    WHERE p.auth_user_id = qima_legacy_test.current_user_id()
      AND (
        (p_offer_id IS NULL AND d.requester_actor_id = p.actor_id)
        OR EXISTS (
          SELECT 1 FROM qima_legacy_test.offers o
          WHERE o.id = p_offer_id AND o.demand_id = d.id
            AND d.requester_actor_id = p.actor_id
        )
        OR EXISTS (
          SELECT 1 FROM qima_legacy_test.offers o
          WHERE o.id = p_offer_id AND o.demand_id = d.id
            AND o.provider_actor_id = p.actor_id
        )
      )
  );
$$;
GRANT EXECUTE ON FUNCTION qima_legacy_test.is_message_participant(uuid, uuid, uuid) TO qima_test_authenticated;

-- Negative cases are executed in a DO block while SET ROLE is active. Each
-- expected RLS violation is caught in a subtransaction, then row absence is
-- checked after returning to the table owner.

SET qima_legacy_test.uid = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
SET ROLE qima_test_authenticated;
DO $$
BEGIN
  BEGIN
    INSERT INTO qima_legacy_test.messages(demand_id, offer_id, sender_actor_id, body)
    VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            'ffffffff-ffff-4fff-8fff-ffffffffffff',
            '22222222-2222-4222-8222-222222222222',
            'foreign-demand');
    RAISE EXCEPTION 'SECURITY REGRESSION: foreign-demand unexpectedly inserted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM qima_legacy_test.messages WHERE body = 'foreign-demand')
  THEN RAISE EXCEPTION 'Denied foreign-demand row persisted'; END IF;
END $$;

SET qima_legacy_test.uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE qima_test_authenticated;
DO $$
BEGIN
  BEGIN
    INSERT INTO qima_legacy_test.messages(demand_id, offer_id, sender_actor_id, body)
    VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            '99999999-9999-4999-8999-999999999999',
            '11111111-1111-4111-8111-111111111111',
            'mismatched-pair');
    RAISE EXCEPTION 'SECURITY REGRESSION: mismatched-pair unexpectedly inserted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO qima_legacy_test.messages(demand_id, offer_id, sender_actor_id, body)
    VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            'ffffffff-ffff-4fff-8fff-ffffffffffff',
            '22222222-2222-4222-8222-222222222222',
            'sender-spoof');
    RAISE EXCEPTION 'SECURITY REGRESSION: sender-spoof unexpectedly inserted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM qima_legacy_test.messages WHERE body IN ('mismatched-pair','sender-spoof'))
  THEN RAISE EXCEPTION 'Denied mismatched/spoof row persisted'; END IF;
END $$;

-- Positive paths and additional negative paths are asserted directly under the
-- test role so RLS is evaluated with the same permissions as an API caller.
SET qima_legacy_test.uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE qima_test_authenticated;
INSERT INTO qima_legacy_test.messages(demand_id, offer_id, sender_actor_id, body)
VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
        '11111111-1111-4111-8111-111111111111',
        'legitimate-requester');
RESET ROLE;

SET qima_legacy_test.uid = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
SET ROLE qima_test_authenticated;
INSERT INTO qima_legacy_test.messages(demand_id, offer_id, sender_actor_id, body)
VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
        '33333333-3333-4333-8333-333333333333',
        'legitimate-provider');
RESET ROLE;

DO $final$
BEGIN
  IF (SELECT count(*) FROM qima_legacy_test.messages) <> 2 THEN
    RAISE EXCEPTION 'Expected two legitimate messages after safe predicate';
  END IF;
  -- Use user A, who is neither requester nor provider on demand B / offer B.
  PERFORM set_config('qima_legacy_test.uid', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
  IF qima_legacy_test.is_message_participant(
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    '99999999-9999-4999-8999-999999999999',
    '11111111-1111-4111-8111-111111111111'
  ) THEN
    RAISE EXCEPTION 'Foreign provider incorrectly authorized';
  END IF;
  IF qima_legacy_test.is_message_participant(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    '99999999-9999-4999-8999-999999999999',
    '11111111-1111-4111-8111-111111111111'
  ) THEN
    RAISE EXCEPTION 'Mismatched demand/offer pair incorrectly authorized';
  END IF;
END $final$;

SELECT 'Legacy messages synthetic RLS regression tests passed' AS result;
