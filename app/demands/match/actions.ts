"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

type DemandScope = { product_master_id?: unknown };

function getProductMasterId(scope: unknown): string | null {
  let value = scope;
  if (typeof value === "string") {
    try { value = JSON.parse(value); } catch { return null; }
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const id = (value as DemandScope).product_master_id;
  return typeof id === "string" && id.trim() ? id.trim() : null;
}

async function getCurrentActor() {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();

  if (authError || !user) {
    return { supabase, actorId: null as string | null, error: "You must be signed in." };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .maybeSingle();

  if (profileError || !profile?.actor_id) {
    return { supabase, actorId: null as string | null, error: "Your account is not linked to a QimaTrade actor yet." };
  }

  return { supabase, actorId: profile.actor_id as string, error: null as string | null };
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

  // Only the buyer who owns this demand may accept or reject an offer.
  const { data: demand, error: demandError } = await supabase
    .from("demands")
    .select("id, demand_id, requester_actor_id, scope")
    .eq("id", demandId)
    .maybeSingle();

  if (demandError || !demand || demand.requester_actor_id !== actorId) {
    redirect("/demands?error=forbidden");
  }

  const demandProductMasterId = getProductMasterId(demand.scope);
  if (!demandProductMasterId) {
    redirect(`/demands/match?id=${encodeURIComponent(demandId)}&error=product`);
  }

  const { data: offer, error: offerError } = await supabase
    .from("offers")
    .select("id, name, provider_actor_id, product_master_id, lifecycle")
    .eq("id", offerId)
    .maybeSingle();

  if (offerError || !offer || offer.lifecycle !== "published") {
    redirect(`/demands/match?id=${encodeURIComponent(demandId)}&error=offer`);
  }

  // Do not allow self-dealing or accepting an offer for another canonical product.
  if (
    !offer.provider_actor_id ||
    offer.provider_actor_id === actorId ||
    offer.product_master_id !== demandProductMasterId
  ) {
    redirect(`/demands/match?id=${encodeURIComponent(demandId)}&error=forbidden`);
  }

  const { data: existingMatch, error: matchLookupError } = await supabase
    .from("matches")
    .select("id, status")
    .eq("demand_id", demandId)
    .eq("offer_id", offerId)
    .maybeSingle();

  if (matchLookupError) {
    redirect(`/demands/match?id=${encodeURIComponent(demandId)}&error=match`);
  }

  if (existingMatch?.status === "accepted") {
    redirect(`/demands/conversation?demand=${encodeURIComponent(demandId)}&offer=${encodeURIComponent(offerId)}`);
  }

  const status = decision as "accepted" | "rejected";
  const matchPayload = {
    name: `${demand.demand_id} ↔ ${offer.name}`,
    match_type: "buyer_supplier",
    status,
    score: null,
    reason: status === "accepted" ? "Buyer accepted the supplier offer." : "Buyer rejected the supplier offer.",
    recommended_action: status === "accepted" ? "Start commercial conversation." : "Keep the offer available for other demands.",
    detected_at: new Date().toISOString(),
    demand_id: demandId,
    offer_id: offerId,
  };

  // Reuse an existing non-accepted match instead of creating duplicate rows.
  const writeResult = existingMatch
    ? await supabase.from("matches").update({
        // Keep updates compatible with the RLS hardening trigger:
        // only the decision status and its update timestamp may change.
        status: matchPayload.status,
        updated_at: new Date().toISOString(),
      }).eq("id", existingMatch.id)
    : await supabase.from("matches").insert(matchPayload);

  if (writeResult.error) {
    redirect(`/demands/match?id=${encodeURIComponent(demandId)}&error=save`);
  }

  revalidatePath("/demands");
  revalidatePath(`/demands/match?id=${demandId}`);

  if (status === "accepted") {
    redirect(`/demands/conversation?demand=${encodeURIComponent(demandId)}&offer=${encodeURIComponent(offerId)}`);
  }

  redirect(`/demands/match?id=${encodeURIComponent(demandId)}&rejected=1`);
}
