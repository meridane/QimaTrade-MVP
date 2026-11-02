import { expect, test } from "@playwright/test";
import { POST } from "../../app/api/actions/create-offer/route";

type MockRequest = { path: string; query: string; body?: Record<string, unknown>; authorization?: string };

test.describe.configure({ mode: "serial" });

async function postCreateOffer(
  currency: unknown,
  overrides: Record<string, unknown> = {},
  rawBody?: string,
  membershipRows: Array<{ tenant_id: string | null }> = [{ tenant_id: "20000000-0000-4000-8000-000000000001" }],
  rpcStatus = "succeeded",
  authorizationHeader: string | null = "Bearer qima-route-test-token",
  authStatus = 200,
  membershipStatus = 200,
  profileStatus = 200,
  profileActorId: string | null = "30000000-0000-4000-8000-000000000001",
  profileMissing = false,
  createOfferRpcHttpStatus = 200,
  getActionDefinitionRpcHttpStatus = 200,
  actionDefinition: { action_key: string; version: number; status: string } | null = {
    action_key: "CREATE_OFFER",
    version: 1,
    status: "published",
  },
) {
  process.env.NEXT_PUBLIC_SUPABASE_URL ??= "https://example.supabase.co";
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??= "ci-placeholder-anon-key";

  const originalFetch = globalThis.fetch;
  const originalWebSocket = globalThis.WebSocket;
  const requests: MockRequest[] = [];
  const demandId = "50000000-0000-4000-8000-000000000001";

  // Supabase creates a Realtime client even though this route only uses Auth and REST.
  // Node 20 in CI has no native WebSocket; provide a harmless constructor for this isolated test.
  if (typeof globalThis.WebSocket === "undefined") {
    globalThis.WebSocket = class MockWebSocket {} as unknown as typeof WebSocket;
  }

  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const urlString =
      typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    const url = new URL(urlString);
    const request = input instanceof Request ? input : null;
    const rawBody = init?.body ?? (request ? await request.clone().text() : undefined);
    let body: Record<string, unknown> | undefined;
    if (typeof rawBody === "string" && rawBody.length > 0) {
      try {
        body = JSON.parse(rawBody) as Record<string, unknown>;
      } catch {
        body = undefined;
      }
    }
    const headers = new Headers(init?.headers ?? request?.headers);
    requests.push({ path: url.pathname, query: url.search, body, authorization: headers.get("authorization") ?? undefined });

    if (url.pathname === "/auth/v1/user") {
      if (authStatus !== 200) {
        return Response.json({ message: "Invalid JWT", code: "bad_jwt" }, { status: authStatus });
      }
      return Response.json({
        id: "40000000-0000-4000-8000-000000000001",
        aud: "authenticated",
        role: "authenticated",
        email: "qima-route-test@example.invalid",
      });
    }
    if (url.pathname === "/rest/v1/profiles") {
      if (profileStatus !== 200) {
        return Response.json({ message: "Profile lookup failed", code: "XX000" }, { status: profileStatus });
      }
      if (profileMissing) return Response.json(null);
      return Response.json(profileActorId ? { actor_id: profileActorId } : {});
    }
    if (url.pathname === "/rest/v1/dt_memberships") {
      if (membershipStatus !== 200) {
        return Response.json({ message: "Membership lookup failed", code: "XX000" }, { status: membershipStatus });
      }
      return Response.json(membershipRows);
    }
    if (url.pathname === "/rest/v1/rpc/get_action_definition_v1") {
      if (getActionDefinitionRpcHttpStatus !== 200) {
        return Response.json(
          { message: "Action definition lookup unavailable", code: "XX000", details: null, hint: null },
          { status: getActionDefinitionRpcHttpStatus },
        );
      }
      return Response.json(actionDefinition);
    }
    if (url.pathname === "/rest/v1/rpc/execute_create_offer_v1") {
      if (createOfferRpcHttpStatus !== 200) {
        return Response.json(
          { message: "CREATE_OFFER RPC unavailable", code: "XX000", details: null, hint: null },
          { status: createOfferRpcHttpStatus },
        );
      }
      return Response.json({
        executionId: "10000000-0000-4000-8000-000000000001",
        status: rpcStatus,
        objectId: demandId,
        result: { offerId: "70000000-0000-4000-8000-000000000001" },
      });
    }

    return Response.json({ message: `Unexpected mocked request: ${url.pathname}` }, { status: 500 });
  }) as typeof fetch;

  try {
    const response = await POST(
      new Request("https://qima.test/api/actions/create-offer", {
        method: "POST",
        headers: {
          ...(authorizationHeader === null ? {} : { authorization: authorizationHeader }),
          "content-type": "application/json",
        },
        body: rawBody ?? JSON.stringify({
          name: "Currency contract fixture",
          demandId,
          productMasterId: "60000000-0000-4000-8000-000000000001",
          quantity: 1,
          price: 10,
          currency,
          ...overrides,
        }),
      }),
    );

    return {
      status: response.status,
      body: (await response.json()) as Record<string, unknown>,
      requests,
    };
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.WebSocket = originalWebSocket;
  }
}


