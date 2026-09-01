import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "crypto";
import { executeCreateOffer } from "@/lib/actions/create-offer";
import type { ActionContext, CreateOfferInput } from "@/lib/actions/types";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const body = (await request.json()) as Partial<CreateOfferInput> & {
      idempotencyKey?: string;
      correlationId?: string;
    };

    const authHeader = request.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });
    }

    const token = authHeader.slice("Bearer ".length);
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user) {
      return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("actor_id")
      .eq("auth_user_id", user.id)
      .maybeSingle();

    if (profileError || !profile?.actor_id) {
      return NextResponse.json({ error: "PROFILE_ACTOR_NOT_FOUND" }, { status: 403 });
    }

    const { data: membership } = await supabase
      .from("dt_memberships")
      .select("tenant_id")
      .eq("user_id", user.id)
      .limit(1)
      .maybeSingle();

    if (!membership?.tenant_id) {
      return NextResponse.json({ error: "TENANT_MEMBERSHIP_REQUIRED" }, { status: 403 });
    }

    const input: CreateOfferInput = {
      demandId: body.demandId ?? "",
      productMasterId: body.productMasterId ?? "",
      quantity: Number(body.quantity),
      price: Number(body.price),
      currency: body.currency ?? "",
      pricingModel: body.pricingModel ?? null,
      conditions: body.conditions ?? null,
      market: body.market ?? null,
      geography: body.geography ?? null,
    };

    const actionKey = "CREATE_OFFER";
    const actionVersion = 1;
    const correlationId = body.correlationId ?? randomUUID();
    const idempotencyKey = body.idempotencyKey ?? randomUUID();

    const context: ActionContext = {
      userId: user.id,
      tenantId: membership.tenant_id,
      actionKey,
      actionVersion,
      objectType: "Demand",
      objectId: input.demandId,
      correlationId,
      idempotencyKey,
    };

    const result = await executeCreateOffer(context, input, {
      createOffer: async ({ context: actionContext, input: actionInput }) => {
        const { data, error } = await supabase.rpc("execute_create_offer_v1", {
          p_tenant_id: actionContext.tenantId,
          p_idempotency_key: actionContext.idempotencyKey,
          p_correlation_id: actionContext.correlationId,
          p_demand_id: actionInput.demandId,
          p_product_master_id: actionInput.productMasterId,
          p_quantity: actionInput.quantity,
          p_price: actionInput.price,
          p_currency: actionInput.currency,
          p_pricing_model: actionInput.pricingModel,
          p_conditions: actionInput.conditions,
          p_market: actionInput.market,
          p_geography: actionInput.geography,
        });

        if (error) throw new Error(error.message);
        return data as ActionResult;
      },
    });

    return NextResponse.json(result, { status: result.status === "succeeded" ? 200 : 409 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "ACTION_FAILED";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
