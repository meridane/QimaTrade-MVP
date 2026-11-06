import { expect, test } from "@playwright/test";
import { getSafeRedirectUrl } from "../../lib/auth/safe-redirect";

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