test("CREATE_OFFER route rejects missing or non-Bearer authorization before database access", async () => {
  for (const authorizationHeader of [null, "Basic invalid-token"]) {
    const result = await postCreateOffer("USD", {}, undefined, undefined, "succeeded", authorizationHeader);

    expect(result.status, String(authorizationHeader)).toBe(401);
    expect(result.body, String(authorizationHeader)).toMatchObject({ error: "UNAUTHENTICATED" });
    expect(result.requests, String(authorizationHeader)).toEqual([]);
  }
});

test("CREATE_OFFER route fails closed after Auth rejects a normalized mixed-case Bearer token", async () => {
  const rejectedToken = "syntactically-valid-but-rejected-token";
  const result = await postCreateOffer(
    "USD",
    {},
    undefined,
    undefined,
    "succeeded",
    "bEaReR    syntactically-valid-but-rejected-token",
    401,
  );

  expect(result.status).toBe(401);
  expect(result.body).toMatchObject({ error: "UNAUTHENTICATED" });

  const authRequests = result.requests.filter((request) => request.path === "/auth/v1/user");
  expect(authRequests).toHaveLength(1);
  expect(authRequests[0].authorization).toBe(`Bearer ${rejectedToken}`);

  const profileRequests = result.requests.filter((request) => request.path === "/rest/v1/profiles");
  const membershipRequests = result.requests.filter((request) => request.path === "/rest/v1/dt_memberships");
  const rpcRequests = result.requests.filter((request) => request.path.startsWith("/rest/v1/rpc/"));
  expect(profileRequests).toHaveLength(0);
  expect(membershipRequests).toHaveLength(0);
  expect(rpcRequests).toHaveLength(0);
  expect(result.requests).toHaveLength(1);
});

test("CREATE_OFFER route accepts case-insensitive Bearer schemes", async () => {
  for (const authorizationHeader of ["bearer qima-route-test-token", "bEaReR qima-route-test-token"]) {
    const result = await postCreateOffer("USD", {}, undefined, undefined, "succeeded", authorizationHeader);

    expect(result.status, authorizationHeader).toBe(200);
    expect(
      result.requests.some((request) => request.path === "/rest/v1/rpc/execute_create_offer_v1"),
      authorizationHeader,
    ).toBe(true);
  }
});

test("CREATE_OFFER route canonicalizes repeated spaces in Bearer headers for Auth and REST", async () => {
  const result = await postCreateOffer("USD", {}, undefined, undefined, "succeeded", "Bearer   qima-route-test-token");

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  const authRequest = result.requests.find((request) => request.path === "/auth/v1/user");
  const profileRequest = result.requests.find((request) => request.path === "/rest/v1/profiles");
  expect(authRequest?.authorization).toBe("Bearer qima-route-test-token");
  expect(profileRequest?.authorization).toBe("Bearer qima-route-test-token");
  expect(result.requests.some((request) => request.path === "/rest/v1/rpc/execute_create_offer_v1")).toBe(true);
});

test("CREATE_OFFER route rejects Bearer schemes without a credential before any Supabase request", async () => {
  // Request/Headers trims trailing HTTP whitespace, so exercise the bare scheme directly.
  for (const authorizationHeader of ["Bearer", "bEaReR"]) {
    const result = await postCreateOffer("USD", {}, undefined, undefined, "succeeded", authorizationHeader);

    expect(result.status, authorizationHeader).toBe(401);
    expect(result.body, authorizationHeader).toMatchObject({ error: "UNAUTHENTICATED" });
    expect(result.requests, authorizationHeader).toEqual([]);
  }
});

