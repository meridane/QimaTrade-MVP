import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createPaymentRequest, updatePaymentRequestStatus } from "./actions";

const statuses = ["pending", "submitted", "confirmed", "rejected", "cancelled"] as const;
const methods = ["bank_transfer", "card", "toss", "cash"] as const;
type Props = { params: Promise<{ id: string }> };
type Actor = { actor_id: string; name: string };

export default async function PaymentRequestsPage({ params }: Props) {
  const { id } = await params;
  const supabase = await createSupabaseServerClient();
  const { data: project } = await supabase.from("projects").select("id, name, project_id").eq("id", id).maybeSingle();
  if (!project) return <main className="min-h-screen bg-slate-50 p-8"><div className="mx-auto max-w-4xl rounded-3xl border bg-white p-8"><h1 className="text-2xl font-black text-red-600">Project introuvable</h1><Link className="mt-4 inline-block text-orange-600" href="/projects/test">← Retour</Link></div></main>;

  const { data: participants } = await supabase.from("project_participants").select("actor_id, role").eq("project_id", id).order("created_at");
  const actorIds = (participants ?? []).map((p) => p.actor_id);
  let actors: Actor[] = [];
  if (actorIds.length) {
    const { data, error } = await supabase.from("actors").select("id, actor_id, name").in("id", actorIds);
    if (error) throw new Error(error.message);
    actors = (data ?? []).map((a) => ({ actor_id: a.id as string, name: a.name as string }));
  }
  const actorMap = new Map(actors.map((a) => [a.actor_id, a.name]));
  const { data: orders } = await supabase.from("project_orders").select("id, order_id, title, amount, currency, status").eq("project_id", id).order("created_at", { ascending: false });
  const { data: requests, error } = await supabase.from("payment_requests").select("id, request_id, order_id, payer_actor_id, payee_actor_id, amount, currency, method, instructions, status, created_at, submitted_at, confirmed_at").eq("project_id", id).order("created_at", { ascending: false });

  return <main className="min-h-screen bg-slate-50 px-5 py-8"><div className="mx-auto max-w-6xl">
    <header className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm flex items-center justify-between"><div><p className="font-black">QimaTrade</p><p className="text-xs text-slate-500">Payment Request — external payment</p></div><div className="flex gap-4 text-sm font-bold"><Link href={`/projects/test/${id}`} className="text-slate-600">← Project</Link><Link href={`/projects/test/${id}/orders`} className="text-orange-600">Orders</Link></div></header>
    <section className="mt-5 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"><p className="text-xs font-black uppercase tracking-wider text-orange-600">PAYMENT REQUEST</p><div className="mt-1 flex flex-wrap items-center justify-between gap-4"><div><h1 className="text-3xl font-black">Payment Requests — {project.name}</h1><p className="mt-1 text-xs text-slate-400">{project.project_id} · QimaTrade ne détient ni ne transfère les fonds.</p></div><span className="rounded-full bg-orange-50 px-4 py-2 text-xs font-black text-orange-700">{requests?.length ?? 0} requests</span></div></section>
    <div className="mt-6 grid gap-6 lg:grid-cols-3">
      <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"><h2 className="text-xl font-black">Create request</h2><p className="mt-1 text-sm text-slate-500">La demande indique comment payer. Le paiement réel se fait en dehors de QimaTrade.</p><form action={createPaymentRequest.bind(null, id)} className="mt-5 space-y-4">
        <label className="block text-sm font-bold">Order<select name="order_id" className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">No linked order</option>{(orders ?? []).map((o) => <option key={o.id} value={o.id}>{o.order_id} · {o.title}</option>)}</select></label>
        <label className="block text-sm font-bold">Payer<select name="payer_actor_id" required className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">Select payer</option>{(participants ?? []).map((p) => <option key={p.actor_id} value={p.actor_id}>{actorMap.get(p.actor_id) ?? p.actor_id}</option>)}</select></label>
        <label className="block text-sm font-bold">Beneficiary<select name="payee_actor_id" required className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">Select beneficiary</option>{(participants ?? []).map((p) => <option key={p.actor_id} value={p.actor_id}>{actorMap.get(p.actor_id) ?? p.actor_id}</option>)}</select></label>
        <div className="grid grid-cols-2 gap-3"><label className="block text-sm font-bold">Amount<input name="amount" type="number" min="0.01" step="0.01" required className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label><label className="block text-sm font-bold">Currency<input name="currency" defaultValue="USD" required className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm uppercase" /></label></div>
        <label className="block text-sm font-bold">Method<select name="method" defaultValue="bank_transfer" className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm">{methods.map((m) => <option key={m} value={m}>{m}</option>)}</select></label>
        <label className="block text-sm font-bold">Payment instructions<textarea name="instructions" rows={4} placeholder="Bank details / instructions supplied by the beneficiary..." className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
        <button type="submit" className="w-full rounded-xl bg-orange-500 px-4 py-3 text-sm font-black text-white hover:bg-orange-600">Create payment request</button>
      </form></section>
      <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm lg:col-span-2"><div className="flex items-center justify-between"><div><h2 className="text-xl font-black">Request workflow</h2><p className="text-sm text-slate-500">pending → submitted → confirmed</p></div></div>{error && <p className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{error.message}</p>}<div className="mt-5 space-y-4">
        {(requests ?? []).map((r) => <div key={r.id} className="rounded-2xl border border-slate-100 p-4"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="font-black">{r.request_id}</p><p className="mt-1 text-sm text-slate-600">{actorMap.get(r.payer_actor_id) ?? "Payer"} → {actorMap.get(r.payee_actor_id) ?? "Beneficiary"}</p><p className="mt-1 text-xs text-slate-400">{r.method} · {new Date(r.created_at).toLocaleString()}{r.order_id ? " · linked order" : ""}</p></div><div className="text-right"><p className="text-lg font-black">{Number(r.amount).toFixed(2)} {r.currency}</p><span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-black text-orange-700">{r.status}</span></div></div>{r.instructions && <p className="mt-3 rounded-xl bg-slate-50 p-3 text-sm text-slate-600 whitespace-pre-wrap">{r.instructions}</p>}<div className="mt-4 flex flex-wrap gap-2 border-t border-slate-100 pt-4">{statuses.map((status) => <form key={status} action={updatePaymentRequestStatus.bind(null, id, r.id, status)}><button disabled={r.status === status} type="submit" className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-bold disabled:opacity-30 hover:border-orange-300 hover:text-orange-700">{status}</button></form>)}</div></div>)}
        {!requests?.length && !error && <div className="rounded-2xl border border-dashed border-slate-300 p-10 text-center"><p className="font-bold">No payment requests yet</p></div>}
      </div></section>
    </div>
  </div></main>;
}
