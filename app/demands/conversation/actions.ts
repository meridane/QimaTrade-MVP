"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

type ConversationMessage = { id: string; body: string; senderActorId: string; createdAt: string };
type ConversationResult =
  | { ok: true; actorId: string; offerId: string; messages: ConversationMessage[] }
  | { ok: false; error: string };

async function getActorId() {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return { supabase, actorId: null as string | null, error: "You must be signed in." };
  const { data: profile, error } = await supabase.from("profiles").select("actor_id").eq("auth_user_id", user.id).single();
  if (error || !profile?.actor_id) return { supabase, actorId: null as string | null, error: "Your account is not linked to a QimaTrade actor yet." };
  return { supabase, actorId: profile.actor_id as string, error: null as string | null };
}

async function getAcceptedConversation(demandId: string, offerId: string, actorId: string) {
  const supabase = await createSupabaseServerClient();
  const [{ data: demand, error: demandError }, { data: offer, error: offerError }, { data: match, error: matchError }] = await Promise.all([
    supabase.from("demands").select("id, requester_actor_id").eq("id", demandId).maybeSingle(),
    supabase.from("offers").select("id, provider_actor_id").eq("id", offerId).maybeSingle(),
    supabase.from("matches").select("id").eq("demand_id", demandId).eq("offer_id", offerId).eq("status", "accepted").limit(1).maybeSingle(),
  ]);

  if (demandError || offerError || matchError) {
    return { ok: false as const, error: "Unable to verify conversation access." };
  }
  if (!demand || !offer || !match) {
    return { ok: false as const, error: "An accepted match is required before opening this conversation." };
  }
  const isBuyer = demand.requester_actor_id === actorId;
  const isSupplier = offer.provider_actor_id === actorId;
  if (!isBuyer && !isSupplier) {
    return { ok: false as const, error: "You are not a participant in this conversation." };
  }
  if (!offer.provider_actor_id || offer.provider_actor_id === demand.requester_actor_id) {
    return { ok: false as const, error: "This demand and offer do not form a valid buyer-supplier pair." };
  }
  return { ok: true as const, supabase, actorId, demandId: demand.id, offerId: offer.id };
}

export async function loadConversation(demandId: string, requestedOfferId?: string | null): Promise<ConversationResult> {
  if (!demandId || !requestedOfferId) return { ok: false, error: "Demand and offer must be specified." };
  const { actorId, error } = await getActorId();
  if (!actorId) return { ok: false, error: error ?? "Unauthorized." };

  const access = await getAcceptedConversation(demandId, requestedOfferId, actorId);
  if (!access.ok) return access;

  const { data: rows, error: messagesError } = await access.supabase
    .from("messages")
    .select("id, body, sender_actor_id, created_at")
    .eq("demand_id", access.demandId)
    .eq("offer_id", access.offerId)
    .order("created_at", { ascending: true });

  if (messagesError) return { ok: false, error: "Unable to load conversation messages." };
  return {
    ok: true,
    actorId,
    offerId: access.offerId,
    messages: (rows ?? []).map((row) => ({
      id: row.id,
      body: row.body,
      senderActorId: row.sender_actor_id,
      createdAt: row.created_at,
    })),
  };
}

export async function sendConversationMessage(input: { demandId: string; offerId: string | null; body: string }) {
  const body = typeof input.body === "string" ? input.body.trim() : "";
  const demandId = typeof input.demandId === "string" ? input.demandId.trim() : "";
  const offerId = typeof input.offerId === "string" ? input.offerId.trim() : "";
  if (!demandId || !offerId || !body) return { ok: false as const, error: "Demand, offer and message are required." };
  if (body.length > 5000) return { ok: false as const, error: "Message is too long." };

  const { actorId, error } = await getActorId();
  if (!actorId) return { ok: false as const, error: error ?? "Unauthorized." };

  const access = await getAcceptedConversation(demandId, offerId, actorId);
  if (!access.ok) return access;

  const { data, error: insertError } = await access.supabase
    .from("messages")
    .insert({ demand_id: demandId, offer_id: offerId, sender_actor_id: actorId, body })
    .select("id, body, sender_actor_id, created_at")
    .single();

  if (insertError || !data) {
    return { ok: false as const, error: "Unable to send message. Verify that the match is accepted and you are a participant." };
  }
  return {
    ok: true as const,
    message: { id: data.id, body: data.body, senderActorId: data.sender_actor_id, createdAt: data.created_at },
  };
}
