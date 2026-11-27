import { expect, test, type APIRequestContext, type Page } from "@playwright/test";
const jsonHeaders = { "content-type": "application/json" };

test.describe.configure({ mode: "serial" });

const SECURITY_VERIFIER_COOKIE = "sb-127-auth-token-code-verifier";
const SECURITY_SESSION_COOKIE_PATTERN = /^sb-127-auth-token(?:[.][0-9]+)?=/i;

async function authenticateSecurityTestPage(page: Page, request: APIRequestContext) {
  const verifier = `base64-${Buffer.from(JSON.stringify("fresh-verifier"), "utf8").toString("base64url")}`;
  const response = await request.get("/auth/callback?code=qa251-valid-code&next=%2F", {
    maxRedirects: 0,
    headers: { cookie: `${SECURITY_VERIFIER_COOKIE}=${verifier}` },
  });

  expect(response.status()).toBe(307);
  const sessionCookies = (await response.headersArray())
    .filter(({ name }) => name.toLowerCase() === "set-cookie")
    .map(({ value }) => value)
    .filter(value => SECURITY_SESSION_COOKIE_PATTERN.test(value));
  expect(sessionCookies.length).toBeGreaterThan(0);

  for (const setCookie of sessionCookies) {
    const pair = setCookie.split(";", 1)[0];
    const separator = pair.indexOf("=");
    expect(separator).toBeGreaterThan(0);
    for (const domain of ["127.0.0.1", "localhost"]) {
      await page.context().addCookies([{
        name: pair.slice(0, separator),
        value: pair.slice(separator + 1),
        domain,
        path: "/",
        httpOnly: true,
        secure: false,
        sameSite: "Lax",
      }]);
    }
  }
}


test("product-request publish route rejects unauthenticated requests before membership lookup or action RPCs", async ({ request }) => {
  const configured = await request.post("http://127.0.0.1:54321/__test/membership-fixture", {
    data: { rows: [{ tenant_id: "10000000-0000-4000-8000-000000000001" }] },
  });
  expect(configured.status()).toBe(200);

  const response = await request.post("/api/product-requests/publish", {
    data: JSON.stringify({ requestId: "60000000-0000-4000-8000-000000000001" }),
    headers: jsonHeaders,
  });

  expect(response.status()).toBe(401);
  await expect(response.json()).resolves.toEqual({ error: "UNAUTHENTICATED" });

  const observed = await request.get("http://127.0.0.1:54321/__test/publish-route-requests");
  expect(observed.status()).toBe(200);
  await expect(observed.json()).resolves.toEqual({
    memberships: [],
    definitions: [],
    publications: [],
  });

  const resetFixture = await request.post("http://127.0.0.1:54321/__test/membership-fixture", {
    data: { rows: null },
  });
  expect(resetFixture.status()).toBe(200);
});

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


test("product-request publish route derives tenant membership only from the authenticated user", () => {
  const fs = process.getBuiltinModule("node:fs") as typeof import("node:fs") | undefined;
  if (!fs) throw new Error("Node.js fs module is unavailable");
  const source = fs.readFileSync(
    `${process.cwd()}/app/api/product-requests/publish/route.ts`,
    "utf8",
  );

  const membershipStart = source.indexOf('.from("dt_memberships")');
  const membershipEnd = source.indexOf("if (membershipError", membershipStart);
  expect(membershipStart).toBeGreaterThanOrEqual(0);
  expect(membershipEnd).toBeGreaterThan(membershipStart);

  const membershipQuery = source.slice(membershipStart, membershipEnd);
  expect(membershipQuery).toContain('.select("tenant_id")');
  expect(membershipQuery).toContain('.eq("user_id", authData.user.id)');
  expect(membershipQuery).not.toContain("body.");

  expect(source).not.toContain("body.tenantId");
  expect(source).not.toContain("body.tenant_id");

  const actionStart = source.indexOf("const result = await executeUniversalAction");
  expect(actionStart).toBeGreaterThan(membershipEnd);
  const actionContext = source.slice(actionStart, actionStart + 500);
  expect(actionContext).toContain("userId: authData.user.id");
  expect(actionContext).toContain("tenantId: tenantIds[0]");
});

