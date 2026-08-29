import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const requestId = typeof body.requestId === "string" ? body.requestId : "";
    if (!requestId) return NextResponse.json({ error: "requestId is required" }, { status: 400 });

    const supabase = await createSupabaseServerClient();
    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData.user) return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });

    const { data, error } = await supabase.rpc("dt_publish_product_request", {
      p_request_id: requestId,
      p_user_id: authData.user.id,
    });

    if (error) {
      const known = ["PRODUCT_REQUEST_NOT_FOUND", "PRODUCT_MASTER_NOT_FOUND", "ACTOR_NOT_LINKED", "UNAUTHENTICATED"];
      const message = error.message;
      const status = known.some((code) => message.includes(code)) ? 400 : 500;
      return NextResponse.json({ error: message }, { status });
    }

    return NextResponse.json({ result: data });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to publish product request";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
