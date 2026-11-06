import { createSupabaseServerClient } from "@/lib/supabase/server";
import { getSafeRedirectUrl } from "@/lib/auth/safe-redirect";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const redirectUrl = getSafeRedirectUrl(
    requestUrl.searchParams.get("next"),
    requestUrl.origin,
  );

  if (!code) {
    return NextResponse.redirect(new URL("/login?error=oauth_callback_missing_code", requestUrl.origin));
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    return NextResponse.redirect(new URL("/login?error=oauth_callback_failed", requestUrl.origin));
  }

  return NextResponse.redirect(redirectUrl);
}
