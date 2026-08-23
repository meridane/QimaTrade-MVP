"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

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
    .single();

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

  const { supabase, actorId, error } = await getCurrentActor();
  if (!actorId) {
    redirect(`/login?next=${encodeURIComponent(`/demands/match?id=${demandId}`)}`);
  }

  const { data: demand } = await supabase
    .from("demands")
    .select("id, demand_id")
    .eq("id", demandId)
    .single();

  if (!demand) {
    redirect("/demands");
  }

  const { data: offer } = await supabase
    .from("offers")
    .select("id, name, provider_actor_id")
    .eq("id", offerId)
    .single();

  if (!offer) {
    redirect(`/demands/match?id=${encodeURIComponent(demandId)}`);
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
