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
  publishRpcStatus = 200,
  publishRpcPayload: unknown = undefined,
  transportFailureTarget: RedirectTarget | null = null,
  truncatedResponseTarget: RedirectTarget | null = null,
  malformedJsonResponseTarget: RedirectTarget | null = null,
  definitionRpcStatus = 200,
  definitionRpcPayload: unknown = [{
    action_key: "PUBLISH_PRODUCT_REQUEST",
    version: 1,
    status: "published",
  }],
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
        (path === "/rest/v1/rpc/get_action_definition_v1" && malformedJsonResponseTarget === "definition") ||
        (path === "/rest/v1/rpc/dt_publish_product_request" && malformedJsonResponseTarget === "publish")
      ) {
        response.writeHead(200, { "Content-Type": "application/json" });
        response.end("{");
        return;
      }

      if (
        (path === "/rest/v1/rpc/get_action_definition_v1" && truncatedResponseTarget === "definition") ||
        (path === "/rest/v1/rpc/dt_publish_product_request" && truncatedResponseTarget === "publish")
      ) {
        const partialBody =
          path === "/rest/v1/rpc/get_action_definition_v1"
            ? '[{"action_key":"PUBLISH_PRODUCT_REQUEST"'
            : '{"demandId":"70000000-0000-4000-8000-000000000001"}';
        response.writeHead(200, {
          "Content-Type": "application/json",
          "Content-Length": String(Buffer.byteLength(partialBody) + 64),
        });
        response.end(partialBody);
        return;
      }

      if (
        (path === "/rest/v1/rpc/get_action_definition_v1" && transportFailureTarget === "definition") ||
        (path === "/rest/v1/rpc/dt_publish_product_request" && transportFailureTarget === "publish")
      ) {
        response.destroy();
        return;
      }

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

      if (path === "/rest/v1/rpc/get_action_definition_v1" && definitionRpcStatus !== 200) {
        const rateLimited = definitionRpcStatus === 429;
        const unauthorized = definitionRpcStatus === 401;
        const forbidden = definitionRpcStatus === 403;
        response.writeHead(definitionRpcStatus, {
          "Content-Type": "application/json",
          ...(rateLimited ? { "Retry-After": "0" } : {}),
        });
        response.end(JSON.stringify({
          message: rateLimited
            ? "SYNTHETIC_DEFINITION_RATE_LIMIT_DETAIL"
            : unauthorized
              ? "Invalid JWT"
              : forbidden
                ? "permission denied"
                : "SYNTHETIC_DEFINITION_LOOKUP_DETAIL",
          code: rateLimited ? "PGRST429" : unauthorized ? "PGRST301" : forbidden ? "42501" : "PGRST_QIMA_DEFINITION",
          details: "internal definition diagnostic",
          hint: "private rate-limit hint",
        }));
        return;
      }

      if (path === "/rest/v1/rpc/get_action_definition_v1") {
        response.writeHead(200, { "Content-Type": "application/json" });
        response.end(JSON.stringify(definitionRpcPayload));
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

      if (path === "/rest/v1/rpc/dt_publish_product_request" && publishRpcStatus === 204) {
        response.writeHead(204);
        response.end();
        return;
      }

      if (path === "/rest/v1/rpc/dt_publish_product_request" && publishRpcStatus !== 200) {
        const rateLimited = publishRpcStatus === 429;
        response.writeHead(publishRpcStatus, {
          "Content-Type": "application/json",
          ...(rateLimited ? { "Retry-After": "0" } : {}),
        });
        const unavailable = publishRpcStatus >= 500;
        response.end(JSON.stringify({
          message: rateLimited
            ? "UPSTREAM_RATE_LIMITED"
            : unavailable
              ? "UPSTREAM_TEMPORARILY_UNAVAILABLE"
              : "PRODUCT_REQUEST_NOT_FOUND",
          code: rateLimited ? "PGRST429" : unavailable ? "PGRST000" : "P0001",
          details: "internal database row diagnostic",
          hint: "private troubleshooting hint",
        }));
        return;
      }

      if (path === "/rest/v1/rpc/dt_publish_product_request") {
        response.writeHead(200, { "Content-Type": "application/json" });
        response.end(JSON.stringify(publishRpcPayload === undefined ? { demandId } : publishRpcPayload));
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

test("PUBLISH_PRODUCT_REQUEST runtime propagates one exact SQL domain error without retrying", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 400);

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBe("PRODUCT_REQUEST_NOT_FOUND");
  expect(outcome.errorMessage).not.toContain("internal database row diagnostic");
  expect(outcome.errorMessage).not.toContain("private troubleshooting hint");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
  ]);
  expect(outcome.requests[1].body).toEqual({
    p_request_id: outcome.requestId,
    p_user_id: outcome.userId,
  });
  expect(outcome.redirectTargetHits).toBe(0);
});


