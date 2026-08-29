"use client";

import { useState } from "react";
import { ArrowLeft, Check } from "lucide-react";
import Link from "next/link";

const commercialTerms = [
  "FOB",
  "CIF",
  "CFR",
  "EXW",
  "FCA",
  "DDP",
  "Payment in Advance",
  "Letter of Credit",
  "Negotiable",
];

export default function NewOfferPage() {
  const [selectedTerms, setSelectedTerms] = useState<string[]>([]);

  function toggleTerm(term: string) {
    setSelectedTerms((current) =>
      current.includes(term)
        ? current.filter((item) => item !== term)
        : [...current, term],
    );
  }

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-10 sm:px-8">
      <div className="mx-auto max-w-3xl">
        <Link href="/" className="inline-flex items-center gap-2 text-sm font-bold text-orange-600"><ArrowLeft size={16} /> Back</Link>
        <section className="mt-6 rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-orange-600">QimaTrade · Supplier</p>
          <h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950">Create a new offer</h1>
          <p className="mt-3 text-sm leading-6 text-slate-500">Start a supplier offer independently. Product classification and buyer matching come later.</p>
          <form action="/api/offers" method="post" className="mt-8 space-y-5">
            <div><label className="text-sm font-bold text-slate-800" htmlFor="name">Offer name</label><input id="name" name="name" required placeholder="e.g. Used CNC Vertical Machining Center" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" /></div>
            <div className="grid gap-4 sm:grid-cols-3">
              <div><label className="text-sm font-bold" htmlFor="quantity">Quantity</label><input id="quantity" name="quantity" required type="number" min="0.000001" step="any" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" /></div>
              <div><label className="text-sm font-bold" htmlFor="price">Price</label><input id="price" name="price" type="number" min="0" step="any" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" /></div>
              <div><label className="text-sm font-bold" htmlFor="currency">Currency</label><select id="currency" name="currency" defaultValue="USD" className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm"><option>USD</option><option>EUR</option><option>KRW</option><option>MAD</option><option>CNY</option></select></div>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="text-sm font-bold" htmlFor="market">Target market</label>
                <select id="market" name="market" defaultValue="" className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm">
                  <option value="" disabled>Select a target market</option>
                  <option value="Morocco">Morocco</option>
                  <option value="International Market">International Market</option>
                </select>
              </div>
              <div>
                <label className="text-sm font-bold" htmlFor="geography">Supplier geography</label>
                <select id="geography" name="geography" defaultValue="" className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm">
                  <option value="" disabled>Select supplier geography</option>
                  <option value="South Korea">South Korea</option>
                </select>
              </div>
            </div>
            <div>
              <label className="text-sm font-bold text-slate-800" htmlFor="conditions">Commercial terms</label>
              <input id="conditions" name="conditions" type="hidden" value={selectedTerms.join(", ")} readOnly />
              <div className="mt-2 flex flex-wrap gap-2 rounded-xl border border-slate-200 p-3">
                {commercialTerms.map((term) => {
                  const selected = selectedTerms.includes(term);
                  return (
                    <button
                      key={term}
                      type="button"
                      aria-pressed={selected}
                      onClick={() => toggleTerm(term)}
                      className={`inline-flex items-center gap-1.5 rounded-lg border px-3 py-2 text-sm font-bold transition-colors ${
                        selected
                          ? "border-orange-500 bg-orange-500 text-white"
                          : "border-slate-200 bg-white text-slate-700 hover:border-orange-300 hover:text-orange-600"
                      }`}
                    >
                      {selected && <Check size={14} strokeWidth={3} />}
                      {term}
                    </button>
                  );
                })}
              </div>
              <p className="mt-2 text-xs text-slate-500">Select all commercial terms that apply to this offer.</p>
            </div>
            <button type="submit" className="rounded-xl bg-orange-500 px-6 py-3 text-sm font-bold text-white">Create offer</button>
          </form>
        </section>
      </div>
    </main>
  );
}
