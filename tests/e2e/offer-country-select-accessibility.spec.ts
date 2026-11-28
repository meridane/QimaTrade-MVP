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

  const marketLabel = page.getByText("Target market", { exact: true });
  await expect(marketLabel).toHaveAttribute("for", "market");
  await expect(marketTrigger).toHaveAttribute("id", "market");
  await marketLabel.click();
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
  await search.fill("France");
  await expect(choices.getByRole("button", { name: "France", exact: true })).toBeVisible();

  await page.keyboard.press("Escape");
  await expect(geographyTrigger).toHaveAttribute("aria-expanded", "false");
  await expect(geographyTrigger).not.toHaveAttribute("aria-controls");
  await expect(geographyTrigger).toBeFocused();
  await expect(choices).toHaveCount(0);

  await geographyTrigger.click();
  await expect(geographyTrigger).toHaveAttribute("aria-expanded", "true");
  const reopenedChoicesId = await geographyTrigger.getAttribute("aria-controls");
  expect(reopenedChoicesId).toBeTruthy();
  await expect(choices).toHaveAttribute("id", reopenedChoicesId!);
  await expect(search).toHaveValue("");
  await expect(search).toBeFocused();
  await search.fill("qima-no-matching-country-2026");
  const emptyResults = choices.getByRole("status");
  await expect(emptyResults).toHaveText("No country found.");
  await expect(emptyResults).toHaveAttribute("aria-live", "polite");

  await search.fill("  mOrOcCo  ");

  const morocco = choices.getByRole("button", { name: "Morocco", exact: true });
  await expect(morocco).toBeVisible();
  await expect(choices.getByRole("button", { name: "France", exact: true })).toHaveCount(0);
  await morocco.click();

  await expect(geographyTrigger).toHaveAccessibleName("Supplier geography: Morocco");
  await expect(geographyTrigger).toHaveAttribute("aria-expanded", "false");
  await expect(geographyTrigger).not.toHaveAttribute("aria-controls");
  await expect(geographyTrigger).toBeFocused();
});



test("offer commercial-term and documentation toggles expose their fieldset group names", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  const commercialGroup = page.getByRole("group", { name: "Commercial terms" });
  const documentationGroup = page.getByRole("group", { name: "Documentation available" });
  await expect(commercialGroup).toBeVisible();
  await expect(documentationGroup).toBeVisible();

  const exw = commercialGroup.getByRole("button", { name: "EXW", exact: true });
  await expect(exw).toHaveAttribute("aria-pressed", "false");
  await exw.focus();
  await expect(exw).toBeFocused();
  await page.keyboard.press("Space");
  await expect(exw).toHaveAttribute("aria-pressed", "true");

  const invoice = documentationGroup.getByRole("button", { name: "Commercial Invoice", exact: true });
  await expect(invoice).toHaveAttribute("aria-pressed", "false");
  await invoice.focus();
  await expect(invoice).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(invoice).toHaveAttribute("aria-pressed", "true");

  const otherCommercialButton = commercialGroup.getByRole("button", { name: "Other", exact: true });
  const otherCommercialInput = commercialGroup.getByRole("textbox", { name: "Other commercial term" });
  await otherCommercialButton.focus();
  await expect(otherCommercialButton).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(otherCommercialInput).toBeFocused();

  const otherDocumentationButton = documentationGroup.getByRole("button", { name: "Other", exact: true });
  await otherDocumentationButton.focus();
  await page.keyboard.press("Space");
  await expect(otherDocumentationButton).toHaveAttribute("aria-pressed", "true");
  const otherDocumentationInput = documentationGroup.getByRole("textbox", { name: "Other documentation" });
  await expect(otherDocumentationInput).toBeVisible();
  await page.keyboard.press("Tab");
  await expect(otherDocumentationInput).toBeFocused();
  await page.keyboard.press("Shift+Tab");
  await expect(otherDocumentationButton).toBeFocused();
});


test("offer country search announces an empty result set through a polite status", async ({ page, request }) => {
  await authenticatePage(page, request, "/offers/new?productMasterId=" + PRODUCT_MASTER_GATE_ID);
  await page.goto("/offers/new?productMasterId=" + PRODUCT_MASTER_GATE_ID);

  const marketTrigger = page.getByRole("button", { name: /^Target market: / });
  await marketTrigger.click();

  const search = page.getByRole("textbox", { name: "Search countries" });
  await search.fill("qima-no-country-match-20261128");

  const emptyStatus = page.getByRole("status").filter({ hasText: "No country found." });
  await expect(emptyStatus).toHaveText("No country found.");
  await expect(emptyStatus).toHaveAttribute("aria-live", "polite");
});


