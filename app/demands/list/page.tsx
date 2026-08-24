import Link from "next/link";
import { ArrowLeft, ArrowRight, ClipboardList, Plus, CheckCircle2, Circle } from "lucide-react";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function DemandsListPage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return (
      <main className="min-h-screen bg-slate-50 px-5 py-10">
        <div className="mx-auto max-w-3xl rounded-3xl border border-slate-200 bg-white p-8 text-center shadow-soft">
          <h1 className="text-2xl font-black text-slate-950">Sign in to view your demands</h1>
          <p className="mt-2 text-sm text-slate-500">Authentication is required to access your demand list.</p>
          <Link href="/login" className="mt-6 inline-flex rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white">Sign in</Link>
        </div>
      </main>
    );
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .single();

  if (!profile?.actor_id) {
    return (
      <main className="min-h-screen bg-slate-50 px-5 py-10">
        <div className="mx-auto max-w-3xl rounded-3xl border border-slate-200 bg-white p-8 text-center shadow-soft">
          <h1 className="text-2xl font-black text-slate-950">Demand access unavailable</h1>
          <p className="mt-2 text-sm text-slate-500">Your account is not linked to a QimaTrade actor yet.</p>
        </div>
      </main>
    );
  }

  const { data: demands, error } = await supabase
    .from("demands")
    .select("id, name, demand_status, quantity, target_market, requester_actor_id")
    .eq("requester_actor_id", profile.actor_id)
    .order("id", { ascending: false });

  // Qualification is checked through the real relation from the demand workflow.
  // We intentionally do not infer qualification from the demand scope or other fields.
  const demandIds = (demands ?? []).map((demand) => demand.id);
  let qualifiedDemandIds = new Set<string>();

  if (demandIds.length > 0) {
    const { data: qualifications } = await supabase
      .from("demand_qualifications")
      .select("demand_id")
      .in("demand_id", demandIds);

    qualifiedDemandIds = new Set((qualifications ?? []).map((qualification) => qualification.demand_id));
  }

  return (
    <main className="min-h-screen bg-slate-50">
      <div className="mx-auto max-w-6xl px-5 py-6 sm:px-8 lg:py-10">
        <header className="flex flex-col gap-4 rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-soft sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3">
            <Link href="/" className="flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 text-slate-500 transition hover:border-orange-200 hover:text-orange-600" aria-label="Back to home"><ArrowLeft size={18} /></Link>
            <div><p className="text-base font-bold tracking-tight text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Demand management</p></div>
          </div>
          <Link href="/demands" className="inline-flex items-center justify-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600"><Plus size={17} /> New demand</Link>
        </header>

        <section className="mt-8 rounded-3xl border border-slate-200 bg-white p-6 shadow-soft sm:p-8">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div className="flex items-start gap-4">
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-orange-50 text-orange-600"><ClipboardList size={23} /></div>
              <div><p className="text-sm font-bold text-orange-600">MVP · Demands</p><h1 className="mt-1 text-3xl font-black tracking-tight text-slate-950">My demands</h1><p className="mt-2 text-sm leading-6 text-slate-500">View the demands created by your QimaTrade actor.</p></div>
            </div>
            <span className="w-fit rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">{demands?.length ?? 0} demand{(demands?.length ?? 0) === 1 ? "" : "s"}</span>
          </div>

          {error ? (
            <div role="alert" className="mt-8 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">Unable to load demands: {error.message}</div>
          ) : !demands || demands.length === 0 ? (
            <div className="mt-8 rounded-2xl border border-dashed border-slate-200 bg-slate-50 p-10 text-center">
              <p className="font-bold text-slate-800">No demands yet</p>
              <p className="mt-1 text-sm text-slate-500">Create your first demand to start the QimaTrade workflow.</p>
              <Link href="/demands" className="mt-5 inline-flex items-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white">Create demand <ArrowRight size={17} /></Link>
            </div>
          ) : (
            <div className="mt-8 overflow-hidden rounded-2xl border border-slate-200">
              <div className="overflow-x-auto">
                <table className="w-full min-w-[900px] text-left">
                  <thead className="bg-slate-50 text-xs font-bold uppercase tracking-wide text-slate-500">
                    <tr><th className="px-5 py-4">Demand</th><th className="px-5 py-4">Quantity</th><th className="px-5 py-4">Destination</th><th className="px-5 py-4">Status</th><th className="px-5 py-4">Qualification</th><th className="px-5 py-4">Action</th></tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 bg-white">
                    {demands.map((demand) => {
                      const isQualified = qualifiedDemandIds.has(demand.id);
                      return (
                        <tr key={demand.id} className="transition hover:bg-slate-50/70">
                          <td className="px-5 py-4"><p className="font-bold text-slate-900">{demand.name}</p><p className="mt-1 text-xs text-slate-400">{demand.id}</p></td>
                          <td className="px-5 py-4 text-sm font-semibold text-slate-700">{demand.quantity}</td>
                          <td className="px-5 py-4 text-sm text-slate-600">{demand.target_market || "—"}</td>
                          <td className="px-5 py-4"><span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-bold text-orange-700">{demand.demand_status || "—"}</span></td>
                          <td className="px-5 py-4">
                            <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-bold ${isQualified ? "bg-emerald-50 text-emerald-700" : "bg-slate-100 text-slate-500"}`}>
                              {isQualified ? <CheckCircle2 size={14} /> : <Circle size={14} />}
                              {isQualified ? "Checked" : "Not checked"}
                            </span>
                          </td>
                          <td className="px-5 py-4"><Link href={`/demands?id=${encodeURIComponent(demand.id)}`} className="inline-flex items-center gap-1.5 text-sm font-bold text-orange-600 hover:text-orange-700">Open demand <ArrowRight size={15} /></Link></td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </section>
      </div>
    </main>
  );
}
