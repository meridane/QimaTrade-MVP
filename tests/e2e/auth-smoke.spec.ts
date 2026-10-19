import { expect, test } from "@playwright/test";

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
