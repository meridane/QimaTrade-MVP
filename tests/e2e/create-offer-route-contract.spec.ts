import { expect, test } from "@playwright/test";
import { POST } from "../../app/api/actions/create-offer/route";

type MockRequest = { path: string; body?: Record<string, unknown> };

test.describe.configure({ mode: "serial" });

async function postCreateOffer(currency: string) {
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
      return Response.json([{ tenant_id: "20000000-0000-4000-8000-000000000001" }]);
    }
    if (url.pathname === "/rest/v1/rpc/get_action_definition_v1") {
      return Response.json({ action_key: "CREATE_OFFER", version: 1, status: "published" });
    }
    if (url.pathname === "/rest/v1/rpc/execute_create_offer_v1") {
      return Response.json({
        executionId: "10000000-0000-4000-8000-000000000001",
        status: "succeeded",
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
          authorization: "Bearer qima-route-test-token",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          name: "Currency contract fixture",
          demandId,
          productMasterId: "60000000-0000-4000-8000-000000000001",
          quantity: 1,
          price: 10,
          currency,
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

test('CREATE_OFFER route trims whitespace around a supported currency before the RPC', async () => {
  const result = await postCreateOffer(" USD ");

  expect(result.status, JSON.stringify({ body: result.body, requests: result.requests })).toBe(200);
  expect(result.body).toMatchObject({ status: "succeeded" });
  const executionCall = result.requests.find(
    (request) => request.path === "/rest/v1/rpc/execute_create_offer_v1",
  );
  expect(executionCall?.body).toMatchObject({ p_currency: "USD" });
});

test("CREATE_OFFER route rejects lowercase currency without calling database RPCs", async () => {
  const result = await postCreateOffer("usd");

  expect(result.status).toBe(400);
  expect(result.body).toMatchObject({ error: "INVALID_CURRENCY" });
  expect(result.requests.some((request) => request.path.startsWith("/rest/v1/"))).toBe(false);
});
