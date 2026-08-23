"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const ORDER_STATUSES = ["draft", "confirmed", "processing", "completed", "cancelled"] as const;
type OrderStatus = (typeof ORDER_STATUSES)[number];

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

export async function createOrder(projectId: string, formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const buyer = String(formData.get("buyer_actor_id") ?? "");
  const seller = String(formData.get("seller_actor_id") ?? "");
  const title = String(formData.get("title") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const amount = Number(formData.get("amount"));
  const currency = String(formData.get("currency") ?? "USD").trim().toUpperCase();
  const paymentId = String(formData.get("payment_id") ?? "").trim();

  if (!buyer || !seller || buyer === seller) throw new Error("Acheteur et vendeur invalides.");
  if (!title) throw new Error("Le titre de la commande est obligatoire.");
  if (!Number.isFinite(amount) || amount <= 0) throw new Error("Montant invalide.");
  if (!/^[A-Z]{3,10}$/.test(currency)) throw new Error("Devise invalide.");
  await assertParticipant(supabase, projectId, buyer);
  await assertParticipant(supabase, projectId, seller);

  if (paymentId) {
    const { data, error } = await supabase.from("project_payments").select("id").eq("id", paymentId).eq("project_id", projectId).maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) throw new Error("Paiement sélectionné introuvable.");
  }

  const orderId = `ORD-${Date.now().toString(36).toUpperCase()}`;
  const { error } = await supabase.from("project_orders").insert({
    order_id: orderId,
    project_id: projectId,
    buyer_actor_id: buyer,
    seller_actor_id: seller,
    title,
    description: description || null,
    amount,
    currency,
    status: "draft",
    payment_id: paymentId || null,
    created_by_actor_id: actorId,
  });
  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "ORDER_CREATED",
    title: "Order created",
    description: `${orderId}: ${title} — ${amount.toFixed(2)} ${currency}.`,
  });
  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/orders`);
  revalidatePath(`/projects/test/${projectId}`);
}

export async function updateOrderStatus(projectId: string, orderId: string, status: string) {
  if (!ORDER_STATUSES.includes(status as OrderStatus)) throw new Error("Statut de commande invalide.");

  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const { data: order, error: readError } = await supabase
    .from("project_orders")
    .select("id, order_id, title, status")
    .eq("id", orderId)
    .eq("project_id", projectId)
    .maybeSingle();
  if (readError) throw new Error(readError.message);
  if (!order) throw new Error("Commande introuvable.");
  if (order.status === status) return;

  const { error } = await supabase.from("project_orders").update({
    status,
    completed_at: status === "completed" ? new Date().toISOString() : null,
    updated_at: new Date().toISOString(),
  }).eq("id", orderId).eq("project_id", projectId);
  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "ORDER_STATUS_CHANGED",
    title: `Order status changed to ${status}`,
    description: `${order.order_id} (${order.title}): ${order.status} → ${status}.`,
  });
  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/orders`);
  revalidatePath(`/projects/test/${projectId}`);
}
