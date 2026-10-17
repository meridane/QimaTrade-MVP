import { expect, test } from "@playwright/test";

test("login page displays Google authentication", async ({ page }) => {
  await page.goto("/login");

  await expect(page.getByRole("heading", { name: "Sign in to continue" })).toBeVisible();
  await expect(page.getByRole("button", { name: /continue with google/i })).toBeVisible();
});

test("login page explains a failed OAuth callback", async ({ page }) => {
  await page.goto("/login?error=oauth_callback_failed");

  await expect(
    page.getByText("We could not complete your Google sign-in. Please try again.", { exact: true }),
  ).toBeVisible();
});

test("OAuth callback without a code returns to login with a clear error", async ({ page }) => {
  await page.goto("/auth/callback");

  await expect(page).toHaveURL(/\/login\?error=oauth_callback_missing_code/);
  await expect(
    page.getByText("Google sign-in did not return a valid authorization code. Please try again.", { exact: true }),
  ).toBeVisible();
});
