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
