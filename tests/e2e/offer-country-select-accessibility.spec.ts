import { expect, test } from "@playwright/test";

test("offer market selector has a field name and exposes its choices as buttons", async ({ page }) => {
  await page.goto("/offers/new");

  const marketTrigger = page.getByRole("button", {
    name: "Target market: Select a target market",
  });
  await expect(marketTrigger).toBeVisible();
  await expect(marketTrigger).toHaveAttribute("aria-expanded", "false");
  await expect(page.getByRole("button", { name: /^Supplier geography: / })).toBeVisible();

  await marketTrigger.click();
  await expect(marketTrigger).toHaveAttribute("aria-expanded", "true");

  const choices = page.getByRole("group", { name: "Target market options" });
  await expect(choices).toBeVisible();
  await expect(choices.getByRole("button", { name: "International Market" })).toBeVisible();
  await expect(choices.getByRole("button", { name: "South Korea" })).toBeVisible();
  await expect(page.getByRole("listbox")).toHaveCount(0);
});
