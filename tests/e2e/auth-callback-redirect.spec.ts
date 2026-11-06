import { expect, test } from "@playwright/test";
import { getSafeRedirectUrl } from "../../lib/auth/safe-redirect";
import { handleOAuthCallback } from "../../lib/auth/oauth-callback";

const ORIGIN = "https://qimatrade.example";
const FALLBACK = new URL("/demands", ORIGIN);

test("OAuth callback accepts a same-origin relative path with query and fragment", () => {
  const next = "/offers?search=steel&sort=recent#results";

  expect(getSafeRedirectUrl(next, ORIGIN).href).toBe(
    new URL(next, ORIGIN).href,
  );
});

test("OAuth callback falls back for an absolute external URL", () => {
  expect(getSafeRedirectUrl("https://evil.example/path", ORIGIN).href).toBe(
    FALLBACK.href,
  );
});

test("OAuth callback falls back for protocol-relative external URLs", () => {
  for (const next of ["//evil.example/path", "///evil.example/path"]) {
    expect(getSafeRedirectUrl(next, ORIGIN).href).toBe(FALLBACK.href);
  }
});

test("OAuth callback rejects a backslash-normalized external authority", () => {
  const next = "/\\\\evil.example/path";

  expect(new URL(next, ORIGIN).origin).toBe("https://evil.example");
  expect(getSafeRedirectUrl(next, ORIGIN).href).toBe(FALLBACK.href);
});

test("OAuth callback falls back for missing, empty, and non-root-relative destinations", () => {
  for (const next of [null, "", "offers", "https://evil.example"]) {
    expect(getSafeRedirectUrl(next, ORIGIN).href).toBe(FALLBACK.href);
  }
});

function callbackRequest(search: string) {
  return new Request(`${ORIGIN}/auth/callback${search}`);
}

function responseLocation(response: Response) {
  const location = response.headers.get("location");
  expect(location).not.toBeNull();
  return new URL(location!, ORIGIN);
}

test("OAuth callback without a code does not create a Supabase client or honor next", async () => {
  let clientFactoryCalls = 0;

  const response = await handleOAuthCallback(
    callbackRequest("?next=%2Foffers%3Fsearch%3Dsteel"),
    async () => {
      clientFactoryCalls += 1;
      return {
        auth: {
          exchangeCodeForSession: async () => ({ error: null }),
        },
      };
    },
  );

  const location = responseLocation(response);
  expect(response.status).toBe(307);
  expect(location.pathname).toBe("/login");
  expect(location.searchParams.get("error")).toBe("oauth_callback_missing_code");
  expect(location.searchParams.has("next")).toBe(false);
  expect(clientFactoryCalls).toBe(0);
});

test("OAuth callback exchange errors return to login instead of honoring next", async () => {
  let exchangedCode: string | null = null;
  let clientFactoryCalls = 0;

  const response = await handleOAuthCallback(
    callbackRequest("?code=authorization-code&next=%2Foffers%3Fsearch%3Dsteel"),
    async () => {
      clientFactoryCalls += 1;
      return {
        auth: {
          exchangeCodeForSession: async (code: string) => {
            exchangedCode = code;
            return { error: new Error("simulated OAuth exchange failure") };
          },
        },
      };
    },
  );

  const location = responseLocation(response);
  expect(response.status).toBe(307);
  expect(location.pathname).toBe("/login");
  expect(location.searchParams.get("error")).toBe("oauth_callback_failed");
  expect(location.searchParams.has("next")).toBe(false);
  expect(exchangedCode).toBe("authorization-code");
  expect(clientFactoryCalls).toBe(1);
});

test("OAuth callback catches a thrown exchange failure and fails closed", async () => {
  const response = await handleOAuthCallback(
    callbackRequest("?code=authorization-code&next=%2Foffers"),
    async () => ({
      auth: {
        exchangeCodeForSession: async () => {
          throw new Error("simulated transport failure");
        },
      },
    }),
  );

  const location = responseLocation(response);
  expect(response.status).toBe(307);
  expect(location.pathname).toBe("/login");
  expect(location.searchParams.get("error")).toBe("oauth_callback_failed");
  expect(location.searchParams.has("next")).toBe(false);
});

test("OAuth callback honors the safe same-origin destination after a successful exchange", async () => {
  let exchangedCode: string | null = null;

  const response = await handleOAuthCallback(
    callbackRequest("?code=authorization-code&next=%2Foffers%3Fsearch%3Dsteel"),
    async () => ({
      auth: {
        exchangeCodeForSession: async (code: string) => {
          exchangedCode = code;
          return { error: null };
        },
      },
    }),
  );

  const location = responseLocation(response);
  expect(response.status).toBe(307);
  expect(location.origin).toBe(ORIGIN);
  expect(location.pathname).toBe("/offers");
  expect(location.searchParams.get("search")).toBe("steel");
  expect(exchangedCode).toBe("authorization-code");
});

test("OAuth callback catches Supabase client initialization failures without exposing details or honoring next", async () => {
  const secret = "simulated-supabase-client-secret";

  const response = await handleOAuthCallback(
    callbackRequest("?code=authorization-code&next=%2Foffers"),
    async () => {
      throw new Error(secret);
    },
  );

  const location = responseLocation(response);
  expect(response.status).toBe(307);
  expect(location.origin).toBe(ORIGIN);
  expect(location.pathname).toBe("/login");
  expect(location.searchParams.get("error")).toBe("oauth_callback_failed");
  expect(location.searchParams.has("next")).toBe(false);
  expect(location.href).not.toContain(secret);
});