test("product-request publish route fails closed when membership lookup fails or returns no rows", () => {
  const fs = process.getBuiltinModule("node:fs") as typeof import("node:fs") | undefined;
  if (!fs) throw new Error("Node.js fs module is unavailable");
  const source = fs.readFileSync(
    `${process.cwd()}/app/api/product-requests/publish/route.ts`,
    "utf8",
  );

  const membershipQueryStart = source.indexOf('.from("dt_memberships")');
  const membershipFailureGuard = source.indexOf("if (membershipError || !memberships?.length)");
  const tenantResolution = source.indexOf("const tenantIds =");
  const actionExecution = source.indexOf("const result = await executeUniversalAction");

  expect(membershipQueryStart).toBeGreaterThanOrEqual(0);
  expect(membershipFailureGuard).toBeGreaterThan(membershipQueryStart);
  expect(tenantResolution).toBeGreaterThan(membershipFailureGuard);
  expect(actionExecution).toBeGreaterThan(tenantResolution);

  const failureGuard = source.slice(membershipFailureGuard, tenantResolution);
  expect(failureGuard).toContain('error: "TENANT_MEMBERSHIP_REQUIRED"');
  expect(failureGuard).toContain("status: 403");
});


test("product-request publish route authenticates before reading tenant memberships or executing the action", () => {
  const fs = process.getBuiltinModule("node:fs") as typeof import("node:fs") | undefined;
  if (!fs) throw new Error("Node.js fs module is unavailable");
  const source = fs.readFileSync(
    `${process.cwd()}/app/api/product-requests/publish/route.ts`,
    "utf8",
  );

  const authenticationGuard = source.indexOf("if (authError || !authData.user)");
  const membershipQuery = source.indexOf('.from("dt_memberships")');
  const actionExecution = source.indexOf("const result = await executeUniversalAction");

  expect(authenticationGuard).toBeGreaterThanOrEqual(0);
  expect(membershipQuery).toBeGreaterThan(authenticationGuard);
  expect(actionExecution).toBeGreaterThan(membershipQuery);

  const guard = source.slice(authenticationGuard, membershipQuery);
  expect(guard).toContain('error: "UNAUTHENTICATED"');
  expect(guard).toContain("status: 401");
});


test("product-request publish route fails closed when an authenticated user's membership lookup fails", async ({ page, request }) => {
  const requestId = "60000000-0000-4000-8000-000000000001";
  await authenticateSecurityTestPage(page, request);
  await page.goto("/");

  const response = await page.evaluate(async (id) => {
    const result = await fetch("/api/product-requests/publish", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ requestId: id }),
    });
    return { status: result.status, body: await result.json() };
  }, requestId);

  // The isolated mock PostgREST fixture defaults to a synthetic 404 until a test configures rows.
  // This exercises the membership-query error path without contacting live Supabase.
  expect(response).toEqual({
    status: 403,
    body: { error: "TENANT_MEMBERSHIP_REQUIRED" },
  });
});



