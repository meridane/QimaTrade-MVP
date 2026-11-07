import { expect, test } from "@playwright/test";
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
