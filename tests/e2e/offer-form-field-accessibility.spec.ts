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


test("native required and minimum constraints block offer API submission", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  const marketTrigger = page.getByRole("button", {
    name: "Target market: Select a target market",
  });
  await marketTrigger.click();
  await page
    .getByRole("group", { name: "Target market options" })
    .getByRole("button", { name: "South Korea", exact: true })
    .click();

  const geographyTrigger = page.getByRole("button", { name: /^Supplier geography: / });
  await geographyTrigger.click();
  await page
    .getByRole("group", { name: "Supplier geography options" })
    .getByRole("button", { name: "Morocco", exact: true })
    .click();

  const offerName = page.getByRole("textbox", { name: "Offer name" });
  const quantity = page.getByRole("spinbutton", { name: "Quantity" });
  const submit = page.getByRole("button", { name: "Create offer" });
  let apiRequests = 0;

  await page.route("**/api/offers", async (route) => {
    apiRequests += 1;
    await route.fulfill({ status: 500, body: "Unexpected invalid form submission" });
  });

  await offerName.fill("QA offer");
  await quantity.fill("0");
  await expect(submit).toBeEnabled();
  await submit.click();

  await expect(quantity).toBeFocused();
  expect(await quantity.evaluate((element) => (element as HTMLInputElement).validity.rangeUnderflow)).toBe(true);
  expect(apiRequests).toBe(0);

  await quantity.fill("1");
  await offerName.fill("");
  await submit.click();

  await expect(offerName).toBeFocused();
  expect(await offerName.evaluate((element) => (element as HTMLInputElement).validity.valueMissing)).toBe(true);
  expect(apiRequests).toBe(0);
});
