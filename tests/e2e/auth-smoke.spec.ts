import { expect, test } from "@playwright/test";
import { config as middlewareConfig } from "../../middleware";

test("login page displays Google authentication", async ({ page }) => {
  await page.goto("/login");

  await expect(page.getByRole("heading", { name: "Sign in to continue" })).toBeVisible();
  await expect(page.getByRole("button", { name: /continue with google/i })).toBeVisible();
});

test("login page explains a failed OAuth callback", async ({ page }) => {
  await page.goto("/login?error=oauth_callback_failed");

  await expect(
    page.getByText("We could not complete your Google sign-in. Please try again.", { exact: true }),
  ).toBeVisible();
});

test("OAuth callback without a code returns to login with a clear error", async ({ page }) => {
  await page.goto("/auth/callback");

  await expect(page).toHaveURL(/\/login\?error=oauth_callback_missing_code/);
  await expect(
    page.getByText("Google sign-in did not return a valid authorization code. Please try again.", { exact: true }),
  ).toBeVisible();
});

test("offers API rejects an empty offer before accessing the database", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: {},
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Please provide a valid offer name and quantity.",
  });
});

test("product requests API requires the mandatory fields", async ({ request }) => {
  const response = await request.post("/api/product-requests", {
    data: {},
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "title, productMasterId and decisionSessionId are required",
  });
});

test("publishing a product request requires a request ID", async ({ request }) => {
  const response = await request.post("/api/product-requests/publish", {
    data: {},
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "requestId is required",
  });
});

test.describe("protected routes require authentication", () => {
  for (const protectedPath of ["/demands", "/decision-tree", "/offers", "/request"]) {
    test(`${protectedPath} redirects unauthenticated visitors to login`, async ({ page }) => {
      await page.goto(protectedPath);

      await expect(page).toHaveURL(/\/login\?/);
      const currentUrl = new URL(page.url());
      expect(currentUrl.searchParams.get("next")).toBe(protectedPath);
    });
  }
});

test("offers API rejects a zero quantity before authentication", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: { name: "Test offer", quantity: "0" },
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Please provide a valid offer name and quantity.",
  });
});

test("offers API rejects a negative price before authentication", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: { name: "Test offer", quantity: "1", price: "-1" },
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Price must be a valid positive number.",
  });
});

test("offers API rejects an unsupported currency before authentication", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: { name: "Test offer", quantity: "1", price: "10", currency: "XYZ" },
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Please select a valid currency.",
  });
});

test("offers API rejects a non-numeric quantity before authentication", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: { name: "Test offer", quantity: "not-a-number" },
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Please provide a valid offer name and quantity.",
  });
});

test("offers API rejects a non-numeric price before authentication", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: { name: "Test offer", quantity: "1", price: "not-a-number" },
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Price must be a valid positive number.",
  });
});

test("offers API rejects an infinite quantity before authentication", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: { name: "Test offer", quantity: "Infinity" },
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Please provide a valid offer name and quantity.",
  });
});

test("offers API rejects an infinite price before authentication", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: { name: "Test offer", quantity: "1", price: "Infinity" },
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Price must be a valid positive number.",
  });
});

test("offers API rejects NaN quantity before authentication", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: { name: "Test offer", quantity: "NaN" },
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Please provide a valid offer name and quantity.",
  });
});

test("offers API rejects NaN price before authentication", async ({ request }) => {
  const response = await request.post("/api/offers", {
    multipart: { name: "Test offer", quantity: "1", price: "NaN" },
  });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toMatchObject({
    error: "Price must be a valid positive number.",
  });
});


test("CREATE_OFFER action API rejects requests without a bearer token", async ({ request }) => {
  const response = await request.post("/api/actions/create-offer", {
    data: {
      name: "Unauthenticated fixture offer",
      demandId: "50000000-0000-4000-8000-000000000001",
      quantity: 1,
      price: 10,
      currency: "USD",
    },
  });

  expect(response.status()).toBe(401);
  await expect(response.json()).resolves.toMatchObject({
    error: "UNAUTHENTICATED",
  });
});


