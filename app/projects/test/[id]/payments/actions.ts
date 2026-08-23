"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const PAYMENT_STATUSES = ["pending", "authorized", "paid", "failed", "cancelled"] as const;
const PAYMENT_METHODS = ["bank_transfer", "card", "toss", "cash"] as const;

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

export async function createPayment(projectId: string, formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const payer = String(formData.get("payer_actor_id") ?? "");
  const payee = String(formData.get("payee_actor_id") ?? "");
  const amount = Number(formData.get("amount"));
  const currency = String(formData.get("currency") ?? "USD").trim().toUpperCase();
  const method = String(formData.get("method") ?? "bank_transfer");
  const note = String(formData.get("note") ?? "").trim();

  if (!payer || !payee || payer === payee) throw new Error("Payeur et bénéficiaire invalides.");
  if (!Number.isFinite(amount) || amount <= 0) throw new Error("Montant invalide.");
  if (!/^[A-Z]{3,10}$/.test(currency)) throw new Error("Devise invalide.");
  if (!PAYMENT_METHODS.includes(method as (typeof PAYMENT_METHODS)[number])) throw new Error("Méthode invalide.");
  await assertParticipant(supabase, projectId, payer);
  await assertParticipant(supabase, projectId, payee);

  const paymentId = `PAY-${Date.now().toString(36).toUpperCase()}`;
  const { error } = await supabase.from("project_payments").insert({
    payment_id: paymentId,
    project_id: projectId,
    payer_actor_id: payer,
    payee_actor_id: payee,
    amount,
    currency,
    method,
    status: "pending",
    note: note || null,
    created_by_actor_id: actorId,
  });
  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "PAYMENT_CREATED",
    title: "Payment created",
    description: `${paymentId}: ${amount.toFixed(2)} ${currency} via ${method}.`,
  });
  if (eventError) throw new Error(eventError.message);
  revalidatePath(`/projects/test/${projectId}/payments`);
  revalidatePath(`/projects/test/${projectId}`);
}

export async function updatePaymentStatus(projectId: string, paymentId: string, status: string) {
  if (!PAYMENT_STATUSES.includes(status as (typeof PAYMENT_STATUSES)[number])) throw new Error("Statut de paiement invalide.");
  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const { data: payment, error: readError } = await supabase.from("project_payments").select("id, payment_id, status").eq("id", paymentId).eq("project_id", projectId).maybeSingle();
  if (readError) throw new Error(readError.message);
  if (!payment) throw new Error("Paiement introuvable.");
  if (payment.status === status) return;

  const { error } = await supabase.from("project_payments").update({ status, paid_at: status === "paid" ? new Date().toISOString() : null, updated_at: new Date().toISOString() }).eq("id", paymentId).eq("project_id", projectId);
  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "PAYMENT_STATUS_CHANGED",
    title: `Payment status changed to ${status}`,
    description: `${payment.payment_id}: ${payment.status} → ${status}.`,
  });
  if (eventError) throw new Error(eventError.message);
  revalidatePath(`/projects/test/${projectId}/payments`);
  revalidatePath(`/projects/test/${projectId}`);
}
