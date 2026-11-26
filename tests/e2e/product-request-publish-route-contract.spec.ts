import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";

const publishRouteSource = readFileSync(
  new URL("../../app/api/product-requests/publish/route.ts", import.meta.url),
  "utf8",
);

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
  expect(publishRouteSource).toContain("publicPublishErrorCodes.has(message)");
  expect(publishRouteSource).toContain('error: "Unable to publish product request."');
  expect(publishRouteSource).not.toContain("error: message");
  expect(publishRouteSource).not.toContain("message.includes(code)");
});
