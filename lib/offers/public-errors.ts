/**
 * Convert private product-attribute lookup failures into a stable client-safe message.
 * Supabase/PostgREST diagnostics must remain server-side.
 */
export function toPublicOfferContextError(_error: unknown): string {
  return "Unable to load product attributes.";
}
