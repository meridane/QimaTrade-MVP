import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import ProjectTestAuthBar from "@/components/project-test-auth-bar";

export default async function ProjectTestPage() {
  const supabase = await createSupabaseServerClient();
  const { data: projects, error } = await supabase.from("projects").select("id, project_id, name, status, created_at").order("created_at", { ascending: false }).limit(20);

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8">
      <div className="mx-auto max-w-6xl">
        <header className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm">
          <div className="flex items-center justify-between gap-4">
            <div><p className="text-base font-black text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Project Workspace functional test</p></div>
            <Link href="/" className="text-sm font-bold text-orange-600">Home</Link>
          </div>
        </header>

        <div className="mt-5"><ProjectTestAuthBar /></div>

        <section className="mt-6 rounded-3xl border border-orange-100 bg-orange-50 p-6">
          <p className="text-xs font-black uppercase tracking-wider text-orange-600">Functional test</p>
          <h1 className="mt-2 text-3xl font-black text-slate-950">Project → Participants → Tasks → Timeline</h1>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">Test avec les deux comptes réels : <strong>adda.mahdi</strong> comme Buyer / Owner et <strong>madda.yasser</strong> comme Supplier / Participant.</p>
        </section>

        <section className="mt-6 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between gap-3">
            <div><h2 className="text-xl font-black text-slate-950">Projects</h2><p className="text-sm text-slate-500">Les projets accessibles par le compte connecté.</p></div>
            <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold text-slate-600">{projects?.length ?? 0} project(s)</span>
          </div>

          {error ? <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{error.message}</div> : null}

          <div className="mt-5 grid gap-4 md:grid-cols-2">
            {(projects ?? []).map((project) => (
              <article key={project.id} className="rounded-2xl border border-slate-200 p-5">
                <div className="flex items-start justify-between gap-3">
                  <div><p className="font-black text-slate-950">{project.name}</p><p className="mt-1 text-xs text-slate-400">{project.project_id}</p></div>
                  <span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-bold text-orange-700">{project.status}</span>
                </div>
                <p className="mt-3 break-all text-[11px] text-slate-400">UUID: {project.id}</p>
                <div className="mt-4 flex gap-2">
                  <Link href={`/projects/test/${project.id}`} className="rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-bold text-white">Open Workspace</Link>
                </div>
              </article>
            ))}
          </div>

          {(!projects || projects.length === 0) && !error ? <div className="mt-5 rounded-2xl border border-dashed border-slate-300 p-8 text-center"><p className="font-bold text-slate-800">Aucun Project accessible</p><p className="mt-1 text-sm text-slate-500">Nous créerons le premier Project de test après connexion avec adda.mahdi.</p></div> : null}
        </section>
      </div>
    </main>
  );
}