test("authenticated publish route deduplicates one tenant and rejects multiple tenant memberships before RPC execution", async ({ page, request }) => {
  const requestId = "60000000-0000-4000-8000-000000000001";
  const authenticatedUserId = "00000000-0000-4000-8000-00000000251";
  const firstTenantId = "10000000-0000-4000-8000-000000000001";
  const secondTenantId = "10000000-0000-4000-8000-000000000002";
  const demandId = "70000000-0000-4000-8000-000000000001";

  await authenticateSecurityTestPage(page, request);
  await page.goto("/");

  const configureMemberships = async (rows: Array<{ tenant_id: string | null }>) => {
    const configured = await request.post("http://127.0.0.1:54321/__test/membership-fixture", {
      data: { rows },
    });
    expect(configured.status()).toBe(200);
  };

  const inspectRequests = async () => {
    const response = await request.get("http://127.0.0.1:54321/__test/publish-route-requests");
    expect(response.status()).toBe(200);
    return response.json();
  };

  const publish = async (tenantId: string) => page.evaluate(async ({ id, suppliedTenantId }) => {
    const response = await fetch("/api/product-requests/publish", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        requestId: id,
        tenantId: suppliedTenantId,
        tenant_id: suppliedTenantId,
      }),
    });
    return { status: response.status, body: await response.json() };
  }, { id: requestId, suppliedTenantId: tenantId });

  // Duplicate rows for the same authenticated tenant collapse to one distinct tenant.
  await configureMemberships([{ tenant_id: firstTenantId }, { tenant_id: firstTenantId }]);
  const duplicateMembershipResponse = await publish(secondTenantId);
  expect(duplicateMembershipResponse.status).toBe(200);
  expect(duplicateMembershipResponse.body).toMatchObject({
    result: { status: "succeeded", objectId: demandId },
  });

  const duplicateMembershipRequests = await inspectRequests();
  expect(duplicateMembershipRequests.memberships).toEqual([{
    select: "tenant_id",
    userId: `eq.${authenticatedUserId}`,
  }]);
  expect(duplicateMembershipRequests.definitions).toEqual([{
    p_action_key: "PUBLISH_PRODUCT_REQUEST",
    p_version: 1,
  }]);
  expect(duplicateMembershipRequests.publications).toEqual([{
    p_request_id: requestId,
    p_user_id: authenticatedUserId,
  }]);

  // Two distinct memberships are ambiguous: no action-definition or publish RPC may run.
  await configureMemberships([{ tenant_id: firstTenantId }, { tenant_id: secondTenantId }]);
  const multipleMembershipResponse = await publish(firstTenantId);
  expect(multipleMembershipResponse).toEqual({
    status: 409,
    body: {
      error: "TENANT_SELECTION_REQUIRED",
      message: "Select an active tenant before publishing a product request.",
    },
  });

  const multipleMembershipRequests = await inspectRequests();
  expect(multipleMembershipRequests.memberships).toHaveLength(1);
  expect(multipleMembershipRequests.definitions).toHaveLength(0);
  expect(multipleMembershipRequests.publications).toHaveLength(0);

  // Rows without a usable tenant identifier also fail closed before action execution.
  await configureMemberships([{ tenant_id: null }]);
  const unresolvedMembershipResponse = await publish(firstTenantId);
  expect(unresolvedMembershipResponse).toEqual({
    status: 409,
    body: {
      error: "TENANT_SELECTION_REQUIRED",
      message: "Select an active tenant before publishing a product request.",
    },
  });

  const unresolvedMembershipRequests = await inspectRequests();
  expect(unresolvedMembershipRequests.memberships).toHaveLength(1);
  expect(unresolvedMembershipRequests.definitions).toHaveLength(0);
  expect(unresolvedMembershipRequests.publications).toHaveLength(0);

  // A null row must not poison one otherwise unambiguous authenticated tenant.
  await configureMemberships([{ tenant_id: firstTenantId }, { tenant_id: null }]);
  const mixedMembershipResponse = await publish(secondTenantId);
  expect(mixedMembershipResponse.status).toBe(200);
  expect(mixedMembershipResponse.body).toMatchObject({
    result: { status: "succeeded", objectId: demandId },
  });

  const mixedMembershipRequests = await inspectRequests();
  expect(mixedMembershipRequests.memberships).toEqual([{
    select: "tenant_id",
    userId: `eq.${authenticatedUserId}`,
  }]);
  expect(mixedMembershipRequests.definitions).toEqual([{
    p_action_key: "PUBLISH_PRODUCT_REQUEST",
    p_version: 1,
  }]);
  expect(mixedMembershipRequests.publications).toEqual([{
    p_request_id: requestId,
    p_user_id: authenticatedUserId,
  }]);
});
