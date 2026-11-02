import { expect, test } from "@playwright/test";
import { createLegacyOfferHandler } from "../../lib/offers/create-legacy-offer";

const AUTH_USER_ID = "40000000-0000-4000-8000-000000000101";
const PROFILE_ACTOR_ID = "30000000-0000-4000-8000-000000000101";
const SPOOFED_ACTOR_ID = "90000000-0000-4000-8000-000000000101";
const DEMAND_ID = "50000000-0000-4000-8000-000000000101";
const PRODUCT_MASTER_ID = "60000000-0000-4000-8000-000000000101";
const EXPLICIT_PRODUCT_MASTER_ID = "60000000-0000-4000-8000-000000000102";

type MockConfig = {
  user?: { id: string } | null;
  authError?: { message: string } | null;
  profile?: { actor_id: string | null } | null;
  profileError?: { message: string } | null;
  demand?: { id: string; target_market: string | null; scope: unknown } | null;
  demandError?: { message: string } | null;
  productMaster?: { id: string } | null;
  productMasterError?: { message: string } | null;
  offer?: { id: string } | null;
  offerError?: { message: string } | null;
};

function createSupabaseMock(config: MockConfig = {}) {
  const calls = {
    authGetUser: 0,
    profileLookups: [] as Array<{ column: string; value: string }>,
    demandLookups: [] as Array<{ column: string; value: string }>,
    productMasterLookups: [] as Array<{ column: string; value: string }>,
    insertPayload: null as Record<string, unknown> | null,
    offerInsertCalls: 0,
  };

  const user = config.user === undefined ? { id: AUTH_USER_ID } : config.user;
  const profile = config.profile === undefined ? { actor_id: PROFILE_ACTOR_ID } : config.profile;
  const demand = config.demand === undefined ? null : config.demand;
  const productMaster =
    config.productMaster === undefined ? { id: PRODUCT_MASTER_ID } : config.productMaster;
  const offer =
    config.offer === undefined
      ? { id: "70000000-0000-4000-8000-000000000101" }
      : config.offer;

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

      if (table === "demands") {
        return {
          select() {
            return {
              eq(column: string, value: string) {
                calls.demandLookups.push({ column, value });
                return {
                  single: async () => ({
                    data: demand,
                    error: config.demandError ?? null,
                  }),
                };
              },
            };
          },
        };
      }

      if (table === "product_masters") {
        return {
          select() {
            return {
              eq(column: string, value: string) {
                calls.productMasterLookups.push({ column, value });
                return {
                  eq(nextColumn: string, nextValue: string) {
                    calls.productMasterLookups.push({ column: nextColumn, value: nextValue });
                    return {
                      single: async () => ({
                        data: productMaster,
                        error: config.productMasterError ?? null,
                      }),
                    };
                  },
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
                    data: offer,
                    error: config.offerError ?? null,
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


test("legacy offers route resolves the optional product master and market from a demand scope", async () => {
  const { client, calls } = createSupabaseMock({
    demand: {
      id: DEMAND_ID,
      target_market: "South Korea",
      scope: { product_master_id: PRODUCT_MASTER_ID },
    },
  });
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ demandId: DEMAND_ID }));

  expect(response.status).toBe(303);
  expect(calls.demandLookups).toEqual([{ column: "id", value: DEMAND_ID }]);
  expect(calls.productMasterLookups).toEqual([
    { column: "id", value: PRODUCT_MASTER_ID },
    { column: "status", value: "active" },
  ]);
  expect(calls.insertPayload).toMatchObject({
    demand_id: DEMAND_ID,
    product_master_id: PRODUCT_MASTER_ID,
    market: "South Korea",
  });
  expect(calls.offerInsertCalls).toBe(1);
});

test("legacy offers route prefers an explicit productMasterId over the demand scope fallback", async () => {
  const { client, calls } = createSupabaseMock({
    demand: {
      id: DEMAND_ID,
      target_market: "South Korea",
      scope: { product_master_id: PRODUCT_MASTER_ID },
    },
    productMaster: { id: EXPLICIT_PRODUCT_MASTER_ID },
  });
  const handler = createHandler(client);

  const response = await handler(
    createFormRequest({
      demandId: DEMAND_ID,
      productMasterId: EXPLICIT_PRODUCT_MASTER_ID,
      market: "Buyer-specified market",
    }),
  );

  expect(response.status).toBe(303);
  expect(calls.productMasterLookups).toEqual([
    { column: "id", value: EXPLICIT_PRODUCT_MASTER_ID },
    { column: "status", value: "active" },
  ]);
  expect(calls.insertPayload).toMatchObject({
    demand_id: DEMAND_ID,
    product_master_id: EXPLICIT_PRODUCT_MASTER_ID,
    market: "Buyer-specified market",
  });
  expect(calls.offerInsertCalls).toBe(1);
});

test("legacy offers route supports an explicit productMasterId without a demandId", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequest({ productMasterId: PRODUCT_MASTER_ID }),
  );

  expect(response.status).toBe(303);
  expect(calls.demandLookups).toHaveLength(0);
  expect(calls.productMasterLookups).toEqual([
    { column: "id", value: PRODUCT_MASTER_ID },
    { column: "status", value: "active" },
  ]);
  expect(calls.insertPayload).toMatchObject({
    demand_id: null,
    product_master_id: PRODUCT_MASTER_ID,
  });
  expect(calls.offerInsertCalls).toBe(1);
});

test("legacy offers route stops before product lookup and insertion when the optional demand is unavailable", async () => {
  const { client, calls } = createSupabaseMock({ demand: null });
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ demandId: DEMAND_ID }));

  expect(response.status).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Demand not found or unavailable.",
  });
  expect(calls.demandLookups).toEqual([{ column: "id", value: DEMAND_ID }]);
  expect(calls.productMasterLookups).toHaveLength(0);
  expect(calls.offerInsertCalls).toBe(0);
});