test("PUBLISH_PRODUCT_REQUEST runtime does not retry upstream 5xx failures or follow redirect targets", async () => {
  for (const status of [500, 502, 503, 504] as const) {
    const outcome = await executePublishProductRequestRuntime(null, "publish", status);

    expect(outcome.result, "HTTP " + status).toBeNull();
    expect(outcome.errorMessage, "HTTP " + status).toBe("UPSTREAM_TEMPORARILY_UNAVAILABLE");
    expect(outcome.errorMessage, "HTTP " + status).not.toContain("internal database row diagnostic");
    expect(outcome.errorMessage, "HTTP " + status).not.toContain("private troubleshooting hint");
    expect(outcome.requests.map((request) => ({ path: request.path, method: request.method })), "HTTP " + status).toEqual([
      { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
      { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
    ]);
    expect(outcome.requests[1].body, "HTTP " + status).toEqual({
      p_request_id: outcome.requestId,
      p_user_id: outcome.userId,
    });
    expect(outcome.redirectTargetHits, "HTTP " + status).toBe(0);
  }
});

test("PUBLISH_PRODUCT_REQUEST runtime normalizes action-definition transport failures without publishing", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 200, undefined, "definition");

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBe("ACTION_DEFINITION_LOOKUP_FAILED");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
  ]);
  expect(outcome.redirectTargetHits).toBe(0);
});

test("PUBLISH_PRODUCT_REQUEST runtime rejects a truncated action-definition response without publishing", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 200, undefined, null, "definition");

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBe("ACTION_DEFINITION_LOOKUP_FAILED");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
  ]);
  expect(outcome.redirectTargetHits).toBe(0);
});

test("PUBLISH_PRODUCT_REQUEST runtime does not retry a publish transport failure", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 200, undefined, "publish");

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBeTruthy();
  expect(outcome.errorMessage).not.toContain("internal database row diagnostic");
  expect(outcome.errorMessage).not.toContain("private troubleshooting hint");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
  ]);
  expect(outcome.redirectTargetHits).toBe(0);
});

test("PUBLISH_PRODUCT_REQUEST runtime rejects malformed successful RPC payloads instead of reporting success", async () => {
  for (const payload of [
    null,
    [],
    {},
    { demandId: "   " },
    { demandId: 42 },
    { demand_id: 42 },
    { demandId: "not-a-uuid" },
    { demand_id: "70000000-0000-4000-8000-00000000000g" },
    {
      demandId: "70000000-0000-4000-8000-000000000001",
      demand_id: "70000000-0000-4000-8000-000000000002",
    },
  ]) {
    const outcome = await executePublishProductRequestRuntime(null, "publish", 200, payload);

    expect(outcome.result).toBeNull();
    expect(outcome.errorMessage).toBe("PUBLISH_RESULT_INVALID");
    expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
      { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
      { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
    ]);
    expect(outcome.redirectTargetHits).toBe(0);
  }
});