test("CREATE_OFFER route returns HTTP 409 for a non-succeeded execution status", async () => {
  const result = await postCreateOffer("USD", {}, undefined, undefined, "failed");

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(409);
  expect(result.body).toMatchObject({ status: "failed" });
  expect(
    result.requests.some((request) => request.path === "/rest/v1/rpc/execute_create_offer_v1"),
  ).toBe(true);
});

test('CREATE_OFFER route trims whitespace around a supported currency before the RPC', async () => {
  const result = await postCreateOffer(" USD ");

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  expect(result.body).toMatchObject({ status: "succeeded" });
  const executionCall = result.requests.find(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCall?.body).toMatchObject({ p_currency: "USD" });
});

test("CREATE_OFFER route preserves numeric-string quantity and price inputs", async () => {
  const result = await postCreateOffer("USD", { quantity: "2", price: "12.5" });

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  const executionCall = result.requests.find(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCall?.body).toMatchObject({ p_quantity: 2, p_price: 12.5 });
});

test("CREATE_OFFER route rejects lowercase currency without calling database RPCs", async () => {
  const result = await postCreateOffer("usd");

  expect(result.status).toBe(400);
  expect(result.body).toMatchObject({ error: "INVALID_CURRENCY" });
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/"))).toBe(false);
});

test("CREATE_OFFER route rejects an unsupported uppercase currency without calling database RPCs", async () => {
  const result = await postCreateOffer("GBP");

  expect(result.status).toBe(400);
  expect(result.body).toMatchObject({ error: "INVALID_CURRENCY" });
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/"))).toBe(false);
});
test("CREATE_OFFER route rejects non-string currency values without calling database RPCs", async () => {
  for (const currency of [null, 123]) {
    const result = await postCreateOffer(currency);

    expect(result.status).toBe(400);
    expect(result.body).toMatchObject({ error: "INVALID_CURRENCY" });
    expect(result.requests.some((request) => request.path.startsWith("/rest/v1/"))).toBe(false);
  }
});

test("CREATE_OFFER route rejects blank or non-string name/demandId before database access", async () => {
  const invalidCases = [
    { label: "blank name", overrides: { name: "   " } },
    { label: "non-string name", overrides: { name: { value: "offer" } } },
    { label: "blank demandId", overrides: { demandId: "   " } },
    { label: "non-string demandId", overrides: { demandId: 42 } },
  ];

  for (const invalidCase of invalidCases) {
    const result = await postCreateOffer("USD", invalidCase.overrides);

    expect(result.status, invalidCase.label).toBe(400);
    expect(result.body, invalidCase.label).toMatchObject({ error: "NAME_AND_DEMAND_REQUIRED" });
    expect(
      result.requests.some((request) => request.path.startsWith("/rest/v1/")),
      invalidCase.label,
    ).toBe(false);
  }
});

test("CREATE_OFFER route rejects invalid quantity and price before database access", async () => {
  const invalidCases = [
    { label: "zero quantity", overrides: { quantity: 0 }, expectedError: "INVALID_QUANTITY" },
    { label: "nonnumeric quantity", overrides: { quantity: "not-a-number" }, expectedError: "INVALID_QUANTITY" },
    { label: "boolean quantity", overrides: { quantity: true }, expectedError: "INVALID_QUANTITY" },
    { label: "array quantity", overrides: { quantity: [2] }, expectedError: "INVALID_QUANTITY" },
    { label: "non-finite numeric-string quantity", overrides: { quantity: "Infinity" }, expectedError: "INVALID_QUANTITY" },
    { label: "negative price", overrides: { price: -1 }, expectedError: "INVALID_PRICE" },
    { label: "overflowing numeric-string price", overrides: { price: "1e309" }, expectedError: "INVALID_PRICE" },
    { label: "blank price", overrides: { price: "   " }, expectedError: "INVALID_PRICE" },
    { label: "boolean price", overrides: { price: true }, expectedError: "INVALID_PRICE" },
    { label: "array price", overrides: { price: [] }, expectedError: "INVALID_PRICE" },
  ];

  for (const invalidCase of invalidCases) {
    const result = await postCreateOffer("USD", invalidCase.overrides);

    expect(result.status, invalidCase.label).toBe(400);
    expect(result.body, invalidCase.label).toMatchObject({ error: invalidCase.expectedError });
    expect(
      result.requests.some((request) => request.path.startsWith("/rest/v1/")),
      invalidCase.label,
    ).toBe(false);
  }
});


