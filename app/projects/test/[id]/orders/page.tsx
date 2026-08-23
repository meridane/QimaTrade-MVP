import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createOrder, updateOrderStatus } from "./actions";

type Props = { params: Promise<{ id: string }> };
type Actor = { actor_id: string; name: string };

const statuses = ["draft", "confirmed", "processing", "completed", "cancelled"] as const;

export default async function ProjectOrdersPage({ params }: Props) {
  const { id } = await params;
  const supabase = await createSupabaseServerClient();

  const { data: project } = await supabase.from("projects").select("id, name, project_id, status").eq("id", id).maybeSingle();
  if (!project) {
    return <main className="min-h-screen bg-slate-50 p-8"><div className="mx-auto max-w-4xl rounded-3xl border bg-white p-8"><h1 className="text-2xl font-black text-red-600">Project introuvable</h1><Link className="mt-4 inline-block text-orange-600" href="/projects/test">← Retour</Link></div></main>;
  }

  const { data: participants } = await supabase.from("project_participants").select("actor_id, role").eq("project_id", id).order("created_at");
  const actorIds = (participants ?? []).map((p) => p.actor_id);
  let actors: Actor[] = [];
  if (actorIds.length) {
    const { data, error } = await supabase.from("actors").select("actor_id, name").in("actor_id", actorIds);
    if (error) throw new Error(error.message);
    actors = (data ?? []) as Actor[];
  }
  const actorMap = new Map(actors.map((a) => [a.actor_id, a.name]));

  const { data: payments } = await supabase.from("project_payments").select("id, payment_id, amount, currency, status").eq("project_id", id).order("created_at", { ascending: false });
  const { data: orders, error: ordersError } = await supabase.from("project_orders").select("id, order_id, buyer_actor_id, seller_actor_id, title, description, amount, currency, status, payment_id, created_at, completed_at").eq("project_id", id).order("created_at", { ascending: false });

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8">
      <div className="mx-auto max-w-6xl">
        <header className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm">
          <div className="flex items-center justify-between gap-4">
            <div><p className="text-base font-black text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Order / transaction functional test</p></div>
            <div className="flex gap-4 text-sm font-bold"><Link href={`/projects/test/${id}`} className="text-slate-600">← Project</Link><Link href={`/projects/test/${id}/payments`} className="text-orange-600">Payments</Link></div>
          </div>
        </header>

        <section className="mt-5 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <p className="text-xs font-black uppercase tracking-wider text-orange-600">ORDER / TRANSACTION TEST</p>
          <div className="mt-1 flex flex-wrap items-center justify-between gap-4">
            <div><h1 className="text-3xl font-black text-slate-950">Orders — {project.name}</h1><p className="mt-1 text-xs text-slate-400">{project.project_id} · Demand → Match → Conversation → Payment → Order</p></div>
            <span className="rounded-full bg-orange-50 px-4 py-2 text-xs font-black text-orange-700">{orders?.length ?? 0} orders</span>
          </div>
        </section>

        <div className="mt-6 grid gap-6 lg:grid-cols-3">
          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-xl font-black">Create order</h2>
            <p className="mt-1 text-sm text-slate-500">Simulation de la transaction commerciale après le match et le paiement.</p>
            <form action={createOrder.bind(null, id)} className="mt-5 space-y-4">
              <label className="block text-sm font-bold">Buyer<select name="buyer_actor_id" required className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">Select buyer</option>{(participants ?? []).map((p) => <option key={p.actor_id} value={p.actor_id}>{actorMap.get(p.actor_id) ?? p.actor_id} — {p.role}</option>)}</select></label>
              <label className="block text-sm font-bold">Seller<select name="seller_actor_id" required className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">Select seller</option>{(participants ?? []).map((p) => <option key={p.actor_id} value={p.actor_id}>{actorMap.get(p.actor_id) ?? p.actor_id} — {p.role}</option>)}</select></label>
              <label className="block text-sm font-bold">Title<input name="title" required placeholder="Used vehicle order" className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
              <label className="block text-sm font-bold">Description<textarea name="description" rows={3} placeholder="Commercial details..." className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
              <div className="grid grid-cols-2 gap-3"><label className="block text-sm font-bold">Amount<input name="amount" type="number" min="0.01" step="0.01" required placeholder="1000" className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label><label className="block text-sm font-bold">Currency<input name="currency" defaultValue="USD" required maxLength={10} className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm uppercase" /></label></div>
              <label className="block text-sm font-bold">Link payment <span className="font-normal text-slate-400">(optional)</span><select name="payment_id" className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">No linked payment</option>{(payments ?? []).map((p) => <option key={p.id} value={p.id}>{p.payment_id} · {Number(p.amount).toFixed(2)} {p.currency} · {p.status}</option>)}</select></label>
              <button type="submit" className="w-full rounded-xl bg-orange-500 px-4 py-3 text-sm font-black text-white hover:bg-orange-600">Create order</button>
            </form>
          </section>

          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm lg:col-span-2">
            <div className="flex items-center justify-between"><div><h2 className="text-xl font-black">Transaction workflow</h2><p className="text-sm text-slate-500">draft → confirmed → processing → completed</p></div><span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold">{orders?.length ?? 0}</span></div>
            {ordersError && <p className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{ordersError.message}</p>}
            <div className="mt-5 space-y-4">
              {(orders ?? []).map((o) => <div key={o.id} className="rounded-2xl border border-slate-100 p-4"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="font-black">{o.order_id}</p><p className="mt-1 text-base font-bold">{o.title}</p><p className="mt-1 text-sm text-slate-600">{actorMap.get(o.buyer_actor_id) ?? "Buyer"} → {actorMap.get(o.seller_actor_id) ?? "Seller"}</p><p className="mt-1 text-xs text-slate-400">Created {new Date(o.created_at).toLocaleString()}{o.payment_id ? ` · Payment linked` : ""}</p></div><div className="text-right"><p className="text-lg font-black">{Number(o.amount).toFixed(2)} {o.currency}</p><span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-black text-orange-700">{o.status}</span></div></div>{o.description && <p className="mt-3 rounded-xl bg-slate-50 p-3 text-sm text-slate-600">{o.description}</p>}<div className="mt-4 flex flex-wrap gap-2 border-t border-slate-100 pt-4">{statuses.map((status) => <form key={status} action={updateOrderStatus.bind(null, id, o.id, status)}><button disabled={o.status === status} type="submit" className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-bold disabled:opacity-30 hover:border-orange-300 hover:text-orange-700">{status}</button></form>)}</div></div>)}
              {!orders?.length && !ordersError && <div className="rounded-2xl border border-dashed border-slate-300 p-10 text-center"><p className="font-bold">No orders yet</p><p className="mt-1 text-sm text-slate-500">Create the first commercial order above.</p></div>}
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}
