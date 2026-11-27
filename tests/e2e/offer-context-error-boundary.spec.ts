import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { expect, test } from "@playwright/test";
import { toPublicCreateOfferError, toPublicOfferContextError } from "../../lib/offers/public-errors";

test("offer context lookup failures never expose backend diagnostics", () => {
  const privateMessage = "PRIVATE_OFFER_CONTEXT_DATABASE_SENTINEL";
  const failures: unknown[] = [
    new Error(privateMessage),
    {
      message: privateMessage,
      details: "PRIVATE_POSTGREST_DETAILS_SENTINEL",
      hint: "PRIVATE_POSTGREST_HINT_SENTINEL",
      code: "XX000",
    },
  ];

  for (const failure of failures) {
    const publicMessage = toPublicOfferContextError(failure);

    expect(publicMessage).toBe("Unable to load product attributes.");
    expect(publicMessage).not.toContain(privateMessage);
    expect(publicMessage).not.toContain("PRIVATE_POSTGREST_DETAILS_SENTINEL");
    expect(publicMessage).not.toContain("PRIVATE_POSTGREST_HINT_SENTINEL");
    expect(publicMessage).not.toContain("XX000");
  }
});


test("getOfferContext routes every attribute lookup failure through the public error mapper", async () => {
  const source = await readFile(resolve(process.cwd(), "app/offers/actions.ts"), "utf8");
  const start = source.indexOf("export async function getOfferContext");
  const end = source.indexOf("export async function createOffer", start);

  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);

  const getOfferContextSource = source.slice(start, end);
  expect(source).toContain(
    'import { toPublicOfferContextError } from "@/lib/offers/public-errors";',
  );
  expect(getOfferContextSource).toContain("toPublicOfferContextError(rowsError)");
  expect(getOfferContextSource).toContain(
    "toPublicOfferContextError(definitionsResult.error ?? optionsResult.error ?? unitsResult.error)",
  );
  expect(getOfferContextSource).not.toMatch(
    /(?:rowsError|definitionsResult\.error|optionsResult\.error|unitsResult\.error)\??\.message/,
  );
});

test("create-offer server-action errors expose only allowlisted domain codes", () => {
  expect(toPublicCreateOfferError(new Error("ACTION_ALREADY_RUNNING"))).toBe("ACTION_ALREADY_RUNNING");
  expect(toPublicCreateOfferError(new Error("INVALID_CURRENCY"))).toBe("INVALID_CURRENCY");

  const privateFailure = {
    message: "PRIVATE_CREATE_OFFER_DATABASE_SENTINEL",
    details: "PRIVATE_CREATE_OFFER_POSTGREST_DETAILS",
    hint: "PRIVATE_CREATE_OFFER_POSTGREST_HINT",
    code: "XX000",
  };
  const publicMessage = toPublicCreateOfferError(privateFailure);

  expect(publicMessage).toBe("Unable to create the offer. Please try again.");
  expect(publicMessage).not.toContain("PRIVATE_CREATE_OFFER_DATABASE_SENTINEL");
  expect(publicMessage).not.toContain("PRIVATE_CREATE_OFFER_POSTGREST_DETAILS");
  expect(publicMessage).not.toContain("PRIVATE_CREATE_OFFER_POSTGREST_HINT");
  expect(publicMessage).not.toContain("XX000");
});

test("createOffer catches runtime failures and returns the public error mapper result", async () => {
  const source = await readFile(resolve(process.cwd(), "app/offers/actions.ts"), "utf8");
  const start = source.indexOf("export async function createOffer");
  expect(start).toBeGreaterThanOrEqual(0);
  const createOfferSource = source.slice(start);
  expect(createOfferSource).toContain("try {");
  expect(createOfferSource).toContain("toPublicCreateOfferError(error)");
});
