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

function createFormRequest(fields: Record<string, string | File> = {}) {
  const form = new FormData();
  form.set("name", "Legacy draft offer");
  form.set("quantity", "2");
  for (const [key, value] of Object.entries(fields)) form.set(key, value);

  return new Request("https://qima.test/api/offers", {
    method: "POST",
    body: form,
  });
}

function createFormRequestWithDuplicateField(
  fieldName: string,
  first: string | File,
  second: string | File,
  additionalFields: Record<string, string | File> = {},
) {
  const form = new FormData();
  form.set("name", "Legacy draft offer");
  form.set("quantity", "2");
  for (const [key, value] of Object.entries(additionalFields)) form.set(key, value);
  form.delete(fieldName);
  form.append(fieldName, first);
  form.append(fieldName, second);

  return new Request("https://qima.test/api/offers", {
    method: "POST",
    body: form,
  });
}

function createHandler(client: ReturnType<typeof createSupabaseMock>["client"]) {
  return createLegacyOfferHandler(async () => client as never);
}

async function expectInvalidFormBeforeSupabase(
  fields: Record<string, string | File>,
  expectedError: string,
) {
  const { calls } = createSupabaseMock();
  let factoryCalls = 0;
  const handler = createLegacyOfferHandler(async () => {
    factoryCalls += 1;
    throw new Error("Supabase client initialization failed");
  });

  const response = await handler(createFormRequest(fields));

  expect(response.status).toBe(400);
  await expect(response.json()).resolves.toEqual({ error: expectedError });
  expect(factoryCalls).toBe(0);
  expect(calls.authGetUser).toBe(0);
  expect(calls.profileLookups).toHaveLength(0);
  expect(calls.demandLookups).toHaveLength(0);
  expect(calls.productMasterLookups).toHaveLength(0);
  expect(calls.offerInsertCalls).toBe(0);
  expect(calls.insertPayload).toBeNull();
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


test("legacy offers route rejects an empty offer name before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { name: "   " },
    "Please provide a valid offer name and quantity.",
  );
});

test("legacy offers route rejects a negative multipart price before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "-1" },
    "Price must be a valid positive number.",
  );
});

test("legacy offers route rejects an unsupported multipart currency before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "10", currency: "XYZ" },
    "Please select a valid currency.",
  );
});


test("legacy offers route rejects a non-finite multipart quantity before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { quantity: "Infinity" },
    "Please provide a valid offer name and quantity.",
  );
});

test("legacy offers route rejects a NaN multipart price before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "NaN" },
    "Price must be a valid positive number.",
  );
});

test("legacy offers route rejects an infinite multipart price before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "Infinity" },
    "Price must be a valid positive number.",
  );
});

test("legacy offers route rejects an empty multipart quantity before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { quantity: "" },
    "Please provide a valid offer name and quantity.",
  );
});

test("legacy offers route rejects a whitespace-only multipart quantity before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { quantity: "   " },
    "Please provide a valid offer name and quantity.",
  );
});

test("legacy offers route keeps a whitespace-only optional price as an unpriced draft", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "   " }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    name: "Legacy draft offer",
    quantity: 2,
    price: null,
    currency: null,
    pricing_model: null,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});


test("legacy offers route rejects a file supplied as the offer name before invoking Supabase", async () => {
  const file = new File(["not an offer name"], "offer.txt", { type: "text/plain" });

  await expectInvalidFormBeforeSupabase(
    { name: file },
    "Please provide a valid offer name and quantity.",
  );
});

const fileBackedTextFields = [
  "price",
  "currency",
  "conditions",
  "documentation",
  "market",
  "geography",
  "demandId",
  "productMasterId",
  "attributes",
] as const;

for (const field of fileBackedTextFields) {
  test(`legacy offers route rejects a file supplied as ${field} before invoking Supabase`, async () => {
    const file = new File([`unexpected ${field}`], `${field}.txt`, { type: "text/plain" });
    const fields: Record<string, string | File> = { [field]: file };
    if (field === "currency") fields.price = "10";

    await expectInvalidFormBeforeSupabase(fields, "Invalid offer form fields.");
  });
}

test("legacy offers route trims string-valued JSON attributes and ignores non-string values", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequest({
      attributes: JSON.stringify({
        grade: " A ",
        color: " Blue ",
        empty: "   ",
        quantity: 5,
        enabled: true,
        nested: { label: "ignored" },
        missing: null,
      }),
    }),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload?.attributes).toEqual({
    grade: "A",
    color: "Blue",
  });
});

test("legacy offers route defaults omitted optional JSON attributes to an empty object", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest());

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload?.attributes).toEqual({});
});

test("legacy offers route defaults whitespace-only optional JSON attributes to an empty object", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ attributes: "   " }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload?.attributes).toEqual({});
});

