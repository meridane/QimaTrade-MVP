import { expect, test, type APIRequestContext, type Page } from "@playwright/test";
import { getCreatedOfferId } from "../../lib/offers/created-offer-reference";

const OFFER_ID = "7d2d1f7e-7d4e-4f3e-9d8b-3f8d0e6f2c11";
const VERIFIER_COOKIE = "sb-127-auth-token-code-verifier";
const SESSION_COOKIE_PATTERN = /^sb-127-auth-token(?:\.\d+)?=/i;
const APP_COOKIE_DOMAIN = "127.0.0.1";

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

    await page.context().addCookies([{
      name: pair.slice(0, separator),
      value: pair.slice(separator + 1),
      domain: APP_COOKIE_DOMAIN,
      path: "/",
      httpOnly: true,
      secure: false,
      sameSite: "Lax",
    }]);
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

  await expect(page).toHaveURL(/\/login\?/);
  const loginUrl = new URL(page.url());
  expect(loginUrl.searchParams.get("next")).toBe(`/offers/new?created=${OFFER_ID}`);
});

test("an authenticated supplier can view draft confirmation without Product Master and restart supplier classification", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?created=${OFFER_ID}`);

  await page.goto(`/offers/new?created=${OFFER_ID}`);

  await expect(page).toHaveURL(new RegExp(`/offers/new\\?created=${OFFER_ID}$`));
  await expect(page.getByRole("heading", { name: "Create a new offer" })).toBeVisible();
  await expect(page.getByRole("status")).toContainText("Draft submission received");
  await expect(page.getByText(`Offer reference: ${OFFER_ID}`, { exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: "Create another offer" })).toBeVisible();

  await page.getByRole("link", { name: "Create another offer" }).click();
  await expect(page).toHaveURL(/\/decision-tree\?flow=supplier$/);
});

test("an authenticated supplier with an invalid confirmation reference is still sent through classification", async ({ page, request }) => {
  await authenticatePage(page, request, "/offers");

  await page.goto("/offers/new?created=not-a-uuid");

  await expect(page).toHaveURL(/\/decision-tree\?.*flow=supplier/);
});
