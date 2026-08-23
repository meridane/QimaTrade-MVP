import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { respondToOffer } from "@/app/demands/match/actions";
import TestAuthBar from "@/components/test-auth-bar";

export default async function OfferTestPage() {
  const supabase = await createSupabaseServerClient();
  const { data: demands } = await supabase.from("demands").select("id, demand_id, name, quantity, budget, currency, target_market").order("created_at", { ascending: false }).limit(20);
  const { data: offers } = await supabase.from("offers").select("id, offer_id, name, quantity, price, currency, market, geography, demand_id, lifecycle").order("created_at", { ascending: false }).limit(20);

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8">
      <div className="mx-auto max-w-6xl">
        <header className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm">
          <div className="flex items-center justify-between gap-4">
            <div><p className="text-base font-black text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Offer & Counter Offer test</p></div>
            <Link href="/" className="text-sm font-bold text-orange-600">Home</Link>
          </div>
        </header>

        <div className="mt-5">
          <TestAuthBar />
        </div>

        <section className="mt-6 rounded-3xl border border-orange-100 bg-orange-50 p-6">
          <h1 className="text-2xl font-black text-slate-950">Test Supplier Offer → Counter Offer → Agreement</h1>
          <p className="mt-2 text-sm leading-6 text-slate-600">Test this workflow with the two real Google accounts: <strong>adda.mahdi</strong> as Buyer and <strong>madda.yasser</strong> as Supplier. The account bar above always shows the active Google session.</p>
        </section>

        <div className="mt-6 grid gap-6 lg:grid-cols-2">
          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-black text-slate-950">Buyer demands</h2>
            <div className="mt-4 space-y-3">
              {(demands ?? []).map((demand) => (
                <div key={demand.id} className="rounded-2xl border border-slate-200 p-4">
                  <p className="font-bold text-slate-950">{demand.name}</p>
                  <p className="mt-1 text-xs text-slate-500">{demand.demand_id} · {demand.quantity} · {demand.budget ?? "No budget"} {demand.currency ?? ""} · {demand.target_market ?? "No market"}</p>
                  <p className="mt-2 break-all text-[11px] text-slate-400">UUID: {demand.id}</p>
                </div>
              ))}
            </div>
          </section>

          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-black text-slate-950">Supplier offers</h2>
            <div className="mt-4 space-y-4">
              {(offers ?? []).map((offer) => (
                <article key={offer.id} className="rounded-2xl border border-slate-200 p-4">
                  <p className="font-bold text-slate-950">{offer.name}</p>
                  <p className="mt-1 text-xs text-slate-500">{offer.quantity} · {offer.price ?? "No price"} {offer.currency ?? ""} · {offer.market ?? "No market"} · {offer.geography ?? "No geography"}</p>
                  <p className="mt-2 break-all text-[11px] text-slate-400">UUID: {offer.id}</p>
                  <form action={respondToOffer} className="mt-4 grid gap-2 sm:grid-cols-[1fr_auto]">
                    <select name="demandId" required className="rounded-xl border border-slate-200 px-3 py-2.5 text-sm">
                      <option value="">Select buyer demand</option>
                      {(demands ?? []).map((demand) => <option key={demand.id} value={demand.id}>{demand.demand_id} — {demand.name}</option>)}
                    </select>
                    <input type="hidden" name="offerId" value={offer.id} />
                    <div className="flex gap-2 sm:col-span-2">
                      <button name="decision" value="rejected" type="submit" className="rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-bold text-slate-700">Reject</button>
                      <button name="decision" value="accepted" type="submit" className="rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-bold text-white">Accept & open chat</button>
                    </div>
                  </form>
                </article>
              ))}
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}
