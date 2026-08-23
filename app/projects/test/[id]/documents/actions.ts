"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const TYPES = ["invoice", "packing_list", "payment_proof", "delivery_proof", "contract", "other"] as const;
type DocumentType = (typeof TYPES)[number];

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

function safeFileName(name: string) {
  return name.replace(/[^a-zA-Z0-9._()'@+=;? -]/g, "_").slice(0, 180) || "document";
}

export async function uploadDocument(projectId: string, formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const file = formData.get("file");
  const type = String(formData.get("document_type") ?? "other") as DocumentType;
  const orderId = String(formData.get("order_id") ?? "").trim();
  const shipmentId = String(formData.get("shipment_id") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();

  if (!(file instanceof File) || file.size === 0) throw new Error("Veuillez sélectionner un fichier.");
  if (file.size > 6 * 1024 * 1024) throw new Error("Le fichier doit faire 6 MB maximum pour ce test.");
  if (!TYPES.includes(type)) throw new Error("Type de document invalide.");
  if (!orderId && !shipmentId) throw new Error("Liez le document à une Order ou à un Shipment.");

  if (orderId) {
    const { data, error } = await supabase.from("project_orders").select("id").eq("id", orderId).eq("project_id", projectId).maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) throw new Error("Order introuvable.");
  }
  if (shipmentId) {
    const { data, error } = await supabase.from("project_shipments").select("id").eq("id", shipmentId).eq("project_id", projectId).maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) throw new Error("Shipment introuvable.");
  }

  const documentId = `DOC-${Date.now().toString(36).toUpperCase()}`;
  const storagePath = `${projectId}/${crypto.randomUUID()}/${safeFileName(file.name)}`;

  const { error: uploadError } = await supabase.storage.from("project-documents").upload(storagePath, file, {
    contentType: file.type || "application/octet-stream",
    cacheControl: "3600",
    upsert: false,
  });
  if (uploadError) throw new Error(uploadError.message);

  const { error: insertError } = await supabase.from("project_documents").insert({
    document_id: documentId,
    project_id: projectId,
    order_id: orderId || null,
    shipment_id: shipmentId || null,
    uploaded_by_actor_id: actorId,
    document_type: type,
    file_name: file.name,
    storage_path: storagePath,
    mime_type: file.type || null,
    file_size: file.size,
    notes: notes || null,
  });

  if (insertError) {
    await supabase.storage.from("project-documents").remove([storagePath]);
    throw new Error(insertError.message);
  }

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "DOCUMENT_UPLOADED",
    title: "Document uploaded",
    description: `${documentId}: ${file.name}.`,
  });
  if (eventError) throw new Error(eventError.message);

  revalidatePath(`/projects/test/${projectId}/documents`);
  revalidatePath(`/projects/test/${projectId}`);
}

export async function deleteDocument(projectId: string, documentDbId: string) {
  const supabase = await createSupabaseServerClient();
  const actorId = await currentActor(supabase);
  await assertParticipant(supabase, projectId, actorId);

  const { data: doc, error: readError } = await supabase.from("project_documents").select("id, document_id, file_name, storage_path").eq("id", documentDbId).eq("project_id", projectId).maybeSingle();
  if (readError) throw new Error(readError.message);
  if (!doc) throw new Error("Document introuvable.");

  const { error: storageError } = await supabase.storage.from("project-documents").remove([doc.storage_path]);
  if (storageError) throw new Error(storageError.message);

  const { error } = await supabase.from("project_documents").delete().eq("id", documentDbId).eq("project_id", projectId);
  if (error) throw new Error(error.message);

  await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "DOCUMENT_DELETED",
    title: "Document deleted",
    description: `${doc.document_id}: ${doc.file_name}.`,
  });

  revalidatePath(`/projects/test/${projectId}/documents`);
  revalidatePath(`/projects/test/${projectId}`);
}