test("Supabase SSR middleware explicitly uses the Node.js runtime", () => {
  expect(middlewareConfig.runtime).toBe("nodejs");
  expect(middlewareConfig.matcher).toEqual([
    "/demands/:path*",
    "/decision-tree/:path*",
    "/offers/:path*",
    "/request/:path*",
  ]);
});


test("protected route redirects preserve the original query string", async ({ page }) => {
  const requestedPath = "/demands?search=steel&sort=recent";
  await page.goto(requestedPath);

  await expect(page).toHaveURL(/login/);
  const loginUrl = new URL(page.url());
  expect(loginUrl.searchParams.get("next")).toBe(requestedPath);
});


test("protected route redirects preserve duplicate, empty, and encoded query values", async ({ page }) => {
  const requestedPath =
    "/demands?tag=steel&tag=aluminum&empty=&q=stainless%20steel%26pipe%3D1&unicode=%E9%9B%AA";
  await page.goto(requestedPath);

  await expect(page).toHaveURL(/login/);
  const loginUrl = new URL(page.url());
  const next = loginUrl.searchParams.get("next");

  expect(next).not.toBeNull();

  // URLSearchParams may serialize an equivalent space as "+" instead of "%20".
  // Compare the decoded query semantics rather than requiring byte-identical encoding.
  const restoredUrl = new URL(next!, "http://localhost");
  expect(restoredUrl.pathname).toBe("/demands");
  expect(restoredUrl.searchParams.getAll("tag")).toEqual(["steel", "aluminum"]);
  expect(restoredUrl.searchParams.get("empty")).toBe("");
  expect(restoredUrl.searchParams.get("q")).toBe("stainless steel&pipe=1");
  expect(restoredUrl.searchParams.get("unicode")).toBe("雪");
});

const QA251_VERIFIER_COOKIE = "sb-127-auth-token-code-verifier";
const QA252_EXPECTED_APP_ORIGIN = "http://localhost:3000";

// Supabase SSR's default base64url cookie encoding wraps the JSON storage value.
function encodeQa251VerifierCookie(value: string) {
  return `base64-${Buffer.from(JSON.stringify(value), "utf8").toString("base64url")}`;
}

async function getSetCookieHeaders(response: import("@playwright/test").APIResponse) {
  return (await response.headersArray())
    .filter(({ name }) => name.toLowerCase() === "set-cookie")
    .map(({ value }) => value);
}

test("real Next.js OAuth callback expires a stale PKCE verifier after invalid_grant", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await request.get(
    "/auth/callback?code=qa251-invalid-code&next=%2Foffers",
    {
      maxRedirects: 0,
      headers: {
        cookie: `${QA251_VERIFIER_COOKIE}=${encodeQa251VerifierCookie("stale-verifier")}; unrelated=keep`,
      },
    },
  );

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!, "http://127.0.0.1:3000");
  expect(location.pathname).toBe("/login");
  expect(location.searchParams.get("error")).toBe("oauth_callback_failed");
  expect(location.searchParams.has("next")).toBe(false);

  const setCookies = await getSetCookieHeaders(response);
  const verifierDeletion = setCookies.find((value) =>
    value.toLowerCase().startsWith(`${QA251_VERIFIER_COOKIE}=`),
  );
  expect(verifierDeletion).toBeDefined();
  expect(verifierDeletion).toMatch(/(?:max-age=0|expires=thu, 01 jan 1970)/i);
  expect(
    setCookies.some((value) => /^sb-127-auth-token(?:\.\d+)?=/i.test(value)),
  ).toBe(false);
  expect(setCookies.some((value) => /^unrelated=/i.test(value))).toBe(false);

  const observed = await request.get("http://127.0.0.1:54321/__test/requests");
  const authRequests = await observed.json();
  expect(authRequests).toContainEqual(
    expect.objectContaining({
      auth_code: "qa251-invalid-code",
      code_verifier: "stale-verifier",
    }),
  );
});

