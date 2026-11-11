import { expect, test, type APIRequestContext, type Page } from "@playwright/test";
import { getCreatedOfferId } from "../../lib/offers/created-offer-reference";

const OFFER_ID = "7d2d1f7e-7d4e-4f3e-9d8b-3f8d0e6f2c11";
const VERIFIER_COOKIE = "sb-127-auth-token-code-verifier";
const SESSION_COOKIE_PATTERN = /^sb-127-auth-token(?:[.][0-9]+)?=/i;
const APP_COOKIE_DOMAINS = ["127.0.0.1", "localhost"];
const PRODUCT_MASTER_GATE_ID = "60000000-0000-4000-8000-00000000336";
const SYNTHETIC_PROVIDER_ACTOR_ID = "30000000-0000-4000-8000-00000000336";

function encodeVerifierCookie(value: string) {
  return `base64-${Buffer.from(JSON.stringify(value), "utf8").toString("base64url")}`;
}

async function authenticatePage(
  page: Page,
  request: APIRequestContext,
  next: string,
) {
  const params = new URLSearchParams({
    code: "qa251-valid-code",
    next,
  });
  const response = await request.get(`/auth/callback?${params.toString()}`, {
    maxRedirects: 0,
    headers: {
      cookie: `${VERIFIER_COOKIE}=${encodeVerifierCookie("fresh-verifier")}`,
    },
  });

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!, "http://127.0.0.1:3000");
  expect(location.pathname).toBe(new URL(next, "http://127.0.0.1:3000").pathname);

  const setCookies = (await response.headersArray())
    .filter(({ name }) => name.toLowerCase() === "set-cookie")
    .map(({ value }) => value);
  const sessionCookies = setCookies.filter((value) => SESSION_COOKIE_PATTERN.test(value));

  expect(sessionCookies.length).toBeGreaterThan(0);

  for (const setCookie of sessionCookies) {
    const pair = setCookie.split(";", 1)[0];
    const separator = pair.indexOf("=");
    expect(separator).toBeGreaterThan(0);

    for (const domain of APP_COOKIE_DOMAINS) {
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

test("offer confirmation accepts the UUID v4 reference emitted after a successful draft insert", () => {
  expect(getCreatedOfferId(`?created=${OFFER_ID}`)).toBe(OFFER_ID);
});

test("offer confirmation ignores missing, empty, or malformed references", () => {
  expect(getCreatedOfferId("")).toBeNull();
  expect(getCreatedOfferId("?created=")).toBeNull();
  expect(getCreatedOfferId("?created=not-a-uuid")).toBeNull();
  expect(getCreatedOfferId("?created=7d2d1f7e-7d4e-1f3e-9d8b-3f8d0e6f2c11")).toBeNull();
});

test("offer confirmation uses the first created query value and does not fall through to a later duplicate", () => {
  expect(getCreatedOfferId(`?created=invalid&created=${OFFER_ID}`)).toBeNull();
});

test("a valid draft confirmation URL remains protected for unauthenticated visitors", async ({ page }) => {
  await page.goto(`/offers/new?created=${OFFER_ID}`);

  await expect(page).toHaveURL((url) => url.pathname === "/login");
  const loginUrl = new URL(page.url());
  expect(loginUrl.searchParams.get("next")).toBe(`/offers/new?created=${OFFER_ID}`);
});

test("an authenticated supplier can view draft confirmation without Product Master and restart supplier classification", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?created=${OFFER_ID}`);

  await page.goto(`/offers/new?created=${OFFER_ID}`);

  await expect(page).toHaveURL((url) => url.pathname === "/offers/new" && url.searchParams.get("created") === OFFER_ID);
  await expect(page.getByRole("heading", { name: "Create a new offer" })).toBeVisible();
  await expect(page.getByRole("status")).toContainText("Draft submission received");
  await expect(page.getByText(`Offer reference: ${OFFER_ID}`, { exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: "Create another offer" })).toBeVisible();

  await page.getByRole("link", { name: "Create another offer" }).click();
  await expect(page).toHaveURL((url) => url.pathname === "/decision-tree" && url.searchParams.get("flow") === "supplier");
});

test("an authenticated supplier with an invalid confirmation reference is still sent through classification", async ({ page, request }) => {
  await authenticatePage(page, request, "/offers");

  await page.goto("/offers/new?created=not-a-uuid");

  await expect(page).toHaveURL((url) => url.pathname === "/decision-tree" && url.searchParams.get("flow") === "supplier");
});

test("an authenticated supplier can submit the independent draft form through POST and reach its persisted confirmation", async ({ page, request }, testInfo) => {
  const offerName = `QA336 browser end-to-end independent draft retry-${testInfo.retry}`;
  const reset = await request.delete(
    `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
  );
  expect(reset.ok()).toBe(true);

  await authenticatePage(
    page,
    request,
    `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`,
  );
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  await page.getByLabel("Offer name").fill(offerName);
  await page.getByLabel("Quantity").fill("2");

  const countrySelectors = page.locator('button[aria-haspopup="listbox"]');
  await countrySelectors.nth(0).click();
  await page.getByRole("listbox").getByRole("button", { name: "South Korea", exact: true }).click();
  await countrySelectors.nth(1).click();
  await page.getByRole("listbox").getByRole("button", { name: "South Korea", exact: true }).click();

  const postResponsePromise = page.waitForResponse((response) =>
    response.url().endsWith("/api/offers") && response.request().method() === "POST",
  );
  await page.getByRole("button", { name: "Create offer", exact: true }).click();
  const postResponse = await postResponsePromise;

  expect(postResponse.status()).toBe(201);
  expect(postResponse.headers()["content-type"]).toContain("application/json");
  await expect(page).toHaveURL((url) =>
    url.pathname === "/offers/new" && getCreatedOfferId(url.search) !== null,
  );
  const createdOfferId = new URL(page.url()).searchParams.get("created") ?? "";
  expect(createdOfferId).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
  await expect(page.getByRole("status")).toContainText("Draft submission received");
  await expect(page.getByText(`Offer reference: ${createdOfferId}`, { exact: true })).toBeVisible();

  const inspection = await request.get(
    `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
  );
  expect(inspection.ok()).toBe(true);
  const inserts = await inspection.json();
  expect(inserts).toHaveLength(1);

  const [insert] = inserts;
  expect(insert.authorizationValid).toBe(true);
  expect(insert.contentType).toContain("application/json");
  // PostgREST defaults to a minimal response when Prefer is absent.
  expect(insert.prefer ?? "").not.toMatch(/return=representation/i);
  expect(insert.payload).toMatchObject({
    id: createdOfferId,
    name: offerName,
    demand_id: null,
    product_master_id: null,
    provider_actor_id: SYNTHETIC_PROVIDER_ACTOR_ID,
    quantity: 2,
    price: null,
    currency: null,
    conditions: null,
    market: "South Korea",
    geography: "South Korea",
    attributes: {},
    documentation_status: "incomplete",
    lifecycle: "draft",
    offer_type: "supplier_offer",
    pricing_model: null,
  });
});

test("an authenticated supplier sees a generic retry message and no confirmation when PostgREST rejects a draft insert", async ({ page, request }, testInfo) => {
  await authenticatePage(
    page,
    request,
    `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`,
  );
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  const countrySelectors = page.locator('button[aria-haspopup="listbox"]');
  await countrySelectors.nth(0).click();
  await page.getByRole("listbox").getByRole("button", { name: "South Korea", exact: true }).click();
  await countrySelectors.nth(1).click();
  await page.getByRole("listbox").getByRole("button", { name: "South Korea", exact: true }).click();

  for (const upstreamStatus of [400, 403, 500]) {
    const offerName = `QA337 PostgREST failure ${upstreamStatus} retry-${testInfo.retry}`;
    const reset = await request.delete(
      `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
    );
    expect(reset.ok()).toBe(true);

    await page.getByLabel("Offer name").fill(offerName);
    await page.getByLabel("Quantity").fill("2");

    const postResponsePromise = page.waitForResponse((response) =>
      response.url().endsWith("/api/offers") && response.request().method() === "POST",
    );
    await page.getByRole("button", { name: "Create offer", exact: true }).click();
    const postResponse = await postResponsePromise;

    // The handler intentionally maps all upstream insert failures to one generic response.
    expect(postResponse.status()).toBe(500);
    await expect(page.locator('p[role="alert"]')).toHaveText("We couldn't submit your offer. Please try again.");
    await expect(page.locator('[aria-busy="true"]')).toHaveCount(0);
    await expect(page.getByRole("heading", { name: "Create a new offer" })).toBeVisible();
    await expect(page.getByRole("status")).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Create offer", exact: true })).toBeEnabled();
    await expect(page).toHaveURL((url) =>
      url.pathname === "/offers/new" &&
      url.searchParams.get("productMasterId") === PRODUCT_MASTER_GATE_ID &&
      !url.searchParams.has("created"),
    );

    const failuresResponse = await request.get(
      `http://127.0.0.1:54321/__test/offer-failures?name=${encodeURIComponent(offerName)}`,
    );
    expect(failuresResponse.ok()).toBe(true);
    expect(await failuresResponse.json()).toEqual([
      { name: offerName, status: upstreamStatus, code: "PGRST_QA337" },
    ]);

    const inspection = await request.get(
      `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
    );
    expect(inspection.ok()).toBe(true);
    expect(await inspection.json()).toHaveLength(0);

    const visibleText = await page.locator("body").innerText();
    expect(visibleText).not.toContain("SYNTHETIC_DATABASE_INTERNAL_DETAIL");
    expect(visibleText).not.toContain("PGRST_QA337");
  }
});

test("an authenticated supplier can retry a draft after one transient PostgREST failure without losing form data", async ({ page, request }, testInfo) => {
  const offerName = `QA338 transient retry retry-${testInfo.retry}`;
  const reset = await request.delete(
    `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
  );
  expect(reset.ok()).toBe(true);

  await authenticatePage(
    page,
    request,
    `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`,
  );
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  await page.getByLabel("Offer name").fill(offerName);
  await page.getByLabel("Quantity").fill("2");

  const countrySelectors = page.locator('button[aria-haspopup="listbox"]');
  await countrySelectors.nth(0).click();
  await page.getByRole("listbox").getByRole("button", { name: "South Korea", exact: true }).click();
  await countrySelectors.nth(1).click();
  await page.getByRole("listbox").getByRole("button", { name: "South Korea", exact: true }).click();

  const firstPostPromise = page.waitForResponse((response) =>
    response.url().endsWith("/api/offers") && response.request().method() === "POST",
  );
  await page.getByRole("button", { name: "Create offer", exact: true }).click();
  const firstPost = await firstPostPromise;

  // The mock returns one transient upstream 503; the route keeps its public generic 500 contract.
  expect(firstPost.status()).toBe(500);
  await expect(page.locator('p[role="alert"]')).toHaveText("We couldn't submit your offer. Please try again.");
  await expect(page.getByLabel("Offer name")).toHaveValue(offerName);
  await expect(page.getByLabel("Quantity")).toHaveValue("2");
  await expect(page.getByRole("button", { name: "Create offer", exact: true })).toBeEnabled();
  await expect(page.getByRole("status")).toHaveCount(0);
  await expect(page).toHaveURL((url) =>
    url.pathname === "/offers/new" &&
    url.searchParams.get("productMasterId") === PRODUCT_MASTER_GATE_ID &&
    !url.searchParams.has("created"),
  );

  const firstFailureResponse = await request.get(
    `http://127.0.0.1:54321/__test/offer-failures?name=${encodeURIComponent(offerName)}`,
  );
  expect(firstFailureResponse.ok()).toBe(true);
  expect(await firstFailureResponse.json()).toEqual([
    { name: offerName, status: 503, code: "PGRST_QA338" },
  ]);

  const beforeRetry = await request.get(
    `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
  );
  expect(beforeRetry.ok()).toBe(true);
  expect(await beforeRetry.json()).toHaveLength(0);

  const retryPostPromise = page.waitForResponse((response) =>
    response.url().endsWith("/api/offers") && response.request().method() === "POST",
  );
  await page.getByRole("button", { name: "Create offer", exact: true }).click();
  const retryPost = await retryPostPromise;

  expect(retryPost.status()).toBe(201);
  await expect(page).toHaveURL((url) =>
    url.pathname === "/offers/new" && getCreatedOfferId(url.search) !== null,
  );
  const createdOfferId = new URL(page.url()).searchParams.get("created") ?? "";
  expect(createdOfferId).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
  await expect(page.getByRole("status")).toContainText("Draft submission received");
  await expect(page.getByText(`Offer reference: ${createdOfferId}`, { exact: true })).toBeVisible();
  await expect(page.locator('p[role="alert"]')).toHaveCount(0);

  const finalFailures = await request.get(
    `http://127.0.0.1:54321/__test/offer-failures?name=${encodeURIComponent(offerName)}`,
  );
  expect(finalFailures.ok()).toBe(true);
  expect(await finalFailures.json()).toEqual([
    { name: offerName, status: 503, code: "PGRST_QA338" },
  ]);

  const afterRetry = await request.get(
    `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
  );
  expect(afterRetry.ok()).toBe(true);
  const inserts = await afterRetry.json();
  expect(inserts).toHaveLength(1);
  expect(inserts[0].payload).toMatchObject({
    id: createdOfferId,
    name: offerName,
    provider_actor_id: SYNTHETIC_PROVIDER_ACTOR_ID,
    quantity: 2,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });

  const visibleText = await page.locator("body").innerText();
  expect(visibleText).not.toContain("SYNTHETIC_DATABASE_INTERNAL_DETAIL");
  expect(visibleText).not.toContain("PGRST_QA338");
});

test("an authenticated supplier can retry a draft after a browser network interruption without losing form data", async ({ page, request }, testInfo) => {
  const offerName = `QA339 network interruption retry-${testInfo.retry}`;
  const reset = await request.delete(
    `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
  );
  expect(reset.ok()).toBe(true);

  await authenticatePage(
    page,
    request,
    `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`,
  );
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  await page.getByLabel("Offer name").fill(offerName);
  await page.getByLabel("Quantity").fill("2");

  const countrySelectors = page.locator('button[aria-haspopup="listbox"]');
  await countrySelectors.nth(0).click();
  await page.getByRole("listbox").getByRole("button", { name: "South Korea", exact: true }).click();
  await countrySelectors.nth(1).click();
  await page.getByRole("listbox").getByRole("button", { name: "South Korea", exact: true }).click();

  let connectionWasInterrupted = false;
  await page.route("**/api/offers", async (route) => {
    if (!connectionWasInterrupted) {
      connectionWasInterrupted = true;
      await route.abort("connectionreset");
      return;
    }
    await route.continue();
  });

  const failedRequestPromise = page.waitForEvent(
    "requestfailed",
    (failedRequest) => failedRequest.url().endsWith("/api/offers"),
  );
  await page.getByRole("button", { name: "Create offer", exact: true }).click();
  const failedRequest = await failedRequestPromise;

  expect(connectionWasInterrupted).toBe(true);
  expect(failedRequest.url()).toContain("/api/offers");
  await expect(page.locator('p[role="alert"]')).toHaveText(
    "We couldn't submit your offer. Please try again.",
  );
  await expect(page.getByLabel("Offer name")).toHaveValue(offerName);
  await expect(page.getByLabel("Quantity")).toHaveValue("2");
  await expect(countrySelectors.nth(0)).toContainText("South Korea");
  await expect(countrySelectors.nth(1)).toContainText("South Korea");
  await expect(page.getByRole("button", { name: "Create offer", exact: true })).toBeEnabled();
  await expect(page.getByRole("status")).toHaveCount(0);
  await expect(page).toHaveURL((url) =>
    url.pathname === "/offers/new" &&
    url.searchParams.get("productMasterId") === PRODUCT_MASTER_GATE_ID &&
    !url.searchParams.has("created"),
  );

  const beforeRetry = await request.get(
    `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
  );
  expect(beforeRetry.ok()).toBe(true);
  expect(await beforeRetry.json()).toHaveLength(0);

  const failureRecords = await request.get(
    `http://127.0.0.1:54321/__test/offer-failures?name=${encodeURIComponent(offerName)}`,
  );
  expect(failureRecords.ok()).toBe(true);
  expect(await failureRecords.json()).toHaveLength(0);

  // Remove the one-shot network fault so the retry reaches the synthetic PostgREST service.
  await page.unroute("**/api/offers");

  const retryResponsePromise = page.waitForResponse((response) =>
    response.url().endsWith("/api/offers") && response.request().method() === "POST",
  );
  await page.getByRole("button", { name: "Create offer", exact: true }).click();
  const retryResponse = await retryResponsePromise;

  expect(retryResponse.status()).toBe(201);
  await expect(page).toHaveURL((url) =>
    url.pathname === "/offers/new" && getCreatedOfferId(url.search) !== null,
  );
  const createdOfferId = new URL(page.url()).searchParams.get("created") ?? "";
  expect(createdOfferId).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
  await expect(page.getByRole("status")).toContainText("Draft submission received");
  await expect(page.getByText(`Offer reference: ${createdOfferId}`, { exact: true })).toBeVisible();
  await expect(page.locator('p[role="alert"]')).toHaveCount(0);

  const afterRetry = await request.get(
    `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
  );
  expect(afterRetry.ok()).toBe(true);
  const inserts = await afterRetry.json();
  expect(inserts).toHaveLength(1);
  expect(inserts[0].payload).toMatchObject({
    id: createdOfferId,
    name: offerName,
    provider_actor_id: SYNTHETIC_PROVIDER_ACTOR_ID,
    quantity: 2,
    lifecycle: "draft",
    offer_type: "supplier_offer",
  });

  const visibleText = await page.locator("body").innerText();
  expect(visibleText).not.toContain("SYNTHETIC_DATABASE_INTERNAL_DETAIL");
  expect(visibleText).not.toContain("PGRST_QA338");

  const cleanup = await request.delete(
    `http://127.0.0.1:54321/__test/offers?name=${encodeURIComponent(offerName)}`,
  );
  expect(cleanup.ok()).toBe(true);
});
