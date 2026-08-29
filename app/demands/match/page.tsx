import { ArrowLeft, Check, CircleAlert, MapPin, PackageCheck, Scale, Wallet } from "lucide-react";
import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";

type Scope = {
  category?: string;
  subcategory?: string;
  product_master_id?: string;
  product_master_code?: string;
  product_master_name?: string;
  unit?: string;
  description?: string;
  requirements?: string[];
  qualification?: {
    budget?: number | null;
    currency?: string | null;
    deadline?: string | null;
    geography?: string | null;
    commercial_terms?: string | null;
    documentation?: string | null;
    attributes?: Array<{ key: string; value: string }>;
  };
};

type Offer = {
  id: string;
  demand_id: string | null;
  product_master_id: string | null;
  name: string;
  quantity: number;
  price: number | null;
  currency: string | null;
  market: string | null;
  geography: string | null;
  conditions: string | null;
  attributes: Record<string, string> | null;
};

function parseScope(value: unknown): Scope {
  if (!value) return {};
  if (typeof value === "object" && !Array.isArray(value)) return value as Scope;
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed as Scope : {};
    } catch { return {}; }
  }
  return {};
}

function formatMoney(value: number | null, currency: string | null) {
  if (value === null) return "Not specified";
  return `${value.toLocaleString()} ${currency ?? ""}`.trim();
}

function parseAttributes(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value as Record<string, unknown>).filter(([, item]) => typeof item === "string" && item.trim()).map(([key, item]) => [key, String(item)]));
}

function normalize(value: string) {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

export default async function DemandMatchPage({ searchParams }: { searchParams: Promise<{ id?: string }> }) {
  const { id } = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!id) return <MatchShell><EmptyState title="No demand selected" text="Open Match from a qualified demand so QimaTrade can compare compatible supplier offers." /></MatchShell>;

  const { data: demand } = await supabase.from("demands").select("id, demand_id, name, quantity, currency, budget, target_market, geography, scope").eq("id", id).single();
  if (!demand) return <MatchShell><EmptyState title="Demand not found" text="This demand is unavailable or you do not have access to it." /></MatchShell>;

  const scope = parseScope(demand.scope);
  const productMasterId = scope.product_master_id ?? null;
  const { data: offers } = productMasterId
    ? await supabase.from("offers").select("id, demand_id, product_master_id, name, quantity, price, currency, market, geography, conditions, attributes").eq("product_master_id", productMasterId).order("created_at", { ascending: false })
    : { data: [] as Offer[] };

  const requestedAttributes = (scope.qualification?.attributes ?? []).filter((item) => item.value?.trim());
  const evaluated = ((offers ?? []) as Offer[]).map((offer) => {
    const quantityOk = offer.quantity >= Number(demand.quantity ?? 0);
    const budgetOk = demand.budget === null || offer.price === null || offer.price <= demand.budget;
    const currencyOk = !demand.currency || !offer.currency || offer.currency === demand.currency;
    const marketOk = !demand.target_market || !offer.market || offer.market.toLowerCase() === demand.target_market.toLowerCase();
    const offerAttributes = parseAttributes(offer.attributes);
    const attributeResults = requestedAttributes.map((requested) => ({
      key: requested.key,
      requested: requested.value,
      actual: offerAttributes[requested.key] ?? "Not provided",
      ok: Boolean(offerAttributes[requested.key]) && normalize(offerAttributes[requested.key]) === normalize(requested.value),
    }));
    const attributeMatched = attributeResults.filter((item) => item.ok).length;
    const attributeTotal = attributeResults.length;
    const checks = [quantityOk, budgetOk, currencyOk, marketOk, ...(attributeTotal ? attributeResults.map((item) => item.ok) : [])];
    return { offer, quantityOk, budgetOk, currencyOk, marketOk, attributeResults, attributeMatched, attributeTotal, matched: checks.filter(Boolean).length, total: checks.length };
  }).sort((a, b) => b.matched - a.matched);

  return <MatchShell>
    <header className="rounded-3xl border border-slate-200 bg-white p-6 shadow-soft sm:p-8">
      <div className="flex flex-col gap-5 sm:flex-row sm:items-start sm:justify-between"><div><p className="text-sm font-bold text-orange-600">Step 03</p><h1 className="mt-1 text-3xl font-black tracking-tight text-slate-950">Explainable match</h1><p className="mt-2 max-w-2xl text-sm leading-6 text-slate-500">Offers are first restricted to the same canonical Product Master, then evaluated against commercial and requested product attributes.</p></div><div className="text-right"><span className="rounded-full bg-orange-50 px-3 py-1.5 text-xs font-bold text-orange-700">{demand.demand_id}</span>{scope.product_master_code && <p className="mt-2 text-xs font-mono text-slate-400">{scope.product_master_code}</p>}</div></div>
      <div className="mt-7 grid gap-3 sm:grid-cols-2 lg:grid-cols-4"><Summary icon={<PackageCheck size={18}/>} label="Quantity" value={`${demand.quantity ?? 0} ${scope.unit ?? "units"}`}/><Summary icon={<Wallet size={18}/>} label="Budget" value={formatMoney(demand.budget, demand.currency)}/><Summary icon={<MapPin size={18}/>} label="Market" value={demand.target_market ?? "Not specified"}/><Summary icon={<Scale size={18}/>} label="Delivery" value={demand.geography ?? scope.qualification?.geography ?? "Not specified"}/></div>
    </header>
    {evaluated.length === 0 ? <div className="mt-6"><EmptyState title="No compatible supplier offers" text="There are no offers linked to this canonical Product Master yet. An offer for another product will not appear here."/></div> : <section className="mt-6 space-y-5"><div className="flex items-end justify-between px-1"><div><p className="text-xs font-bold uppercase tracking-[0.16em] text-orange-600">Compatible offers</p><h2 className="mt-1 text-xl font-black text-slate-950">Available offers</h2></div><span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold text-slate-600">{evaluated.length} offer{evaluated.length > 1 ? "s" : ""}</span></div>
      {evaluated.map(({ offer, quantityOk, budgetOk, currencyOk, marketOk, attributeResults, attributeMatched, attributeTotal, matched, total }, index) => <article key={offer.id} className="rounded-3xl border border-slate-200 bg-white p-6 shadow-soft sm:p-8"><div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"><div><div className="flex items-center gap-3"><span className="flex h-8 w-8 items-center justify-center rounded-lg bg-orange-500 text-xs font-black text-white">#{index + 1}</span><h2 className="text-xl font-black text-slate-950">{offer.name}</h2></div><p className="mt-2 text-sm text-slate-500">Supplier location: {offer.geography ?? "Not specified"}</p></div><div className="rounded-xl bg-slate-950 px-4 py-2 text-right text-white"><p className="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Criteria matched</p><p className="text-lg font-black">{matched}/{total}</p></div></div>
        <div className="mt-6 grid gap-3 sm:grid-cols-2"><Criterion ok={quantityOk} label="Quantity" detail={`${offer.quantity} offered vs ${demand.quantity ?? 0} requested`}/><Criterion ok={budgetOk} label="Budget" detail={`${formatMoney(offer.price, offer.currency)} vs ${formatMoney(demand.budget, demand.currency)}`}/><Criterion ok={currencyOk} label="Currency" detail={`${offer.currency ?? "Not specified"} vs ${demand.currency ?? "Not specified"}`}/><Criterion ok={marketOk} label="Target market" detail={`${offer.market ?? "Not specified"} vs ${demand.target_market ?? "Not specified"}`}/></div>
        {attributeTotal > 0 && <div className="mt-5 rounded-2xl border border-orange-100 bg-orange-50/50 p-4"><div className="flex items-center justify-between gap-3"><div><p className="text-xs font-bold uppercase tracking-wide text-orange-600">Product attributes</p><p className="mt-1 text-sm font-bold text-slate-900">{attributeMatched}/{attributeTotal} requested attributes matched</p></div></div><div className="mt-3 grid gap-2 sm:grid-cols-2">{attributeResults.map((item) => <div key={item.key} className={`rounded-xl border p-3 ${item.ok ? "border-emerald-200 bg-emerald-50" : "border-amber-200 bg-amber-50"}`}><div className="flex items-center gap-2">{item.ok ? <Check size={16} className="text-emerald-600"/> : <CircleAlert size={16} className="text-amber-600"/>}<span className="text-xs font-bold text-slate-800">{item.key}</span></div><p className="mt-1 text-xs text-slate-600">Request: {item.requested} · Offer: {item.actual}</p></div>)}</div></div>}
        {offer.conditions && <div className="mt-5 rounded-2xl bg-slate-50 p-4"><p className="text-xs font-bold uppercase tracking-wide text-slate-500">Commercial conditions</p><p className="mt-2 text-sm leading-6 text-slate-700">{offer.conditions}</p></div>}
        <div className="mt-5 flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-orange-100 bg-orange-50/60 p-4"><div><p className="text-sm font-bold text-slate-900">Interested in this supplier?</p><p className="text-xs text-slate-500">Start a conversation after reviewing the match.</p></div><Link href={`/demands/conversation?offer=${encodeURIComponent(offer.id)}&demand=${encodeURIComponent(demand.id)}`} className="rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-bold text-white hover:bg-orange-600">Open conversation</Link></div>
      </article>)}
    </section>}
  </MatchShell>;
}

