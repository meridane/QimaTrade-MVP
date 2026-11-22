import { expect, test } from "@playwright/test";
import { createServer } from "node:http";
import { executeUniversalAction } from "../../lib/actions/runtime";
import type { ActionContext, ActionResult } from "../../lib/actions/types";

type RedirectStatus = 301 | 302 | 303 | 307 | 308 | null;
type RedirectTarget = "definition" | "publish";

type CapturedRequest = {
  path: string;
  method: string;
  authorization: string | undefined;
  apikey: string | undefined;
  contentType: string | undefined;
  body: unknown;
};

test.describe.configure({ mode: "serial" });

async function executePublishProductRequestRuntime(
  redirectStatus: RedirectStatus,
  redirectTarget: RedirectTarget = "publish",
) {
  const requestId = "60000000-0000-4000-8000-000000000001";
  const userId = "40000000-0000-4000-8000-000000000001";
  const demandId = "70000000-0000-4000-8000-000000000001";
  const correlationId = "80000000-0000-4000-8000-000000000001";
  const accessToken = "qima-publish-runtime-test-token";
  const requests: CapturedRequest[] = [];
  let redirectTargetHits = 0;

  const server = createServer((request, response) => {
    const path = new URL(request.url ?? "/", "http://127.0.0.1").pathname;
    const chunks: Buffer[] = [];

    request.on("data", (chunk: Buffer | string) => {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    });

    request.on("end", () => {
      const rawBody = Buffer.concat(chunks).toString("utf8");
      let body: unknown = null;
      if (rawBody) {
        try {
          body = JSON.parse(rawBody);
        } catch {
          body = rawBody;
        }
      }

      requests.push({
        path,
        method: request.method ?? "GET",
        authorization: request.headers.authorization,
        apikey: typeof request.headers.apikey === "string" ? request.headers.apikey : undefined,
        contentType: typeof request.headers["content-type"] === "string" ? request.headers["content-type"] : undefined,
        body,
      });

      if (
        path === "/rest/v1/rpc/get_action_definition_v1" &&
        redirectStatus !== null &&
        redirectTarget === "definition"
      ) {
        response.writeHead(redirectStatus, {
          Location: "/redirect-target",
          "Content-Type": "application/json",
        });
        response.end(JSON.stringify({ message: "PUBLISH_PRODUCT_REQUEST definition redirect fixture" }));
        return;
      }

      if (path === "/rest/v1/rpc/get_action_definition_v1") {
        response.writeHead(200, { "Content-Type": "application/json" });
        response.end(JSON.stringify([{
          action_key: "PUBLISH_PRODUCT_REQUEST",
          version: 1,
          status: "published",
        }]));
        return;
      }

      if (
        path === "/rest/v1/rpc/dt_publish_product_request" &&
        redirectStatus !== null &&
        redirectTarget === "publish"
      ) {
        response.writeHead(redirectStatus, {
          Location: "/redirect-target",
          "Content-Type": "application/json",
        });
        response.end(JSON.stringify({ message: "PUBLISH_PRODUCT_REQUEST redirect fixture" }));
        return;
      }

      if (path === "/rest/v1/rpc/dt_publish_product_request") {
        response.writeHead(200, { "Content-Type": "application/json" });
        response.end(JSON.stringify({ demandId }));
        return;
      }

      if (path === "/redirect-target") {
        redirectTargetHits += 1;
        response.writeHead(200, { "Content-Type": "application/json" });
        if (redirectTarget === "definition") {
          response.end(JSON.stringify([{
            action_key: "PUBLISH_PRODUCT_REQUEST",
            version: 1,
            status: "published",
          }]));
        } else {
          response.end(JSON.stringify({ demandId }));
        }
        return;
      }

      response.writeHead(404, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ message: "Unexpected local runtime request" }));
    });
  });

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });

  const address = server.address();
  if (!address || typeof address === "string") {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    throw new Error("Could not resolve the local PUBLISH_PRODUCT_REQUEST fixture address");
  }

  const originalSupabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const originalAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const originalWebSocket = globalThis.WebSocket;

  if (typeof globalThis.WebSocket === "undefined") {
    globalThis.WebSocket = class MockWebSocket {} as unknown as typeof WebSocket;
  }
  process.env.NEXT_PUBLIC_SUPABASE_URL = "http://127.0.0.1:" + address.port;
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "ci-placeholder-anon-key";

  const context: ActionContext = {
    userId,
    tenantId: "20000000-0000-4000-8000-000000000001",
    actionKey: "PUBLISH_PRODUCT_REQUEST",
    actionVersion: 1,
    objectType: "ProductRequest",
    objectId: requestId,
    correlationId,
    idempotencyKey: "90000000-0000-4000-8000-000000000001",
  };

  try {
    let result: ActionResult | null = null;
    let errorMessage: string | null = null;
    try {
      result = await executeUniversalAction(context, { requestId }, accessToken);
    } catch (error) {
      errorMessage = error instanceof Error ? error.message : String(error);
    }

    return { result, errorMessage, requests, redirectTargetHits, requestId, userId, demandId, correlationId, accessToken };
  } finally {
    if (originalSupabaseUrl === undefined) delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    else process.env.NEXT_PUBLIC_SUPABASE_URL = originalSupabaseUrl;

    if (originalAnonKey === undefined) delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    else process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = originalAnonKey;

    globalThis.WebSocket = originalWebSocket;
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

test("PUBLISH_PRODUCT_REQUEST runtime does not follow action-definition RPC redirects", async () => {
  for (const status of [301, 302, 303, 307, 308] as const) {
    const outcome = await executePublishProductRequestRuntime(status, "definition");

    expect(outcome.errorMessage, "HTTP " + status).toBe("ACTION_DEFINITION_LOOKUP_FAILED");
    expect(outcome.requests.map((request) => ({ path: request.path, method: request.method })), "HTTP " + status).toEqual([
      { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    ]);
    expect(outcome.requests.every(
      ({ authorization, apikey, contentType }) =>
        authorization === "Bearer " + outcome.accessToken &&
        apikey === "ci-placeholder-anon-key" &&
        typeof contentType === "string" && contentType.toLowerCase().includes("application/json"),
    ), "HTTP " + status).toBe(true);
    expect(outcome.redirectTargetHits, "HTTP " + status).toBe(0);
  }
});

test("PUBLISH_PRODUCT_REQUEST runtime does not follow real Supabase RPC redirects", async () => {
  for (const status of [301, 302, 303, 307, 308] as const) {
    const outcome = await executePublishProductRequestRuntime(status);

    expect(outcome.errorMessage, "HTTP " + status).toBeTruthy();
    expect(outcome.requests.map((request) => ({ path: request.path, method: request.method })), "HTTP " + status).toEqual([
      { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
      { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
    ]);
    expect(outcome.requests.every(
      ({ authorization, apikey, contentType }) =>
        authorization === "Bearer " + outcome.accessToken &&
        apikey === "ci-placeholder-anon-key" &&
        typeof contentType === "string" && contentType.toLowerCase().includes("application/json"),
    ), "HTTP " + status).toBe(true);
    expect(outcome.redirectTargetHits, "HTTP " + status).toBe(0);
    expect(outcome.requests[0].body).toEqual({
      p_action_key: "PUBLISH_PRODUCT_REQUEST",
      p_version: 1,
    });
    expect(outcome.requests[1].body).toEqual({
      p_request_id: outcome.requestId,
      p_user_id: outcome.userId,
    });
  }
});

test("PUBLISH_PRODUCT_REQUEST runtime preserves successful execution without a redirect", async () => {
  const outcome = await executePublishProductRequestRuntime(null);

  expect(outcome.errorMessage).toBeNull();
  expect(outcome.result).toEqual({
    executionId: outcome.correlationId,
    status: "succeeded",
    objectId: outcome.demandId,
    result: {
      requestId: outcome.requestId,
      demandId: outcome.demandId,
      source: "dt_publish_product_request",
    },
  });
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
  ]);
  expect(outcome.requests.every(
    ({ authorization, apikey, contentType }) =>
      authorization === "Bearer " + outcome.accessToken &&
      apikey === "ci-placeholder-anon-key" &&
      typeof contentType === "string" && contentType.toLowerCase().includes("application/json"),
  )).toBe(true);
  expect(outcome.redirectTargetHits).toBe(0);
  expect(outcome.requests[0].body).toEqual({
    p_action_key: "PUBLISH_PRODUCT_REQUEST",
    p_version: 1,
  });
  expect(outcome.requests[1].body).toEqual({
    p_request_id: outcome.requestId,
    p_user_id: outcome.userId,
  });
});
