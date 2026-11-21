-- These assertions exercise the actual function installed by the branch migration.
-- RLS policies below are a minimal synthetic representation of the existing policy contract;
-- this test does not claim parity with the live Supabase policies.

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY messages_insert_participants ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_message_participant(demand_id, offer_id, sender_actor_id)
    AND sender_actor_id = (
      SELECT p.actor_id
      FROM public.profiles p
      WHERE p.auth_user_id = auth.uid()
    )
  );

CREATE POLICY messages_select_participants ON public.messages
  FOR SELECT TO authenticated
  USING (public.is_message_participant(demand_id, offer_id, sender_actor_id));

DO $privileges$
BEGIN
  IF NOT has_function_privilege(
    'authenticated',
    'public.is_message_participant(uuid,uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated must retain EXECUTE on is_message_participant';
  END IF;
  IF has_function_privilege(
    'anon',
    'public.is_message_participant(uuid,uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'anon must not inherit EXECUTE on is_message_participant';
  END IF;
END
$privileges$;

-- An unrelated authenticated user cannot write into another requester's conversation.
SET request.jwt.claim.sub = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
SET ROLE authenticated;
DO $foreign_demand$
BEGIN
  BEGIN
    INSERT INTO public.messages(demand_id, offer_id, sender_actor_id, body)
    VALUES (
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      'ffffffff-ffff-4fff-8fff-ffffffffffff',
      '22222222-2222-4222-8222-222222222222',
      'foreign-demand'
    );
    RAISE EXCEPTION 'SECURITY REGRESSION: unrelated user inserted into a foreign demand';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$foreign_demand$;
RESET ROLE;
DO $foreign_demand_absent$
BEGIN
  IF EXISTS (SELECT 1 FROM public.messages WHERE body = 'foreign-demand') THEN
    RAISE EXCEPTION 'Denied foreign-demand row persisted';
  END IF;
END
$foreign_demand_absent$;

-- The requester cannot pair their demand with an offer belonging to another demand,
-- and cannot spoof a different sender actor even when they own the demand.
SET request.jwt.claim.sub = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE authenticated;
DO $requester_negative$
BEGIN
  BEGIN
    INSERT INTO public.messages(demand_id, offer_id, sender_actor_id, body)
    VALUES (
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      '99999999-9999-4999-8999-999999999999',
      '11111111-1111-4111-8111-111111111111',
      'mismatched-pair'
    );
    RAISE EXCEPTION 'SECURITY REGRESSION: mismatched demand/offer pair inserted';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  BEGIN
    INSERT INTO public.messages(demand_id, offer_id, sender_actor_id, body)
    VALUES (
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      'ffffffff-ffff-4fff-8fff-ffffffffffff',
      '22222222-2222-4222-8222-222222222222',
      'sender-spoof'
    );
    RAISE EXCEPTION 'SECURITY REGRESSION: spoofed sender actor inserted';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$requester_negative$;
RESET ROLE;
DO $requester_negative_absent$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.messages
    WHERE body IN ('mismatched-pair', 'sender-spoof')
  ) THEN
    RAISE EXCEPTION 'Denied mismatched/spoof rows persisted';
  END IF;
END
$requester_negative_absent$;

-- A provider cannot use its offer from demand B to enter demand A.
SET request.jwt.claim.sub = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
SET ROLE authenticated;
DO $provider_negative$
BEGIN
  BEGIN
    INSERT INTO public.messages(demand_id, offer_id, sender_actor_id, body)
    VALUES (
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      '99999999-9999-4999-8999-999999999999',
      '33333333-3333-4333-8333-333333333333',
      'provider-cross-demand'
    );
    RAISE EXCEPTION 'SECURITY REGRESSION: provider crossed demand/offer boundary';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$provider_negative$;
RESET ROLE;
DO $provider_negative_absent$
BEGIN
  IF EXISTS (SELECT 1 FROM public.messages WHERE body = 'provider-cross-demand') THEN
    RAISE EXCEPTION 'Denied provider-cross-demand row persisted';
  END IF;
END
$provider_negative_absent$;

-- Legitimate requester and provider paths remain available; a requester may also
-- create a message before an offer is attached.
SET request.jwt.claim.sub = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE authenticated;
INSERT INTO public.messages(demand_id, offer_id, sender_actor_id, body)
VALUES (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  '11111111-1111-4111-8111-111111111111',
  'legitimate-requester'
);
INSERT INTO public.messages(demand_id, offer_id, sender_actor_id, body)
VALUES (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  NULL,
  '11111111-1111-4111-8111-111111111111',
  'legitimate-requester-without-offer'
);
RESET ROLE;

SET request.jwt.claim.sub = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
SET ROLE authenticated;
INSERT INTO public.messages(demand_id, offer_id, sender_actor_id, body)
VALUES (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  '33333333-3333-4333-8333-333333333333',
  'legitimate-provider'
);
RESET ROLE;

-- Unrelated user B cannot read the conversation; requester A sees all three rows;
-- provider C sees only the two rows attached to its own offer.
SET request.jwt.claim.sub = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
SET ROLE authenticated;
DO $select_foreign$
BEGIN
  IF (SELECT count(*) FROM public.messages
      WHERE demand_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') <> 0 THEN
    RAISE EXCEPTION 'SECURITY REGRESSION: unrelated user read a foreign conversation';
  END IF;
END
$select_foreign$;
RESET ROLE;

SET request.jwt.claim.sub = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE authenticated;
DO $select_requester$
BEGIN
  IF (SELECT count(*) FROM public.messages
      WHERE demand_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') <> 3 THEN
    RAISE EXCEPTION 'Requester must read all messages in their own demand';
  END IF;
END
$select_requester$;
RESET ROLE;

SET request.jwt.claim.sub = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
SET ROLE authenticated;
DO $select_provider$
BEGIN
  IF (SELECT count(*) FROM public.messages
      WHERE demand_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') <> 2 THEN
    RAISE EXCEPTION 'Provider must read only messages tied to their own offer';
  END IF;
END
$select_provider$;
RESET ROLE;

SELECT 'Legacy messages actual migration disposable-db regression tests passed' AS result;
