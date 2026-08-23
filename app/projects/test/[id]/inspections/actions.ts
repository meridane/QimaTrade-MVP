"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const TYPES = ["pre_purchase","pickup","warehouse_receipt","repair","pre_loading","final_delivery"] as const;
const STATUSES = ["draft","in_progress","completed","approved","rejected"] as const;
const SEVERITIES = ["low","medium","high","critical"] as const;
const FINDING_STATUSES = ["open","in_progress","resolved","accepted"] as const;

async function actor(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Utilisateur non connecté.");
  const { data, error } = await supabase.from("profiles").select("actor_id").eq("auth_user_id", user.id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data?.actor_id) throw new Error("Aucun actor_id n'est associé à ce compte.");
  return data.actor_id as string;
}

async function participant(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>, projectId: string, actorId: string) {
  const { data, error } = await supabase.from("project_participants").select("id").eq("project_id", projectId).eq("actor_id", actorId).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error("Ce compte n'est pas participant à ce Project.");
}

export async function createInspection(projectId: string, formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const actorId = await actor(supabase);
  await participant(supabase, projectId, actorId);
  const type = String(formData.get("type") ?? "");
  if (!TYPES.includes(type as (typeof TYPES)[number])) throw new Error("Type d'inspection invalide.");
  const inspector = String(formData.get("inspector_actor_id") ?? "").trim();
  const orderId = String(formData.get("order_id") ?? "").trim();
  const shipmentId = String(formData.get("shipment_id") ?? "").trim();
  const summary = String(formData.get("summary") ?? "").trim();
  const recommendation = String(formData.get("recommendation") ?? "").trim();
  if (inspector) await participant(supabase, projectId, inspector);
  const inspectionId = `INS-${Date.now().toString(36).toUpperCase()}`;
  const { data, error } = await supabase.from("project_inspections").insert({ inspection_id: inspectionId, project_id: projectId, order_id: orderId || null, shipment_id: shipmentId || null, inspector_actor_id: inspector || null, created_by_actor_id: actorId, type, status: "draft", summary: summary || null, recommendation: recommendation || null }).select("id, inspection_id").single();
  if (error) throw new Error(error.message);
  const { error: eventError } = await supabase.from("project_events").insert({ project_id: projectId, actor_id: actorId, event_type: "INSPECTION_CREATED", title: "Inspection created", description: `${inspectionId} (${type}).` });
  if (eventError) throw new Error(eventError.message);
  revalidatePath(`/projects/test/${projectId}/inspections`);
  return data;
}

export async function updateInspectionStatus(projectId: string, inspectionId: string, status: string) {
  if (!STATUSES.includes(status as (typeof STATUSES)[number])) throw new Error("Statut invalide.");
  const supabase = await createSupabaseServerClient();
  const actorId = await actor(supabase);
  await participant(supabase, projectId, actorId);
  const { data: inspection, error: readError } = await supabase.from("project_inspections").select("id, inspection_id, status").eq("id", inspectionId).eq("project_id", projectId).maybeSingle();
  if (readError) throw new Error(readError.message);
  if (!inspection) throw new Error("Inspection introuvable.");
  const completed = status === "completed" || status === "approved" || status === "rejected";
  const { error } = await supabase.from("project_inspections").update({ status, updated_at: new Date().toISOString(), completed_at: completed ? new Date().toISOString() : null }).eq("id", inspectionId).eq("project_id", projectId);
  if (error) throw new Error(error.message);
  const { error: eventError } = await supabase.from("project_events").insert({ project_id: projectId, actor_id: actorId, event_type: "INSPECTION_STATUS_CHANGED", title: `Inspection ${status}`, description: `${inspection.inspection_id}: ${inspection.status} → ${status}.` });
  if (eventError) throw new Error(eventError.message);
  revalidatePath(`/projects/test/${projectId}/inspections`);
}

export async function createFinding(projectId: string, inspectionId: string, formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const actorId = await actor(supabase);
  await participant(supabase, projectId, actorId);
  const { data: inspection } = await supabase.from("project_inspections").select("id, inspection_id").eq("id", inspectionId).eq("project_id", projectId).maybeSingle();
  if (!inspection) throw new Error("Inspection introuvable.");
  const severity = String(formData.get("severity") ?? "low");
  if (!SEVERITIES.includes(severity as (typeof SEVERITIES)[number])) throw new Error("Sévérité invalide.");
  const title = String(formData.get("title") ?? "").trim();
  if (!title) throw new Error("Le titre du finding est obligatoire.");
  const { data, error } = await supabase.from("project_inspection_findings").insert({ inspection_id: inspectionId, title, description: String(formData.get("description") ?? "").trim() || null, severity, recommendation: String(formData.get("recommendation") ?? "").trim() || null, evidence_url: String(formData.get("evidence_url") ?? "").trim() || null, created_by_actor_id: actorId }).select("id").single();
  if (error) throw new Error(error.message);
  const { error: eventError } = await supabase.from("project_events").insert({ project_id: projectId, actor_id: actorId, event_type: "INSPECTION_FINDING_CREATED", title: "Inspection finding added", description: `${inspection.inspection_id}: ${title} (${severity}).` });
  if (eventError) throw new Error(eventError.message);
  revalidatePath(`/projects/test/${projectId}/inspections`);
  return data;
}

export async function updateFindingStatus(projectId: string, findingId: string, status: string) {
  if (!FINDING_STATUSES.includes(status as (typeof FINDING_STATUSES)[number])) throw new Error("Statut du finding invalide.");
  const supabase = await createSupabaseServerClient();
  const actorId = await actor(supabase);
  await participant(supabase, projectId, actorId);
  const { data: finding } = await supabase.from("project_inspection_findings").select("id, title, inspection_id, status").eq("id", findingId).maybeSingle();
  if (!finding) throw new Error("Finding introuvable.");
  const { data: inspection } = await supabase.from("project_inspections").select("inspection_id, project_id").eq("id", finding.inspection_id).eq("project_id", projectId).maybeSingle();
  if (!inspection) throw new Error("Accès refusé.");
  const { error } = await supabase.from("project_inspection_findings").update({ status, updated_at: new Date().toISOString(), resolved_at: status === "resolved" || status === "accepted" ? new Date().toISOString() : null }).eq("id", findingId);
  if (error) throw new Error(error.message);
  const { error: eventError } = await supabase.from("project_events").insert({ project_id: projectId, actor_id: actorId, event_type: "INSPECTION_FINDING_STATUS_CHANGED", title: "Finding status changed", description: `${finding.title}: ${finding.status} → ${status}.` });
  if (eventError) throw new Error(eventError.message);
  revalidatePath(`/projects/test/${projectId}/inspections`);
}
