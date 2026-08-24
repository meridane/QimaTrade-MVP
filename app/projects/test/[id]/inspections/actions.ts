"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const TYPES = [
  "pre_purchase",
  "pickup",
  "warehouse_receipt",
  "repair",
  "pre_loading",
  "final_delivery",
] as const;

const STATUSES = [
  "draft",
  "in_progress",
  "completed",
  "approved",
  "rejected",
] as const;

const SEVERITIES = [
  "low",
  "medium",
  "high",
  "critical",
] as const;

const FINDING_STATUSES = [
  "open",
  "in_progress",
  "resolved",
  "accepted",
] as const;

type ActorIdentity = {
  uuid: string;
  key: string;
};

async function actor(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>
): Promise<ActorIdentity> {
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("Utilisateur non connecté.");
  }

  // profiles.actor_id is the UUID of actors.id.
  // The inspection foreign keys use actors.actor_id (ACT-XXXX),
  // so we resolve both values here once and use the correct one per column.
  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .maybeSingle();

  if (profileError) {
    throw new Error(`Impossible de lire le profil du compte courant: ${profileError.message}`);
  }

  if (profile?.actor_id) {
    const { data: actorRow, error: actorError } = await supabase
      .from("actors")
      .select("id, actor_id")
      .eq("id", profile.actor_id)
      .maybeSingle();

    if (actorError) {
      throw new Error(`Impossible de retrouver l'acteur du compte courant: ${actorError.message}`);
    }

    if (actorRow?.id && actorRow.actor_id) {
      return {
        uuid: actorRow.id,
        key: actorRow.actor_id,
      };
    }
  }

  // Fallback for accounts whose profile mapping is temporarily missing.
  // Existing actors use the ACT- + first 12 hex characters convention.
  const fallbackKey = `ACT-${user.id.replace(/-/g, "").slice(0, 12).toUpperCase()}`;
  const { data: fallbackActor, error: fallbackError } = await supabase
    .from("actors")
    .select("id, actor_id")
    .eq("actor_id", fallbackKey)
    .maybeSingle();

  if (fallbackError) {
    throw new Error(`Impossible de retrouver l'acteur du compte courant: ${fallbackError.message}`);
  }

  if (!fallbackActor?.id || !fallbackActor.actor_id) {
    throw new Error(
      "Impossible de retrouver l'actor_id du compte courant. Vérifiez que votre compte possède bien un profil et un acteur associés."
    );
  }

  return {
    uuid: fallbackActor.id,
    key: fallbackActor.actor_id,
  };
}

async function participant(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  projectId: string,
  actorUuid: string
) {
  const { data, error } = await supabase
    .from("project_participants")
    .select("id")
    .eq("project_id", projectId)
    .eq("actor_id", actorUuid)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  if (!data) {
    throw new Error("Ce compte n'est pas participant à ce Project.");
  }
}

async function getActorFromKey(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  actorKey: string
) {
  const { data, error } = await supabase
    .from("actors")
    .select("id, actor_id, name")
    .eq("actor_id", actorKey)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  if (!data) {
    throw new Error("Inspecteur introuvable dans la table actors.");
  }

  return data;
}

export async function createInspection(
  projectId: string,
  formData: FormData
): Promise<void> {
  const supabase = await createSupabaseServerClient();
  const currentActor = await actor(supabase);

  await participant(supabase, projectId, currentActor.uuid);

  const type = String(formData.get("type") ?? "");

  if (!TYPES.includes(type as (typeof TYPES)[number])) {
    throw new Error("Type d'inspection invalide.");
  }

  const inspectorActorKey = String(
    formData.get("inspector_actor_id") ?? ""
  ).trim();

  const orderId = String(formData.get("order_id") ?? "").trim();
  const shipmentId = String(formData.get("shipment_id") ?? "").trim();
  const summary = String(formData.get("summary") ?? "").trim();
  const recommendation = String(formData.get("recommendation") ?? "").trim();

  if (inspectorActorKey) {
    const selectedActor = await getActorFromKey(supabase, inspectorActorKey);
    await participant(supabase, projectId, selectedActor.id);
  }

  if (orderId) {
    const { data, error } = await supabase
      .from("project_orders")
      .select("id")
      .eq("id", orderId)
      .eq("project_id", projectId)
      .maybeSingle();

    if (error) throw new Error(error.message);
    if (!data) throw new Error("Order introuvable.");
  }

  if (shipmentId) {
    const { data, error } = await supabase
      .from("project_shipments")
      .select("id")
      .eq("id", shipmentId)
      .eq("project_id", projectId)
      .maybeSingle();

    if (error) throw new Error(error.message);
    if (!data) throw new Error("Shipment introuvable.");
  }

  const inspectionId = `INS-${Date.now().toString(36).toUpperCase()}`;

  const { error } = await supabase
    .from("project_inspections")
    .insert({
      inspection_id: inspectionId,
      project_id: projectId,
      order_id: orderId || null,
      shipment_id: shipmentId || null,
      inspector_actor_id: inspectorActorKey || null,
      created_by_actor_id: currentActor.key,
      type,
      inspection_type: type,
      status: "draft",
      summary: summary || null,
      recommendation: recommendation || null,
    })
    .select("id, inspection_id")
    .single();

  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase
    .from("project_events")
    .insert({
      project_id: projectId,
      actor_id: currentActor.uuid,
      event_type: "INSPECTION_CREATED",
      title: "Inspection created",
      description: `${inspectionId} (${type}).`,
    });

  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/inspections`);
}

export async function updateInspectionStatus(
  projectId: string,
  inspectionId: string,
  status: string
): Promise<void> {
  if (!STATUSES.includes(status as (typeof STATUSES)[number])) {
    throw new Error("Statut invalide.");
  }

  const supabase = await createSupabaseServerClient();
  const currentActor = await actor(supabase);
  await participant(supabase, projectId, currentActor.uuid);

  const { data: inspection, error: readError } = await supabase
    .from("project_inspections")
    .select("id, inspection_id, status")
    .eq("id", inspectionId)
    .eq("project_id", projectId)
    .maybeSingle();

  if (readError) throw new Error(readError.message);
  if (!inspection) throw new Error("Inspection introuvable.");

  const completed =
    status === "completed" || status === "approved" || status === "rejected";

  const { error } = await supabase
    .from("project_inspections")
    .update({
      status,
      updated_at: new Date().toISOString(),
      completed_at: completed ? new Date().toISOString() : null,
    })
    .eq("id", inspectionId)
    .eq("project_id", projectId);

  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase
    .from("project_events")
    .insert({
      project_id: projectId,
      actor_id: currentActor.uuid,
      event_type: "INSPECTION_STATUS_CHANGED",
      title: `Inspection ${status}`,
      description: `${inspection.inspection_id}: ${inspection.status} → ${status}.`,
    });

  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/inspections`);
}

