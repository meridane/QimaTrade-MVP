import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "crypto";
import { executeUniversalAction } from "@/lib/actions/runtime";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const authHeader = request.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });
    }

    const token = authHeader.slice("Bearer ".length);
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { auth: { autoRefreshToken: false, persistSession: false }, global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user) return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });

    const body = await request.json();
    const { data: profile, error: profileError } = await supabase.from("profiles").select("actor_id").eq("auth_user_id", user.id).maybeSingle();
    if (profileError || !profile?.actor_id) return NextResponse.json({ error: "PROFILE_ACTOR_NOT_FOUND" }, { status: 403 });

    const { data: membership, error: membershipError } = await supabase.from("dt_memberships").select("tenant_id").eq("user_id", user.id).limit(1).maybeSingle();
    if (membershipError || !membership?.tenant_id) return NextResponse.json({ error: "TENANT_MEMBERSHIP_REQUIRED" }, { status: 403 });

    const input = {
      name: String(body.name ?? "Offer"),
      demandId: String(body.demandId ?? ""),
      productMasterId: String(body.productMasterId ?? ""),
      providerActorId: profile.actor_id,
      quantity: Number(body.quantity),
      price: Number(body.price),
      currency: String(body.currency ?? ""),
      pricingModel: body.pricingModel == null ? null : String(body.pricingModel),
      conditions: body.conditions == null ? null : String(body.conditions),
      market: body.market == null ? null : String(body.market),
      geography: body.geography == null ? null : String(body.geography),
      attributes: body.attributes ?? {},
      documentationStatus: body.documentationStatus == null ? null : String(body.documentationStatus),
      lifecycle: body.lifecycle == null ? null : String(body.lifecycle),
      offerType: body.offerType == null ? null : String(body.offerType),
    };

    const result = await executeUniversalAction({
      userId: user.id,
      tenantId: membership.tenant_id,
      actionKey: "CREATE_OFFER",
      actionVersion: 1,
      objectType: "Demand",
      objectId: input.demandId,
      correlationId: body.correlationId?.trim() || randomUUID(),
      idempotencyKey: body.idempotencyKey?.trim() || randomUUID(),
    }, input, token);

    return NextResponse.json(result, { status: result.status === "succeeded" ? 200 : 409 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "ACTION_FAILED";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
