import Link from "next/link";
import ProjectTestAuthBar from "@/components/project-test-auth-bar";
import { createSupabaseServerClient } from "@/lib/supabase/server";

type ProjectWorkspacePageProps = { params: Promise<{ id: string }> };

type QueryError = { section: string; message: string };

export default async function ProjectWorkspacePage({ params }: ProjectWorkspacePageProps) {
  const { id } = await params;
  const supabase = await createSupabaseServerClient();
  const errors: QueryError[] = [];

  const { data: project, error: projectError } = await supabase
    .from("projects")
    .select("id, project_id, name, description, status, demand_id, offer_id, match_id, created_by_actor_id, start_at, target_end_at, created_at")
    .eq("id", id)
    .maybeSingle();
  if (projectError) errors.push({ section: "projects", message: projectError.message });

  const { data: participants, error: participantsError } = await supabase
    .from("project_participants")
    .select("id, actor_id, role, created_at")
    .eq("project_id", id)
    .order("created_at");
  if (participantsError) errors.push({ section: "project_participants", message: participantsError.message });

  const participantActorIds = (participants ?? []).map((p) => p.actor_id);
  const { data: participantActors, error: participantActorsError } = participantActorIds.length
    ? await supabase.from("actors").select("id, actor_id, name").in("actor_id", participantActorIds)
    : { data: [], error: null };
  if (participantActorsError) errors.push({ section: "actors", message: participantActorsError.message });

  const { data: tasks, error: tasksError } = await supabase
    .from("tasks")
    .select("id, task_id, title, description, status, priority, owner_actor_id, due_at, created_at")
    .eq("project_id", id)
    .order("created_at", { ascending: false });
  if (tasksError) errors.push({ section: "tasks", message: tasksError.message });

  const taskOwnerIds = (tasks ?? []).map((t) => t.owner_actor_id).filter(Boolean);
  const { data: taskActors, error: taskActorsError } = taskOwnerIds.length
    ? await supabase.from("actors").select("id, actor_id, name").in("actor_id", taskOwnerIds)
    : { data: [], error: null };
  if (taskActorsError) errors.push({ section: "task actors", message: taskActorsError.message });

  const { data: events, error: eventsError } = await supabase
    .from("project_events")
    .select("id, event_type, title, description, actor_id, created_at")
    .eq("project_id", id)
    .order("created_at", { ascending: false })
    .limit(20);
  if (eventsError) errors.push({ section: "project_events", message: eventsError.message });

  const actorMap = new Map((participantActors ?? []).map((a) => [a.actor_id, a]));
  const taskActorMap = new Map((taskActors ?? []).map((a) => [a.actor_id, a]));

  if (projectError || !project) {
    return (
      <main className="min-h-screen bg-slate-50 p-8">
        <div className="mx-auto max-w-4xl rounded-3xl border border-red-200 bg-white p-8 text-center">
          <h1 className="text-2xl font-black text-red-600">Unable to load Project</h1>
          <p className="mt-2 text-sm text-slate-500">Project not found or unavailable.</p>
          {errors.map((e) => <p key={e.section} className="mt-2 text-xs text-red-500">{e.section}: {e.message}</p>)}
          <Link href="/projects/test" className="mt-6 inline-block rounded-xl bg-orange-500 px-5 py-3 font-bold text-white">Back to tests</Link>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8">
      <div className="mx-auto max-w-6xl">
        <header className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm">
          <div className="flex items-center justify-between gap-4">
            <div><p className="text-base font-black text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Project Workspace functional test</p></div>
            <Link href="/projects/test" className="text-sm font-bold text-orange-600">← Projects</Link>
          </div>
        </header>

        <div className="mt-5"><ProjectTestAuthBar /></div>

        <section className="mt-6 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div><p className="text-xs font-black uppercase tracking-wider text-orange-600">Project</p><h1 className="mt-1 text-3xl font-black text-slate-950">{project.name}</h1><p className="mt-1 text-xs text-slate-400">{project.project_id} · {project.id}</p></div>
            <span className="rounded-full bg-orange-50 px-4 py-2 text-xs font-black text-orange-700">{project.status}</span>
          </div>
          <p className="mt-5 text-sm text-slate-600">Test Buyer <strong>adda.mahdi</strong> ↔ Supplier <strong>madda.yasser</strong>.</p>
        </section>

        {errors.length > 0 && (
          <section className="mt-5 rounded-2xl border border-red-200 bg-red-50 p-5">
            <p className="text-sm font-black text-red-700">Lecture des données : erreur détectée</p>
            {errors.map((e) => <p key={`${e.section}-${e.message}`} className="mt-1 text-xs text-red-600"><strong>{e.section}:</strong> {e.message}</p>)}
          </section>
        )}

        <div className="mt-6 grid gap-6 lg:grid-cols-3">
          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div className="flex items-center justify-between"><h2 className="text-xl font-black">Participants</h2><span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold">{participants?.length ?? 0}</span></div>
            <div className="mt-4 space-y-3">
              {(participants ?? []).map((p) => <div key={p.id} className="rounded-2xl border border-slate-100 bg-slate-50 p-4"><p className="text-sm font-black">{actorMap.get(p.actor_id)?.name ?? "Participant"}</p><p className="mt-1 text-xs font-bold text-orange-600">{p.role}</p><p className="mt-1 break-all text-[11px] text-slate-400">Actor: {p.actor_id}</p></div>)}
              {!participants?.length && <p className="text-sm text-slate-500">No participants found.</p>}
            </div>
          </section>

          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm lg:col-span-2">
            <div className="flex items-center justify-between"><div><h2 className="text-xl font-black">Tasks</h2><p className="text-sm text-slate-500">Assignment and status workflow.</p></div><span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold">{tasks?.length ?? 0}</span></div>
            <div className="mt-4 space-y-3">
              {(tasks ?? []).map((t) => <div key={t.id} className="rounded-2xl border border-slate-100 p-4"><div className="flex justify-between gap-3"><div><p className="font-black">{t.title}</p><p className="mt-1 text-[11px] text-slate-400">{t.task_id}</p></div><span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-bold text-orange-700">{t.status}</span></div><p className="mt-2 text-xs text-slate-500">Priority: <strong>{t.priority}</strong> · Assigned: <strong>{taskActorMap.get(t.owner_actor_id)?.name ?? "Unassigned"}</strong></p></div>)}
              {!tasks?.length && <p className="rounded-2xl border border-dashed border-slate-300 p-6 text-center text-sm text-slate-500">No tasks yet.</p>}
            </div>
          </section>

          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm lg:col-span-3">
            <div className="flex items-center justify-between"><h2 className="text-xl font-black">Timeline</h2><span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold">{events?.length ?? 0}</span></div>
            <div className="mt-4 space-y-3">
              {(events ?? []).map((e) => <div key={e.id} className="rounded-2xl border border-slate-100 p-4"><div className="flex justify-between gap-3"><div><p className="font-bold">{e.title || e.event_type}</p><p className="text-[11px] font-bold uppercase text-orange-600">{e.event_type}</p></div><span className="text-xs text-slate-400">{new Date(e.created_at).toLocaleString()}</span></div><p className="mt-1 text-sm text-slate-600">{e.description}</p></div>)}
              {!events?.length && <p className="rounded-2xl border border-dashed border-slate-300 p-6 text-center text-sm text-slate-500">No timeline events yet.</p>}
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}