test("offer country selectors preserve their values in native form data", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  const marketTrigger = page.getByRole("button", { name: /^Target market: / });
  await marketTrigger.click();
  const marketOptions = page.getByRole("group", { name: "Target market options" });
  const marketSearch = page.getByRole("textbox", { name: "Search countries" });
  await marketSearch.fill("South Korea");
  await marketOptions.getByRole("button", { name: "South Korea", exact: true }).click();

  const geographyTrigger = page.getByRole("button", { name: /^Supplier geography: / });
  await geographyTrigger.click();
  const geographyOptions = page.getByRole("group", { name: "Supplier geography options" });
  const geographySearch = page.getByRole("textbox", { name: "Search countries" });
  await geographySearch.fill("Morocco");
  await geographyOptions.getByRole("button", { name: "Morocco", exact: true }).click();

  const serialized = await page.locator("form").evaluate((element) => {
    const formData = new FormData(element as HTMLFormElement);
    return {
      market: formData.get("market"),
      geography: formData.get("geography"),
    };
  });
  expect(serialized).toEqual({ market: "South Korea", geography: "Morocco" });
});

test("offer commercial terms and documentation serialize selected and custom values into native form data", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  const commercialGroup = page.getByRole("group", { name: "Commercial terms" });
  const documentationGroup = page.getByRole("group", { name: "Documentation available" });

  const exw = commercialGroup.getByRole("button", { name: "EXW", exact: true });
  const invoice = documentationGroup.getByRole("button", { name: "Commercial Invoice", exact: true });
  await exw.click();
  await invoice.click();
  await expect(exw).toHaveAttribute("aria-pressed", "true");
  await expect(invoice).toHaveAttribute("aria-pressed", "true");

  const otherCommercialButton = commercialGroup.getByRole("button", { name: "Other", exact: true });
  const otherCommercialInput = commercialGroup.getByRole("textbox", { name: "Other commercial term" });
  await otherCommercialButton.click();
  await expect(otherCommercialInput).toBeFocused();
  await otherCommercialInput.fill("  Custom inspection window  ");

  const otherDocumentationButton = documentationGroup.getByRole("button", { name: "Other", exact: true });
  await otherDocumentationButton.click();
  await expect(otherDocumentationButton).toHaveAttribute("aria-pressed", "true");
  const otherDocumentationInput = documentationGroup.getByRole("textbox", { name: "Other documentation" });
  await expect(otherDocumentationInput).toBeVisible();
  await otherDocumentationInput.fill("  Mill test report  ");

  const serialized = await page.locator("form").evaluate((element) => {
    const formData = new FormData(element as HTMLFormElement);
    return {
      conditions: formData.get("conditions"),
      documentation: formData.get("documentation"),
    };
  });

  expect(serialized).toEqual({
    conditions: "EXW, Other: Custom inspection window",
    documentation: "Commercial Invoice, Other: Mill test report",
  });
});

test("deselecting Other documentation excludes stale custom text from native form data", async ({ page, request }) => {
  await authenticatePage(page, request, `/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);
  await page.goto(`/offers/new?productMasterId=${PRODUCT_MASTER_GATE_ID}`);

  const documentationGroup = page.getByRole("group", { name: "Documentation available" });
  const invoice = documentationGroup.getByRole("button", { name: "Commercial Invoice", exact: true });
  const otherButton = documentationGroup.getByRole("button", { name: "Other", exact: true });

  await invoice.click();
  await otherButton.click();
  await expect(otherButton).toHaveAttribute("aria-pressed", "true");

  const otherInput = documentationGroup.getByRole("textbox", { name: "Other documentation" });
  await otherInput.fill("Mill test report");

  await otherButton.click();
  await expect(otherButton).toHaveAttribute("aria-pressed", "false");
  await expect(otherInput).toBeHidden();

  const serialized = await page.locator("form").evaluate((element) => {
    const formData = new FormData(element as HTMLFormElement);
    return formData.get("documentation");
  });

  expect(serialized).toBe("Commercial Invoice");
});