export async function createFinding(
  projectId: string,
  inspectionId: string,
  formData: FormData
): Promise<void> {
  const supabase = await createSupabaseServerClient();
  const currentActor = await actor(supabase);
  await participant(supabase, projectId, currentActor.uuid);

  const { data: inspection } = await supabase
    .from("project_inspections")
    .select("id, inspection_id")
    .eq("id", inspectionId)
    .eq("project_id", projectId)
    .maybeSingle();

  if (!inspection) throw new Error("Inspection introuvable.");

  const severity = String(formData.get("severity") ?? "low");
  if (!SEVERITIES.includes(severity as (typeof SEVERITIES)[number])) {
    throw new Error("Sévérité invalide.");
  }

  const title = String(formData.get("title") ?? "").trim();
  if (!title) throw new Error("Le titre du finding est obligatoire.");

  const { error } = await supabase
    .from("project_inspection_findings")
    .insert({
      inspection_id: inspectionId,
      title,
      description: String(formData.get("description") ?? "").trim() || null,
      severity,
      recommendation: String(formData.get("recommendation") ?? "").trim() || null,
      evidence_url: String(formData.get("evidence_url") ?? "").trim() || null,
      created_by_actor_id: currentActor.key,
    })
    .select("id")
    .single();

  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase
    .from("project_events")
    .insert({
      project_id: projectId,
      actor_id: currentActor.uuid,
      event_type: "INSPECTION_FINDING_CREATED",
      title: "Inspection finding added",
      description: `${inspection.inspection_id}: ${title} (${severity}).`,
    });

  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/inspections`);
}

export async function updateFindingStatus(
  projectId: string,
  findingId: string,
  status: string
): Promise<void> {
  if (!FINDING_STATUSES.includes(status as (typeof FINDING_STATUSES)[number])) {
    throw new Error("Statut du finding invalide.");
  }

  const supabase = await createSupabaseServerClient();
  const currentActor = await actor(supabase);
  await participant(supabase, projectId, currentActor.uuid);

  const { data: finding } = await supabase
    .from("project_inspection_findings")
    .select("id, title, inspection_id, status")
    .eq("id", findingId)
    .maybeSingle();

  if (!finding) throw new Error("Finding introuvable.");

  const { data: inspection } = await supabase
    .from("project_inspections")
    .select("inspection_id, project_id")
    .eq("id", finding.inspection_id)
    .eq("project_id", projectId)
    .maybeSingle();

  if (!inspection) throw new Error("Accès refusé.");

  const { error } = await supabase
    .from("project_inspection_findings")
    .update({
      status,
      updated_at: new Date().toISOString(),
      resolved_at:
        status === "resolved" || status === "accepted"
          ? new Date().toISOString()
          : null,
    })
    .eq("id", findingId);

  if (error) throw new Error(error.message);

  const { error: eventError } = await supabase
    .from("project_events")
    .insert({
      project_id: projectId,
      actor_id: currentActor.uuid,
      event_type: "INSPECTION_FINDING_STATUS_CHANGED",
      title: "Finding status changed",
      description: `${finding.title}: ${finding.status} → ${status}.`,
    });

  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/inspections`);
}
