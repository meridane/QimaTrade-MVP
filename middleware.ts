import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    return response;
  }

  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value, options }) => {
          request.cookies.set(name, value);
          response = NextResponse.next({ request });
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  const { data: { user } } = await supabase.auth.getUser();
  const path = request.nextUrl.pathname;
  const protectedPath =
    path.startsWith("/demands") ||
    path.startsWith("/decision-tree") ||
    path.startsWith("/offers") ||
    path.startsWith("/request");

  if (!user && protectedPath) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = "/login";
    loginUrl.searchParams.set("next", `${path}${request.nextUrl.search}`);
    return NextResponse.redirect(loginUrl);
  }

  if (path === "/offers/new" && !request.nextUrl.searchParams.get("productMasterId")) {
    const treeUrl = request.nextUrl.clone();
    treeUrl.pathname = "/decision-tree";
    treeUrl.searchParams.set("flow", "supplier");
    response.cookies.set("qimatrade_flow", "supplier", {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge: 10 * 60,
    });
    return NextResponse.redirect(treeUrl);
  }

  if (path === "/request/new" && request.cookies.get("qimatrade_flow")?.value === "supplier") {
    const productMasterId = request.nextUrl.searchParams.get("productMasterId");
    if (productMasterId) {
      const offerUrl = request.nextUrl.clone();
      offerUrl.pathname = "/offers/new";
      offerUrl.searchParams.delete("demandId");
      offerUrl.searchParams.delete("productMasterId");
      offerUrl.searchParams.set("productMasterId", productMasterId);
      response.cookies.delete("qimatrade_flow");
      return NextResponse.redirect(offerUrl);
    }
  }

  if (path === "/decision-tree" && request.nextUrl.searchParams.get("flow") === "supplier") {
    response.cookies.set("qimatrade_flow", "supplier", {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge: 10 * 60,
    });
  }

  return response;
}

export const config = {
  matcher: [
    "/demands/:path*",
    "/decision-tree/:path*",
    "/offers/:path*",
    "/request/:path*",
  ],
};
