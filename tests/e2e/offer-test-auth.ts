import { expect, type APIRequestContext, type Page } from "@playwright/test";

const VERIFIER_COOKIE = "sb-127-auth-token-code-verifier";
const SESSION_COOKIE_PATTERN = /^sb-127-auth-token(?:[.][0-9]+)?=/i;
const APP_COOKIE_DOMAINS = ["127.0.0.1", "localhost"];

function encodeVerifierCookie(value: string) {
  return `base64-${Buffer.from(JSON.stringify(value), "utf8").toString("base64url")}`;
}

export async function authenticatePage(page: Page, request: APIRequestContext, next: string) {
  const params = new URLSearchParams({ code: "qa251-valid-code", next });
  const response = await request.get(`/auth/callback?${params.toString()}`, {
    maxRedirects: 0,
    headers: { cookie: `${VERIFIER_COOKIE}=${encodeVerifierCookie("fresh-verifier")}` },
  });

  expect(response.status()).toBe(307);
  const location = new URL(response.headers().location!, "http://127.0.0.1:3000");
  expect(location.pathname).toBe(new URL(next, "http://127.0.0.1:3000").pathname);

  const setCookies = (await response.headersArray())
    .filter(({ name }) => name.toLowerCase() === "set-cookie")
    .map(({ value }) => value);
  const sessionCookies = setCookies.filter(value => SESSION_COOKIE_PATTERN.test(value));
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