test("real Next.js OAuth callback consumes a fresh PKCE verifier and persists the session", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await request.get(
    "/auth/callback?code=qa251-valid-code&next=%2Foffers",
    {
      maxRedirects: 0,
      headers: {
        cookie: `${QA251_VERIFIER_COOKIE}=${encodeQa251VerifierCookie("fresh-verifier")}`,
      },
    },
  );

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!, "http://127.0.0.1:3000");
  expect(location.pathname).toBe("/offers");

  const setCookies = await getSetCookieHeaders(response);
  const verifierDeletion = setCookies.find((value) =>
    value.toLowerCase().startsWith(`${QA251_VERIFIER_COOKIE}=`),
  );
  expect(verifierDeletion).toBeDefined();
  expect(verifierDeletion).toMatch(/(?:max-age=0|expires=thu, 01 jan 1970)/i);

  const sessionCookie = setCookies.find((value) =>
    /^sb-127-auth-token(?:\.\d+)?=/i.test(value),
  );
  expect(sessionCookie).toBeDefined();
  expect(sessionCookie).not.toMatch(/(?:max-age=0|expires=thu, 01 jan 1970)/i);

  const observed = await request.get("http://127.0.0.1:54321/__test/requests");
  const authRequests = await observed.json();
  expect(authRequests).toContainEqual(
    expect.objectContaining({
      auth_code: "qa251-valid-code",
      code_verifier: "fresh-verifier",
    }),
  );
});


async function requestQa252OAuthCallback(
  request: import("@playwright/test").APIRequestContext,
  next: string,
) {
  const params = new URLSearchParams({
    code: "qa251-valid-code",
    next,
  });

  return request.get(`/auth/callback?${params.toString()}`, {
    maxRedirects: 0,
    headers: {
      cookie: `${QA251_VERIFIER_COOKIE}=${encodeQa251VerifierCookie("fresh-verifier")}`,
    },
  });
}

test("real Next.js OAuth callback falls back for an absolute external next URL", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa252OAuthCallback(request, "https://evil.example/phish");

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.origin).toBe(QA252_EXPECTED_APP_ORIGIN);
  expect(location.pathname).toBe("/demands");
  expect(location.href).not.toContain("evil.example");
});

test("real Next.js OAuth callback falls back for a protocol-relative external next URL", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa252OAuthCallback(request, "//evil.example/phish");

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.origin).toBe(QA252_EXPECTED_APP_ORIGIN);
  expect(location.pathname).toBe("/demands");
  expect(location.href).not.toContain("evil.example");
});

test("real Next.js OAuth callback preserves a safe same-origin next path and query", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa252OAuthCallback(
    request,
    "/offers?search=steel&sort=recent#results",
  );

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.origin).toBe(QA252_EXPECTED_APP_ORIGIN);
  expect(location.pathname).toBe("/offers");
  expect(location.searchParams.get("search")).toBe("steel");
  expect(location.searchParams.get("sort")).toBe("recent");
  expect(location.hash).toBe("#results");
});

// QA253: exercise WHATWG URL normalization through the real OAuth Route Handler.
test("real Next.js OAuth callback rejects a backslash-normalized external destination", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa252OAuthCallback(request, "/\\evil.example/phish");

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.origin).toBe(QA252_EXPECTED_APP_ORIGIN);
  expect(location.pathname).toBe("/demands");
  expect(location.href).not.toContain("evil.example");
});

test("real Next.js OAuth callback rejects an external destination after control-character normalization", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa252OAuthCallback(request, "/\r\n//evil.example/phish");

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.origin).toBe(QA252_EXPECTED_APP_ORIGIN);
  expect(location.pathname).toBe("/demands");
  expect(location.href).not.toContain("evil.example");
});

test("real Next.js OAuth callback keeps percent-encoded backslashes on the same-origin path", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa252OAuthCallback(request, "/%5C%5Cevil.example/phish");

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.origin).toBe(QA252_EXPECTED_APP_ORIGIN);
  expect(location.pathname).toBe("/%5C%5Cevil.example/phish");
});

test("real Next.js OAuth callback preserves Unicode paths and duplicate or empty query values", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa252OAuthCallback(
    request,
    "/offers/雪?tag=steel&tag=aluminum&empty=&q=stainless%20steel%26pipe%3D1#résultats",
  );

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.origin).toBe(QA252_EXPECTED_APP_ORIGIN);
  expect(decodeURIComponent(location.pathname)).toBe("/offers/雪");
  expect(location.searchParams.getAll("tag")).toEqual(["steel", "aluminum"]);
  expect(location.searchParams.get("empty")).toBe("");
  expect(location.searchParams.get("q")).toBe("stainless steel&pipe=1");
  expect(decodeURIComponent(location.hash.slice(1))).toBe("résultats");
});

