import { expect, test } from "@playwright/test";
import { createServerClient } from "@supabase/ssr";
import { NextResponse } from "next/server";
import type { CookieOptions } from "@supabase/ssr";
import { createSupabaseCookieMethods } from "../../lib/supabase/cookie-methods";
import { createSupabaseServerClientOptions } from "../../lib/supabase/server";

test("Supabase cookie adapter returns every request cookie", () => {
  const requestCookies = [
    { name: "sb-access-token", value: "access-value" },
    { name: "sb-refresh-token", value: "refresh-value" },
  ];
  const writes: Array<{ name: string; value: string; options: CookieOptions }> = [];

  const methods = createSupabaseCookieMethods({
    getAll: () => requestCookies,
    set: (name, value, options) => writes.push({ name, value, options }),
  });

  expect(methods.getAll()).toEqual(requestCookies);
  expect(writes).toEqual([]);
});

test("Supabase cookie adapter forwards every mutation with its complete options", () => {
  const writes: Array<{ name: string; value: string; options: CookieOptions }> = [];
  const methods = createSupabaseCookieMethods({
    getAll: () => [],
    set: (name, value, options) => writes.push({ name, value, options }),
  });
  const sessionOptions: CookieOptions = {
    httpOnly: true,
    secure: true,
    sameSite: "lax",
    path: "/",
    maxAge: 3600,
  };
  const removalOptions: CookieOptions = {
    httpOnly: true,
    secure: true,
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  };

  methods.setAll([
    { name: "sb-access-token", value: "new-access", options: sessionOptions },
    { name: "sb-refresh-token", value: "", options: removalOptions },
  ]);

  expect(writes).toEqual([
    { name: "sb-access-token", value: "new-access", options: sessionOptions },
    { name: "sb-refresh-token", value: "", options: removalOptions },
  ]);
});

test("Supabase cookie adapter tolerates immutable cookie stores outside Route Handlers", () => {
  const methods = createSupabaseCookieMethods({
    getAll: () => [],
    set: () => {
      throw new Error("Cookies can only be modified in a Server Action or Route Handler");
    },
  });

  expect(() =>
    methods.setAll([
      {
        name: "sb-access-token",
        value: "access-value",
        options: { httpOnly: true, path: "/" },
      },
    ]),
  ).not.toThrow();
});


test("Supabase cookie adapter serializes auth cookie chunks into Next.js redirect Set-Cookie headers", () => {
  const response = NextResponse.redirect(
    new URL("/offers?source=oauth", "https://qimatrade.example"),
  );
  const methods = createSupabaseCookieMethods({
    getAll: () => [],
    set: (name, value, options) => {
      response.cookies.set(name, value, options);
    },
  });
  const secureOptions: CookieOptions = {
    httpOnly: true,
    secure: true,
    sameSite: "lax",
    path: "/",
    maxAge: 3600,
  };

  methods.setAll([
    { name: "sb-qima-auth-token.0", value: "chunk-zero", options: secureOptions },
    { name: "sb-qima-auth-token.1", value: "chunk-one", options: secureOptions },
    {
      name: "sb-qima-auth-token",
      value: "",
      options: { ...secureOptions, maxAge: 0 },
    },
  ]);

  const serializedCookies = (response.headers.get("set-cookie") ?? "").toLowerCase();

  expect(response.status).toBe(307);
  expect(response.headers.get("location")).toBe(
    "https://qimatrade.example/offers?source=oauth",
  );
  expect(response.cookies.getAll().map(({ name }) => name)).toEqual([
    "sb-qima-auth-token.0",
    "sb-qima-auth-token.1",
    "sb-qima-auth-token",
  ]);
  expect(serializedCookies).toContain("sb-qima-auth-token.0=chunk-zero");
  expect(serializedCookies).toContain("sb-qima-auth-token.1=chunk-one");
  expect(serializedCookies).toContain("sb-qima-auth-token=;");
  expect(serializedCookies).toContain("httponly");
  expect(serializedCookies).toContain("secure");
  expect(serializedCookies).toContain("samesite=lax");
  expect(serializedCookies).toContain("path=/");
  expect(serializedCookies).toContain("max-age=0");
});


test("Supabase server client options bind the request cookie store through the SSR adapter", () => {
  const requestCookies = [
    { name: "sb-qima-auth-token.0", value: "session-fragment" },
  ];
  const writes: Array<{ name: string; value: string; options: CookieOptions }> = [];
  const cookieStore = {
    getAll: () => requestCookies,
    set: (name: string, value: string, options: CookieOptions) => {
      writes.push({ name, value, options });
    },
  };

  const options = createSupabaseServerClientOptions(cookieStore);
  expect(options.cookies.getAll()).toEqual(requestCookies);

  const sessionOptions: CookieOptions = {
    httpOnly: true,
    secure: true,
    sameSite: "lax",
    path: "/",
    maxAge: 60,
  };
  options.cookies.setAll([
    {
      name: "sb-qima-auth-token.1",
      value: "refresh-fragment",
      options: sessionOptions,
    },
  ]);

  expect(writes).toEqual([
    {
      name: "sb-qima-auth-token.1",
      value: "refresh-fragment",
      options: sessionOptions,
    },
  ]);
});

