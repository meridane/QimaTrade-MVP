import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { createSupabaseCookieMethods } from "./cookie-methods";

export function createSupabaseServerClientOptions(
  cookieStore: Parameters<typeof createSupabaseCookieMethods>[0],
) {
  return {
    cookies: createSupabaseCookieMethods({
      getAll: () => cookieStore.getAll(),
      set: (name, value, options) => cookieStore.set(name, value, options),
    }),
  };
}

export async function createSupabaseServerClient() {
  const cookieStore = await cookies();

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY");
  }

  return createServerClient(
    supabaseUrl,
    supabaseAnonKey,
    createSupabaseServerClientOptions(cookieStore),
  );
}

type PkceVerifierCookieStore = {
  getAll(): Array<{ name: string; value: string }>;
  delete(name: string): unknown;
};

const supabasePkceVerifierCookieName = /^sb-.+-auth-token-code-verifier(?:\\.\\d+)?$/;

/**
 * Expires only Supabase auth code-verifier cookies, including any chunked
 * fragments. Session and unrelated application cookies are left untouched.
 */
export function clearSupabasePkceVerifierCookiesFromStore(
  cookieStore: PkceVerifierCookieStore,
): string[] {
  const verifierCookieNames = cookieStore
    .getAll()
    .map(({ name }) => name)
    .filter((name) => supabasePkceVerifierCookieName.test(name));

  for (const name of verifierCookieNames) {
    cookieStore.delete(name);
  }

  return verifierCookieNames;
}

export async function clearSupabasePkceVerifierCookies(): Promise<void> {
  const cookieStore = await cookies();
  clearSupabasePkceVerifierCookiesFromStore(cookieStore);
}
