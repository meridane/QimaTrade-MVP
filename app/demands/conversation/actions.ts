"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

type ConversationMessage = { id: string; body: string; senderActorId: string; createdAt: string };
type ConversationResult =
  | { ok: true; actorId: string; offerId: string; messages: ConversationMessage[] }
  | { ok: false; error: string };

async function getCurrentActor() {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return { supabase, user: null, actorId: null as string | null, error: "You must be signed in." };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .single();

  if (profileError || !profile?.actor_id) {
    return { supabase, user, actorId: null as string | null, error: "Your account is not linked to a QimaTrade actor yet." };
  }

  return { supabase, user, actorId: profile.actor_id as string, error: null };
}

/**
 * A conversation is available only after an explicit accepted match links
 * this demand and offer. Database RLS remains an additional security boundary.
 */
async function authorizeConversation(
  demandId: string,
  requestedOfferId: string | null | undefined,
) {
  const current = await getCurrentActor();
  if (!current.actorId || !current.user) {
    return { ...current, offerId: null as string | null, error: current.error ?? "Unauthorized." };
  }

  const demandResult = await current.supabase
    .from("demands")
    .select("id, requester_actor_id")
    .eq("id", demandId)
    .maybeSingle();

  if (demandResult.error) {
    return { ...current, offerId: null as string | null, error: "Unable to verify demand access." };
  }
  if (!demandResult.data) {
    return { ...current, offerId: null as string | null, error: "Demand not found or unavailable." };
  }

  const offerQuery = current.supabase
    .from("offers")
    .select("id, provider_actor_id")
    .eq("id", requestedOfferId ?? "")
    .maybeSingle();

  if (!requestedOfferId) {
    return { ...current, offerId: null as string | null, error: "Offer not specified." };
  }

  const offerResult = await offerQuery;
  if (offerResult.error) {
    return { ...current, offerId: null as string | null, error: "Unable to verify offer access." };
  }
  if (!offerResult.data) {
    return { ...current, offerId: null as string | null, error: "Offer not found or unavailable." };
  }

  const demandActorId = demandResult.data.requester_actor_id;
  const offerActorId = offerResult.data.provider_actor_id;
  const isDemandOwner = demandActorId === current.actorId;
  const isOfferOwner = offerActorId === current.actorId;
  if (!isDemandOwner && !isOfferOwner) {
    return { ...current, offerId: null as string | null, error: "You are not a participant in this commercial exchange." };
  }

  const matchResult = await current.supabase
    .from("matches")
    .select("id")
    .eq("demand_id", demandId)
    .eq("offer_id", requestedOfferId)
    .eq("status", "accepted")
    .limit(1)
    .maybeSingle();

  if (matchResult.error) {
    return { ...current, offerId: null as string | null, error: "Unable to verify the accepted match." };
  }
  if (!matchResult.data) {
    return { ...current, offerId: null as string | null, error: "A conversation is available only after the offer is accepted." };
  }

  return { ...current, offerId: requestedOfferId, error: null };
}

export async function loadConversation(
  demandId: string,
  requestedOfferId?: string | null,
): Promise<ConversationResult> {
  if (!demandId) return { ok: false, error: "Demand not specified." };

  const authorized = await authorizeConversation(demandId, requestedOfferId);
  if (!authorized.actorId || !authorized.user || !authorized.offerId || authorized.error) {
    return { ok: false, error: authorized.error ?? "Unauthorized." };
  }

  const { data: rows, error: messagesError } = await authorized.supabase
    .from("messages")
    .select("id, body, sender_actor_id, created_at")
    .eq("demand_id", demandId)
    .eq("offer_id", authorized.offerId)
    .order("created_at", { ascending: true });

  if (messagesError) {
    return { ok: false, error: "Unable to load conversation messages." };
  }

  return {
    ok: true,
    actorId: authorized.actorId,
    offerId: authorized.offerId,
    messages: (rows ?? []).map((row) => ({
      id: row.id,
      body: row.body,
      senderActorId: row.sender_actor_id,
      createdAt: row.created_at,
    })),
  };
}

export async function sendConversationMessage(input: {
  demandId: string;
  offerId: string | null;
  body: string;
}) {
  const body = typeof input.body === "string" ? input.body.trim() : "";
  const demandId = typeof input.demandId === "string" ? input.demandId.trim() : "";
  const offerId = typeof input.offerId === "string" ? input.offerId.trim() : "";

  if (!demandId || !offerId || !body) {
    return { ok: false as const, error: "Demand, offer and message are required." };
  }
  if (body.length > 5000) {
    return { ok: false as const, error: "Message is too long." };
  }

  const authorized = await authorizeConversation(demandId, offerId);
  if (!authorized.actorId || !authorized.user || !authorized.offerId || authorized.error) {
    return { ok: false as const, error: authorized.error ?? "Unauthorized." };
  }

  const { data, error: insertError } = await authorized.supabase
    .from("messages")
    .insert({
      demand_id: demandId,
      offer_id: authorized.offerId,
      sender_actor_id: authorized.actorId,
      body,
    })
    .select("id, body, sender_actor_id, created_at")
    .single();

  if (insertError || !data) {
    return { ok: false as const, error: "Unable to send message." };
  }

  return {
    ok: true as const,
    message: {
      id: data.id,
      body: data.body,
      senderActorId: data.sender_actor_id,
      createdAt: data.created_at,
    },
  };
}