test("legacy offers route rejects an unavailable explicit product master before insertion", async () => {
  const { client, calls } = createSupabaseMock({
    productMaster: null,
    productMasterError: { message: "Product master is not active" },
  });
  const handler = createHandler(client);

  const response = await handler(
    createFormRequest({ productMasterId: PRODUCT_MASTER_ID }),
  );

  expect(response.status).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "PRODUCT_MASTER_NOT_FOUND",
  });
  expect(calls.demandLookups).toHaveLength(0);
  expect(calls.productMasterLookups).toEqual([
    { column: "id", value: PRODUCT_MASTER_ID },
    { column: "status", value: "active" },
  ]);
  expect(calls.offerInsertCalls).toBe(0);
});

test("legacy offers route rejects malformed multipart attributes before inserting an offer", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ attributes: "{" }));

  expect(response.status).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Invalid offer attributes.",
  });
  expect(calls.authGetUser).toBe(1);
  expect(calls.profileLookups).toEqual([{ column: "auth_user_id", value: AUTH_USER_ID }]);
  expect(calls.offerInsertCalls).toBe(0);
  expect(calls.insertPayload).toBeNull();
});

test("legacy offers route rejects invalid multipart quantity before authentication", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ quantity: "0" }));

  expect(response.status).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Please provide a valid offer name and quantity.",
  });
  expect(calls.authGetUser).toBe(0);
  expect(calls.profileLookups).toHaveLength(0);
  expect(calls.offerInsertCalls).toBe(0);
});

test("legacy offers route rejects an invalid multipart price before authentication", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "-1" }));

  expect(response.status).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Price must be a valid positive number.",
  });
  expect(calls.authGetUser).toBe(0);
  expect(calls.profileLookups).toHaveLength(0);
  expect(calls.offerInsertCalls).toBe(0);
});

test("legacy offers route rejects an unsupported multipart currency before authentication", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequest({ price: "10", currency: "XYZ" }),
  );

  expect(response.status).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Please select a valid currency.",
  });
  expect(calls.authGetUser).toBe(0);
  expect(calls.profileLookups).toHaveLength(0);
  expect(calls.offerInsertCalls).toBe(0);
});


