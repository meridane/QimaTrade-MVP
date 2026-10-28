import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "crypto";
import { executeUniversalAction } from "../../../../lib/actions/runtime";

export const dynamic = "force-dynamic";
const currencies = new Set(["USD", "EUR", "KRW", "MAD", "CNY"]);

export async function POST(request: Request) {
  try {
    const authHeader = request.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });

    const token = authHeader.slice("Bearer ".length);
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { auth: { autoRefreshToken: false, persistSession: false }, global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user) return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });

    let body: Record<string, unknown>;
    try {
      const parsedBody: unknown = await request.json();
      if (!parsedBody || typeof parsedBody !== "object" || Array.isArray(parsedBody)) {
        return NextResponse.json({ error: "INVALID_REQUEST_BODY" }, { status: 400 });
      }
      body = parsedBody as Record<string, unknown>;
    } catch {
      return NextResponse.json({ error: "INVALID_REQUEST_BODY" }, { status: 400 });
    }

    const name = typeof body.name === "string" ? body.name.trim() : "";
    const demandId = typeof body.demandId === "string" ? body.demandId.trim() : "";
    const quantity =
      typeof body.quantity === "number"
        ? body.quantity
        : typeof body.quantity === "string" && body.quantity.trim()
          ? Number(body.quantity)
          : Number.NaN;
    const rawPrice = body.price;
    const price =
      typeof rawPrice === "number"
        ? rawPrice
        : typeof rawPrice === "string" && rawPrice.trim()
          ? Number(rawPrice)
          : Number.NaN;
    const currency = typeof body.currency === "string" ? body.currency.trim() : "";

    if (!name || !demandId) return NextResponse.json({ error: "NAME_AND_DEMAND_REQUIRED" }, { status: 400 });
    if (!Number.isFinite(quantity) || quantity <= 0) return NextResponse.json({ error: "INVALID_QUANTITY" }, { status: 400 });
    if (!Number.isFinite(price) || price < 0) return NextResponse.json({ error: "INVALID_PRICE" }, { status: 400 });
    if (!currencies.has(currency)) return NextResponse.json({ error: "INVALID_CURRENCY" }, { status: 400 });

    const { data: profile, error: profileError } = await supabase.from("profiles").select("actor_id").eq("auth_user_id", user.id).maybeSingle();
    if (profileError || !profile?.actor_id) return NextResponse.json({ error: "PROFILE_ACTOR_NOT_FOUND" }, { status: 403 });

    const { data: memberships, error: membershipError } = await supabase.from("dt_memberships").select("tenant_id").eq("user_id", user.id);
    if (membershipError || !memberships?.length) return NextResponse.json({ error: "TENANT_MEMBERSHIP_REQUIRED" }, { status: 403 });

    const tenantIds = [...new Set(memberships.map((membership) => membership.tenant_id).filter(Boolean))];
    if (tenantIds.length !== 1) {
      return NextResponse.json({ error: "TENANT_SELECTION_REQUIRED", message: "Select an active tenant before creating an offer." }, { status: 409 });
    }
    const tenantId = tenantIds[0];

    const input = {
      name,
      demandId,
      productMasterId: typeof body.productMasterId === "string" ? body.productMasterId.trim() : "",
      providerActorId: profile.actor_id,
      quantity,
      price,
      currency,
      pricingModel: body.pricingModel == null ? "fixed" : String(body.pricingModel),
      conditions: body.conditions == null ? null : String(body.conditions),
      market: body.market == null ? null : String(body.market),
      geography: body.geography == null ? null : String(body.geography),
      attributes: body.attributes && typeof body.attributes === "object" && !Array.isArray(body.attributes) ? body.attributes as Record<string, unknown> : {},
      documentationStatus: body.documentationStatus == null ? null : String(body.documentationStatus),
      lifecycle: body.lifecycle == null ? "draft" : String(body.lifecycle),
      offerType: body.offerType == null ? "supplier_offer" : String(body.offerType),
    };

    const result = await executeUniversalAction({
      userId: user.id,
      tenantId,
      actionKey: "CREATE_OFFER",
      actionVersion: 1,
      objectType: "Demand",
      objectId: input.demandId,
      correlationId: typeof body.correlationId === "string" && body.correlationId.trim() ? body.correlationId.trim() : randomUUID(),
      idempotencyKey: typeof body.idempotencyKey === "string" && body.idempotencyKey.trim() ? body.idempotencyKey.trim() : randomUUID(),
    }, input, token);

    return NextResponse.json(result, { status: result.status === "succeeded" ? 200 : 409 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "ACTION_FAILED";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
