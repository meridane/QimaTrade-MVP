import { expect, test } from "@playwright/test";
const jsonHeaders = { "content-type": "application/json" };

test("product-request publish route returns a stable 400 for malformed JSON", async ({ request }) => {
  const response = await request.post("/api/product-requests/publish", {
    data: "{",
    headers: jsonHeaders,
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toEqual({ error: "INVALID_REQUEST_BODY" });
});

for (const [label, body] of [
  ["null", "null"],
  ["array", "[]"],
  ["string", JSON.stringify("request-id")],
  ["number", "42"],
  ["boolean", "false"],
] as const) {
  test(`product-request publish route rejects a JSON ${label} before authentication`, async ({ request }) => {
    const response = await request.post("/api/product-requests/publish", {
      data: body,
      headers: jsonHeaders,
    });

    expect(response.status()).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: "INVALID_REQUEST_BODY" });
  });
}

test("product-request publish route rejects a non-string request ID before authentication", async ({ request }) => {
  const response = await request.post("/api/product-requests/publish", {
    data: JSON.stringify({ requestId: 123 }),
    headers: jsonHeaders,
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toEqual({ error: "requestId is required" });
});

for (const [label, requestId] of [
  ["non-UUID text", "not-a-uuid"],
  ["non-hex UUID", "00000000-0000-0000-0000-00000000000g"],
] as const) {
  test(`product-request publish route rejects a malformed UUID (${label}) before authentication`, async ({ request }) => {
    const response = await request.post("/api/product-requests/publish", {
      data: JSON.stringify({ requestId }),
      headers: jsonHeaders,
    });

    expect(response.status()).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: "INVALID_REQUEST_ID" });
  });
}

test("product-request publish route never returns raw exception messages", () => {
  const fs = process.getBuiltinModule("node:fs") as typeof import("node:fs") | undefined;
  if (!fs) throw new Error("Node.js fs module is unavailable");
  const publishRouteSource = fs.readFileSync(
    `${process.cwd()}/app/api/product-requests/publish/route.ts`,
    "utf8",
  );

  expect(publishRouteSource).toContain("publicPublishErrorCodes.has(message)");
  expect(publishRouteSource).toContain('error: "Unable to publish product request."');
  expect(publishRouteSource).not.toContain("error: message");
  expect(publishRouteSource).not.toContain("message.includes(code)");
});

test("product-request publish route keeps multi-tenant selection fail-closed before action execution", () => {
  const fs = process.getBuiltinModule("node:fs") as typeof import("node:fs") | undefined;
  if (!fs) throw new Error("Node.js fs module is unavailable");
  const source = fs.readFileSync(
    `${process.cwd()}/app/api/product-requests/publish/route.ts`,
    "utf8",
  );

  const tenantGuardIndex = source.indexOf("if (tenantIds.length !== 1)");
  const actionExecutionIndex = source.indexOf("const result = await executeUniversalAction");

  expect(source).toContain(
    "const tenantIds = [...new Set(memberships.map((membership) => membership.tenant_id).filter(Boolean))]",
  );
  expect(tenantGuardIndex).toBeGreaterThanOrEqual(0);
  expect(actionExecutionIndex).toBeGreaterThan(tenantGuardIndex);

  const tenantGuard = source.slice(tenantGuardIndex, actionExecutionIndex);
  expect(tenantGuard).toContain('error: "TENANT_SELECTION_REQUIRED"');
  expect(tenantGuard).toContain("status: 409");
  expect(tenantGuard).toContain("Select an active tenant before publishing a product request.");
});
