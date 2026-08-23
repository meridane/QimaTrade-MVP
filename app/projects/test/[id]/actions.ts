"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const ALLOWED_STATUSES = ["created", "assigned", "in_progress", "completed"] as const;
type TaskStatus = (typeof ALLOWED_STATUSES)[number];

async function getCurrentActorId(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Utilisateur non connecté.");

  const { data: profile, error } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .maybeSingle();

  if (error) throw new Error(error.message);
  if (!profile?.actor_id) throw new Error("Aucun actor_id n'est associé à ce compte.");
  return profile.actor_id as string;
}

async function assertProjectParticipant(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  projectId: string,
  actorId: string,
) {
  const { data, error } = await supabase
    .from("project_participants")
    .select("id")
    .eq("project_id", projectId)
    .eq("actor_id", actorId)
    .maybeSingle();

  if (error) throw new Error(error.message);
  if (!data) throw new Error("Ce compte n'est pas participant à ce Project.");
}

export async function updateTaskStatus(projectId: string, taskId: string, status: string) {
  if (!ALLOWED_STATUSES.includes(status as TaskStatus)) throw new Error("Statut de tâche invalide.");

  const supabase = await createSupabaseServerClient();
  const actorId = await getCurrentActorId(supabase);
  await assertProjectParticipant(supabase, projectId, actorId);

  const { data: task, error: taskReadError } = await supabase
    .from("tasks")
    .select("id, title, status")
    .eq("id", taskId)
    .eq("project_id", projectId)
    .maybeSingle();

  if (taskReadError) throw new Error(taskReadError.message);
  if (!task) throw new Error("Tâche introuvable.");
  if (task.status === status) return;

  const completedAt = status === "completed" ? new Date().toISOString() : null;
  const { error: updateError } = await supabase
    .from("tasks")
    .update({ status, completed_at: completedAt, updated_at: new Date().toISOString() })
    .eq("id", taskId)
    .eq("project_id", projectId);

  if (updateError) throw new Error(updateError.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "TASK_STATUS_CHANGED",
    title: `Task status changed to ${status}`,
    description: `${task.title}: ${task.status} → ${status}.`,
  });

  if (eventError) throw new Error(eventError.message);
  revalidatePath(`/projects/test/${projectId}`);
}

export async function assignTask(projectId: string, taskId: string, ownerActorId: string) {
  const supabase = await createSupabaseServerClient();
  const actorId = await getCurrentActorId(supabase);
  await assertProjectParticipant(supabase, projectId, actorId);
  await assertProjectParticipant(supabase, projectId, ownerActorId);

  const { data: task, error: taskReadError } = await supabase
    .from("tasks")
    .select("id, title, owner_actor_id, status")
    .eq("id", taskId)
    .eq("project_id", projectId)
    .maybeSingle();

  if (taskReadError) throw new Error(taskReadError.message);
  if (!task) throw new Error("Tâche introuvable.");

  const { data: owner, error: ownerError } = await supabase
    .from("actors")
    .select("name")
    .eq("actor_id", ownerActorId)
    .maybeSingle();
  if (ownerError) throw new Error(ownerError.message);

  const { error: updateError } = await supabase
    .from("tasks")
    .update({ owner_actor_id: ownerActorId, status: task.status === "created" ? "assigned" : task.status, updated_at: new Date().toISOString() })
    .eq("id", taskId)
    .eq("project_id", projectId);

  if (updateError) throw new Error(updateError.message);

  const { error: eventError } = await supabase.from("project_events").insert({
    project_id: projectId,
    actor_id: actorId,
    event_type: "TASK_ASSIGNED",
    title: "Task assigned",
    description: `${task.title} assigned to ${owner?.name ?? "participant"}.`,
  });

  if (eventError) throw new Error(eventError.message);
  revalidatePath(`/projects/test/${projectId}`);
}
