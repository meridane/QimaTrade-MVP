-- Synthetic regression tests for participant self-enrollment candidates.
-- Disposable PostgreSQL only. Models the observed policy shortcut and a proposed
-- safer contract; it is not a verbatim dump of the live schema or a production migration.

CREATE SCHEMA IF NOT EXISTS qima_participant_test;
GRANT USAGE ON SCHEMA qima_participant_test TO PUBLIC;

DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qima_participant_authenticated') THEN
    CREATE ROLE qima_participant_authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qima_participant_service') THEN
    CREATE ROLE qima_participant_service NOLOGIN;
  END IF;
END $roles$;

CREATE OR REPLACE FUNCTION qima_participant_test.current_uid()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('qima_participant_test.uid', true), '')::uuid
$$;
CREATE OR REPLACE FUNCTION qima_participant_test.is_admin()
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE(NULLIF(current_setting('qima_participant_test.admin', true), '')::boolean, false)
$$;

CREATE TABLE IF NOT EXISTS qima_participant_test.profiles (
  user_id uuid PRIMARY KEY,
  is_admin boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS qima_participant_test.requests (
  id uuid PRIMARY KEY,
  owner_user_id uuid NOT NULL REFERENCES qima_participant_test.profiles(user_id)
);
CREATE TABLE IF NOT EXISTS qima_participant_test.conversations (
  id uuid PRIMARY KEY,
  request_id uuid NOT NULL REFERENCES qima_participant_test.requests(id)
);
CREATE TABLE IF NOT EXISTS qima_participant_test.conversation_participants (
  conversation_id uuid NOT NULL REFERENCES qima_participant_test.conversations(id),
  user_id uuid NOT NULL REFERENCES qima_participant_test.profiles(user_id),
  PRIMARY KEY (conversation_id, user_id)
);
CREATE TABLE IF NOT EXISTS qima_participant_test.transactions (
  id uuid PRIMARY KEY,
  owner_user_id uuid NOT NULL REFERENCES qima_participant_test.profiles(user_id)
);
CREATE TABLE IF NOT EXISTS qima_participant_test.transaction_parties (
  transaction_id uuid NOT NULL REFERENCES qima_participant_test.transactions(id),
  user_id uuid NOT NULL REFERENCES qima_participant_test.profiles(user_id),
  PRIMARY KEY (transaction_id, user_id)
);
CREATE TABLE IF NOT EXISTS qima_participant_test.messages (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES qima_participant_test.conversations(id),
  body text NOT NULL
);

TRUNCATE qima_participant_test.messages,
  qima_participant_test.transaction_parties,
  qima_participant_test.transactions,
  qima_participant_test.conversation_participants,
  qima_participant_test.conversations,
  qima_participant_test.requests,
  qima_participant_test.profiles RESTART IDENTITY CASCADE;

INSERT INTO qima_participant_test.profiles(user_id,is_admin) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', false),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', false),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', true);
INSERT INTO qima_participant_test.requests VALUES
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
INSERT INTO qima_participant_test.conversations VALUES
 ('11111111-aaaa-4aaa-8aaa-111111111111','dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
 ('22222222-bbbb-4bbb-8bbb-222222222222','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
INSERT INTO qima_participant_test.transaction_parties(transaction_id,user_id)
SELECT '33333333-cccc-4ccc-8ccc-333333333333', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
WHERE false;
INSERT INTO qima_participant_test.transactions VALUES
 ('33333333-cccc-4ccc-8ccc-333333333333','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

CREATE OR REPLACE FUNCTION qima_participant_test.can_access_conversation(p_conversation_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = qima_participant_test, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM qima_participant_test.conversation_participants cp
    WHERE cp.conversation_id = p_conversation_id AND cp.user_id = qima_participant_test.current_uid()
  ) OR EXISTS (
    SELECT 1 FROM qima_participant_test.conversations c
    JOIN qima_participant_test.requests r ON r.id = c.request_id
    WHERE c.id = p_conversation_id AND r.owner_user_id = qima_participant_test.current_uid()
  ) OR qima_participant_test.is_admin()
$$;
CREATE OR REPLACE FUNCTION qima_participant_test.can_access_transaction(p_transaction_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = qima_participant_test, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM qima_participant_test.transaction_parties tp
    WHERE tp.transaction_id = p_transaction_id AND tp.user_id = qima_participant_test.current_uid()
  ) OR EXISTS (
    SELECT 1 FROM qima_participant_test.transactions t
    WHERE t.id = p_transaction_id AND t.owner_user_id = qima_participant_test.current_uid()
  ) OR qima_participant_test.is_admin()
$$;

ALTER TABLE qima_participant_test.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE qima_participant_test.transaction_parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE qima_participant_test.messages ENABLE ROW LEVEL SECURITY;

-- Baseline policy reproduces the observed unconditional user_id = auth.uid() shortcut.
CREATE POLICY cp_insert_baseline ON qima_participant_test.conversation_participants
  FOR INSERT TO qima_participant_authenticated
  WITH CHECK (
    user_id = qima_participant_test.current_uid()
    OR qima_participant_test.can_access_conversation(conversation_id)
    OR qima_participant_test.is_admin()
  );
CREATE POLICY tp_insert_baseline ON qima_participant_test.transaction_parties
  FOR INSERT TO qima_participant_authenticated
  WITH CHECK (
    user_id = qima_participant_test.current_uid()
    OR qima_participant_test.can_access_transaction(transaction_id)
    OR qima_participant_test.is_admin()
  );
CREATE POLICY cp_select ON qima_participant_test.conversation_participants
  FOR SELECT TO qima_participant_authenticated
  USING (qima_participant_test.can_access_conversation(conversation_id));
CREATE POLICY tp_select ON qima_participant_test.transaction_parties
  FOR SELECT TO qima_participant_authenticated
  USING (qima_participant_test.can_access_transaction(transaction_id));
CREATE POLICY message_select ON qima_participant_test.messages
  FOR SELECT TO qima_participant_authenticated
  USING (qima_participant_test.can_access_conversation(conversation_id));

GRANT SELECT, INSERT ON qima_participant_test.conversation_participants,
  qima_participant_test.transaction_parties TO qima_participant_authenticated;
GRANT SELECT ON qima_participant_test.messages TO qima_participant_authenticated;
GRANT SELECT ON qima_participant_test.profiles, qima_participant_test.requests,
  qima_participant_test.conversations, qima_participant_test.transactions TO qima_participant_authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA qima_participant_test TO qima_participant_authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA qima_participant_test TO qima_participant_authenticated;

INSERT INTO qima_participant_test.messages(conversation_id,body) VALUES
 ('11111111-aaaa-4aaa-8aaa-111111111111','request A private message'),
 ('22222222-bbbb-4bbb-8bbb-222222222222','request B private message');

-- Reproduce the candidate on baseline policies: user A can enroll in B's conversation
-- and then the participant-based access helper sees the inserted row.
SET qima_participant_test.uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET qima_participant_test.admin = 'false';
SET ROLE qima_participant_authenticated;
INSERT INTO qima_participant_test.conversation_participants VALUES
 ('22222222-bbbb-4bbb-8bbb-222222222222','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
DO $baseline$
BEGIN
  IF NOT qima_participant_test.can_access_conversation('22222222-bbbb-4bbb-8bbb-222222222222') THEN
    RAISE EXCEPTION 'Expected baseline self-enrollment candidate to reproduce';
  END IF;
END $baseline$;
RESET ROLE;
DELETE FROM qima_participant_test.conversation_participants
WHERE conversation_id = '22222222-bbbb-4bbb-8bbb-222222222222'
  AND user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

-- Replace insert predicates with tightened synthetic contract:
-- conversation: requester may join only a conversation attached to their own request;
-- transaction: only an already-authorized party/admin may insert directly.
DROP POLICY cp_insert_baseline ON qima_participant_test.conversation_participants;
DROP POLICY tp_insert_baseline ON qima_participant_test.transaction_parties;
CREATE POLICY cp_insert_safe ON qima_participant_test.conversation_participants
  FOR INSERT TO qima_participant_authenticated
  WITH CHECK (
    qima_participant_test.is_admin()
    OR EXISTS (
      SELECT 1
      FROM qima_participant_test.conversations c
      JOIN qima_participant_test.requests r ON r.id = c.request_id
      WHERE c.id = conversation_id AND r.owner_user_id = qima_participant_test.current_uid()
    )
  );
CREATE POLICY tp_insert_safe ON qima_participant_test.transaction_parties
  FOR INSERT TO qima_participant_authenticated
  WITH CHECK (
    qima_participant_test.is_admin()
    OR qima_participant_test.can_access_transaction(transaction_id)
  );

-- CP-01: foreign self-enrollment is rejected, with no persisted row.
SET qima_participant_test.uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE qima_participant_authenticated;
DO $cp01$
BEGIN
  BEGIN
    INSERT INTO qima_participant_test.conversation_participants VALUES
      ('22222222-bbbb-4bbb-8bbb-222222222222','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    RAISE EXCEPTION 'REGRESSION: CP-01 foreign self-enrollment unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $cp01$;
RESET ROLE;
DO $cp01_check$
BEGIN
  IF EXISTS (SELECT 1 FROM qima_participant_test.conversation_participants
    WHERE conversation_id='22222222-bbbb-4bbb-8bbb-222222222222'
      AND user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') THEN
    RAISE EXCEPTION 'CP-01 failed: membership persisted';
  END IF;
END $cp01_check$;

-- CP-02: user A cannot see user B's messages when not a participant.
SET qima_participant_test.uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE qima_participant_authenticated;
DO $cp02$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM qima_participant_test.messages
  WHERE conversation_id='22222222-bbbb-4bbb-8bbb-222222222222';
  IF n <> 0 THEN RAISE EXCEPTION 'CP-02 failed: foreign messages visible'; END IF;
END $cp02$;
RESET ROLE;

-- CP-04: request owner can legitimately join their own conversation.
SET qima_participant_test.uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE qima_participant_authenticated;
INSERT INTO qima_participant_test.conversation_participants VALUES
 ('11111111-aaaa-4aaa-8aaa-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
RESET ROLE;

-- TP-01: unrelated user cannot self-enroll in another user's transaction.
SET qima_participant_test.uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE qima_participant_authenticated;
DO $tp01$
BEGIN
  BEGIN
    INSERT INTO qima_participant_test.transaction_parties VALUES
      ('33333333-cccc-4ccc-8ccc-333333333333','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    RAISE EXCEPTION 'REGRESSION: TP-01 foreign self-enrollment unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $tp01$;
RESET ROLE;
DO $tp01_check$
BEGIN
  IF EXISTS (SELECT 1 FROM qima_participant_test.transaction_parties
    WHERE transaction_id='33333333-cccc-4ccc-8ccc-333333333333'
      AND user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') THEN
    RAISE EXCEPTION 'TP-01 failed: party row persisted';
  END IF;
END $tp01_check$;

-- TP-02: user A cannot see B's transaction party list.
SET qima_participant_test.uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE qima_participant_authenticated;
DO $tp02$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM qima_participant_test.transaction_parties
  WHERE transaction_id='33333333-cccc-4ccc-8ccc-333333333333';
  IF n <> 0 THEN RAISE EXCEPTION 'TP-02 failed: foreign transaction parties visible'; END IF;
END $tp02$;
RESET ROLE;

-- Trusted transaction party assignment is modelled as a narrowly scoped SECURITY DEFINER
-- function, avoiding direct authenticated self-enrollment. This is only a fixture model.
CREATE OR REPLACE FUNCTION qima_participant_test.assign_transaction_party(
  p_transaction_id uuid, p_user_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = qima_participant_test, pg_temp AS $$
BEGIN
  INSERT INTO qima_participant_test.transaction_parties(transaction_id,user_id)
  VALUES (p_transaction_id,p_user_id)
  ON CONFLICT DO NOTHING;
END
$$;
GRANT EXECUTE ON FUNCTION qima_participant_test.assign_transaction_party(uuid,uuid)
  TO qima_participant_service;
GRANT USAGE ON SCHEMA qima_participant_test TO qima_participant_service;

-- Trusted workflow positive path: table owner/service invokes the trusted function.
RESET ROLE;
SET ROLE qima_participant_service;
SELECT qima_participant_test.assign_transaction_party(
 '33333333-cccc-4ccc-8ccc-333333333333',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
);
RESET ROLE;

-- ADM-01: admin may perform the supported direct assignment.
SET qima_participant_test.uid = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
SET qima_participant_test.admin = 'true';
SET ROLE qima_participant_authenticated;
INSERT INTO qima_participant_test.transaction_parties VALUES
 ('33333333-cccc-4ccc-8ccc-333333333333','cccccccc-cccc-4ccc-8ccc-cccccccccccc');
RESET ROLE;

-- Final assertions: positive paths persisted, negatives did not.
DO $final$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM qima_participant_test.conversation_participants
    WHERE conversation_id='11111111-aaaa-4aaa-8aaa-111111111111'
      AND user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') THEN
    RAISE EXCEPTION 'CP-04 failed: request owner could not join own conversation';
  END IF;
  IF EXISTS (SELECT 1 FROM qima_participant_test.conversation_participants
    WHERE conversation_id='22222222-bbbb-4bbb-8bbb-222222222222'
      AND user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') THEN
    RAISE EXCEPTION 'CP-01 failed at final assertion';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM qima_participant_test.transaction_parties
    WHERE transaction_id='33333333-cccc-4ccc-8ccc-333333333333'
      AND user_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') THEN
    RAISE EXCEPTION 'TP-03 failed: trusted party assignment missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM qima_participant_test.transaction_parties
    WHERE transaction_id='33333333-cccc-4ccc-8ccc-333333333333'
      AND user_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc') THEN
    RAISE EXCEPTION 'ADM-01 failed: admin assignment missing';
  END IF;
END $final$;

SELECT 'Participant self-enrollment synthetic RLS regression tests passed' AS result;
