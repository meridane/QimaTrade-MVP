"use client";

import { ArrowLeft, ArrowRight, Check, ClipboardList, Loader2, Plus, X } from "lucide-react";
import Link from "next/link";
import { FormEvent, useState } from "react";
import { createDemand } from "./actions";

const categories = ["Raw materials", "Industrial equipment", "Packaging", "Automotive", "Other"];

export default function DemandsPage() {
  const [requirements, setRequirements] = useState<string[]>([]);
  const [requirement, setRequirement] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [demandId, setDemandId] = useState("");

  function addRequirement() {
    const value = requirement.trim();
    if (!value || requirements.includes(value)) return;
    setRequirements((current) => [...current, value].slice(0, 20));
    setRequirement("");
  }

  function removeRequirement(value: string) {
    setRequirements((current) => current.filter((item) => item !== value));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError("");

    const formData = new FormData(event.currentTarget);
    const result = await createDemand({
      title: String(formData.get("title") ?? ""),
      category: String(formData.get("category") ?? ""),
      quantity: String(formData.get("quantity") ?? ""),
      unit: String(formData.get("unit") ?? ""),
      destination: String(formData.get("destination") ?? ""),
      description: String(formData.get("description") ?? ""),
      requirements,
    });

    if (result.ok) {
      setDemandId(result.demandId);
      setSubmitted(true);
    } else {
      setError(result.error);
    }

    setSaving(false);
  }

  return (
    <main className="min-h-screen bg-slate-50">
      <div className="mx-auto max-w-5xl px-5 py-6 sm:px-8 lg:py-10">
        <header className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-soft">
          <div className="flex items-center gap-3">
            <Link href="/" className="flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 text-slate-500 transition hover:border-orange-200 hover:text-orange-600" aria-label="Back to home"><ArrowLeft size={18} /></Link>
            <div><p className="text-base font-bold tracking-tight text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Create a demand</p></div>
          </div>
          <span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-semibold text-orange-700">MVP · Demand</span>
        </header>

        <div className="mt-8 grid gap-6 lg:grid-cols-[1fr_320px]">
          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-soft sm:p-8">
            <div className="mb-8 flex items-start gap-4">
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-orange-50 text-orange-600"><ClipboardList size={23} /></div>
              <div><p className="text-sm font-bold text-orange-600">Step 01</p><h1 className="mt-1 text-3xl font-black tracking-tight text-slate-950">Create a demand</h1><p className="mt-2 max-w-2xl text-sm leading-6 text-slate-500">Tell QimaTrade what you need. These first fields define the minimum information used to qualify and match the demand.</p></div>
            </div>

            {submitted ? (
              <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-5 text-emerald-800">
                <div className="flex items-center gap-3"><div className="flex h-9 w-9 items-center justify-center rounded-full bg-emerald-600 text-white"><Check size={18} /></div><div><p className="font-bold">Demand saved</p><p className="mt-1 text-sm text-emerald-700">Your demand is now stored in QimaTrade and ready for qualification.</p><p className="mt-2 break-all text-xs font-medium text-emerald-800">ID: {demandId}</p></div></div>
                <div className="mt-5 flex flex-col gap-3 sm:flex-row"><Link href={`/demands/qualification?id=${encodeURIComponent(demandId)}`} className="inline-flex items-center justify-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600">Continue to qualification <ArrowRight size={17} /></Link><Link href="/demands" className="inline-flex items-center justify-center rounded-xl border border-slate-200 bg-white px-5 py-3 text-sm font-bold text-slate-700">Create another demand</Link></div>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-6">
                {error && <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">{error}</div>}
                <div><label htmlFor="title" className="mb-2 block text-sm font-bold text-slate-800">Demand title</label><input id="title" name="title" required placeholder="e.g. 20 tonnes of recycled aluminium" className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div>
                <div className="grid gap-5 sm:grid-cols-2"><div><label htmlFor="category" className="mb-2 block text-sm font-bold text-slate-800">Category</label><select id="category" name="category" required defaultValue="" className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition focus:border-orange-400 focus:ring-4 focus:ring-orange-100"><option value="" disabled>Select a category</option>{categories.map((item) => <option key={item}>{item}</option>)}</select></div><div><label htmlFor="quantity" className="mb-2 block text-sm font-bold text-slate-800">Quantity</label><input id="quantity" name="quantity" type="number" min="0.000001" step="any" required placeholder="e.g. 20" className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div></div>
                <div className="grid gap-5 sm:grid-cols-2"><div><label htmlFor="unit" className="mb-2 block text-sm font-bold text-slate-800">Unit</label><select id="unit" name="unit" defaultValue="tonnes" className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition focus:border-orange-400 focus:ring-4 focus:ring-orange-100"><option value="tonnes">Tonnes</option><option value="kg">Kilograms</option><option value="units">Units</option><option value="containers">Containers</option></select></div><div><label htmlFor="destination" className="mb-2 block text-sm font-bold text-slate-800">Destination market</label><input id="destination" name="destination" placeholder="e.g. Morocco" className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div></div>
                <div><label htmlFor="description" className="mb-2 block text-sm font-bold text-slate-800">Description</label><textarea id="description" name="description" rows={5} required placeholder="Describe quality, specifications, delivery expectations and anything a supplier needs to know." className="w-full resize-none rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm leading-6 outline-none transition placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div>
                <div><label htmlFor="requirement" className="mb-2 block text-sm font-bold text-slate-800">Important requirements</label><div className="flex gap-2"><input id="requirement" value={requirement} onChange={(event) => setRequirement(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); addRequirement(); } }} placeholder="e.g. Certificate of analysis" className="min-w-0 flex-1 rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /><button type="button" onClick={addRequirement} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 px-4 py-3 text-sm font-bold text-slate-700 transition hover:border-orange-200 hover:text-orange-600"><Plus size={17} />Add</button></div>{requirements.length > 0 && <div className="mt-3 flex flex-wrap gap-2">{requirements.map((item) => <span key={item} className="inline-flex items-center gap-1.5 rounded-full bg-slate-100 px-3 py-1.5 text-xs font-semibold text-slate-700">{item}<button type="button" onClick={() => removeRequirement(item)} aria-label={`Remove ${item}`} className="text-slate-400 hover:text-slate-700"><X size={13} /></button></span>)}</div>}</div>
                <div className="flex flex-col gap-3 border-t border-slate-100 pt-6 sm:flex-row sm:items-center sm:justify-between"><p className="text-xs leading-5 text-slate-400">Next: qualification and matching will use this structured demand.</p><button disabled={saving} type="submit" className="inline-flex items-center justify-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600 disabled:cursor-not-allowed disabled:opacity-60">{saving ? <><Loader2 size={17} className="animate-spin" /> Saving...</> : <>Save demand <Plus size={17} /></>}</button></div>
              </form>
            )}
          </section>

          <aside className="h-fit rounded-3xl border border-slate-200 bg-slate-950 p-6 text-white shadow-soft"><p className="text-xs font-bold uppercase tracking-[0.18em] text-orange-400">MVP flow</p><div className="mt-5 space-y-3">{[["01", "Demand", true], ["02", "Qualification", false], ["03", "Match", false], ["04", "Conversation", false]].map(([number, label, active]) => <div key={number as string} className={`flex items-center gap-3 rounded-xl px-3 py-3 ${active ? "bg-white/10" : "opacity-50"}`}><span className={`flex h-8 w-8 items-center justify-center rounded-lg text-xs font-black ${active ? "bg-orange-500 text-white" : "bg-white/10 text-slate-300"}`}>{number}</span><span className="text-sm font-semibold">{label}</span></div>)}</div><div className="mt-7 border-t border-white/10 pt-5"><p className="text-sm font-bold">Why these fields?</p><p className="mt-2 text-xs leading-5 text-slate-400">The MVP starts with structured commercial information so future matching can be explainable instead of relying on an opaque score.</p></div></aside>
        </div>
      </div>
    </main>
  );
}
