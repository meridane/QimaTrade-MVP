import { expect, test } from "@playwright/test";
import { getCreatedOfferId } from "../../lib/offers/created-offer-reference";

const OFFER_ID = "7d2d1f7e-7d4e-4f3e-9d8b-3f8d0e6f2c11";

test("offer confirmation accepts the UUID v4 reference emitted after a successful draft insert", () => {
  expect(getCreatedOfferId(`?created=${OFFER_ID}`)).toBe(OFFER_ID);
});

test("offer confirmation ignores missing, empty, or malformed references", () => {
  expect(getCreatedOfferId("")).toBeNull();
  expect(getCreatedOfferId("?created=")).toBeNull();
  expect(getCreatedOfferId("?created=not-a-uuid")).toBeNull();
  expect(getCreatedOfferId("?created=7d2d1f7e-7d4e-1f3e-9d8b-3f8d0e6f2c11")).toBeNull();
});

test("offer confirmation uses the first created query value and does not fall through to a later duplicate", () => {
  expect(getCreatedOfferId(`?created=invalid&created=${OFFER_ID}`)).toBeNull();
});