test("legacy offers route rejects a file supplied as quantity before invoking Supabase", async () => {
  const file = new File(["2"], "quantity.txt", { type: "text/plain" });

  await expectInvalidFormBeforeSupabase(
    { quantity: file },
    "Please provide a valid offer name and quantity.",
  );
});

test("legacy offers route uses the first value when quantity is submitted twice", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField("quantity", "2", "3"),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    name: "Legacy draft offer",
    quantity: 2,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route ignores a second file value after a valid quantity", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);
  const file = new File(["invalid"], "quantity.txt", { type: "text/plain" });

  const response = await handler(
    createFormRequestWithDuplicateField("quantity", "2", file),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    quantity: 2,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route rejects a file when it is the first duplicated quantity value", async () => {
  const { calls } = createSupabaseMock();
  let factoryCalls = 0;
  const handler = createLegacyOfferHandler(async () => {
    factoryCalls += 1;
    throw new Error("Supabase client initialization failed");
  });
  const file = new File(["2"], "quantity.txt", { type: "text/plain" });

  const response = await handler(
    createFormRequestWithDuplicateField("quantity", file, "2"),
  );

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

test("legacy offers route uses the first value when the offer name is submitted twice", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField("name", "First offer name", "Second offer name"),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    name: "First offer name",
    quantity: 2,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});



test("legacy offers route uses the first value when currency is submitted twice", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField("currency", "USD", "XYZ", { price: "10" }),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10,
    currency: "USD",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route uses the first JSON value when attributes are submitted twice", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField(
      "attributes",
      JSON.stringify({ grade: "A" }),
      JSON.stringify({ grade: "B" }),
    ),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload?.attributes).toEqual({ grade: "A" });
});

test("legacy offers route uses the first reference when demandId is submitted twice", async () => {
  const { client, calls } = createSupabaseMock({
    demand: {
      id: DEMAND_ID,
      target_market: "South Korea",
      scope: {},
    },
  });
  const handler = createHandler(client);
  const secondDemandId = "50000000-0000-4000-8000-000000000102";

  const response = await handler(
    createFormRequestWithDuplicateField("demandId", DEMAND_ID, secondDemandId),
  );

  expect(response.status).toBe(303);
  expect(calls.demandLookups).toEqual([{ column: "id", value: DEMAND_ID }]);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    demand_id: DEMAND_ID,
    market: "South Korea",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route uses the first reference when productMasterId is submitted twice", async () => {
  const { client, calls } = createSupabaseMock({
    productMaster: { id: EXPLICIT_PRODUCT_MASTER_ID },
  });
  const handler = createHandler(client);
  const secondProductMasterId = "60000000-0000-4000-8000-000000000103";

  const response = await handler(
    createFormRequestWithDuplicateField(
      "productMasterId",
      EXPLICIT_PRODUCT_MASTER_ID,
      secondProductMasterId,
    ),
  );

  expect(response.status).toBe(303);
  expect(calls.productMasterLookups).toEqual([
    { column: "id", value: EXPLICIT_PRODUCT_MASTER_ID },
    { column: "status", value: "active" },
  ]);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    product_master_id: EXPLICIT_PRODUCT_MASTER_ID,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});


test("legacy offers route uses the first value when conditions are submitted twice", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField(
      "conditions",
      "Delivery within 7 days",
      "Delivery within 30 days",
    ),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    conditions: "Delivery within 7 days",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route uses the first value when documentation is submitted twice", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField("documentation", "", "safety-sheet.pdf"),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    documentation_status: "incomplete",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route uses the first value when market is submitted twice", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField("market", "South Korea", "Morocco"),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    market: "South Korea",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route uses the first value when geography is submitted twice", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField("geography", "Busan", "Casablanca"),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    geography: "Busan",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route uses the first price when price is submitted twice", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField("price", "10", "20", { currency: "USD" }),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10,
    currency: "USD",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route keeps an empty first price unpriced when a later price is submitted", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequestWithDuplicateField("price", "   ", "10", { currency: "USD" }),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: null,
    currency: null,
    pricing_model: null,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route rejects a non-finite first price even when a valid duplicate follows before invoking Supabase", async () => {
  let factoryCalls = 0;
  const handler = createLegacyOfferHandler(async () => {
    factoryCalls += 1;
    throw new Error("Supabase client initialization failed");
  });

  const response = await handler(
    createFormRequestWithDuplicateField("price", "NaN", "10", { currency: "USD" }),
  );

  expect(response.status).toBe(400);
  await expect(response.json()).resolves.toEqual({
    error: "Price must be a valid positive number.",
  });
  expect(factoryCalls).toBe(0);
});

