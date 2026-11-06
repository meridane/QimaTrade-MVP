import { expect, test } from "@playwright/test";
import type { CookieOptions } from "@supabase/ssr";
import { createSupabaseCookieMethods } from "../../lib/supabase/cookie-methods";

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
