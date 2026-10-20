"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

async function getCurrentActor() {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();

  if (authError || !user) {
    return { supabase, actorId: null as string | null };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .single();

  if (profileError || !profile?.actor_id) {
    return { supabase, actorId: null as string | null };
  }

  return { supabase, actorId: profile.actor_id as string };
}

function getProductMasterId(scope: unknown): string | null {
  let value = scope;

  if (typeof value === "string") {
    try {
      value = JSON.parse(value);
    } catch {
      return null;
    }
  }

  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const productMasterId = (value as Record<string, unknown>).product_master_id;
  return typeof productMasterId === "string" && productMasterId.trim()
    ? productMasterId.trim()
    : null;
}

export async function respondToOffer(formData: FormData) {
  const demandId = String(formData.get("demandId") ?? "").trim();
  const offerId = String(formData.get("offerId") ?? "").trim();
  const decision = String(formData.get("decision") ?? "").trim();

  if (!demandId || !offerId || !["accepted", "rejected"].includes(decision)) {
    redirect("/demands");
  }

  const { supabase, actorId } = await getCurrentActor();
  if (!actorId) {
    redirect(`/login?next=${encodeURIComponent(`/demands/match?id=${demandId}`)}`);
  }

  // Enforce ownership in the query itself; do not rely only on RLS behavior.
  const { data: demand } = await supabase
    .from("demands")
    .select("id, demand_id, requester_actor_id, scope")
    .eq("id", demandId)
    .eq("requester_actor_id", actorId)
    .single();

  if (!demand || demand.requester_actor_id !== actorId) {
    redirect("/demands");
  }

  const { data: offer } = await supabase
    .from("offers")
    .select("id, name, provider_actor_id, product_master_id")
    .eq("id", offerId)
    .single();

  if (!offer || !offer.provider_actor_id || offer.provider_actor_id === actorId) {
    redirect(`/demands/match?id=${encodeURIComponent(demandId)}&error=${encodeURIComponent("OFFER_NOT_AVAILABLE")}`);
  }

  // The selected offer must belong to the same canonical product as the demand.
  const demandProductMasterId = getProductMasterId(demand.scope);
  if (!demandProductMasterId || offer.product_master_id !== demandProductMasterId) {
    redirect(`/demands/match?id=${encodeURIComponent(demandId)}&error=${encodeURIComponent("OFFER_PRODUCT_MISMATCH")}`);
  }

  const { data: existingMatch } = await supabase
    .from("matches")
    .select("id, status")
    .eq("demand_id", demandId)
    .eq("offer_id", offerId)
    .eq("status", "accepted")
    .maybeSingle();

  if (existingMatch) {
    redirect(`/demands/conversation?demand=${encodeURIComponent(demandId)}&offer=${encodeURIComponent(offerId)}`);
  }

  const status = decision as "accepted" | "rejected";
  const { error: insertError } = await supabase
    .from("matches")
    .insert({
      name: `${demand.demand_id} ↔ ${offer.name}`,
      match_type: "buyer_supplier",
      status,
      score: null,
      reason: status === "accepted" ? "Buyer accepted the supplier offer." : "Buyer rejected the supplier offer.",
      recommended_action: status === "accepted" ? "Start commercial conversation." : "Keep the offer available for other demands.",
      detected_at: new Date().toISOString(),
      demand_id: demandId,
      offer_id: offerId,
    });

  if (insertError) {
    redirect(`/demands/match?id=${encodeURIComponent(demandId)}&error=${encodeURIComponent(insertError.message)}`);
  }

  revalidatePath(`/demands/match?id=${demandId}`);

  if (status === "accepted") {
    redirect(`/demands/conversation?demand=${encodeURIComponent(demandId)}&offer=${encodeURIComponent(offerId)}`);
  }

  redirect(`/demands/match?id=${encodeURIComponent(demandId)}&rejected=1`);
}
