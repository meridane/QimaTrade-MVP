"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";

type Capability = {
  id: string;
  capability_id: string;
  name: string;
  capability_type: string | null;
  capacity: number | null;
  geography: string | null;
  markets_served: string | null;
  documentation_status: string | null;
};

export default function CapabilitiesPage() {
  const [items, setItems] = useState<Capability[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [form, setForm] = useState({ name: "", capabilityType: "", capacity: "", geography: "", marketsServed: "" });

  async function load() {
    try {
      setError("");
      const response = await fetch("/api/service-provider/capabilities", { cache: "no-store" });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Unable to load capabilities.");
      setItems(data.capabilities ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unable to load capabilities.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!form.name.trim()) return setError("Capability name is required.");

    setSaving(true);
    setError("");
    try {
      const response = await fetch("/api/service-provider/capabilities", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Unable to create capability.");
      setItems((current) => [data.capability, ...current]);
      setForm({ name: "", capabilityType: "", capacity: "", geography: "", marketsServed: "" });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unable to create capability.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-10 sm:px-8">
      <div className="mx-auto max-w-6xl">
        <Link href="/service-provider" className="text-sm font-bold text-orange-600">← Service Provider</Link>
        <h1 className="mt-3 text-3xl font-black tracking-tight text-slate-950">My Capabilities</h1>
        <p className="mt-2 text-sm text-slate-500">Define the capabilities your organization can deliver.</p>

        {error && <div className="mt-6 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">{error}</div>}

        <section className="mt-7 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm">
          <h2 className="text-xl font-black text-slate-950">Add capability</h2>
          <form onSubmit={submit} className="mt-5 grid gap-4 md:grid-cols-2">
            <Input label="Name *" value={form.name} onChange={(v) => setForm({ ...form, name: v })} />
            <Input label="Type" value={form.capabilityType} onChange={(v) => setForm({ ...form, capabilityType: v })} />
            <Input label="Capacity" value={form.capacity} type="number" onChange={(v) => setForm({ ...form, capacity: v })} />
            <Input label="Geography" value={form.geography} onChange={(v) => setForm({ ...form, geography: v })} />
            <div className="md:col-span-2"><Input label="Markets served" value={form.marketsServed} onChange={(v) => setForm({ ...form, marketsServed: v })} /></div>
            <div className="md:col-span-2"><button disabled={saving} className="rounded-xl bg-orange-600 px-5 py-3 text-sm font-bold text-white disabled:opacity-50">{saving ? "Saving…" : "Create capability"}</button></div>
          </form>
        </section>

        <section className="mt-7 space-y-4">
          {loading && <div className="rounded-3xl border border-slate-200 bg-white p-7">Loading…</div>}
          {!loading && items.length === 0 && <div className="rounded-3xl border border-dashed border-slate-300 bg-white p-7 text-sm text-slate-500">No capabilities yet.</div>}
          {items.map((item) => (
            <article key={item.id} className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                <div><h3 className="text-lg font-black text-slate-950">{item.name}</h3><p className="text-xs text-slate-400">{item.capability_id}</p></div>
                <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold text-slate-600">{item.documentation_status || "not documented"}</span>
              </div>
              <div className="mt-4 grid gap-3 text-sm text-slate-600 sm:grid-cols-3">
                <p><b>Type:</b> {item.capability_type || "—"}</p><p><b>Capacity:</b> {item.capacity ?? "—"}</p><p><b>Geography:</b> {item.geography || "—"}</p>
              </div>
              {item.markets_served && <p className="mt-3 text-sm text-slate-600"><b>Markets:</b> {item.markets_served}</p>}
            </article>
          ))}
        </section>
      </div>
    </main>
  );
}

function Input({ label, value, onChange, type = "text" }: { label: string; value: string; onChange: (value: string) => void; type?: string }) {
  return <label className="block"><span className="mb-2 block text-xs font-bold uppercase tracking-wide text-slate-500">{label}</span><input type={type} value={value} onChange={(e) => onChange(e.target.value)} className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-500" /></label>;
}
