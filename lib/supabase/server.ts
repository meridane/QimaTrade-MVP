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
