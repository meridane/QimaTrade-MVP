import { ArrowLeft } from "lucide-react";
import Link from "next/link";

export default function NewOfferPage() {
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
            <div className="grid gap-4 sm:grid-cols-2"><div><label className="text-sm font-bold" htmlFor="market">Target market</label><input id="market" name="market" placeholder="Morocco" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" /></div><div><label className="text-sm font-bold" htmlFor="geography">Supplier geography</label><input id="geography" name="geography" placeholder="South Korea" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" /></div></div>
            <div><label className="text-sm font-bold text-slate-800" htmlFor="conditions">Commercial terms</label><textarea id="conditions" name="conditions" rows={4} placeholder="Payment terms, Incoterm, delivery conditions..." className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" /></div>
            <button type="submit" className="rounded-xl bg-orange-500 px-6 py-3 text-sm font-bold text-white">Create offer</button>
          </form>
        </section>
      </div>
    </main>
  );
}