test("Supabase cookie adapter stops the remaining batch when an immutable store rejects a write", () => {
  const attemptedNames: string[] = [];
  const methods = createSupabaseCookieMethods({
    getAll: () => [],
    set: (name) => {
      attemptedNames.push(name);
      if (name === "sb-refresh-token") {
        throw new Error("Cookie store is immutable");
      }
    },
  });

  expect(() =>
    methods.setAll([
      { name: "sb-access-token", value: "access", options: { path: "/" } },
      { name: "sb-refresh-token", value: "refresh", options: { path: "/" } },
      { name: "sb-session-metadata", value: "metadata", options: { path: "/" } },
    ]),
  ).not.toThrow();

  // setAll is best-effort, not transactional: earlier writes remain and the
  // first rejected write aborts the rest of this batch.
  expect(attemptedNames).toEqual(["sb-access-token", "sb-refresh-token"]);
});


test("Supabase SSR client persists its PKCE verifier through the production cookie wiring", async () => {
  const writes: Array<{ name: string; value: string; options: CookieOptions }> = [];
  const cookieStore = {
    getAll: () => [],
    set: (name: string, value: string, options: CookieOptions) => {
      writes.push({ name, value, options });
    },
  };
  const supabase = createServerClient(
    "https://qima-test.supabase.co",
    "ci-placeholder-anon-key",
    {
      ...createSupabaseServerClientOptions(cookieStore),
      auth: {
        flowType: "pkce",
        autoRefreshToken: false,
        detectSessionInUrl: false,
        persistSession: true,
      },
      // The test exercises auth cookie storage only and never opens a realtime channel.
      realtime: {
        transport: class NoopWebSocket {} as unknown as typeof WebSocket,
      },
    },
  );

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: {
      redirectTo: "https://qimatrade.example/auth/callback",
      skipBrowserRedirect: true,
    },
  });

  expect(error).toBeNull();
  expect(data.url).not.toBeNull();
  const authorizationUrl = new URL(data.url!);
  expect(authorizationUrl.searchParams.get("provider")).toBe("google");
  expect(authorizationUrl.searchParams.get("code_challenge_method")).toBe("s256");

  const verifierCookie = writes.find(({ name }) => name.endsWith("-code-verifier"));
  expect(verifierCookie).toBeDefined();
  expect(verifierCookie?.value.length).toBeGreaterThan(0);
  expect(verifierCookie?.options.path).toBe("/");
});


function createQa249CookieStore() {
  const values = new Map<string, { name: string; value: string }>();
  const writes: Array<{ name: string; value: string; options: CookieOptions }> = [];

  return {
    values,
    writes,
    cookieStore: {
      getAll: () => Array.from(values.values()),
      set: (name: string, value: string, options: CookieOptions) => {
        writes.push({ name, value, options });
        if (options.maxAge === 0 || value === "") {
          values.delete(name);
        } else {
          values.set(name, { name, value });
        }
      },
    },
  };
}

function createQa249SupabaseClient(
  cookieStore: ReturnType<typeof createQa249CookieStore>["cookieStore"],
  fetch: typeof globalThis.fetch,
) {
  return createServerClient(
    "https://qima-test.supabase.co",
    "ci-placeholder-anon-key",
    {
      ...createSupabaseServerClientOptions(cookieStore),
      auth: {
        flowType: "pkce",
        autoRefreshToken: false,
        detectSessionInUrl: false,
        persistSession: true,
      },
      global: { fetch },
      // This test covers Auth only and never opens a Realtime channel.
      realtime: {
        transport: class NoopWebSocket {} as unknown as typeof WebSocket,
      },
    },
  );
}

const qa249SessionResponse = {
  access_token: "qa249-access-token",
  token_type: "bearer",
  expires_in: 3600,
  refresh_token: "qa249-refresh-token",
  user: {
    id: "00000000-0000-4000-8000-00000000249",
    aud: "authenticated",
    role: "authenticated",
    email: "qa249@example.test",
    app_metadata: { provider: "google", providers: ["google"] },
    user_metadata: {},
    created_at: "2026-11-07T00:00:00.000Z",
    updated_at: "2026-11-07T00:00:00.000Z",
  },
};

