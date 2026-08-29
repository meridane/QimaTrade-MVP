import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const currencies = new Set(["USD", "EUR", "KRW", "MAD", "CNY"]);

export async function POST(request: NextRequest) {
  try {
    const form = await request.formData();
    const name = String(form.get("name") ?? "").trim();
    const quantity = Number(form.get("quantity") ?? "");
    const priceRaw = String(form.get("price") ?? "").trim();
    const price = priceRaw ? Number(priceRaw) : null;
    const currency = String(form.get("currency") ?? "USD").trim();
    const conditions = String(form.get("conditions") ?? "").trim();
    const documentation = String(form.get("documentation") ?? "").trim();
    const market = String(form.get("market") ?? "").trim();
    const geography = String(form.get("geography") ?? "").trim();
    const demandId = String(form.get("demandId") ?? "").trim() || null;
    const productMasterIdFromForm = String(form.get("productMasterId") ?? "").trim() || null;

    if (!name || !Number.isFinite(quantity) || quantity <= 0) {
      return NextResponse.json({ error: "Please provide a valid offer name and quantity." }, { status: 400 });
    }
    if (price !== null && (!Number.isFinite(price) || price < 0)) {
      return NextResponse.json({ error: "Price must be a valid positive number." }, { status: 400 });
    }
    if (price !== null && !currencies.has(currency)) {
      return NextResponse.json({ error: "Please select a valid currency." }, { status: 400 });
    }

    const supabase = await createSupabaseServerClient();
    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData.user) return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("actor_id")
      .eq("auth_user_id", authData.user.id)
      .single();
    if (profileError || !profile?.actor_id) {
      return NextResponse.json({ error: "Your account is not linked to a QimaTrade actor yet." }, { status: 403 });
    }

    let productMasterId = productMasterIdFromForm;
    let resolvedDemandId = demandId;
    let fallbackMarket = market;

    if (demandId) {
      const { data: demand, error: demandError } = await supabase
        .from("demands")
        .select("id, target_market, scope")
        .eq("id", demandId)
        .single();
      if (demandError || !demand) return NextResponse.json({ error: "Demand not found or unavailable." }, { status: 400 });
      resolvedDemandId = demand.id;
      fallbackMarket = market || demand.target_market || "";
      if (!productMasterId) {
        const scope = typeof demand.scope === "object" && demand.scope !== null ? demand.scope as Record<string, unknown> : {};
        productMasterId = typeof scope.product_master_id === "string" ? scope.product_master_id : null;
      }
    }

    if (productMasterId) {
      const { data: product, error: productError } = await supabase
        .from("product_masters")
        .select("id")
        .eq("id", productMasterId)
        .eq("status", "active")
        .single();
      if (productError || !product) return NextResponse.json({ error: "PRODUCT_MASTER_NOT_FOUND" }, { status: 400 });
    }

    const attributesRaw = String(form.get("attributes") ?? "").trim();
    let attributes: Record<string, string> = {};
    if (attributesRaw) {
      try {
        const parsed = JSON.parse(attributesRaw);
        if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
          attributes = Object.fromEntries(Object.entries(parsed).filter(([, value]) => typeof value === "string" && value.trim()).map(([key, value]) => [key, (value as string).trim()]));
        }
      } catch {
        return NextResponse.json({ error: "Invalid offer attributes." }, { status: 400 });
      }
    }

    const { data: offer, error: insertError } = await supabase
      .from("offers")
      .insert({
        name,
        demand_id: resolvedDemandId,
        product_master_id: productMasterId,
        provider_actor_id: profile.actor_id,
        quantity,
        price,
        currency: price === null ? null : currency,
        conditions: conditions || null,
        market: fallbackMarket || null,
        geography: geography || null,
        attributes,
        documentation_status: documentation ? "available" : "incomplete",
        lifecycle: "draft",
        offer_type: "supplier_offer",
        pricing_model: price === null ? null : "fixed",
      })
      .select("id")
      .single();

    if (insertError || !offer) {
      return NextResponse.json({ error: insertError?.message ?? "Unable to create the offer." }, { status: 500 });
    }

    return NextResponse.redirect(new URL(`/offers?created=${offer.id}`, request.url), 303);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to create the offer.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
