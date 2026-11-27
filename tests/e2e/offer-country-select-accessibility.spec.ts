import { expect, test } from "@playwright/test";
import { authenticatePage } from "./offer-test-auth";

const PRODUCT_MASTER_GATE_ID = "60000000-0000-4000-8000-00000000336";

test("offer market selector has a field name and exposes its choices as buttons", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

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
  const optionsId = await marketTrigger.getAttribute("aria-controls");
  expect(optionsId).toBeTruthy();
  await expect(choices).toHaveAttribute("id", optionsId!);
  const countrySearch = page.getByRole("textbox", { name: "Search countries" });
  await expect(countrySearch).toBeVisible();
  await expect(countrySearch).toBeFocused();
  await expect(choices.getByRole("button", { name: "International Market" })).toBeVisible();
  await expect(choices.getByRole("button", { name: "South Korea" })).toBeVisible();
  await expect(page.getByRole("listbox")).toHaveCount(0);
});
test("offer country selector supports Escape and keyboard selection with focus restoration", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  const marketTrigger = page.getByRole("button", { name: /^Target market: / });
  await expect(marketTrigger).toHaveAccessibleName("Target market: Select a target market");

  await marketTrigger.click();
  await expect(page.getByRole("group", { name: "Target market options" })).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(marketTrigger).toHaveAttribute("aria-expanded", "false");
  await expect(marketTrigger).not.toHaveAttribute("aria-controls");
  await expect(marketTrigger).toBeFocused();

  await marketTrigger.click();
  const search = page.getByRole("textbox", { name: "Search countries" });
  await expect(search).toHaveValue("");
  await expect(search).toHaveAttribute("placeholder", "Search country...");
  await search.fill("South Korea");

  const choices = page.getByRole("group", { name: "Target market options" });
  const southKorea = choices.getByRole("button", { name: "South Korea", exact: true });
  await expect(southKorea).toBeVisible();
  await expect(choices.getByRole("button", { name: "Japan", exact: true })).toHaveCount(0);
  const internationalMarket = choices.getByRole("button", { name: "International Market", exact: true });
  await page.keyboard.press("Tab");
  await expect(internationalMarket).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(southKorea).toBeFocused();
  await page.keyboard.press("Enter");

  await expect(marketTrigger).toHaveAttribute("aria-expanded", "false");
  await expect(marketTrigger).not.toHaveAttribute("aria-controls");
  await expect(marketTrigger).toHaveAccessibleName("Target market: South Korea");
  await expect(marketTrigger).toBeFocused();
  await expect(choices).toHaveCount(0);
});

test("supplier geography selector exposes its own labelled options and restores focus", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  const geographyTrigger = page.getByRole("button", { name: /^Supplier geography: / });
  await expect(geographyTrigger).toBeVisible();
  await geographyTrigger.click();
  await expect(geographyTrigger).toHaveAttribute("aria-expanded", "true");

  const choices = page.getByRole("group", { name: "Supplier geography options" });
  await expect(choices).toBeVisible();
  const choicesId = await geographyTrigger.getAttribute("aria-controls");
  expect(choicesId).toBeTruthy();
  await expect(choices).toHaveAttribute("id", choicesId!);

  const search = page.getByRole("textbox", { name: "Search countries" });
  await expect(search).toBeFocused();
  await search.fill("Morocco");

  const morocco = choices.getByRole("button", { name: "Morocco", exact: true });
  await expect(morocco).toBeVisible();
  await expect(choices.getByRole("button", { name: "France", exact: true })).toHaveCount(0);
  await morocco.click();

  await expect(geographyTrigger).toHaveAccessibleName("Supplier geography: Morocco");
  await expect(geographyTrigger).toHaveAttribute("aria-expanded", "false");
  await expect(geographyTrigger).not.toHaveAttribute("aria-controls");
  await expect(geographyTrigger).toBeFocused();
});
