import { expect, test } from "@playwright/test";
import { POST } from "../../app/api/actions/create-offer/route";

type MockRequest = { path: string; body?: Record<string, unknown> };

test.describe.configure({ mode: "serial" });

async function postCreateOffer(
  currency: unknown,
  overrides: Record<string, unknown> = {},
  rawBody?: string,
  membershipRows: Array<{ tenant_id: string }> = [{ tenant_id: "20000000-0000-4000-8000-000000000001" }],
  rpcStatus = "succeeded",
  authorizationHeader: string | null = "Bearer qima-route-test-token",
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
    requests.push({ path: url.pathname, body });

    if (url.pathname === "/auth/v1/user") {
      return Response.json({
        id: "40000000-0000-4000-8000-000000000001",
        aud: "authenticated",
        role: "authenticated",
        email: "qima-route-test@example.invalid",
      });
    }
    if (url.pathname === "/rest/v1/profiles") {
      return Response.json({ actor_id: "30000000-0000-4000-8000-000000000001" });
    }
    if (url.pathname === "/rest/v1/dt_memberships") {
      return Response.json(membershipRows);
    }
    if (url.pathname === "/rest/v1/rpc/get_action_definition_v1") {
      return Response.json({ action_key: "CREATE_OFFER", version: 1, status: "published" });
    }
    if (url.pathname === "/rest/v1/rpc/execute_create_offer_v1") {
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

test("CREATE_OFFER route normalizes non-object attributes and preserves optional defaults", async () => {
  const result = await postCreateOffer("USD", { attributes: ["not", "an object"] });

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  const executionCall = result.requests.find(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCall?.body).toMatchObject({
    p_attributes: {},
    p_pricing_model: "fixed",
    p_lifecycle: "draft",
    p_offer_type: "supplier_offer",
  });
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


test("CREATE_OFFER route rejects missing tenant membership before calling RPC", async () => {
  const result = await postCreateOffer("USD", {}, undefined, []);

  expect(result.status).toBe(403);
  expect(result.body).toMatchObject({ error: "TENANT_MEMBERSHIP_REQUIRED" });
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/rpc/"))).toBe(false);
});

test("CREATE_OFFER route requires explicit tenant selection for multiple memberships", async () => {
  const result = await postCreateOffer("USD", {}, undefined, [
    { tenant_id: "20000000-0000-4000-8000-000000000001" },
    { tenant_id: "20000000-0000-4000-8000-000000000002" },
  ]);

  expect(result.status).toBe(409);
  expect(result.body).toMatchObject({ error: "TENANT_SELECTION_REQUIRED" });
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/rpc/"))).toBe(false);
});
