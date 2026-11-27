/**
 * Convert private product-attribute lookup failures into a stable client-safe message.
 * Supabase/PostgREST diagnostics must remain server-side.
 */
export function toPublicOfferContextError(_error: unknown): string {
  return "Unable to load product attributes.";
}

const publicCreateOfferErrorCodes = new Set([
  "ACTION_NOT_PUBLISHED",
  "UNAUTHENTICATED",
  "TENANT_REQUIRED",
  "IDEMPOTENCY_KEY_REQUIRED",
  "ACTION_INPUT_REQUIRED",
  "TENANT_ACCESS_DENIED",
  "PROFILE_ACTOR_NOT_FOUND",
  "INVALID_PROVIDER_ACTOR",
  "INVALID_QUANTITY",
  "INVALID_PRICE",
  "INVALID_CURRENCY",
  "PRODUCT_MASTER_NOT_FOUND",
  "DEMAND_NOT_FOUND",
  "IDEMPOTENCY_KEY_REUSE",
  "ACTION_ALREADY_RUNNING",
]);

/**
 * Preserve only documented CREATE_OFFER domain codes across the server-action boundary.
 * Unexpected Supabase/PostgREST diagnostics are replaced with a stable public message.
 */
export function toPublicCreateOfferError(error: unknown): string {
  const candidate = error instanceof Error ? error.message : "";
  return publicCreateOfferErrorCodes.has(candidate)
    ? candidate
    : "Unable to create the offer. Please try again.";
}
