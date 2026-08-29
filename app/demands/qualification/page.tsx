"use client";

import { ArrowLeft, ArrowRight, ClipboardCheck, Loader2 } from "lucide-react";
import Link from "next/link";
import { FormEvent, Suspense, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { getQualificationDemand, type QualificationDemandData, qualifyDemand } from "./actions";

const currencies = ["USD", "EUR", "KRW", "MAD", "CNY"];
const regionCodes = "AF AX AL DZ AS AD AO AI AQ AG AR AM AW AU AT AZ BS BH BD BB BY BE BZ BJ BM BT BO BQ BA BW BV BR IO BN BG BF BI CV KH CM CA KY CF TD CL CN CX CC CO KM CG CD CK CR CI HR CU CW CY CZ DK DJ DM DO EC EG SV GQ ER EE SZ ET FK FO FJ FI FR GF PF TF GA GM GE DE GH GI GR GL GD GP GU GT GG GN GW GY HT HM VA HN HK HU IS IN ID IR IQ IE IM IL IT JM JP JE JO KZ KE KI KP KR KW KG LA LV LB LS LR LY LI LT LU MO MG MW MY MV ML MT MH MQ MR MU YT MX FM MD MC MN ME MS MA MZ MM NA NR NP NL NC NZ NI NE NG NU NF MK MP NO OM PK PW PS PA PG PY PE PH PN PL PT PR QA RE RO RU RW BL SH KN LC MF PM VC WS SM ST SA SN RS SC SL SG SX SK SI SB SO ZA GS SS ES LK SD SR SJ SE CH SY TW TJ TZ TH TL TG TK TO TT TN TR TM TC TV UG UA AE GB US UM UY UZ VU VE VN VG VI WF EH YE ZM ZW".split(" ");

function countryName(code: string) {
  try { return new Intl.DisplayNames([typeof navigator !== "undefined" ? navigator.language : "en"], { type: "region" }).of(code) || code; } catch { return code; }
}

function getDefaultCountry() {
  if (typeof navigator === "undefined") return "KR";
  try {
    const locale = new Intl.Locale(navigator.language);
    if (locale.region && regionCodes.includes(locale.region)) return locale.region;
  } catch {}
  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  return timezone === "Asia/Seoul" ? "KR" : "US";
}

function parseTags(value: string | null | undefined) {
  if (!value) return [];
  return value.split(";").map((item) => item.trim()).filter(Boolean);
}

function TagPicker({ label, options, value, onChange, otherPlaceholder }: { label: string; options: string[]; value: string; onChange: (value: string) => void; otherPlaceholder: string }) {
  const selected = useMemo(() => parseTags(value), [value]);
  const hasOther = selected.some((item) => item.startsWith("Other: "));
  const otherValue = selected.find((item) => item.startsWith("Other: "))?.slice(7) ?? "";

  function toggle(option: string) {
    const next = selected.includes(option) ? selected.filter((item) => item !== option) : [...selected, option];
    onChange(next.join("; "));
  }

  function toggleOther() {
    if (hasOther) onChange(selected.filter((item) => !item.startsWith("Other: ")).join("; "));
    else onChange([...selected, "Other: "].join("; "));
  }

  function updateOther(text: string) {
    const next = selected.filter((item) => !item.startsWith("Other: "));
    onChange(text.trim() ? [...next, `Other: ${text.trim()}`].join("; ") : next.join("; "));
  }

  return <div><p className="mb-2 block text-sm font-bold text-slate-800">{label}</p><div className="flex flex-wrap gap-2">{options.map((option) => { const active = selected.includes(option); return <button key={option} type="button" onClick={() => toggle(option)} className={`rounded-full border px-3.5 py-2 text-xs font-semibold transition ${active ? "border-orange-300 bg-orange-500 text-white" : "border-slate-200 bg-white text-slate-600 hover:border-orange-200 hover:text-orange-600"}`}>{option}</button>; })}<button type="button" onClick={toggleOther} className={`rounded-full border px-3.5 py-2 text-xs font-semibold transition ${hasOther ? "border-orange-300 bg-orange-500 text-white" : "border-slate-200 bg-white text-slate-600 hover:border-orange-200 hover:text-orange-600"}`}>Other</button></div>{hasOther && <input value={otherValue} onChange={(event) => updateOther(event.target.value)} placeholder={otherPlaceholder} className="mt-3 w-full rounded-xl border border-orange-200 bg-orange-50/50 px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100" />}</div>;
}

function DemandQualificationContent() {
  const searchParams = useSearchParams();
  const initialDemandId = searchParams.get("id") ?? "";
  const [saving, setSaving] = useState(false); const [loading, setLoading] = useState(Boolean(initialDemandId)); const [completed, setCompleted] = useState(false); const [error, setError] = useState(""); const [demandId, setDemandId] = useState(initialDemandId); const [data, setData] = useState<QualificationDemandData | null>(null); const [budget, setBudget] = useState(""); const [currency, setCurrency] = useState("USD"); const [deadline, setDeadline] = useState(""); const [geography, setGeography] = useState(""); const [commercialTerms, setCommercialTerms] = useState(""); const [documentation, setDocumentation] = useState("");

  useEffect(() => {
    if (!initialDemandId) { setLoading(false); setError("Demand ID is missing."); return; }
    let cancelled = false; setLoading(true); setError("");
    getQualificationDemand(initialDemandId).then((result) => { if (cancelled) return; if (!result.ok) { setError(result.error); setLoading(false); return; } setData(result.data); setDemandId(result.data.demand.id); setBudget(result.data.qualification.budget === null ? "" : String(result.data.qualification.budget)); setCurrency(result.data.qualification.currency || "USD"); setDeadline(result.data.qualification.deadline || ""); setGeography(result.data.qualification.geography || countryName(getDefaultCountry())); setCommercialTerms(result.data.qualification.commercialTerms || ""); setDocumentation(result.data.qualification.documentation || ""); setLoading(false); });
    return () => { cancelled = true; };
  }, [initialDemandId]);

  function handleSubmit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); setSaving(true); setError(""); qualifyDemand({ demandId, budget, currency, deadline, geography, commercialTerms, documentation }).then((result) => { if (result.ok) setCompleted(true); else setError(result.error); setSaving(false); }); }

  return <main className="min-h-screen bg-slate-50"><div className="mx-auto max-w-6xl px-5 py-6 sm:px-8 lg:py-10"><header className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-soft"><div className="flex items-center gap-3"><Link href="/demands" className="flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 text-slate-500 transition hover:border-orange-200 hover:text-orange-600" aria-label="Back"><ArrowLeft size={18}/></Link><div><p className="text-base font-bold tracking-tight text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Demand qualification</p></div></div><span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-semibold text-orange-700">MVP · Qualification</span></header><div className="mt-8 grid gap-6 lg:grid-cols-[1fr_320px]"><section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-soft sm:p-8"><div className="mb-8 flex items-start gap-4"><div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-orange-50 text-orange-600"><ClipboardCheck size={23}/></div><div><p className="text-sm font-bold text-orange-600">Step 02</p><h1 className="mt-1 text-3xl font-black tracking-tight text-slate-950">Qualify the demand</h1><p className="mt-2 max-w-2xl text-sm leading-6 text-slate-500">Add the commercial and delivery constraints needed before matching.</p></div></div>{loading ? <div className="flex items-center justify-center rounded-2xl border border-slate-200 bg-slate-50 p-10 text-sm text-slate-500"><Loader2 size={18} className="mr-2 animate-spin"/>Loading demand information...</div> : completed ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-5 text-emerald-800"><p className="font-bold">Qualification saved</p><p className="mt-1 text-sm text-emerald-700">The demand is ready for the next MVP step.</p><div className="mt-5 flex flex-col gap-3 sm:flex-row"><Link href={`/demands/match?id=${encodeURIComponent(demandId)}`} className="inline-flex items-center justify-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white">Continue to match <ArrowRight size={17}/></Link><Link href="/demands" className="inline-flex items-center justify-center rounded-xl border border-slate-200 bg-white px-5 py-3 text-sm font-bold text-slate-700">Back to demands</Link></div></div> : <>{error && <div role="alert" className="mb-6 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">{error}</div>}{data && <div className="mb-8 rounded-2xl border border-orange-100 bg-orange-50/50 p-5"><div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"><div><p className="text-xs font-bold uppercase tracking-[0.16em] text-orange-600">Demand selected</p><h2 className="mt-1 text-xl font-black text-slate-950">{data.demand.name}</h2></div><span className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-slate-600">{data.demand.targetMarket || "No target market"}</span></div><div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4"><Info label="Quantity" value={`${data.demand.quantity ?? "—"} ${data.demand.unit || ""}`}/><Info label="Category" value={data.demand.category || "—"}/><Info label="Destination" value={data.demand.geography || "—"}/><Info label="Budget" value={data.demand.budget !== null ? `${data.demand.budget.toLocaleString()} ${data.demand.currency || ""}` : "—"}/></div></div>}
<form onSubmit={handleSubmit} className="space-y-7"><div className="grid gap-5 sm:grid-cols-2"><div><label htmlFor="budget" className="mb-2 block text-sm font-bold text-slate-800">Target budget <span className="font-normal text-slate-400">(optional)</span></label><input id="budget" type="number" min="0" step="any" value={budget} onChange={(event)=>setBudget(event.target.value)} placeholder="e.g. 40000" className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100"/></div><div><label htmlFor="currency" className="mb-2 block text-sm font-bold text-slate-800">Currency</label><select id="currency" value={currency} onChange={(event)=>setCurrency(event.target.value)} className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100">{currencies.map((item)=><option key={item}>{item}</option>)}</select></div></div><div className="grid gap-5 sm:grid-cols-2"><div><label htmlFor="deadline" className="mb-2 block text-sm font-bold text-slate-800">Required delivery date <span className="font-normal text-slate-400">(optional)</span></label><input id="deadline" type="date" value={deadline} onChange={(event)=>setDeadline(event.target.value)} className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100"/></div><div><label htmlFor="geography" className="mb-2 block text-sm font-bold text-slate-800">Destination country</label><select id="geography" required value={geography} onChange={(event)=>setGeography(event.target.value)} className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100"><option value="">Select a country</option>{[...regionCodes].sort((a,b)=>countryName(a).localeCompare(countryName(b))).map((code)=><option key={code} value={countryName(code)}>{countryName(code)}</option>)}</select><p className="mt-2 text-xs text-slate-400">Preselected from the user’s regional settings when no destination is saved.</p></div></div><TagPicker label="Commercial terms" options={["EXW","FOB","CIF","DAP","Bank transfer","Letter of credit","Net 30"]} value={commercialTerms} onChange={setCommercialTerms} otherPlaceholder="Describe another commercial term..."/><TagPicker label="Documentation available" options={["Product specification","Certificate of origin","Certificate of analysis","Photos","Inspection report","Invoice"]} value={documentation} onChange={setDocumentation} otherPlaceholder="Describe another available document..."/><div className="flex flex-col gap-3 border-t border-slate-100 pt-6 sm:flex-row sm:items-center sm:justify-between"><p className="text-xs leading-5 text-slate-400">Choose tags that apply. Use Other for anything not listed.</p><button disabled={saving} type="submit" className="inline-flex items-center justify-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white shadow-lg shadow-orange-500/20 disabled:opacity-60">{saving?<><Loader2 size={17} className="animate-spin"/>Saving...</>:<>Save qualification <ArrowRight size={17}/></>}</button></div></form></>}</section><aside className="h-fit rounded-3xl border border-slate-200 bg-slate-950 p-6 text-white shadow-soft"><p className="text-xs font-bold uppercase tracking-[0.18em] text-orange-400">MVP flow</p>{[["01","Demand"],["02","Qualification"],["03","Match"],["04","Conversation"]].map(([number,label],index)=><div key={number} className={`mt-3 flex items-center gap-3 rounded-xl px-3 py-3 ${index<2?"bg-white/10":"opacity-50"}`}><span className={`flex h-8 w-8 items-center justify-center rounded-lg text-xs font-black ${index===1?"bg-orange-500 text-white":"bg-white/10 text-slate-300"}`}>{number}</span><span className="text-sm font-semibold">{label}</span></div>)}</aside></div></div></main>;
}

function Info({ label, value }: { label: string; value: string }) { return <div className="rounded-xl bg-white p-3"><p className="text-[11px] font-bold uppercase text-slate-400">{label}</p><p className="mt-1 text-sm font-bold text-slate-800">{value}</p></div>; }

export default function DemandQualificationPage() { return <Suspense fallback={<main className="min-h-screen bg-slate-50 p-8"><div className="mx-auto max-w-5xl rounded-2xl border border-slate-200 bg-white p-8 text-sm text-slate-500">Loading qualification…</div></main>}><DemandQualificationContent /></Suspense>; }
