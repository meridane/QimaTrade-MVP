"use client";

import { ArrowLeft, Check, Loader2, Send } from "lucide-react";
import Link from "next/link";
import { FormEvent, useState } from "react";
import { createOffer } from "./actions";

export default function OffersPage() {
  const [savedOfferId, setSavedOfferId] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError("");

    const form = new FormData(event.currentTarget);
    const result = await createOffer({
      demandId: String(form.get("demandId") ?? ""),
      name: String(form.get("name") ?? ""),
      quantity: String(form.get("quantity") ?? ""),
      price: String(form.get("price") ?? ""),
      currency: String(form.get("currency") ?? "USD"),
      conditions: String(form.get("conditions") ?? ""),
      market: String(form.get("market") ?? ""),
      geography: String(form.get("geography") ?? ""),
    });

    if (result.ok) {
      setSavedOfferId(result.offerId);
      event.currentTarget.reset();
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
            <Link href="/" className="flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 text-slate-500 hover:border-orange-200 hover:text-orange-600" aria-label="Back"><ArrowLeft size={18} /></Link>
            <div><p className="text-base font-bold tracking-tight text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Supplier workspace</p></div>
          </div>
          <span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-semibold text-orange-700">MVP · Offer</span>
        </header>

        <div className="mt-8 grid gap-6 lg:grid-cols-[1fr_320px]">
          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-soft sm:p-8">
            <p className="text-sm font-bold text-orange-600">Supplier step</p>
            <h1 className="mt-1 text-3xl font-black tracking-tight text-slate-950">Submit an offer</h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-500">Create a structured supplier offer against an existing buyer demand. The next Match step will use these fields to explain compatibility.</p>

            {savedOfferId ? (
              <div className="mt-8 rounded-2xl border border-emerald-200 bg-emerald-50 p-5 text-emerald-800">
                <div className="flex items-center gap-3"><div className="flex h-9 w-9 items-center justify-center rounded-full bg-emerald-600 text-white"><Check size={18} /></div><div><p className="font-bold">Offer saved</p><p className="mt-1 text-sm text-emerald-700">The supplier offer is now stored in QimaTrade.</p><p className="mt-2 break-all text-xs font-medium">Offer ID: {savedOfferId}</p></div></div>
                <button type="button" onClick={() => setSavedOfferId("")} className="mt-5 rounded-xl border border-emerald-200 bg-white px-4 py-2.5 text-sm font-bold text-emerald-800">Create another offer</button>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="mt-8 space-y-6">
                {error && <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">{error}</div>}

                <div><label htmlFor="demandId" className="mb-2 block text-sm font-bold text-slate-800">Demand ID</label><input id="demandId" name="demandId" required placeholder="Paste the demand UUID" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /><p className="mt-1 text-xs text-slate-400">For this first supplier test, use the UUID shown after creating the demand.</p></div>
                <div><label htmlFor="name" className="mb-2 block text-sm font-bold text-slate-800">Offer name</label><input id="name" name="name" required placeholder="e.g. Recycled copper cathode grade A" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div>
                <div className="grid gap-5 sm:grid-cols-3"><div><label htmlFor="quantity" className="mb-2 block text-sm font-bold text-slate-800">Quantity</label><input id="quantity" name="quantity" type="number" min="0.000001" step="any" required placeholder="20" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div><div><label htmlFor="price" className="mb-2 block text-sm font-bold text-slate-800">Price</label><input id="price" name="price" type="number" min="0" step="any" placeholder="40000" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div><div><label htmlFor="currency" className="mb-2 block text-sm font-bold text-slate-800">Currency</label><select id="currency" name="currency" defaultValue="USD" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100"><option>USD</option><option>EUR</option><option>KRW</option><option>MAD</option><option>CNY</option></select></div></div>
                <div className="grid gap-5 sm:grid-cols-2"><div><label htmlFor="market" className="mb-2 block text-sm font-bold text-slate-800">Target market</label><input id="market" name="market" placeholder="Morocco" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div><div><label htmlFor="geography" className="mb-2 block text-sm font-bold text-slate-800">Supplier geography</label><input id="geography" name="geography" placeholder="South Korea" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div></div>
                <div><label htmlFor="conditions" className="mb-2 block text-sm font-bold text-slate-800">Commercial conditions</label><textarea id="conditions" name="conditions" rows={4} placeholder="Payment terms, Incoterm, delivery conditions, documentation..." className="w-full resize-none rounded-xl border border-slate-200 px-4 py-3 text-sm leading-6 outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /></div>

                <div className="flex justify-end border-t border-slate-100 pt-6"><button disabled={saving} type="submit" className="inline-flex items-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white shadow-lg shadow-orange-500/20 hover:bg-orange-600 disabled:cursor-not-allowed disabled:opacity-60">{saving ? <><Loader2 size={17} className="animate-spin" /> Saving...</> : <>Submit offer <Send size={17} /></>}</button></div>
              </form>
            )}
          </section>

          <aside className="h-fit rounded-3xl border border-slate-200 bg-slate-950 p-6 text-white shadow-soft"><p className="text-xs font-bold uppercase tracking-[0.18em] text-orange-400">MVP flow</p><div className="mt-5 space-y-3">{[["01", "Demand", false], ["02", "Qualification", false], ["03", "Supplier offer", true], ["04", "Match", false], ["05", "Conversation", false]].map(([number, label, active]) => <div key={number as string} className={`flex items-center gap-3 rounded-xl px-3 py-3 ${active ? "bg-white/10" : "opacity-50"}`}><span className={`flex h-8 w-8 items-center justify-center rounded-lg text-xs font-black ${active ? "bg-orange-500 text-white" : "bg-white/10 text-slate-300"}`}>{number}</span><span className="text-sm font-semibold">{label}</span></div>)}</div><div className="mt-7 border-t border-white/10 pt-5"><p className="text-sm font-bold">Why structured offers?</p><p className="mt-2 text-xs leading-5 text-slate-400">The Match engine needs comparable quantity, price, market, geography and commercial conditions.</p></div></aside>
        </div>
      </div>
    </main>
  );
}
