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
