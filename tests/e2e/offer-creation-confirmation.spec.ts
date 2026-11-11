import { expect, test, type APIRequestContext, type Page } from "@playwright/test";
import { getCreatedOfferId } from "../../lib/offers/created-offer-reference";

const OFFER_ID = "7d2d1f7e-7d4e-4f3e-9d8b-3f8d0e6f2c11";
const VERIFIER_COOKIE = "sb-127-auth-token-code-verifier";
const SESSION_COOKIE_PATTERN = /^sb-127-auth-token(?:\\.\\d+)?=/i;
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

  await expect(page).toHaveURL(/\\/login\\?/);
  const loginUrl = new URL(page.url());
  expect(loginUrl.searchParams.get("next")).toBe(`/offers/new?created=${OFFER_ID}`);
});

test("an authenticated supplier can view draft confirmation without Product Master and restart supplier classification", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?created=${OFFER_ID}`);

  await page.goto(`/offers/new?created=${OFFER_ID}`);

  await expect(page).toHaveURL(new RegExp(`/offers/new\\\\?created=${OFFER_ID}$`));
  await expect(page.getByRole("heading", { name: "Create a new offer" })).toBeVisible();
  await expect(page.getByRole("status")).toContainText("Draft submission received");
  await expect(page.getByText(`Offer reference: ${OFFER_ID}`, { exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: "Create another offer" })).toBeVisible();

  await page.getByRole("link", { name: "Create another offer" }).click();
  await expect(page).toHaveURL(/\\/decision-tree\\?flow=supplier$/);
});

test("an authenticated supplier with an invalid confirmation reference is still sent through classification", async ({ page, request }) => {
  await authenticatePage(page, request, "/offers");

  await page.goto("/offers/new?created=not-a-uuid");

  await expect(page).toHaveURL(/\\/decision-tree\\?.*flow=supplier/);
});

test("an authenticated supplier can submit the independent draft form through POST and reach its persisted confirmation", async ({ page, request }) => {
  const offerName = "QA336 browser end-to-end independent draft";

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

  expect(postResponse.status()).toBe(303);
  const redirectLocation = new URL(postResponse.headers().location!, "http://127.0.0.1:3000");
  expect(redirectLocation.pathname).toBe("/offers/new");
  const createdOfferId = redirectLocation.searchParams.get("created");
  expect(createdOfferId).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);

  await expect(page).toHaveURL(new RegExp(`/offers/new\\\\?created=${createdOfferId}$`));
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
  expect(insert.prefer).toMatch(/return=minimal/i);
  expect(insert.prefer).not.toMatch(/return=representation/i);
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
