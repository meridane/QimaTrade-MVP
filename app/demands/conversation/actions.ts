"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

type ConversationMessage = { id: string; body: string; senderActorId: string; createdAt: string };
type ConversationResult =
  | { ok: true; actorId: string; offerId: string | null; messages: ConversationMessage[] }
  | { ok: false; error: string };

async function getActorId() {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return { supabase, actorId: null, error: "You must be signed in." };
  const { data: profile, error } = await supabase.from("profiles").select("actor_id").eq("auth_user_id", user.id).single();
  if (error || !profile?.actor_id) return { supabase, actorId: null, error: "Your account is not linked to a QimaTrade actor yet." };
  return { supabase, actorId: profile.actor_id as string, error: null };
}

export async function loadConversation(demandId: string, requestedOfferId?: string | null): Promise<ConversationResult> {
  if (!demandId) return { ok: false, error: "Demand not specified." };
  const { supabase, actorId, error } = await getActorId();
  if (!actorId) return { ok: false, error: error ?? "Unauthorized." };

  const { data: demand, error: demandError } = await supabase.from("demands").select("id").eq("id", demandId).single();
  if (demandError || !demand) return { ok: false, error: "Demand not found or unavailable." };

  let offerId = requestedOfferId ?? null;
  if (offerId) {
    const { data: offer, error: offerError } = await supabase.from("offers").select("id").eq("id", offerId).maybeSingle();
    if (offerError) return { ok: false, error: offerError.message };
    if (!offer) return { ok: false, error: "Offer not found or unavailable." };
    offerId = offer.id;
  } else {
    const { data: offer, error: offerError } = await supabase.from("offers").select("id").eq("demand_id", demandId).order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (offerError) return { ok: false, error: offerError.message };
    offerId = offer?.id ?? null;
  }

  let query = supabase.from("messages").select("id, body, sender_actor_id, created_at").eq("demand_id", demandId).order("created_at", { ascending: true });
  if (offerId) query = query.eq("offer_id", offerId);
  const { data: rows, error: messagesError } = await query;
  if (messagesError) return { ok: false, error: messagesError.message };

  return { ok: true, actorId, offerId, messages: (rows ?? []).map((row) => ({ id: row.id, body: row.body, senderActorId: row.sender_actor_id, createdAt: row.created_at })) };
}

export async function sendConversationMessage(input: { demandId: string; offerId: string | null; body: string }) {
  const body = input.body.trim();
  if (!input.demandId || !body) return { ok: false as const, error: "Message cannot be empty." };
  if (body.length > 5000) return { ok: false as const, error: "Message is too long." };
  const { supabase, actorId, error } = await getActorId();
  if (!actorId) return { ok: false as const, error: error ?? "Unauthorized." };

  const { data, error: insertError } = await supabase.from("messages").insert({ demand_id: input.demandId, offer_id: input.offerId, sender_actor_id: actorId, body }).select("id, body, sender_actor_id, created_at").single();
  if (insertError || !data) return { ok: false as const, error: insertError?.message ?? "Unable to send message." };
  return { ok: true as const, message: { id: data.id, body: data.body, senderActorId: data.sender_actor_id, createdAt: data.created_at } };
}