// QA254: verify that forwarded authority headers do not replace the configured
// Next.js request origin used by the OAuth callback. The local next start server
// is started with an explicit hostname/port; this does not model a Vercel edge.
async function requestQa254OAuthCallback(
  request: import("@playwright/test").APIRequestContext,
  authorityHeaders: Record<string, string>,
) {
  const params = new URLSearchParams({
    code: "qa251-valid-code",
    next: "/offers",
  });

  return request.get(`/auth/callback?${params.toString()}`, {
    maxRedirects: 0,
    headers: {
      cookie: `${QA251_VERIFIER_COOKIE}=${encodeQa251VerifierCookie("fresh-verifier")}`,
      ...authorityHeaders,
    },
  });
}

test("real Next.js OAuth callback does not derive its redirect origin from a forged Host header", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa254OAuthCallback(request, {
    host: "evil.example",
  });

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.origin).toBe(QA252_EXPECTED_APP_ORIGIN);
  expect(location.pathname).toBe("/offers");
  expect(location.href).not.toContain("evil.example");
});

test("real Next.js OAuth callback does not derive its redirect origin from a forged X-Forwarded-Host header", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa254OAuthCallback(request, {
    "x-forwarded-host": "evil.example",
  });

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.origin).toBe(QA252_EXPECTED_APP_ORIGIN);
  expect(location.pathname).toBe("/offers");
  expect(location.href).not.toContain("evil.example");
});

// QA255: characterize Next.js 15.5.28's X-Forwarded-Proto handling.
// The self-hosted test server uses an explicit hostname/port; this does not model a Vercel edge.
async function requestQa255OAuthCallback(
  request: import("@playwright/test").APIRequestContext,
  forwardedProto: string,
) {
  const params = new URLSearchParams({
    code: "qa251-valid-code",
    next: "/offers",
  });

  return request.get(`/auth/callback?${params.toString()}`, {
    maxRedirects: 0,
    headers: {
      cookie: `${QA251_VERIFIER_COOKIE}=${encodeQa251VerifierCookie("fresh-verifier")}`,
      "x-forwarded-proto": forwardedProto,
    },
  });
}

test("real Next.js OAuth callback derives an HTTPS redirect scheme from X-Forwarded-Proto https", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa255OAuthCallback(request, "https");

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.protocol).toBe("https:");
  expect(location.host).toBe(new URL(QA252_EXPECTED_APP_ORIGIN).host);
  expect(location.pathname).toBe("/offers");
});

test("real Next.js OAuth callback derives an HTTP redirect scheme from X-Forwarded-Proto http", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa255OAuthCallback(request, "http");

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.protocol).toBe("http:");
  expect(location.host).toBe(new URL(QA252_EXPECTED_APP_ORIGIN).host);
  expect(location.pathname).toBe("/offers");
});

test("real Next.js OAuth callback treats a comma-separated X-Forwarded-Proto containing https as HTTPS", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa255OAuthCallback(request, "http, https");

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.protocol).toBe("https:");
  expect(location.host).toBe(new URL(QA252_EXPECTED_APP_ORIGIN).host);
  expect(location.pathname).toBe("/offers");
});


// QA256: pin the framework's substring-based handling of malformed forwarded-proto values.
// This characterizes the self-hosted Next.js server only; it does not assert Vercel proxy behavior.
test("real Next.js OAuth callback treats a malformed X-Forwarded-Proto value containing https as HTTPS", async ({ request }) => {
  test.skip(process.env.CI !== "true", "Requires the isolated mock Supabase Auth server configured for CI.");

  const response = await requestQa255OAuthCallback(request, "nothttps");

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!);
  expect(location.protocol).toBe("https:");
  expect(location.host).toBe(new URL(QA252_EXPECTED_APP_ORIGIN).host);
  expect(location.pathname).toBe("/offers");
});
