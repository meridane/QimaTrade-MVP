import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createPayment, updatePaymentStatus } from "./actions";

const statuses = ["pending", "authorized", "paid", "failed", "cancelled"] as const;
const methods = ["bank_transfer", "card", "toss", "cash"] as const;

type Props = { params: Promise<{ id: string }> };

export default async function ProjectPaymentsPage({ params }: Props) {
  const { id } = await params;
  const supabase = await createSupabaseServerClient();

  const { data: project } = await supabase
    .from("projects")
    .select("id, name, project_id, status")
    .eq("id", id)
    .maybeSingle();

  if (!project) {
    return <main className="min-h-screen bg-slate-50 p-8"><div className="mx-auto max-w-4xl rounded-3xl border bg-white p-8"><h1 className="text-2xl font-black text-red-600">Project introuvable</h1><Link className="mt-4 inline-block text-orange-600" href="/projects/test">← Retour</Link></div></main>;
  }

  const { data: participants } = await supabase
    .from("project_participants")
    .select("actor_id, role")
    .eq("project_id", id)
    .order("created_at");

  const actorIds = (participants ?? []).map((p) => p.actor_id);
  const { data: actors } = actorIds.length
    ? await supabase.from("actors").select("actor_id, name").in("actor_id", actorIds)
    : { data: [], error: null };

  const actorMap = new Map((actors ?? []).map((a) => [a.actor_id, a.name]));

  const { data: payments, error: paymentsError } = await supabase
    .from("project_payments")
    .select("id, payment_id, payer_actor_id, payee_actor_id, amount, currency, method, status, reference, note, created_at, paid_at")
    .eq("project_id", id)
    .order("created_at", { ascending: false });

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8">
      <div className="mx-auto max-w-6xl">
        <header className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm">
          <div className="flex items-center justify-between gap-4">
            <div><p className="text-base font-black text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Payment functional test</p></div>
            <Link href={`/projects/test/${id}`} className="text-sm font-bold text-orange-600">← Project</Link>
          </div>
        </header>

        <section className="mt-5 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <p className="text-xs font-black uppercase tracking-wider text-orange-600">PAYMENT TEST</p>
          <div className="mt-1 flex flex-wrap items-center justify-between gap-4">
            <div><h1 className="text-3xl font-black text-slate-950">Payments — {project.name}</h1><p className="mt-1 text-xs text-slate-400">{project.project_id} · Buyer adda.mahdi ↔ Supplier madda.yasser</p></div>
            <span className="rounded-full bg-orange-50 px-4 py-2 text-xs font-black text-orange-700">{payments?.length ?? 0} payments</span>
          </div>
        </section>

        <div className="mt-6 grid gap-6 lg:grid-cols-3">
          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-xl font-black">Create payment</h2>
            <p className="mt-1 text-sm text-slate-500">Simulation fonctionnelle avant intégration du vrai paiement.</p>
            <form action={createPayment.bind(null, id)} className="mt-5 space-y-4">
              <label className="block text-sm font-bold">Payer
                <select name="payer_actor_id" required className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm">
                  <option value="">Select payer</option>
                  {(participants ?? []).map((p) => <option key={p.actor_id} value={p.actor_id}>{actorMap.get(p.actor_id) ?? p.actor_id} — {p.role}</option>)}
                </select>
              </label>
              <label className="block text-sm font-bold">Beneficiary
                <select name="payee_actor_id" required className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm">
                  <option value="">Select beneficiary</option>
                  {(participants ?? []).map((p) => <option key={p.actor_id} value={p.actor_id}>{actorMap.get(p.actor_id) ?? p.actor_id} — {p.role}</option>)}
                </select>
              </label>
              <div className="grid grid-cols-2 gap-3">
                <label className="block text-sm font-bold">Amount<input name="amount" type="number" min="0.01" step="0.01" required placeholder="1000" className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
                <label className="block text-sm font-bold">Currency<input name="currency" defaultValue="USD" maxLength={10} required className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm uppercase" /></label>
              </div>
              <label className="block text-sm font-bold">Method
                <select name="method" defaultValue="bank_transfer" className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm">{methods.map((m) => <option key={m} value={m}>{m}</option>)}</select>
              </label>
              <label className="block text-sm font-bold">Note<textarea name="note" rows={3} placeholder="Optional note..." className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
              <button type="submit" className="w-full rounded-xl bg-orange-500 px-4 py-3 text-sm font-black text-white hover:bg-orange-600">Create payment</button>
            </form>
          </section>

          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm lg:col-span-2">
            <div className="flex items-center justify-between"><div><h2 className="text-xl font-black">Payment workflow</h2><p className="text-sm text-slate-500">pending → authorized → paid</p></div><span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold">{payments?.length ?? 0}</span></div>
            {paymentsError && <p className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{paymentsError.message}</p>}
            <div className="mt-5 space-y-4">
              {(payments ?? []).map((p) => (
                <div key={p.id} className="rounded-2xl border border-slate-100 p-4">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div><p className="font-black">{p.payment_id}</p><p className="mt-1 text-sm text-slate-600">{actorMap.get(p.payer_actor_id) ?? "Payer"} → {actorMap.get(p.payee_actor_id) ?? "Beneficiary"}</p><p className="mt-1 text-xs text-slate-400">{p.method} · {new Date(p.created_at).toLocaleString()}</p></div>
                    <div className="text-right"><p className="text-lg font-black">{Number(p.amount).toFixed(2)} {p.currency}</p><span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-black text-orange-700">{p.status}</span></div>
                  </div>
                  {p.note && <p className="mt-3 rounded-xl bg-slate-50 p-3 text-sm text-slate-600">{p.note}</p>}
                  <div className="mt-4 flex flex-wrap gap-2 border-t border-slate-100 pt-4">
                    {statuses.map((status) => <form key={status} action={updatePaymentStatus.bind(null, id, p.id, status)}><button disabled={p.status === status} type="submit" className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-bold disabled:opacity-30 hover:border-orange-300 hover:text-orange-700">{status}</button></form>)}
                  </div>
                </div>
              ))}
              {!payments?.length && !paymentsError && <div className="rounded-2xl border border-dashed border-slate-300 p-10 text-center"><p className="font-bold">No payments yet</p><p className="mt-1 text-sm text-slate-500">Create the first payment above.</p></div>}
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}
