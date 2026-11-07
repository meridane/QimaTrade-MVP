-- Disposable PostgreSQL fixture for exercising the actual branch migration.
-- This file is run only in a fresh CI database created by run-legacy-messages-rls-regression.sh.
-- It does not connect to or modify Supabase production.

CREATE SCHEMA IF NOT EXISTS auth;

DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
END
$roles$;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $uid$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$uid$;

GRANT USAGE ON SCHEMA auth TO authenticated, anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
GRANT USAGE ON SCHEMA public TO authenticated, anon;

CREATE TABLE public.profiles (
  auth_user_id uuid PRIMARY KEY,
  actor_id uuid NOT NULL UNIQUE
);

CREATE TABLE public.demands (
  id uuid PRIMARY KEY,
  requester_actor_id uuid NOT NULL
);

CREATE TABLE public.offers (
  id uuid PRIMARY KEY,
  demand_id uuid NOT NULL REFERENCES public.demands(id),
  provider_actor_id uuid NOT NULL
);

CREATE TABLE public.messages (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  demand_id uuid NOT NULL REFERENCES public.demands(id),
  offer_id uuid NULL REFERENCES public.offers(id),
  sender_actor_id uuid NOT NULL,
  body text NOT NULL
);

INSERT INTO public.profiles(auth_user_id, actor_id) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '22222222-2222-4222-8222-222222222222'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '33333333-3333-4333-8333-333333333333');

INSERT INTO public.demands(id, requester_actor_id) VALUES
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '11111111-1111-4111-8111-111111111111'),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', '22222222-2222-4222-8222-222222222222');

INSERT INTO public.offers(id, demand_id, provider_actor_id) VALUES
  ('ffffffff-ffff-4fff-8fff-ffffffffffff',
   'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   '33333333-3333-4333-8333-333333333333'),
  ('99999999-9999-4999-8999-999999999999',
   'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
   '33333333-3333-4333-8333-333333333333');

GRANT SELECT ON public.profiles TO authenticated;
GRANT SELECT, INSERT ON public.messages TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