function MatchShell({ children }: { children: React.ReactNode }) { return <main className="min-h-screen bg-slate-50"><div className="mx-auto max-w-5xl px-5 py-6 sm:px-8 lg:py-10"><header className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-soft"><div className="flex items-center gap-3"><Link href="/demands" className="flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 text-slate-500 hover:border-orange-200 hover:text-orange-600" aria-label="Back"><ArrowLeft size={18}/></Link><div><p className="text-base font-bold tracking-tight text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Demand matching</p></div></div><span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-semibold text-orange-700">MVP · Match</span></header>{children}</div></main>; }
function Summary({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) { return <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4"><div className="flex items-center gap-2 text-orange-600">{icon}<span className="text-xs font-bold uppercase tracking-wide text-slate-500">{label}</span></div><p className="mt-2 text-sm font-bold text-slate-900">{value}</p></div>; }
function Criterion({ ok, label, detail }: { ok: boolean; label: string; detail: string }) { return <div className={`rounded-2xl border p-4 ${ok ? "border-emerald-200 bg-emerald-50" : "border-amber-200 bg-amber-50"}`}><div className="flex items-center gap-2">{ok ? <Check size={17} className="text-emerald-600"/> : <CircleAlert size={17} className="text-amber-600"/>}<span className={`text-sm font-bold ${ok ? "text-emerald-800" : "text-amber-800"}`}>{label}</span></div><p className={`mt-1 text-xs leading-5 ${ok ? "text-emerald-700" : "text-amber-700"}`}>{detail}</p></div>; }
function EmptyState({ title, text }: { title: string; text: string }) { return <div className="rounded-3xl border border-slate-200 bg-white p-8 text-center shadow-soft"><p className="text-lg font-black text-slate-950">{title}</p><p className="mx-auto mt-2 max-w-xl text-sm leading-6 text-slate-500">{text}</p></div>; }
