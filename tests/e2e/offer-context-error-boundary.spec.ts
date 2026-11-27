import { readFile } from "node:fs/promises";
import { expect, test } from "@playwright/test";
import { toPublicOfferContextError } from "../../lib/offers/public-errors";

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
  const source = await readFile(
    new URL("../../app/offers/actions.ts", import.meta.url),
    "utf8",
  );
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