test("PUBLISH_PRODUCT_REQUEST runtime preserves the legacy snake_case demand ID response", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 200, {
    demand_id: "70000000-0000-4000-8000-000000000001",
  });

  expect(outcome.errorMessage).toBeNull();
  expect(outcome.result?.status).toBe("succeeded");
  expect(outcome.result?.objectId).toBe(outcome.demandId);
});

test("PUBLISH_PRODUCT_REQUEST runtime accepts matching camelCase and snake_case demand IDs regardless of UUID hex casing", async () => {
  const demandId = "abcdefab-cdef-4abc-8def-abcdefabcdef";
  const upperDemandId = demandId.toUpperCase();
  expect(upperDemandId).not.toBe(demandId);

  const outcome = await executePublishProductRequestRuntime(null, "publish", 200, {
    demandId,
    demand_id: upperDemandId,
  });

  expect(outcome.errorMessage).toBeNull();
  expect(outcome.result?.status).toBe("succeeded");
  expect(outcome.result?.objectId).toBe(demandId);
  expect(outcome.result?.result).toEqual({
    requestId: outcome.requestId,
    demandId,
    source: "dt_publish_product_request",
  });
});

test("PUBLISH_PRODUCT_REQUEST runtime rejects an empty HTTP 204 response instead of reporting success", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 204);

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBe("PUBLISH_RESULT_INVALID");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
  ]);
  expect(outcome.requests[1].body).toEqual({
    p_request_id: outcome.requestId,
    p_user_id: outcome.userId,
  });
  expect(outcome.redirectTargetHits).toBe(0);
});


test("PUBLISH_PRODUCT_REQUEST runtime rejects a truncated publish RPC response without retrying", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 200, undefined, null, "publish");

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBeTruthy();
  expect(outcome.errorMessage).not.toContain("internal database row diagnostic");
  expect(outcome.errorMessage).not.toContain("private troubleshooting hint");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
  ]);
  expect(outcome.redirectTargetHits).toBe(0);
});


test("PUBLISH_PRODUCT_REQUEST runtime rejects malformed successful publish JSON without retrying", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 200, undefined, null, null, "publish");

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBeTruthy();
  expect(outcome.errorMessage).not.toContain("internal database row diagnostic");
  expect(outcome.errorMessage).not.toContain("private troubleshooting hint");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
  ]);
  expect(outcome.requests[1].body).toEqual({
    p_request_id: outcome.requestId,
    p_user_id: outcome.userId,
  });
  expect(outcome.redirectTargetHits).toBe(0);
});


test("PUBLISH_PRODUCT_REQUEST runtime normalizes malformed action-definition JSON without publishing", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 200, undefined, null, null, "definition");

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBe("ACTION_DEFINITION_LOOKUP_FAILED");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
  ]);
  expect(outcome.redirectTargetHits).toBe(0);
});


test("PUBLISH_PRODUCT_REQUEST runtime normalizes action-definition HTTP 429 without retrying or publishing", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "definition", 200, undefined, null, null, null, 429);

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBe("ACTION_DEFINITION_LOOKUP_FAILED");
  expect(outcome.errorMessage).not.toContain("SYNTHETIC_DEFINITION_RATE_LIMIT_DETAIL");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
  ]);
  expect(outcome.redirectTargetHits).toBe(0);
});

for (const [status, label] of [[401, "unauthenticated"], [403, "forbidden"]] as const) {
  test(`PUBLISH_PRODUCT_REQUEST runtime normalizes ${label} action-definition responses without publishing`, async () => {
    const outcome = await executePublishProductRequestRuntime(null, "definition", 200, undefined, null, null, null, status);

    expect(outcome.result).toBeNull();
    expect(outcome.errorMessage).toBe("ACTION_DEFINITION_LOOKUP_FAILED");
    expect(outcome.errorMessage).not.toContain("Invalid JWT");
    expect(outcome.errorMessage).not.toContain("permission denied");
    expect(outcome.errorMessage).not.toContain("internal definition diagnostic");
    expect(outcome.errorMessage).not.toContain("private rate-limit hint");
    expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
      { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    ]);
    expect(outcome.redirectTargetHits).toBe(0);
  });
}


