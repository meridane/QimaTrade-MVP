import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { executeUniversalAction } from "@/lib/actions/runtime";
import { randomUUID } from "crypto";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const requestId = typeof body.requestId === "string" ? body.requestId.trim() : "";
    if (!requestId) return NextResponse.json({ error: "requestId is required" }, { status: 400 });

    const supabase = await createSupabaseServerClient();
    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData.user) return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });

    const { data: membership, error: membershipError } = await supabase
      .from("dt_memberships")
      .select("tenant_id")
      .eq("user_id", authData.user.id)
      .limit(1)
      .maybeSingle();
    if (membershipError || !membership?.tenant_id) return NextResponse.json({ error: "TENANT_MEMBERSHIP_REQUIRED" }, { status: 403 });

    const result = await executeUniversalAction(
      {
        userId: authData.user.id,
        tenantId: membership.tenant_id,
        actionKey: "PUBLISH_PRODUCT_REQUEST",
        actionVersion: 1,
        objectType: "ProductRequest",
        objectId: requestId,
        correlationId: randomUUID(),
        idempotencyKey: body.idempotencyKey?.trim() || randomUUID(),
      },
      { requestId },
      (await supabase.auth.getSession()).data.session?.access_token ?? "",
    );

    return NextResponse.json({ result }, { status: result.status === "succeeded" ? 200 : 409 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to publish product request";
    const known = ["PRODUCT_REQUEST_NOT_FOUND", "PRODUCT_MASTER_NOT_FOUND", "ACTOR_NOT_LINKED", "UNAUTHENTICATED", "PRODUCT_REQUEST_ID_REQUIRED"];
    const status = known.some((code) => message.includes(code)) ? 400 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