test("legacy offers route returns the Supabase insert error without redirecting", async () => {
  const { client, calls } = createSupabaseMock({
    offerError: { message: "Offer insert failed" },
  });
  const handler = createHandler(client);

  const response = await handler(createFormRequest());

  expect(response.status).toBe(500);
  await expect(response.json()).resolves.toEqual({ error: "Offer insert failed" });
  expect(response.headers.get("location")).toBeNull();
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    name: "Legacy draft offer",
    provider_actor_id: PROFILE_ACTOR_ID,
    price: null,
    currency: null,
    pricing_model: null,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route returns a stable error when insert returns no offer row", async () => {
  const { client, calls } = createSupabaseMock({ offer: null });
  const handler = createHandler(client);

  const response = await handler(createFormRequest());

  expect(response.status).toBe(500);
  await expect(response.json()).resolves.toEqual({
    error: "Unable to create the offer.",
  });
  expect(response.headers.get("location")).toBeNull();
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    lifecycle: "draft",
    offer_type: "supplier_offer",
    price: null,
    currency: null,
    pricing_model: null,
  });
});

test("legacy offers route redirects to the ID returned by insert and preserves draft fields", async () => {
  const createdOfferId = "70000000-0000-4000-8000-000000000202";
  const { client, calls } = createSupabaseMock({
    offer: { id: createdOfferId },
  });
  const handler = createHandler(client);

  const response = await handler(
    createFormRequest({
      conditions: "Delivery within 14 days",
      market: "South Korea",
      geography: "Busan",
      attributes: JSON.stringify({ grade: "A" }),
    }),
  );

  expect(response.status).toBe(303);
  expect(response.headers.get("location")).toBe(
    `https://qima.test/offers?created=${createdOfferId}`,
  );
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    name: "Legacy draft offer",
    provider_actor_id: PROFILE_ACTOR_ID,
    quantity: 2,
    price: null,
    currency: null,
    pricing_model: null,
    conditions: "Delivery within 14 days",
    market: "South Korea",
    geography: "Busan",
    attributes: { grade: "A" },
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route returns HTTP 500 when Supabase client initialization rejects before authentication", async () => {
  const { calls } = createSupabaseMock();
  let factoryCalls = 0;
  const handler = createLegacyOfferHandler(async () => {
    factoryCalls += 1;
    throw new Error("Supabase client initialization failed");
  });

  const response = await handler(createFormRequest());

  expect(response.status).toBe(500);
  await expect(response.json()).resolves.toEqual({
    error: "Supabase client initialization failed",
  });
  expect(factoryCalls).toBe(1);
  expect(calls.authGetUser).toBe(0);
  expect(calls.profileLookups).toHaveLength(0);
  expect(calls.demandLookups).toHaveLength(0);
  expect(calls.productMasterLookups).toHaveLength(0);
  expect(calls.offerInsertCalls).toBe(0);
  expect(calls.insertPayload).toBeNull();
});


test("legacy offers route rejects invalid multipart quantity before invoking a rejecting Supabase factory", async () => {
  const { calls } = createSupabaseMock();
  let factoryCalls = 0;
  const handler = createLegacyOfferHandler(async () => {
    factoryCalls += 1;
    throw new Error("Supabase client initialization failed");
  });

  const response = await handler(createFormRequest({ quantity: "0" }));

  expect(response.status).toBe(400);
  await expect(response.json()).resolves.toEqual({
    error: "Please provide a valid offer name and quantity.",
  });
  expect(factoryCalls).toBe(0);
  expect(calls.authGetUser).toBe(0);
  expect(calls.profileLookups).toHaveLength(0);
  expect(calls.demandLookups).toHaveLength(0);
  expect(calls.productMasterLookups).toHaveLength(0);
  expect(calls.offerInsertCalls).toBe(0);
  expect(calls.insertPayload).toBeNull();
});
