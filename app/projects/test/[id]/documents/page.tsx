import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { deleteDocument, uploadDocument } from "./actions";

type Props = { params: Promise<{ id: string }> };
type Doc = { id: string; document_id: string; order_id: string | null; shipment_id: string | null; document_type: string; file_name: string; storage_path: string; mime_type: string | null; file_size: number | null; notes: string | null; created_at: string };

const labels: Record<string, string> = { invoice: "Invoice", packing_list: "Packing list", payment_proof: "Payment proof", delivery_proof: "Delivery proof", contract: "Contract", other: "Other" };

export default async function ProjectDocumentsPage({ params }: Props) {
  const { id } = await params;
  const supabase = await createSupabaseServerClient();
  const { data: project } = await supabase.from("projects").select("id, name, project_id").eq("id", id).maybeSingle();
  if (!project) return <main className="min-h-screen bg-slate-50 p-8"><div className="mx-auto max-w-4xl rounded-3xl border bg-white p-8"><h1 className="text-2xl font-black text-red-600">Project introuvable</h1><Link className="mt-4 inline-block text-orange-600" href="/projects/test">← Retour</Link></div></main>;

  const { data: participants } = await supabase.from("project_participants").select("actor_id, role").eq("project_id", id).order("created_at");
  const actorIds = (participants ?? []).map((p) => p.actor_id);
  let actors: { actor_id: string; name: string }[] = [];
  if (actorIds.length) {
    const { data, error } = await supabase.from("actors").select("actor_id, name").in("actor_id", actorIds);
    if (error) throw new Error(error.message);
    actors = data ?? [];
  }
  const actorMap = new Map(actors.map((a) => [a.actor_id, a.name]));
  const { data: orders } = await supabase.from("project_orders").select("id, order_id, title").eq("project_id", id).order("created_at", { ascending: false });
  const { data: shipments } = await supabase.from("project_shipments").select("id, shipment_id, pickup_location, destination").eq("project_id", id).order("created_at", { ascending: false });
  const { data: docs, error: docsError } = await supabase.from("project_documents").select("id, document_id, order_id, shipment_id, document_type, file_name, storage_path, mime_type, file_size, notes, created_at, uploaded_by_actor_id").eq("project_id", id).order("created_at", { ascending: false });

  const documents = await Promise.all((docs ?? []).map(async (doc) => {
    const { data } = await supabase.storage.from("project-documents").createSignedUrl(doc.storage_path, 3600);
    return { ...doc, signedUrl: data?.signedUrl ?? null };
  }));

  return <main className="min-h-screen bg-slate-50 px-5 py-8"><div className="mx-auto max-w-6xl">
    <header className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm"><div className="flex items-center justify-between gap-4"><div><p className="text-base font-black text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Documents & proof functional test</p></div><div className="flex gap-4 text-sm font-bold"><Link href={`/projects/test/${id}/orders`} className="text-slate-600">Orders</Link><Link href={`/projects/test/${id}/shipments`} className="text-slate-600">Shipping</Link><Link href={`/projects/test/${id}`} className="text-orange-600">← Project</Link></div></div></header>
    <section className="mt-5 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"><p className="text-xs font-black uppercase tracking-wider text-orange-600">DOCUMENTS / PROOF TEST</p><div className="mt-1 flex flex-wrap items-center justify-between gap-4"><div><h1 className="text-3xl font-black text-slate-950">Documents — {project.name}</h1><p className="mt-1 text-xs text-slate-400">{project.project_id} · Invoice · Payment proof · Delivery proof · Shipping documents</p></div><span className="rounded-full bg-orange-50 px-4 py-2 text-xs font-black text-orange-700">{documents.length} documents</span></div></section>
    <div className="mt-6 grid gap-6 lg:grid-cols-3">
      <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"><h2 className="text-xl font-black">Upload document</h2><p className="mt-1 text-sm text-slate-500">Fichiers privés, accessibles uniquement aux participants du Project.</p><form action={uploadDocument.bind(null, id)} encType="multipart/form-data" className="mt-5 space-y-4">
        <label className="block text-sm font-bold">Document type<select name="document_type" defaultValue="invoice" className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm">{Object.entries(labels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
        <label className="block text-sm font-bold">Order <span className="font-normal text-slate-400">(optional if Shipment selected)</span><select name="order_id" className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">No order</option>{(orders ?? []).map((o) => <option key={o.id} value={o.id}>{o.order_id} · {o.title}</option>)}</select></label>
        <label className="block text-sm font-bold">Shipment <span className="font-normal text-slate-400">(optional if Order selected)</span><select name="shipment_id" className="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm"><option value="">No shipment</option>{(shipments ?? []).map((s) => <option key={s.id} value={s.id}>{s.shipment_id} · {s.pickup_location} → {s.destination}</option>)}</select></label>
        <label className="block text-sm font-bold">File<input name="file" type="file" required className="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-3 text-sm" /></label>
        <p className="text-xs text-slate-400">Maximum test file size: 6 MB.</p>
        <label className="block text-sm font-bold">Notes<textarea name="notes" rows={3} placeholder="Optional notes..." className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-3 text-sm" /></label>
        <button type="submit" className="w-full rounded-xl bg-orange-500 px-4 py-3 text-sm font-black text-white hover:bg-orange-600">Upload document</button>
      </form></section>
      <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm lg:col-span-2"><div className="flex items-center justify-between"><div><h2 className="text-xl font-black">Documents</h2><p className="text-sm text-slate-500">Private files linked to Orders and Shipments.</p></div><span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold">{documents.length}</span></div>
        {docsError && <p className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{docsError.message}</p>}
        <div className="mt-5 space-y-4">{documents.map((doc) => <div key={doc.id} className="rounded-2xl border border-slate-100 p-4"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="font-black">{doc.document_id}</p><p className="mt-1 text-base font-bold">{doc.file_name}</p><p className="mt-1 text-xs text-slate-500">{labels[doc.document_type] ?? doc.document_type} · {doc.mime_type ?? "file"} · {doc.file_size ? `${(doc.file_size / 1024).toFixed(1)} KB` : "size unknown"}</p><p className="mt-1 text-xs text-slate-400">Added by participant · {new Date(doc.created_at).toLocaleString()}</p></div><div className="flex gap-2">{doc.signedUrl && <a href={doc.signedUrl} target="_blank" rel="noreferrer" className="rounded-xl border border-slate-200 px-3 py-2 text-xs font-bold text-orange-600 hover:border-orange-300">Open</a>}<form action={deleteDocument.bind(null, id, doc.id)}><button type="submit" className="rounded-xl border border-red-100 px-3 py-2 text-xs font-bold text-red-600 hover:bg-red-50">Delete</button></form></div></div><div className="mt-3 flex flex-wrap gap-2 text-xs text-slate-500">{doc.order_id && <span className="rounded-full bg-slate-50 px-3 py-1">Order: {orders?.find((o) => o.id === doc.order_id)?.order_id ?? doc.order_id}</span>}{doc.shipment_id && <span className="rounded-full bg-slate-50 px-3 py-1">Shipment: {shipments?.find((s) => s.id === doc.shipment_id)?.shipment_id ?? doc.shipment_id}</span>}</div>{doc.notes && <p className="mt-3 rounded-xl bg-slate-50 p-3 text-sm text-slate-600">{doc.notes}</p>}</div>)}{!documents.length && !docsError && <div className="rounded-2xl border border-dashed border-slate-300 p-10 text-center"><p className="font-bold">No documents yet</p><p className="mt-1 text-sm text-slate-500">Upload the first proof document above.</p></div>}</div>
      </section>
    </div>
  </div></main>;
}
