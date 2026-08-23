import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createShipment, updateShipmentStatus } from "./actions";
import LoadingForm from "./loading-form";

const statuses = ["pending", "pickup_scheduled", "picked_up", "in_transit", "delivered", "cancelled"] as const;
type Props = { params: Promise<{ id: string }> };
type Actor = { actor_id: string; name: string };

export default async function ProjectShipmentsPage({ params }: Props) {
  const { id } = await params;
  const supabase = await createSupabaseServerClient();
  const { data: project } = await supabase.from("projects").select("id, name, project_id").eq("id", id).maybeSingle();
  if (!project) return <main className="min-h-screen bg-slate-50 p-8"><div className="mx-auto max-w-4xl rounded-3xl border bg-white p-8"><h1 className="text-2xl font-black text-red-600">Project introuvable</h1><Link className="mt-4 inline-block text-orange-600" href="/projects/test">← Retour</Link></div></main>;

  const { data: participants } = await supabase.from("project_participants").select("actor_id, role").eq("project_id", id).order("created_at");
  const actorIds = (participants ?? []).map((p) => p.actor_id);
  let actors: Actor[] = [];
  if (actorIds.length) {
    const { data, error } = await supabase.from("actors").select("actor_id, name").in("actor_id", actorIds);
    if (error) throw new Error(error.message);
    actors = (data ?? []) as Actor[];
  }
  const actorMap = new Map(actors.map((a) => [a.actor_id, a.name]));
  const { data: orders } = await supabase.from("project_orders").select("id, order_id, title").eq("project_id", id).order("created_at", { ascending: false });
  const { data: shipments, error: shipmentsError } = await supabase.from("project_shipments").select("id, shipment_id, order_id, transporter_actor_id, pickup_location, destination, pickup_scheduled_at, delivery_scheduled_at, tracking_reference, status, notes, created_at, picked_up_at, delivered_at").eq("project_id", id).order("created_at", { ascending: false });

  return <main className="min-h-screen bg-slate-50 px-5 py-8"><div className="mx-auto max-w-6xl">
    <header className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm"><div className="flex items-center justify-between gap-4"><div><p className="text-base font-black text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Shipping / delivery functional test</p></div><div className="flex gap-4 text-sm font-bold"><Link href={`/projects/test/${id}/orders`} className="text-slate-600">Orders</Link><Link href={`/projects/test/${id}`} className="text-orange-600">← Project</Link></div></div></header>
    <section className="mt-5 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"><p className="text-xs font-black uppercase tracking-wider text-orange-600">SHIPPING / DELIVERY TEST</p><div className="mt-1 flex flex-wrap items-center justify-between gap-4"><div><h1 className="text-3xl font-black text-slate-950">Shipments — {project.name}</h1><p className="mt-1 text-xs text-slate-400">{project.project_id} · Order → Pickup → In transit → Delivered</p></div><span className="rounded-full bg-orange-50 px-4 py-2 text-xs font-black text-orange-700">{shipments?.length ?? 0} shipments</span></div></section>
    <div className="mt-6 grid gap-6 lg:grid-cols-3">
      <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"><h2 className="text-xl font-black">Create shipment</h2><p className="mt-1 text-sm text-slate-500">QimaTrade suit la livraison sans exécuter le transport.</p><LoadingForm action={createShipment.bind(null, id)} loadingText="Creating shipment..." className="mt-5 space-y-4">
        <label className="block text-sm font-bold">Order<select name="order_id" required className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">Select order</option>{(orders ?? []).map((o) => <option key={o.id} value={o.id}>{o.order_id} · {o.title}</option>)}</select></label>
        <label className="block text-sm font-bold">Transporter <span className="font-normal text-slate-400">(optional)</span><select name="transporter_actor_id" className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">External / not assigned</option>{(participants ?? []).map((p) => <option key={p.actor_id} value={p.actor_id}>{actorMap.get(p.actor_id) ?? p.actor_id} — {p.role}</option>)}</select></label>
        <label className="block text-sm font-bold">Pickup location<input name="pickup_location" required placeholder="Supplier warehouse" className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
        <label className="block text-sm font-bold">Destination<input name="destination" required placeholder="Buyer warehouse" className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
        <div className="grid grid-cols-2 gap-3"><label className="block text-sm font-bold">Pickup date<input name="pickup_scheduled_at" type="datetime-local" className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label><label className="block text-sm font-bold">Delivery date<input name="delivery_scheduled_at" type="datetime-local" className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label></div>
        <label className="block text-sm font-bold">Tracking reference<input name="tracking_reference" placeholder="TRK-2026-001" className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
        <label className="block text-sm font-bold">Notes<textarea name="notes" rows={3} placeholder="Optional logistics notes..." className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
        <button type="submit" className="w-full rounded-xl bg-orange-500 px-4 py-3 text-sm font-black text-white hover:bg-orange-600">Create shipment</button>
      </LoadingForm></section>
      <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm lg:col-span-2"><div className="flex items-center justify-between"><div><h2 className="text-xl font-black">Delivery workflow</h2><p className="text-sm text-slate-500">pending → pickup_scheduled → picked_up → in_transit → delivered</p></div><span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold">{shipments?.length ?? 0}</span></div>
        {shipmentsError && <p className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{shipmentsError.message}</p>}
        <div className="mt-5 space-y-4">{(shipments ?? []).map((s) => <div key={s.id} className="rounded-2xl border border-slate-100 p-4"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="font-black">{s.shipment_id}</p><p className="mt-1 text-sm font-bold">{s.pickup_location} → {s.destination}</p><p className="mt-1 text-xs text-slate-400">Order {orders?.find((o) => o.id === s.order_id)?.order_id ?? s.order_id}{s.transporter_actor_id ? ` · ${actorMap.get(s.transporter_actor_id) ?? "Transporter"}` : " · External transporter"}</p>{s.tracking_reference && <p className="mt-1 text-xs text-slate-500">Tracking: {s.tracking_reference}</p>}</div><span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-black text-orange-700">{s.status}</span></div>{s.notes && <p className="mt-3 rounded-xl bg-slate-50 p-3 text-sm text-slate-600">{s.notes}</p>}<div className="mt-4 flex flex-wrap gap-2 border-t border-slate-100 pt-4">{statuses.map((status) => <LoadingForm key={status} action={updateShipmentStatus.bind(null, id, s.id, status)} loadingText="Updating..." className="contents"><button disabled={s.status === status} type="submit" className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-bold disabled:cursor-not-allowed disabled:opacity-30 hover:border-orange-300 hover:text-orange-700">{status}</button></LoadingForm>)}</div></div>)}{!shipments?.length && !shipmentsError && <div className="rounded-2xl border border-dashed border-slate-300 p-10 text-center"><p className="font-bold">No shipments yet</p><p className="mt-1 text-sm text-slate-500">Create the first shipment above.</p></div>}</div>
      </section>
    </div>
  </div></main>;
}
