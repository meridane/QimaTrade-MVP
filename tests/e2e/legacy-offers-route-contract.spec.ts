import { expect, test } from "@playwright/test";
import { createLegacyOfferHandler } from "../../lib/offers/create-legacy-offer";

const AUTH_USER_ID = "40000000-0000-4000-8000-000000000101";
const PROFILE_ACTOR_ID = "30000000-0000-4000-8000-000000000101";
const SPOOFED_ACTOR_ID = "90000000-0000-4000-8000-000000000101";

type MockConfig = {
  user?: { id: string } | null;
  authError?: { message: string } | null;
  profile?: { actor_id: string | null } | null;
  profileError?: { message: string } | null;
};

function createSupabaseMock(config: MockConfig = {}) {
  const calls = {
    authGetUser: 0,
    profileLookups: [] as Array<{ column: string; value: string }>,
    insertPayload: null as Record<string, unknown> | null,
    offerInsertCalls: 0,
  };

  const user = config.user === undefined ? { id: AUTH_USER_ID } : config.user;
  const profile = config.profile === undefined ? { actor_id: PROFILE_ACTOR_ID } : config.profile;

  const client = {
    auth: {
      getUser: async () => {
        calls.authGetUser += 1;
        return {
          data: { user },
          error: config.authError ?? null,
        };
      },
    },
    from(table: string) {
      if (table === "profiles") {
        return {
          select() {
            return {
              eq(column: string, value: string) {
                calls.profileLookups.push({ column, value });
                return {
                  single: async () => ({
                    data: profile,
                    error: config.profileError ?? null,
                  }),
                };
              },
            };
          },
        };
      }

      if (table === "offers") {
        return {
          insert(payload: Record<string, unknown>) {
            calls.offerInsertCalls += 1;
            calls.insertPayload = payload;
            return {
              select() {
                return {
                  single: async () => ({
                    data: { id: "70000000-0000-4000-8000-000000000101" },
                    error: null,
                  }),
                };
              },
            };
          },
        };
      }

      throw new Error(`Unexpected Supabase table in QA134 fixture: ${table}`);
    },
  };

  return { client, calls };
}

function createFormRequest(fields: Record<string, string> = {}) {
  const form = new FormData();
  form.set("name", "Legacy draft offer");
  form.set("quantity", "2");
  for (const [key, value] of Object.entries(fields)) form.set(key, value);

  return new Request("https://qima.test/api/offers", {
    method: "POST",
    body: form,
  });
}

function createHandler(client: ReturnType<typeof createSupabaseMock>["client"]) {
  return createLegacyOfferHandler(async () => client as never);
}

test("legacy offers route derives provider_actor_id from the authenticated user's profile", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);
  const request = createFormRequest({
    provider_actor_id: SPOOFED_ACTOR_ID,
    providerActorId: SPOOFED_ACTOR_ID,
  });

  const response = await handler(request);

  expect(response.status).toBe(303);
  expect(calls.authGetUser).toBe(1);
  expect(calls.profileLookups).toEqual([{ column: "auth_user_id", value: AUTH_USER_ID }]);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    provider_actor_id: PROFILE_ACTOR_ID,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
  expect(calls.insertPayload?.provider_actor_id).not.toBe(SPOOFED_ACTOR_ID);
});

test("legacy offers route refuses a profile without an actor before inserting an offer", async () => {
  const { client, calls } = createSupabaseMock({ profile: { actor_id: null } });
  const handler = createHandler(client);

  const response = await handler(createFormRequest());

  expect(response.status).toBe(403);
  await expect(response.json()).resolves.toMatchObject({
    error: "Your account is not linked to a QimaTrade actor yet.",
  });
  expect(calls.profileLookups).toEqual([{ column: "auth_user_id", value: AUTH_USER_ID }]);
  expect(calls.offerInsertCalls).toBe(0);
  expect(calls.insertPayload).toBeNull();
});

test("legacy offers route refuses a missing profile before inserting an offer", async () => {
  const { client, calls } = createSupabaseMock({ profile: null });
  const handler = createHandler(client);

  const response = await handler(createFormRequest());

  expect(response.status).toBe(403);
  expect(calls.offerInsertCalls).toBe(0);
  expect(calls.insertPayload).toBeNull();
});

test("legacy offers route stops before profile lookup when Supabase Auth rejects the user", async () => {
  const { client, calls } = createSupabaseMock({
    user: null,
    authError: { message: "Invalid session" },
  });
  const handler = createHandler(client);

  const response = await handler(createFormRequest());

  expect(response.status).toBe(401);
  await expect(response.json()).resolves.toMatchObject({ error: "UNAUTHENTICATED" });
  expect(calls.authGetUser).toBe(1);
  expect(calls.profileLookups).toHaveLength(0);
  expect(calls.offerInsertCalls).toBe(0);
});

test("legacy offers route stops before offer insertion when the profile lookup fails", async () => {
  const { client, calls } = createSupabaseMock({
    profile: null,
    profileError: { message: "Profile lookup failed" },
  });
  const handler = createHandler(client);

  const response = await handler(createFormRequest());

  expect(response.status).toBe(403);
  expect(calls.profileLookups).toEqual([{ column: "auth_user_id", value: AUTH_USER_ID }]);
  expect(calls.offerInsertCalls).toBe(0);
  expect(calls.insertPayload).toBeNull();
});
