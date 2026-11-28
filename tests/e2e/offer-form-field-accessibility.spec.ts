import { expect, test } from "@playwright/test";
import { authenticatePage } from "./offer-test-auth";

const PRODUCT_MASTER_GATE_ID = "60000000-0000-4000-8000-00000000336";

test("offer draft form exposes accessible field names and native validation constraints", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  const offerName = page.getByRole("textbox", { name: "Offer name" });
  const quantity = page.getByRole("spinbutton", { name: "Quantity" });
  const price = page.getByRole("spinbutton", { name: "Price" });
  const currency = page.getByRole("combobox", { name: "Currency" });

  await expect(offerName).toBeVisible();
  await expect(offerName).toHaveAttribute("required", "");
  await expect(quantity).toBeVisible();
  await expect(quantity).toHaveAttribute("required", "");
  await expect(quantity).toHaveAttribute("min", "0.000001");
  await expect(quantity).toHaveAttribute("step", "any");

  await expect(price).toBeVisible();
  await expect(price).not.toHaveAttribute("required");
  await expect(price).toHaveAttribute("min", "0");

  await expect(currency).toBeVisible();
  await expect(currency).toHaveValue("USD");
  await expect(currency.locator("option")).toHaveCount(5);
});
