"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

type CreateOfferInput = {
  demandId: string;
  name: string;
  quantity: string;
  price: string;
  currency: string;
  conditions: string;
  market: string;
  geography: string;
};

type CreateOfferResult =
  | { ok: true; offerId: string }
  | { ok: false; error: string };

const currencies = new Set(["USD", "EUR", "KRW", "MAD", "CNY"]);

export async function createOffer(input: CreateOfferInput): Promise<CreateOfferResult> {
  const demandId = input.demandId.trim();
  const name = input.name.trim();
  const quantity = Number(input.quantity);
  const price = input.price.trim() ? Number(input.price) : null;
  const currency = input.currency.trim();
  const conditions = input.conditions.trim();
  const market = input.market.trim();
  const geography = input.geography.trim();

  if (!demandId || !name || !Number.isFinite(quantity) || quantity <= 0) {
    return { ok: false, error: "Please provide a valid demand, offer name and quantity." };
  }

  if (price !== null && (!Number.isFinite(price) || price < 0)) {
    return { ok: false, error: "Price must be a valid positive number." };
  }

  if (price !== null && !currencies.has(currency)) {
    return { ok: false, error: "Please select a valid currency." };
  }

  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();

  if (authError || !user) {
    return { ok: false, error: "You must be signed in to create an offer." };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .single();

  if (profileError || !profile?.actor_id) {
    return { ok: false, error: "Your account is not linked to a QimaTrade actor yet." };
  }

  const { data: demand, error: demandError } = await supabase
    .from("demands")
    .select("id, demand_id, name, target_market")
    .eq("id", demandId)
    .single();

  if (demandError || !demand) {
    return { ok: false, error: "Demand not found or unavailable." };
  }

  const { data: offer, error: insertError } = await supabase
    .from("offers")
    .insert({
      name,
      demand_id: demand.id,
      provider_actor_id: profile.actor_id,
      quantity,
      price,
      currency: price === null ? null : currency,
      conditions: conditions || null,
      market: market || demand.target_market || null,
      geography: geography || null,
      lifecycle: "draft",
      documentation_status: "incomplete",
      offer_type: "supplier_offer",
      pricing_model: price === null ? null : "fixed",
    })
    .select("id")
    .single();

  if (insertError || !offer) {
    return { ok: false, error: insertError?.message ?? "Unable to create the offer." };
  }

  return { ok: true, offerId: offer.id };
}