test("CREATE_OFFER route rejects malformed JSON with a stable error before database access", async () => {
  const result = await postCreateOffer("USD", {}, '{"name":');

  expect(result.status).toBe(400);
  expect(result.body).toMatchObject({ error: "INVALID_REQUEST_BODY" });
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/"))).toBe(false);
});

test("CREATE_OFFER route rejects a JSON array as an invalid request body", async () => {
  const result = await postCreateOffer("USD", {}, JSON.stringify([{ name: "not an object" }]));

  expect(result.status).toBe(400);
  expect(result.body).toMatchObject({ error: "INVALID_REQUEST_BODY" });
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/"))).toBe(false);
});

test("CREATE_OFFER route rejects JSON primitive values as invalid request bodies", async () => {
  for (const rawBody of ["null", '"plain text"', "42", "true"]) {
    const result = await postCreateOffer("USD", {}, rawBody);

    expect(result.status, rawBody).toBe(400);
    expect(result.body, rawBody).toMatchObject({ error: "INVALID_REQUEST_BODY" });
    expect(
      result.requests.some((request) => request.path.startsWith("/rest/v1/")),
      rawBody,
    ).toBe(false);
  }
});

test("CREATE_OFFER route normalizes every non-object attributes value before the RPC", async () => {
  const nonObjectAttributes: Array<{ label: string; value: unknown }> = [
    { label: "non-empty array", value: ["not", "an object"] },
    { label: "empty array", value: [] },
    { label: "string", value: "plain text" },
    { label: "empty string", value: "" },
    { label: "number", value: 42 },
    { label: "zero", value: 0 },
    { label: "boolean", value: true },
    { label: "false", value: false },
    { label: "JSON null", value: null },
  ];

  for (const { label, value } of nonObjectAttributes) {
    const result = await postCreateOffer("USD", { attributes: value });

    expect(result.status, label).toBe(200);
    const executionCalls = result.requests.filter(
      (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
    );
    expect(executionCalls, label).toHaveLength(1);
    expect(
      Object.prototype.hasOwnProperty.call(executionCalls[0].body, "p_attributes"),
      label,
    ).toBe(true);
    expect(executionCalls[0].body?.p_attributes, label).toEqual({});

    const rpcInput = executionCalls[0].body?.p_input as Record<string, unknown> | undefined;
    expect(rpcInput, label).toBeDefined();
    expect(Object.prototype.hasOwnProperty.call(rpcInput, "attributes"), label).toBe(true);
    expect(rpcInput?.attributes, label).toEqual({});
    expect(executionCalls[0].body).toMatchObject({
      p_pricing_model: "fixed",
      p_lifecycle: "draft",
      p_offer_type: "supplier_offer",
    });
    expect(rpcInput).toMatchObject({
      pricingModel: "fixed",
      lifecycle: "draft",
      offerType: "supplier_offer",
    });
  }
});

test("CREATE_OFFER route preserves valid object attributes including nested JSON values", async () => {
  const attributes = {
    category: "industrial",
    rank: 42,
    nested: {
      enabled: true,
      tags: ["a", "b"],
      nullable: null,
    },
  };
  const result = await postCreateOffer("USD", { attributes });

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  const executionCall = result.requests.find(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCall?.body?.p_attributes).toEqual(attributes);
});

test("CREATE_OFFER route treats omitted attributes and an explicit empty object identically before the RPC", async () => {
  const cases = [
    { label: "omitted attributes", overrides: {} },
    { label: "explicit empty attributes", overrides: { attributes: {} } },
  ];
  const normalizedRpcPayloads: Array<Record<string, unknown>> = [];

  for (const testCase of cases) {
    const result = await postCreateOffer("USD", testCase.overrides);

    expect(result.status, testCase.label).toBe(200);
    const executionCalls = result.requests.filter(
      (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
    );
    expect(executionCalls, testCase.label).toHaveLength(1);

    const rpcBody = executionCalls[0].body;
    expect(rpcBody, testCase.label).toBeDefined();
    expect(
      Object.prototype.hasOwnProperty.call(rpcBody, "p_attributes"),
      testCase.label,
    ).toBe(true);
    expect(rpcBody?.p_attributes, testCase.label).toEqual({});

    const rpcInput = rpcBody?.p_input as Record<string, unknown> | undefined;
    expect(rpcInput, testCase.label).toBeDefined();
    expect(
      Object.prototype.hasOwnProperty.call(rpcInput, "attributes"),
      testCase.label,
    ).toBe(true);
    expect(rpcInput?.attributes, testCase.label).toEqual({});
    expect(rpcBody).toMatchObject({
      p_pricing_model: "fixed",
      p_lifecycle: "draft",
      p_offer_type: "supplier_offer",
    });
    expect(rpcInput).toMatchObject({
      pricingModel: "fixed",
      lifecycle: "draft",
      offerType: "supplier_offer",
    });

    // Compare the complete business payload while excluding the per-request idempotency key.
    normalizedRpcPayloads.push({
      p_input: rpcBody?.p_input,
      p_name: rpcBody?.p_name,
      p_demand_id: rpcBody?.p_demand_id,
      p_product_master_id: rpcBody?.p_product_master_id,
      p_provider_actor_id: rpcBody?.p_provider_actor_id,
      p_quantity: rpcBody?.p_quantity,
      p_price: rpcBody?.p_price,
      p_currency: rpcBody?.p_currency,
      p_conditions: rpcBody?.p_conditions,
      p_market: rpcBody?.p_market,
      p_geography: rpcBody?.p_geography,
      p_attributes: rpcBody?.p_attributes,
      p_documentation_status: rpcBody?.p_documentation_status,
      p_lifecycle: rpcBody?.p_lifecycle,
      p_offer_type: rpcBody?.p_offer_type,
      p_pricing_model: rpcBody?.p_pricing_model,
    });
  }

  expect(normalizedRpcPayloads).toHaveLength(2);
  expect(normalizedRpcPayloads[0]).toEqual(normalizedRpcPayloads[1]);
});

test("CREATE_OFFER route trims an explicit idempotency key before the RPC", async () => {
  const result = await postCreateOffer("USD", { idempotencyKey: "  client-key-123  " });

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  const executionCall = result.requests.find(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCall?.body).toMatchObject({ p_idempotency_key: "client-key-123" });
});

test("CREATE_OFFER route generates an idempotency UUID when the supplied key is blank", async () => {
  const result = await postCreateOffer("USD", { idempotencyKey: "   " });

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  const executionCall = result.requests.find(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCall?.body?.p_idempotency_key).toMatch(
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
  );
});


test("CREATE_OFFER route ignores non-string idempotency keys and generates UUIDs before the RPC", async () => {
  const invalidKeys: Array<{ label: string; value: unknown }> = [
    { label: "number zero", value: 0 },
    { label: "boolean false", value: false },
    { label: "array", value: [] },
    { label: "object", value: {} },
    { label: "JSON null", value: null },
  ];
  const generatedKeys: string[] = [];
  const uuidV4Pattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

  for (const { label, value } of invalidKeys) {
    const result = await postCreateOffer("USD", { idempotencyKey: value });

    expect(result.status, label).toBe(200);
    const executionCalls = result.requests.filter(
      (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
    );
    expect(executionCalls, label).toHaveLength(1);

    const rpcBody = executionCalls[0].body;
    expect(
      Object.prototype.hasOwnProperty.call(rpcBody, "p_idempotency_key"),
      label,
    ).toBe(true);
    expect(typeof rpcBody?.p_idempotency_key, label).toBe("string");
    expect(rpcBody?.p_idempotency_key, label).toMatch(uuidV4Pattern);
    generatedKeys.push(rpcBody?.p_idempotency_key as string);
  }

  expect(new Set(generatedKeys).size).toBe(invalidKeys.length);
});


test("CREATE_OFFER route generates distinct UUIDs when idempotencyKey is omitted", async () => {
  const uuidV4Pattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const generatedKeys: string[] = [];

  for (const requestNumber of [1, 2]) {
    const result = await postCreateOffer("USD", {});

    expect(result.status, `request ${requestNumber}`).toBe(200);
    const executionCalls = result.requests.filter(
      (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
    );
    expect(executionCalls, `request ${requestNumber}`).toHaveLength(1);

    const rpcBody = executionCalls[0].body;
    expect(
      Object.prototype.hasOwnProperty.call(rpcBody, "p_idempotency_key"),
      `request ${requestNumber}`,
    ).toBe(true);
    expect(typeof rpcBody?.p_idempotency_key, `request ${requestNumber}`).toBe("string");
    expect(rpcBody?.p_idempotency_key, `request ${requestNumber}`).toMatch(uuidV4Pattern);
    generatedKeys.push(rpcBody?.p_idempotency_key as string);
  }

  expect(new Set(generatedKeys).size).toBe(2);
});

test("CREATE_OFFER route ignores a client-supplied providerActorId and uses the authenticated profile actor", async () => {
  const profileActorId = "30000000-0000-4000-8000-000000000001";
  const spoofedActorId = "90000000-0000-4000-8000-000000000009";
  const result = await postCreateOffer(
    "USD",
    { providerActorId: spoofedActorId },
    undefined,
    undefined,
    "succeeded",
    "Bearer qima-route-test-token",
    200,
    200,
    200,
    profileActorId,
  );

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  expect(result.requests.some((request) => request.path === "/rest/v1/profiles")).toBe(true);

  const executionCalls = result.requests.filter(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCalls).toHaveLength(1);

  const rpcBody = executionCalls[0].body;
  expect(Object.prototype.hasOwnProperty.call(rpcBody, "p_provider_actor_id")).toBe(true);
  expect(rpcBody?.p_provider_actor_id).toBe(profileActorId);
  expect(rpcBody?.p_provider_actor_id).not.toBe(spoofedActorId);

  const rpcInput = rpcBody?.p_input as Record<string, unknown> | undefined;
  expect(rpcInput).toBeDefined();
  expect(Object.prototype.hasOwnProperty.call(rpcInput, "providerActorId")).toBe(true);
  expect(rpcInput?.providerActorId).toBe(profileActorId);
  expect(rpcInput?.providerActorId).not.toBe(spoofedActorId);
});

test("CREATE_OFFER route scopes profile and membership lookups to the authenticated Supabase user, ignoring client userId", async () => {
  const authenticatedUserId = "40000000-0000-4000-8000-000000000001";
  const spoofedUserId = "90000000-0000-4000-8000-000000000009";
  const profileActorId = "30000000-0000-4000-8000-000000000001";
  const membershipTenantId = "20000000-0000-4000-8000-000000000001";
  const result = await postCreateOffer("USD", { userId: spoofedUserId });

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);

  const authRequest = result.requests.find((request) => request.path === "/auth/v1/user");
  expect(authRequest?.authorization).toBe("Bearer qima-route-test-token");

  const profileRequest = result.requests.find((request) => request.path === "/rest/v1/profiles");
  expect(profileRequest).toBeDefined();
  const profileQuery = new URLSearchParams(profileRequest?.query ?? "");
  expect(profileQuery.get("auth_user_id")).toBe(`eq.${authenticatedUserId}`);
  expect(profileQuery.get("auth_user_id")).not.toBe(`eq.${spoofedUserId}`);

  const membershipRequest = result.requests.find((request) => request.path === "/rest/v1/dt_memberships");
  expect(membershipRequest).toBeDefined();
  const membershipQuery = new URLSearchParams(membershipRequest?.query ?? "");
  expect(membershipQuery.get("user_id")).toBe(`eq.${authenticatedUserId}`);
  expect(membershipQuery.get("user_id")).not.toBe(`eq.${spoofedUserId}`);

  const executionCalls = result.requests.filter(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCalls).toHaveLength(1);
  expect(executionCalls[0].body?.p_provider_actor_id).toBe(profileActorId);
  expect(executionCalls[0].body?.p_tenant_id).toBe(membershipTenantId);

  const rpcInput = executionCalls[0].body?.p_input as Record<string, unknown> | undefined;
  expect(rpcInput).toBeDefined();
  expect(Object.prototype.hasOwnProperty.call(rpcInput, "userId")).toBe(false);
});

test("CREATE_OFFER route fails closed when the profile has no actor_id", async () => {
  const result = await postCreateOffer(
    "USD",
    {},
    undefined,
    undefined,
    "succeeded",
    "Bearer qima-route-test-token",
    200,
    200,
    200,
    null,
  );

  expect(result.status).toBe(403);
  expect(result.body).toMatchObject({ error: "PROFILE_ACTOR_NOT_FOUND" });
  expect(result.requests.some((request) => request.path === "/rest/v1/profiles")).toBe(true);
  expect(result.requests.some((request) => request.path === "/rest/v1/dt_memberships")).toBe(false);
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/rpc/"))).toBe(false);
});

test("CREATE_OFFER route fails closed when profile lookup returns an error", async () => {
  const result = await postCreateOffer(
    "USD",
    {},
    undefined,
    undefined,
    "succeeded",
    "Bearer qima-route-test-token",
    200,
    200,
    500,
  );

  expect(result.status).toBe(403);
  expect(result.body).toMatchObject({ error: "PROFILE_ACTOR_NOT_FOUND" });
  expect(result.requests.some((request) => request.path === "/rest/v1/profiles")).toBe(true);
  expect(result.requests.some((request) => request.path === "/rest/v1/dt_memberships")).toBe(false);
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/rpc/"))).toBe(false);
});

test("CREATE_OFFER route fails closed when the profile row is absent", async () => {
  const result = await postCreateOffer(
    "USD",
    {},
    undefined,
    undefined,
    "succeeded",
    "Bearer qima-route-test-token",
    200,
    200,
    200,
    null,
    true,
  );

  expect(result.status).toBe(403);
  expect(result.body).toMatchObject({ error: "PROFILE_ACTOR_NOT_FOUND" });
  expect(result.requests.some((request) => request.path === "/rest/v1/profiles")).toBe(true);
  expect(result.requests.some((request) => request.path === "/rest/v1/dt_memberships")).toBe(false);
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/rpc/"))).toBe(false);
});

test("CREATE_OFFER route rejects missing tenant membership before calling RPC", async () => {
  const result = await postCreateOffer("USD", {}, undefined, []);

  expect(result.status).toBe(403);
  expect(result.body).toMatchObject({ error: "TENANT_MEMBERSHIP_REQUIRED" });
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/rpc/"))).toBe(false);
});

test("CREATE_OFFER route fails closed when tenant membership lookup returns an error", async () => {
  const result = await postCreateOffer(
    "USD",
    {},
    undefined,
    undefined,
    "succeeded",
    "Bearer qima-route-test-token",
    200,
    500,
  );

  expect(result.status).toBe(403);
  expect(result.body).toMatchObject({ error: "TENANT_MEMBERSHIP_REQUIRED" });
  expect(result.requests.some((request) => request.path === "/rest/v1/dt_memberships")).toBe(true);
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/rpc/"))).toBe(false);
});

test("CREATE_OFFER route requires explicit tenant selection even when the client supplies one of multiple tenant IDs", async () => {
  const firstTenantId = "20000000-0000-4000-8000-000000000001";
  const secondTenantId = "20000000-0000-4000-8000-000000000002";
  const result = await postCreateOffer("USD", { tenantId: firstTenantId }, undefined, [
    { tenant_id: firstTenantId },
    { tenant_id: secondTenantId },
  ]);

  expect(result.status).toBe(409);
  expect(result.body).toMatchObject({ error: "TENANT_SELECTION_REQUIRED" });
  expect(result.requests.some((request) => request.path === "/rest/v1/dt_memberships")).toBe(true);
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/rpc/"))).toBe(false);
});

test("CREATE_OFFER route ignores a client-supplied tenantId when exactly one membership exists", async () => {
  const membershipTenantId = "20000000-0000-4000-8000-000000000001";
  const spoofedTenantId = "90000000-0000-4000-8000-000000000009";
  const result = await postCreateOffer(
    "USD",
    { tenantId: spoofedTenantId },
    undefined,
    [{ tenant_id: membershipTenantId }],
  );

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  const executionCalls = result.requests.filter(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCalls).toHaveLength(1);
  expect(executionCalls[0].body?.p_tenant_id).toBe(membershipTenantId);
  expect(executionCalls[0].body?.p_tenant_id).not.toBe(spoofedTenantId);

  const rpcInput = executionCalls[0].body?.p_input as Record<string, unknown> | undefined;
  expect(rpcInput).toBeDefined();
  expect(Object.prototype.hasOwnProperty.call(rpcInput, "tenantId")).toBe(false);
});


test("CREATE_OFFER route treats duplicate membership rows for the same tenant as one tenant", async () => {
  const tenantId = "20000000-0000-4000-8000-000000000001";
  const result = await postCreateOffer("USD", {}, undefined, [
    { tenant_id: tenantId },
    { tenant_id: tenantId },
  ]);

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  expect(result.body).toMatchObject({ status: "succeeded" });
  expect(
    result.requests.some((request) => request.path === "/rest/v1/rpc/execute_create_offer_v1"),
  ).toBe(true);
});

test("CREATE_OFFER route ignores null membership rows when one valid tenant remains", async () => {
  const tenantId = "20000000-0000-4000-8000-000000000001";
  const result = await postCreateOffer("USD", {}, undefined, [
    { tenant_id: null },
    { tenant_id: tenantId },
    { tenant_id: null },
  ]);

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  const executionCall = result.requests.find(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCall?.body?.p_tenant_id).toBe(tenantId);
});

test("CREATE_OFFER route preserves the current error response when the execution RPC returns HTTP 500", async () => {
  const result = await postCreateOffer(
    "USD",
    {},
    undefined,
    undefined,
    "succeeded",
    "Bearer qima-route-test-token",
    200,
    200,
    200,
    "30000000-0000-4000-8000-000000000001",
    false,
    500,
  );

  expect(result.status).toBe(400);
  expect(result.body).toMatchObject({ error: "CREATE_OFFER RPC unavailable" });
  expect(
    result.requests.some((request) => request.path === "/rest/v1/rpc/get_action_definition_v1"),
  ).toBe(true);
  expect(
    result.requests.some((request) => request.path === "/rest/v1/rpc/execute_create_offer_v1"),
  ).toBe(true);
});

test("CREATE_OFFER route stops before execution when action definition lookup returns HTTP 500", async () => {
  const result = await postCreateOffer(
    "USD",
    {},
    undefined,
    undefined,
    "succeeded",
    "Bearer qima-route-test-token",
    200,
    200,
    200,
    "30000000-0000-4000-8000-000000000001",
    false,
    200,
    500,
  );

  expect(result.status).toBe(400);
  expect(result.body).toMatchObject({ error: "Action definition lookup unavailable" });
  expect(
    result.requests.some((request) => request.path === "/rest/v1/rpc/get_action_definition_v1"),
  ).toBe(true);
  expect(
    result.requests.some((request) => request.path === "/rest/v1/rpc/execute_create_offer_v1"),
  ).toBe(false);
});


test("CREATE_OFFER route rejects missing or unpublished action definitions before execution", async () => {
  const invalidDefinitions = [
    { label: "missing definition", definition: null },
    {
      label: "draft definition",
      definition: { action_key: "CREATE_OFFER", version: 1, status: "draft" },
    },
    {
      label: "retired definition",
      definition: { action_key: "CREATE_OFFER", version: 1, status: "retired" },
    },
  ];

  for (const invalidCase of invalidDefinitions) {
    const result = await postCreateOffer(
      "USD",
      {},
      undefined,
      undefined,
      "succeeded",
      "Bearer qima-route-test-token",
      200,
      200,
      200,
      "30000000-0000-4000-8000-000000000001",
      false,
      200,
      200,
      invalidCase.definition,
    );

    expect(result.status, invalidCase.label).toBe(400);
    expect(result.body, invalidCase.label).toMatchObject({ error: "ACTION_NOT_PUBLISHED" });
    expect(
      result.requests.some((request) => request.path === "/rest/v1/rpc/get_action_definition_v1"),
      invalidCase.label,
    ).toBe(true);
    expect(
      result.requests.some((request) => request.path === "/rest/v1/rpc/execute_create_offer_v1"),
      invalidCase.label,
    ).toBe(false);
  }
});

test("CREATE_OFFER route normalizes a mixed-case Bearer header and forwards the same authenticated token to both RPCs", async () => {
  const accessToken = "qima-route-test-token";
  const result = await postCreateOffer(
    "USD",
    {},
    undefined,
    undefined,
    "succeeded",
    "bEaReR    qima-route-test-token",
  );

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);

  const expectedPaths = [
    "/auth/v1/user",
    "/rest/v1/profiles",
    "/rest/v1/dt_memberships",
    "/rest/v1/rpc/get_action_definition_v1",
    "/rest/v1/rpc/execute_create_offer_v1",
  ];

  for (const path of expectedPaths) {
    const matchingRequests = result.requests.filter((request) => request.path === path);
    expect(matchingRequests, path).toHaveLength(1);
    expect(matchingRequests[0].authorization, path).toBe(`Bearer ${accessToken}`);
  }

  const rpcRequests = result.requests.filter((request) =>
    request.path === "/rest/v1/rpc/get_action_definition_v1" ||
    request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(rpcRequests).toHaveLength(2);
  expect(rpcRequests.every((request) => request.authorization === `Bearer ${accessToken}`)).toBe(true);
});