test("legacy offers route ignores a second file value after a valid first price", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);
  const file = new File(["20"], "price.txt", { type: "text/plain" });

  const response = await handler(
    createFormRequestWithDuplicateField("price", "10", file, { currency: "USD" }),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10,
    currency: "USD",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route rejects a negative fractional multipart price before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "-0.01" },
    "Price must be a valid positive number.",
  );
});

test("legacy offers route rejects negative infinity as a multipart price before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "-Infinity" },
    "Price must be a valid positive number.",
  );
});

test("legacy offers route rejects an overflowing numeric multipart price before invoking a rejecting Supabase factory", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "1e309" },
    "Price must be a valid positive number.",
  );
});

test("legacy offers route accepts a fractional decimal multipart price and preserves its numeric value", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: " 10.25 ", currency: "USD" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10.25,
    currency: "USD",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route accepts scientific notation for a multipart price using JavaScript Number parsing", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "1e2", currency: "USD" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 100,
    currency: "USD",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route currently accepts hexadecimal notation for a multipart price", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "0x10", currency: "USD" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 16,
    currency: "USD",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});


test("legacy offers route accepts a fractional decimal multipart quantity and preserves its numeric value", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ quantity: "1.5" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    quantity: 1.5,
    price: null,
    currency: null,
    pricing_model: null,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route accepts scientific notation for a multipart quantity using JavaScript Number parsing", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ quantity: "1e2" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    quantity: 100,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route currently accepts hexadecimal notation for a multipart quantity", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ quantity: "0x10" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    quantity: 16,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route rejects an overflowing numeric multipart quantity before invoking Supabase", async () => {
  await expectInvalidFormBeforeSupabase(
    { quantity: "1e309" },
    "Please provide a valid offer name and quantity.",
  );
});


test("legacy offers route preserves the maximum safe integer multipart quantity", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ quantity: "9007199254740991" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    quantity: 9007199254740991,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route currently accepts an unsafe integer multipart quantity after JavaScript Number rounding", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ quantity: "9007199254740993" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    quantity: 9007199254740992,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
  expect(Number.isSafeInteger(calls.insertPayload?.quantity as number)).toBe(false);
});

test("legacy offers route currently rounds a high-precision decimal multipart quantity to JavaScript Number precision", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(
    createFormRequest({ quantity: "0.12345678901234567890" }),
  );

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    quantity: 0.12345678901234568,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route accepts the smallest positive JavaScript Number multipart quantity", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ quantity: "5e-324" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    quantity: 5e-324,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route rejects a positive multipart quantity that underflows to zero before invoking Supabase", async () => {
  await expectInvalidFormBeforeSupabase(
    { quantity: "1e-324" },
    "Please provide a valid offer name and quantity.",
  );
});

test("legacy offers route defaults an omitted currency to USD for a priced draft", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "10" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10,
    currency: "USD",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route rejects a whitespace-only currency for a priced draft before invoking Supabase", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "10", currency: "   " },
    "Please select a valid currency.",
  );
});

test("legacy offers route keeps an unpriced draft when an unsupported currency is submitted without a price", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ currency: "XYZ" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: null,
    currency: null,
    pricing_model: null,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route trims surrounding whitespace from the USD currency code", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "10", currency: " USD " }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10,
    currency: "USD",
    pricing_model: "fixed",
    lifecycle: "draft",
  });
});

test("legacy offers route rejects a lowercase currency code before invoking Supabase", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "10", currency: "usd" },
    "Please select a valid currency.",
  );
});

test("legacy offers route trims surrounding whitespace from the EUR currency code", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "10", currency: " EUR " }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10,
    currency: "EUR",
    pricing_model: "fixed",
    lifecycle: "draft",
  });
});


test("legacy offers route accepts KRW as a supported currency for a priced draft", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "10", currency: "KRW" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10,
    currency: "KRW",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route accepts MAD as a supported currency for a priced draft", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "10", currency: "MAD" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10,
    currency: "MAD",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route accepts CNY as a supported currency for a priced draft", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ price: "10", currency: "CNY" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: 10,
    currency: "CNY",
    pricing_model: "fixed",
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route rejects JPY as an unsupported currency before invoking Supabase", async () => {
  await expectInvalidFormBeforeSupabase(
    { price: "10", currency: "JPY" },
    "Please select a valid currency.",
  );
});


test("legacy offers route keeps an unpriced draft when USD is explicitly selected", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ currency: "USD" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: null,
    currency: null,
    pricing_model: null,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});

test("legacy offers route keeps an unpriced draft when KRW is explicitly selected", async () => {
  const { client, calls } = createSupabaseMock();
  const handler = createHandler(client);

  const response = await handler(createFormRequest({ currency: "KRW" }));

  expect(response.status).toBe(303);
  expect(calls.offerInsertCalls).toBe(1);
  expect(calls.insertPayload).toMatchObject({
    price: null,
    currency: null,
    pricing_model: null,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });
});
