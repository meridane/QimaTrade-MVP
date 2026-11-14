import {
  clearSupabasePkceVerifierCookies,
  createSupabaseServerClient,
} from "@/lib/supabase/server";
import { handleOAuthCallback } from "@/lib/auth/oauth-callback";

export async function GET(request: Request) {
  return handleOAuthCallback(
    request,
    createSupabaseServerClient,
    clearSupabasePkceVerifierCookies,
  );
}
