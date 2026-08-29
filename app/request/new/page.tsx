"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { FormEvent, useState } from "react";

export default function NewProductRequestPage() {
  const params = useSearchParams();
  const productMasterId = params.get("productMasterId") ?? "";
  const decisionSessionId = params.get("sessionId") ?? "";
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [quantity, setQuantity] = useState("");
  const [unit, setUnit] = useState("pcs");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [createdId, setCreatedId] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError("");
    setCreatedId("");
    try {
      const response = await fetch("/api/product-requests", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title,
          description,
          quantity,
          unit,
          productMasterId,
          decisionSessionId,
        }),
      });
      const data = await response.json();
      if (!response.ok) {
        setError(data.error || "Unable to create the request.");
        return;
      }
      setCreatedId(data.request.id);
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Unable to create the request.");
    } finally {
      setSaving(false);
    }
  }

  if (!productMasterId || !decisionSessionId) {
    return (
      <main className="min-h-screen bg-slate-50 px-5 py-10">
        <div className="mx-auto max-w-xl rounded-3xl border border-red-200 bg-white p-8 shadow-sm">
          <h1 className="text-2xl font-black text-slate-950">Product context missing</h1>
          <p className="mt-2 text-sm text-slate-500">Start from the Decision Tree and select a Product Master first.</p>
          <Link href="/decision-tree" className="mt-6 inline-flex rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white">Back to Decision Tree</Link>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-10 sm:px-8">
      <div className="mx-auto max-w-2xl">
        <Link href="/decision-tree" className="text-sm font-bold text-orange-600">← Back to classification</Link>
        <div className="mt-6 rounded-3xl border border-slate-200 bg-white p-8 shadow-sm sm:p-10">
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-orange-600">QimaTrade · Product Request V1</p>
          <h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950">Create a product request</h1>
          <p className="mt-2 text-sm leading-6 text-slate-500">The request is already linked to the Product Master selected during classification.</p>

          {createdId ? (
            <section className="mt-8 rounded-2xl border border-emerald-200 bg-emerald-50 p-6">
              <p className="text-sm font-bold text-emerald-700">Request created successfully.</p>
              <p className="mt-1 text-sm text-emerald-800">Request ID: {createdId}</p>
              <Link href="/decision-tree" className="mt-5 inline-flex rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white">Start another classification</Link>
            </section>
          ) : (
            <form onSubmit={submit} className="mt-8 space-y-5">
              <label className="block">
                <span className="text-sm font-bold text-slate-800">What do you need?</span>
                <input value={title} onChange={(e) => setTitle(e.target.value)} required maxLength={180} placeholder="e.g. 20 CNC turning centers" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400" />
              </label>
              <label className="block">
                <span className="text-sm font-bold text-slate-800">Description</span>
                <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={5} maxLength={4000} placeholder="Specs, preferred brand, condition, delivery notes..." className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400" />
              </label>
              <div className="grid gap-5 sm:grid-cols-2">
                <label className="block">
                  <span className="text-sm font-bold text-slate-800">Quantity</span>
                  <input type="number" min="0.001" step="0.001" value={quantity} onChange={(e) => setQuantity(e.target.value)} placeholder="Optional" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400" />
                </label>
                <label className="block">
                  <span className="text-sm font-bold text-slate-800">Unit</span>
                  <select value={unit} onChange={(e) => setUnit(e.target.value)} className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none focus:border-orange-400">
                    <option value="pcs">pieces</option>
                    <option value="units">units</option>
                    <option value="kg">kg</option>
                    <option value="tons">tons</option>
                    <option value="lots">lots</option>
                  </select>
                </label>
              </div>
              {error && <div role="alert" className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">{error}</div>}
              <button type="submit" disabled={saving} className="w-full rounded-xl bg-orange-500 px-5 py-3.5 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600 disabled:opacity-60">{saving ? "Creating request…" : "Create product request"}</button>
            </form>
          )}
        </div>
      </div>
    </main>
  );
}
