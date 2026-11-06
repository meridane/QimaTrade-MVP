import { NextResponse } from "next/server";
import { getSafeRedirectUrl } from "./safe-redirect";

type OAuthClient = {
  auth: {
    exchangeCodeForSession(code: string): Promise<{ error: unknown | null }>;
  };
};

type OAuthClientFactory = () => Promise<OAuthClient>;

export async function handleOAuthCallback(
  request: Request,
  createClient: OAuthClientFactory,
) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const redirectUrl = getSafeRedirectUrl(
    requestUrl.searchParams.get("next"),
    requestUrl.origin,
  );

  if (!code) {
    return NextResponse.redirect(
      new URL("/login?error=oauth_callback_missing_code", requestUrl.origin),
    );
  }

  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (error) {
      return NextResponse.redirect(
        new URL("/login?error=oauth_callback_failed", requestUrl.origin),
      );
    }

    return NextResponse.redirect(redirectUrl);
  } catch {
    return NextResponse.redirect(
      new URL("/login?error=oauth_callback_failed", requestUrl.origin),
    );
  }
}
