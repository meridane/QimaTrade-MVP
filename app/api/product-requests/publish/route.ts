import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { executeUniversalAction } from "@/lib/actions/runtime";
import { randomUUID } from "crypto";

export const dynamic = "force-dynamic";

const publicPublishErrorCodes = new Set([
  "PRODUCT_REQUEST_NOT_FOUND",
  "PRODUCT_MASTER_NOT_FOUND",
  "ACTOR_NOT_LINKED",
  "UNAUTHENTICATED",
  "PRODUCT_REQUEST_ID_REQUIRED",
]);

export async function POST(request: NextRequest) {
  try {
    let parsedBody: unknown;
    try {
      parsedBody = await request.json();
    } catch {
      return NextResponse.json({ error: "INVALID_REQUEST_BODY" }, { status: 400 });
    }

    if (!parsedBody || typeof parsedBody !== "object" || Array.isArray(parsedBody)) {
      return NextResponse.json({ error: "INVALID_REQUEST_BODY" }, { status: 400 });
    }

    const body = parsedBody as Record<string, unknown>;
    const requestId = typeof body.requestId === "string" ? body.requestId.trim() : "";
    if (!requestId) {
      return NextResponse.json({ error: "requestId is required" }, { status: 400 });
    }

    const supabase = await createSupabaseServerClient();
    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData.user) {
      return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });
    }

    const { data: memberships, error: membershipError } = await supabase
      .from("dt_memberships")
      .select("tenant_id")
      .eq("user_id", authData.user.id);

    if (membershipError || !memberships?.length) {
      return NextResponse.json({ error: "TENANT_MEMBERSHIP_REQUIRED" }, { status: 403 });
    }

    // Never bind an action to an arbitrary tenant when the user belongs to several.
    const tenantIds = [...new Set(memberships.map((membership) => membership.tenant_id).filter(Boolean))];
    if (tenantIds.length !== 1) {
      return NextResponse.json(
        {
          error: "TENANT_SELECTION_REQUIRED",
          message: "Select an active tenant before publishing a product request.",
        },
        { status: 409 },
      );
    }

    const result = await executeUniversalAction(
      {
        userId: authData.user.id,
        tenantId: tenantIds[0],
        actionKey: "PUBLISH_PRODUCT_REQUEST",
        actionVersion: 1,
        objectType: "ProductRequest",
        objectId: requestId,
        correlationId: randomUUID(),
        idempotencyKey:
          typeof body.idempotencyKey === "string" && body.idempotencyKey.trim()
            ? body.idempotencyKey.trim()
            : randomUUID(),
      },
      { requestId },
      (await supabase.auth.getSession()).data.session?.access_token ?? "",
    );

    return NextResponse.json({ result }, { status: result.status === "succeeded" ? 200 : 409 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "";
    if (publicPublishErrorCodes.has(message)) {
      const publicCode = message;
      return NextResponse.json({ error: publicCode }, { status: 400 });
    }
    return NextResponse.json({ error: "Unable to publish product request." }, { status: 500 });
  }
}