test("Supabase SSR exchanges a PKCE code, persists session cookies, and removes the verifier", async () => {
  const { cookieStore, values, writes } = createQa249CookieStore();
  const authRequests: Array<{ url: string; method: string; body: string }> = [];
  const authFetch: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    authRequests.push({
      url: request.url,
      method: request.method,
      body: await request.clone().text(),
    });

    return new Response(JSON.stringify(qa249SessionResponse), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };
  const supabase = createQa249SupabaseClient(cookieStore, authFetch);

  const oauth = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: {
      redirectTo: "https://qimatrade.example/auth/callback",
      skipBrowserRedirect: true,
    },
  });
  expect(oauth.error).toBeNull();

  const verifierName = Array.from(values.keys()).find((name) =>
    name.endsWith("-code-verifier"),
  );
  expect(verifierName).toBeDefined();
  expect(values.get(verifierName!)?.value.length).toBeGreaterThan(0);

  const exchange = await supabase.auth.exchangeCodeForSession("qa249-auth-code");

  expect(exchange.error).toBeNull();
  expect(exchange.data.session?.access_token).toBe("qa249-access-token");
  expect(exchange.data.session?.refresh_token).toBe("qa249-refresh-token");
  expect(exchange.data.user?.id).toBe("00000000-0000-4000-8000-00000000249");

  expect(authRequests).toHaveLength(1);
  const tokenRequest = authRequests[0];
  const requestUrl = new URL(tokenRequest.url);
  const requestBody = JSON.parse(tokenRequest.body) as {
    auth_code?: string;
    code_verifier?: string;
  };
  expect(tokenRequest.method).toBe("POST");
  expect(requestUrl.pathname).toBe("/auth/v1/token");
  expect(requestUrl.searchParams.get("grant_type")).toBe("pkce");
  expect(requestBody.auth_code).toBe("qa249-auth-code");
  expect(requestBody.code_verifier).toBeTruthy();

  expect(
    writes.some(
      ({ name, value, options }) =>
        name === verifierName && (value === "" || options.maxAge === 0),
    ),
  ).toBe(true);
  expect(values.has(verifierName!)).toBe(false);

  const persistedSessionCookieNames = Array.from(values.keys()).filter(
    (name) => name.includes("-auth-token") && !name.endsWith("-code-verifier"),
  );
  expect(persistedSessionCookieNames.length).toBeGreaterThan(0);
  expect(
    writes.some(
      ({ name, value }) =>
        name.includes("-auth-token") &&
        !name.endsWith("-code-verifier") &&
        value.length > 0,
    ),
  ).toBe(true);
});

test("Supabase SSR does not persist a session and defers verifier-cookie removal after token exchange fails", async () => {
  const { cookieStore, values, writes } = createQa249CookieStore();
  const authRequests: Array<{ url: string; method: string }> = [];
  const authFetch: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    authRequests.push({ url: request.url, method: request.method });

    return new Response(
      JSON.stringify({
        code: "invalid_grant",
        error: "invalid_grant",
        error_description: "Synthetic invalid authorization code",
      }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      },
    );
  };
  const supabase = createQa249SupabaseClient(cookieStore, authFetch);

  const oauth = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: {
      redirectTo: "https://qimatrade.example/auth/callback",
      skipBrowserRedirect: true,
    },
  });
  expect(oauth.error).toBeNull();

  const verifierName = Array.from(values.keys()).find((name) =>
    name.endsWith("-code-verifier"),
  );
  expect(verifierName).toBeDefined();

  const exchange = await supabase.auth.exchangeCodeForSession("qa249-invalid-code");

  expect(exchange.error).not.toBeNull();
  expect(exchange.data.session).toBeNull();
  expect(exchange.data.user).toBeNull();
  expect(authRequests).toHaveLength(1);
  expect(new URL(authRequests[0].url).searchParams.get("grant_type")).toBe("pkce");
  // @supabase/ssr 0.7.0 records this removal in request-local storage but
  // flushes cookie mutations only after an auth-state event. A failed exchange
  // emits no such event, so the external cookie store still contains the old
  // verifier even though this client no longer exposes it to a second attempt.
  expect(values.has(verifierName!)).toBe(true);
  expect(
    writes.some(
      ({ name, value, options }) =>
        name === verifierName && (value === "" || options.maxAge === 0),
    ),
  ).toBe(false);

  const secondAttempt = await supabase.auth.exchangeCodeForSession("qa249-second-code");
  expect(secondAttempt.error).not.toBeNull();
  expect(authRequests).toHaveLength(1);

  expect(
    writes.some(
      ({ name, value }) =>
        name.includes("-auth-token") &&
        !name.endsWith("-code-verifier") &&
        value.length > 0,
    ),
  ).toBe(false);
});
