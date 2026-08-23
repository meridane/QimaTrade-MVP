"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const STATUSES = ["pending", "submitted", "confirmed", "rejected", "cancelled"] as const;
type PaymentRequestStatus = (typeof STATUSES)[number];

async function currentActor(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Utilisateur non connecté.");
  const { data, error } = await supabase.from("profiles").select("actor_id").eq("auth_user_id", user.id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data?.actor_id) throw new Error("Aucun actor_id n'est associé à ce compte.");
  return data.actor_id as string;
}

async function assertParticipant(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>, projectId: string, actorId: string) {
  const { data, error } = await supabase.from("project_participants").select("id").eq("project_id", projectId).eq("actor_id", actorId).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error("Ce compte n'est pas participant à ce Project.");
}

export async function createPaymentRequest(projectId: string, formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const orderId = String(formData.get("order_id") ?? "").trim();
  const payer = String(formData.get("payer_actor_id") ?? "");
  const payee = String(formData.get("payee_actor_id") ?? "");
  const amount = Number(formData.get("amount"));
  const currency = String(formData.get("currency") ?? "USD").trim().toUpperCase();
  const method = String(formData.get("method") ?? "bank_transfer");
  const instructions = String(formData.get("instructions") ?? "").trim();

  if (!payer || !payee || payer === payee) throw new Error("Payeur et bénéficiaire invalides.");
  if (!Number.isFinite(amount) || amount <= 0) throw new Error("Montant invalide.");
  if (!/^[A-Z]{3,10}$/.test(currency)) throw new Error("Devise invalide.");
  await assertParticipant(supabase, projectId, payer);
  await assertParticipant(supabase, projectId, payee);

  if (orderId) {
    const { data, error } = await supabase.from("project_orders").select("id").eq("id", orderId).eq("project_id", projectId).maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) throw new Error("Commande introuvable.");
  }

  const { data: created, error } = await supabase.from("payment_requests").insert({
    project_id: projectId,
    order_id: orderId || null,
    payer_actor_id: payer,
    payee_actor_id: payee,
    amount,
    currency,
    method,
    instructions: instructions || null,
    status: "pending",
    created_by_actor_id: actorId,
  }).select("request_id").single();
  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "PAYMENT_REQUEST_CREATED",
    title: "Payment request created",
    description: `${created.request_id}: ${amount.toFixed(2)} ${currency}. Payment is handled outside QimaTrade.`,
  });
  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/payment-requests`);
  revalidatePath(`/projects/test/${projectId}`);
}

export async function updatePaymentRequestStatus(projectId: string, requestId: string, status: string) {
  if (!STATUSES.includes(status as PaymentRequestStatus)) throw new Error("Statut de demande de paiement invalide.");

  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const { data: request, error: readError } = await supabase.from("payment_requests").select("id, request_id, status, amount, currency").eq("id", requestId).eq("project_id", projectId).maybeSingle();
  if (readError) throw new Error(readError.message);
  if (!request) throw new Error("Demande de paiement introuvable.");
  if (request.status === status) return;

  const now = new Date().toISOString();
  const update: Record<string, unknown> = { status, updated_at: now };
  if (status === "submitted") update.submitted_at = now;
  if (status === "confirmed") update.confirmed_at = now;

  const { error } = await supabase.from("payment_requests").update(update).eq("id", requestId).eq("project_id", projectId);
  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "PAYMENT_REQUEST_STATUS_CHANGED",
    title: `Payment request ${status}`,
    description: `${request.request_id}: ${request.status} → ${status}.`,
  });
  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/payment-requests`);
  revalidatePath(`/projects/test/${projectId}`);
}
