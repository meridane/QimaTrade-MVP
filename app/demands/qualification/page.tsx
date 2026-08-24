"use client";

import { ArrowLeft, ArrowRight, ClipboardCheck, Loader2 } from "lucide-react";
import Link from "next/link";
import { FormEvent, Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import {
  getQualificationDemand,
  type QualificationDemandData,
  qualifyDemand,
} from "./actions";

const currencies = ["USD", "EUR", "KRW", "MAD", "CNY"];

function DemandQualificationContent() {
  const searchParams = useSearchParams();
  const initialDemandId = searchParams.get("id") ?? "";
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(Boolean(initialDemandId));
  const [completed, setCompleted] = useState(false);
  const [error, setError] = useState("");
  const [demandId, setDemandId] = useState(initialDemandId);
  const [data, setData] = useState<QualificationDemandData | null>(null);
  const [budget, setBudget] = useState("");
  const [currency, setCurrency] = useState("USD");
  const [deadline, setDeadline] = useState("");
  const [geography, setGeography] = useState("");
  const [commercialTerms, setCommercialTerms] = useState("");
  const [documentation, setDocumentation] = useState("");

  useEffect(() => {
    if (!initialDemandId) {
      setLoading(false);
      setError("Demand ID is missing.");
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError("");

    getQualificationDemand(initialDemandId).then((result) => {
      if (cancelled) return;

      if (!result.ok) {
        setError(result.error);
        setLoading(false);
        return;
      }

      setData(result.data);
      setDemandId(result.data.demand.id);
      setBudget(
        result.data.qualification.budget === null
          ? ""
          : String(result.data.qualification.budget),
      );
      setCurrency(result.data.qualification.currency || "USD");
      setDeadline(result.data.qualification.deadline || "");
      setGeography(result.data.qualification.geography || "");
      setCommercialTerms(result.data.qualification.commercialTerms || "");
      setDocumentation(result.data.qualification.documentation || "");
      setLoading(false);
    });

    return () => {
      cancelled = true;
    };
  }, [initialDemandId]);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError("");

    qualifyDemand({
      demandId,
      budget,
      currency,
      deadline,
      geography,
      commercialTerms,
      documentation,
    }).then((result) => {
      if (result.ok) {
        setCompleted(true);
      } else {
        setError(result.error);
      }
      setSaving(false);
    });
  }

  return (
    <main className="min-h-screen bg-slate-50">
      <div className="mx-auto max-w-6xl px-5 py-6 sm:px-8 lg:py-10">
        <header className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-soft">
          <div className="flex items-center gap-3">
            <Link
              href="/demands"
              className="flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 text-slate-500 transition hover:border-orange-200 hover:text-orange-600"
              aria-label="Back to demand"
            >
              <ArrowLeft size={18} />
            </Link>
            <div>
              <p className="text-base font-bold tracking-tight text-slate-950">QimaTrade</p>
              <p className="text-xs text-slate-500">Demand qualification</p>
            </div>
          </div>
          <span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-semibold text-orange-700">
            MVP · Qualification
          </span>
        </header>

        <div className="mt-8 grid gap-6 lg:grid-cols-[1fr_320px]">
          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-soft sm:p-8">
            <div className="mb-8 flex items-start gap-4">
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-orange-50 text-orange-600">
                <ClipboardCheck size={23} />
              </div>
              <div>
                <p className="text-sm font-bold text-orange-600">Step 02</p>
                <h1 className="mt-1 text-3xl font-black tracking-tight text-slate-950">
                  Qualify the demand
                </h1>
                <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-500">
                  Add the commercial and delivery constraints that suppliers need before QimaTrade can explain a useful match.
                </p>
              </div>
            </div>

            {loading ? (
              <div className="flex items-center justify-center rounded-2xl border border-slate-200 bg-slate-50 p-10 text-sm text-slate-500">
                <Loader2 size={18} className="mr-2 animate-spin" />
                Loading demand information...
              </div>
            ) : completed ? (
              <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-5 text-emerald-800">
                <p className="font-bold">Qualification saved</p>
                <p className="mt-1 text-sm text-emerald-700">
                  The demand now contains its qualification data and is ready for the next MVP step.
                </p>
                <div className="mt-5 flex flex-col gap-3 sm:flex-row">
                  <Link
                    href={`/demands/match?id=${encodeURIComponent(demandId)}`}
                    className="inline-flex items-center justify-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white transition hover:bg-orange-600"
                  >
                    Continue to match <ArrowRight size={17} />
                  </Link>
                  <Link
                    href="/demands"
                    className="inline-flex items-center justify-center rounded-xl border border-slate-200 bg-white px-5 py-3 text-sm font-bold text-slate-700"
                  >
                    Back to demands
                  </Link>
                </div>
              </div>
            ) : (
              <>
                {error && (
                  <div role="alert" className="mb-6 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">
                    {error}
                  </div>
                )}

                {data && (
                  <div className="mb-8 rounded-2xl border border-orange-100 bg-orange-50/50 p-5">
                    <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                      <div>
                        <p className="text-xs font-bold uppercase tracking-[0.16em] text-orange-600">
                          Demand selected
                        </p>
                        <h2 className="mt-1 text-xl font-black text-slate-950">{data.demand.name}</h2>
                        <p className="mt-1 text-xs font-mono text-slate-400">{data.demand.id}</p>
                      </div>
                      <span className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-slate-600">
                        {data.demand.targetMarket || "No target market"}
                      </span>
                    </div>

                    <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                      <div className="rounded-xl bg-white p-3">
                        <p className="text-[11px] font-bold uppercase text-slate-400">Quantity</p>
                        <p className="mt-1 text-sm font-bold text-slate-800">
                          {data.demand.quantity ?? "—"} {data.demand.unit || ""}
                        </p>
                      </div>
                      <div className="rounded-xl bg-white p-3">
                        <p className="text-[11px] font-bold uppercase text-slate-400">Category</p>
                        <p className="mt-1 text-sm font-bold text-slate-800">{data.demand.category || "—"}</p>
                      </div>
                      <div className="rounded-xl bg-white p-3">
                        <p className="text-[11px] font-bold uppercase text-slate-400">Destination</p>
                        <p className="mt-1 text-sm font-bold text-slate-800">{data.demand.geography || "—"}</p>
                      </div>
                      <div className="rounded-xl bg-white p-3">
                        <p className="text-[11px] font-bold uppercase text-slate-400">Budget</p>
                        <p className="mt-1 text-sm font-bold text-slate-800">
                          {data.demand.budget !== null ? `${data.demand.budget.toLocaleString()} ${data.demand.currency || ""}` : "—"}
                        </p>
                      </div>
                    </div>

                    {(data.demand.description || data.demand.requirements.length > 0) && (
                      <div className="mt-3 grid gap-3 sm:grid-cols-2">
                        {data.demand.description && (
                          <div className="rounded-xl bg-white p-3">
                            <p className="text-[11px] font-bold uppercase text-slate-400">Description</p>
                            <p className="mt-1 text-sm leading-5 text-slate-700">{data.demand.description}</p>
                          </div>
                        )}
                        {data.demand.requirements.length > 0 && (
                          <div className="rounded-xl bg-white p-3">
                            <p className="text-[11px] font-bold uppercase text-slate-400">Requirements</p>
                            <div className="mt-2 flex flex-wrap gap-2">
                              {data.demand.requirements.map((requirement) => (
                                <span key={requirement} className="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                                  {requirement}
                                </span>
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                )}

                <form onSubmit={handleSubmit} className="space-y-6">
                  <div>
                    <label htmlFor="demandId" className="mb-2 block text-sm font-bold text-slate-800">Demand ID</label>
                    <input
                      id="demandId"
                      name="demandId"
                      value={demandId}
                      onChange={(event) => setDemandId(event.target.value)}
                      required
                      placeholder="Demand ID from Step 01"
                      className="w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm font-mono outline-none transition placeholder:font-sans placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100"
                    />
                    <p className="mt-2 text-xs text-slate-400">It is filled automatically when you arrive from Step 01.</p>
                  </div>

                  <div className="grid gap-5 sm:grid-cols-2">
                    <div>
                      <label htmlFor="budget" className="mb-2 block text-sm font-bold text-slate-800">Target budget <span className="font-normal text-slate-400">(optional)</span></label>
                      <input id="budget" name="budget" type="number" min="0" step="any" value={budget} onChange={(event) => setBudget(event.target.value)} placeholder="e.g. 40000" className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100" />
                    </div>
                    <div>
                      <label htmlFor="currency" className="mb-2 block text-sm font-bold text-slate-800">Currency</label>
                      <select id="currency" name="currency" value={currency} onChange={(event) => setCurrency(event.target.value)} className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition focus:border-orange-400 focus:ring-4 focus:ring-orange-100">
                        {currencies.map((item) => <option key={item}>{item}</option>)}
                      </select>
                    </div>
                  </div>

                  <div className="grid gap-5 sm:grid-cols-2">
                    <div>
                      <label htmlFor="deadline" className="mb-2 block text-sm font-bold text-slate-800">Required delivery date <span className="font-normal text-slate-400">(optional)</span></label>
                      <input id="deadline" name="deadline" type="date" value={deadline} onChange={(event) => setDeadline(event.target.value)} className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition focus:border-orange-400 focus:ring-4 focus:ring-orange-100" />
                    </div>
                    <div>
                      <label htmlFor="geography" className="mb-2 block text-sm font-bold text-slate-800">Delivery geography</label>
                      <input id="geography" name="geography" required value={geography} onChange={(event) => setGeography(event.target.value)} placeholder="e.g. Casablanca, Morocco" className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100" />
                    </div>
                  </div>

                  <div>
                    <label htmlFor="commercialTerms" className="mb-2 block text-sm font-bold text-slate-800">Commercial terms</label>
                    <textarea id="commercialTerms" name="commercialTerms" required rows={4} value={commercialTerms} onChange={(event) => setCommercialTerms(event.target.value)} placeholder="e.g. CIF Casablanca, payment by bank transfer, quotation valid for 15 days." className="w-full resize-none rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm leading-6 outline-none transition placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100" />
                  </div>

                  <div>
                    <label htmlFor="documentation" className="mb-2 block text-sm font-bold text-slate-800">Documentation available <span className="font-normal text-slate-400">(optional)</span></label>
                    <textarea id="documentation" name="documentation" rows={3} value={documentation} onChange={(event) => setDocumentation(event.target.value)} placeholder="e.g. Certificate of origin, product specification, photos." className="w-full resize-none rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm leading-6 outline-none transition placeholder:text-slate-400 focus:border-orange-400 focus:ring-4 focus:ring-orange-100" />
                  </div>

                  <div className="flex flex-col gap-3 border-t border-slate-100 pt-6 sm:flex-row sm:items-center sm:justify-between">
                    <p className="text-xs leading-5 text-slate-400">Existing qualification data is loaded automatically and can be edited.</p>
                    <button disabled={saving} type="submit" className="inline-flex items-center justify-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600 disabled:cursor-not-allowed disabled:opacity-60">
                      {saving ? <><Loader2 size={17} className="animate-spin" /> Saving...</> : <>Save qualification <ArrowRight size={17} /></>}
                    </button>
                  </div>
                </form>
              </>
            )}
          </section>

          <aside className="h-fit rounded-3xl border border-slate-200 bg-slate-950 p-6 text-white shadow-soft">
            <p className="text-xs font-bold uppercase tracking-[0.18em] text-orange-400">MVP flow</p>
            <div className="mt-5 space-y-3">
              {[["01", "Demand", true], ["02", "Qualification", true], ["03", "Match", false], ["04", "Conversation", false]].map(([number, label, active]) => (
                <div key={number as string} className={`flex items-center gap-3 rounded-xl px-3 py-3 ${active ? "bg-white/10" : "opacity-50"}`}>
                  <span className={`flex h-8 w-8 items-center justify-center rounded-lg text-xs font-black ${label === "Qualification" ? "bg-orange-500 text-white" : "bg-white/10 text-slate-300"}`}>{number}</span>
                  <span className="text-sm font-semibold">{label}</span>
                </div>
              ))}
            </div>
            <div className="mt-7 border-t border-white/10 pt-5">
              <p className="text-sm font-bold">What happens here?</p>
              <p className="mt-2 text-xs leading-5 text-slate-400">We capture the constraints that determine whether an offer is genuinely useful, before any matching result is shown.</p>
            </div>
          </aside>
        </div>
      </div>
    </main>
  );
}

export default function DemandQualificationPage() {
  return (
    <Suspense
      fallback={
        <main className="min-h-screen bg-slate-50 p-8">
          <div className="mx-auto max-w-5xl rounded-2xl border border-slate-200 bg-white p-8 text-sm text-slate-500">Loading qualification…</div>
        </main>
      }
    >
      <DemandQualificationContent />
    </Suspense>
  );
}
