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