test("PUBLISH_PRODUCT_REQUEST runtime does not retry a publish RPC HTTP 429 or expose diagnostics", async () => {
  const outcome = await executePublishProductRequestRuntime(null, "publish", 429);

  expect(outcome.result).toBeNull();
  expect(outcome.errorMessage).toBe("UPSTREAM_RATE_LIMITED");
  expect(outcome.errorMessage).not.toContain("internal database row diagnostic");
  expect(outcome.errorMessage).not.toContain("private troubleshooting hint");
  expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
    { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    { path: "/rest/v1/rpc/dt_publish_product_request", method: "POST" },
  ]);
  expect(outcome.redirectTargetHits).toBe(0);
});



for (const [label, definition] of [
  ["wrong action key", [{ action_key: "CREATE_OFFER", version: 1, status: "published" }]],
  ["wrong version", [{ action_key: "PUBLISH_PRODUCT_REQUEST", version: 2, status: "published" }]],
  ["draft status", [{ action_key: "PUBLISH_PRODUCT_REQUEST", version: 1, status: "draft" }]],
  ["retired status", [{ action_key: "PUBLISH_PRODUCT_REQUEST", version: 1, status: "retired" }]],
] as const) {
  test(`PUBLISH_PRODUCT_REQUEST runtime rejects a published definition with ${label} before publishing`, async () => {
    const outcome = await executePublishProductRequestRuntime(
      null,
      "publish",
      200,
      undefined,
      null,
      null,
      null,
      200,
      definition,
    );

    expect(outcome.result).toBeNull();
    expect(outcome.errorMessage).toBe("ACTION_NOT_PUBLISHED");
    expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
      { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    ]);
    expect(outcome.requests[0].body).toEqual({
      p_action_key: "PUBLISH_PRODUCT_REQUEST",
      p_version: 1,
    });
    expect(outcome.redirectTargetHits).toBe(0);
  });
}


for (const [label, definition] of [
  ["empty definition result set", []],
  ["null definition result", null],
] as const) {
  test("PUBLISH_PRODUCT_REQUEST runtime rejects a missing action definition from " + label + " without publishing", async () => {
    const outcome = await executePublishProductRequestRuntime(
      null,
      "publish",
      200,
      undefined,
      null,
      null,
      null,
      200,
      definition,
    );

    expect(outcome.result).toBeNull();
    expect(outcome.errorMessage).toBe("ACTION_NOT_PUBLISHED");
    expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
      { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    ]);
    expect(outcome.requests[0].body).toEqual({
      p_action_key: "PUBLISH_PRODUCT_REQUEST",
      p_version: 1,
    });
    expect(outcome.redirectTargetHits).toBe(0);
  });
}

for (const status of [500, 502, 503, 504] as const) {
  test(`PUBLISH_PRODUCT_REQUEST runtime normalizes action-definition HTTP ${status} without retrying or publishing`, async () => {
    const outcome = await executePublishProductRequestRuntime(null, "definition", 200, undefined, null, null, null, status);

    expect(outcome.result).toBeNull();
    expect(outcome.errorMessage).toBe("ACTION_DEFINITION_LOOKUP_FAILED");
    expect(outcome.errorMessage).not.toContain("SYNTHETIC_DEFINITION_LOOKUP_DETAIL");
    expect(outcome.errorMessage).not.toContain("internal definition diagnostic");
    expect(outcome.errorMessage).not.toContain("private rate-limit hint");
    expect(outcome.requests.map((request) => ({ path: request.path, method: request.method }))).toEqual([
      { path: "/rest/v1/rpc/get_action_definition_v1", method: "POST" },
    ]);
    expect(outcome.redirectTargetHits).toBe(0);
  });
}
