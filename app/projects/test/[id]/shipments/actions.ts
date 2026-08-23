"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const STATUSES = ["pending", "pickup_scheduled", "picked_up", "in_transit", "delivered", "cancelled"] as const;
type ShipmentStatus = (typeof STATUSES)[number];

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

export async function createShipment(projectId: string, formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const orderId = String(formData.get("order_id") ?? "");
  const transporter = String(formData.get("transporter_actor_id") ?? "").trim();
  const pickup = String(formData.get("pickup_location") ?? "").trim();
  const destination = String(formData.get("destination") ?? "").trim();
  const pickupDate = String(formData.get("pickup_scheduled_at") ?? "").trim();
  const deliveryDate = String(formData.get("delivery_scheduled_at") ?? "").trim();
  const tracking = String(formData.get("tracking_reference") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();

  if (!orderId || !pickup || !destination) throw new Error("Order, lieu de récupération et destination sont obligatoires.");
  const { data: order, error: orderError } = await supabase.from("project_orders").select("id, order_id").eq("id", orderId).eq("project_id", projectId).maybeSingle();
  if (orderError) throw new Error(orderError.message);
  if (!order) throw new Error("Commande introuvable.");
  if (transporter) await assertParticipant(supabase, projectId, transporter);

  const shipmentId = `SHP-${Date.now().toString(36).toUpperCase()}`;
  const { error } = await supabase.from("project_shipments").insert({
    shipment_id: shipmentId,
    project_id: projectId,
    order_id: orderId,
    transporter_actor_id: transporter || null,
    pickup_location: pickup,
    destination,
    pickup_scheduled_at: pickupDate ? new Date(pickupDate).toISOString() : null,
    delivery_scheduled_at: deliveryDate ? new Date(deliveryDate).toISOString() : null,
    tracking_reference: tracking || null,
    status: "pending",
    notes: notes || null,
    created_by_actor_id: actorId,
  });
  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "SHIPMENT_CREATED",
    title: "Shipment created",
    description: `${shipmentId} linked to ${order.order_id}.`,
  });
  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/shipments`);
  revalidatePath(`/projects/test/${projectId}`);
}

export async function updateShipmentStatus(projectId: string, shipmentId: string, status: string) {
  if (!STATUSES.includes(status as ShipmentStatus)) throw new Error("Statut de livraison invalide.");
  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const { data: shipment, error: readError } = await supabase.from("project_shipments").select("id, shipment_id, status").eq("id", shipmentId).eq("project_id", projectId).maybeSingle();
  if (readError) throw new Error(readError.message);
  if (!shipment) throw new Error("Expédition introuvable.");
  if (shipment.status === status) return;

  const { error } = await supabase.from("project_shipments").update({
    status,
    picked_up_at: status === "picked_up" ? new Date().toISOString() : undefined,
    delivered_at: status === "delivered" ? new Date().toISOString() : null,
    updated_at: new Date().toISOString(),
  }).eq("id", shipmentId).eq("project_id", projectId);
  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "SHIPMENT_STATUS_CHANGED",
    title: `Shipment status changed to ${status}`,
    description: `${shipment.shipment_id}: ${shipment.status} → ${status}.`,
  });
  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/shipments`);
  revalidatePath(`/projects/test/${projectId}`);
}
