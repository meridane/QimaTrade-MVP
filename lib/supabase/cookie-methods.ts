import type { CookieOptions } from "@supabase/ssr";

type CookieStore = {
  getAll(): Array<{ name: string; value: string }>;
  set(name: string, value: string, options: CookieOptions): unknown;
};

type CookieMutation = {
  name: string;
  value: string;
  options: CookieOptions;
};

/**
 * Adapts the Next.js cookie store to Supabase SSR's getAll/setAll contract.
 * Route Handlers can mutate cookies; Server Components may reject writes.
 * A failed write is swallowed; the batch is not transactional, and later
 * mutations are skipped after the first rejected write.
 */
export function createSupabaseCookieMethods(cookieStore: CookieStore) {
  return {
    getAll() {
      return cookieStore.getAll();
    },
    setAll(cookiesToSet: CookieMutation[]) {
      try {
        cookiesToSet.forEach(({ name, value, options }) => {
          cookieStore.set(name, value, options);
        });
      } catch {
        // Server Components may not be able to mutate cookies.
      }
    },
  };
}
