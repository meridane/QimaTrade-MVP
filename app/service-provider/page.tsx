"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

export default function ServiceProviderPage() {
  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState<any>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        const response = await fetch("/api/service-provider/me", {
          cache: "no-store",
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || "Unable to load provider profile.");
        if (active) setProfile(data);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Unable to load provider profile.");
      } finally {
        if (active) setLoading(false);
      }
    }

    load();
    return () => { active = false; };
  }, []);

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-10 sm:px-8">
      <div className="mx-auto max-w-6xl">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-orange-600">QimaTrade</p>
            <h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950">Service Provider</h1>
            <p className="mt-2 text-sm text-slate-500">Manage your capabilities and services.</p>
          </div>
          <Link href="/" className="text-sm font-bold text-orange-600">← Dashboard</Link>
        </div>

        {loading && <div className="mt-8 rounded-3xl border border-slate-200 bg-white p-8">Loading provider profile…</div>}

        {error && <div className="mt-8 rounded-3xl border border-red-200 bg-red-50 p-6 text-sm font-medium text-red-700">{error}</div>}

        {!loading && !error && (
          <>
            <section className="mt-8 grid gap-5 md:grid-cols-3">
              <Stat label="Capabilities" value={profile?.capabilitiesCount ?? 0} />
              <Stat label="Services" value={profile?.servicesCount ?? 0} />
              <Stat label="Requests" value={profile?.requestsCount ?? 0} />
            </section>

            <section className="mt-8 grid gap-5 md:grid-cols-2">
              <Card title="My Capabilities" text="Define what your organization can deliver." href="/service-provider/capabilities" />
              <Card title="My Services" text="Publish and manage services offered on QimaTrade." href="/service-provider/services" />
            </section>

            <section className="mt-8 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm">
              <p className="text-xs font-bold uppercase tracking-[0.14em] text-slate-400">Provider identity</p>
              <h2 className="mt-2 text-xl font-black text-slate-950">{profile?.actor?.name || "Service Provider"}</h2>
              <p className="mt-1 text-sm text-slate-500">Actor type: {profile?.actor?.actor_type || "—"}</p>
              <p className="mt-1 text-sm text-slate-500">Status: {profile?.actor?.status || "—"}</p>
            </section>
          </>
        )}
      </div>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return <div className="rounded-3xl border border-slate-200 bg-white p-7 shadow-sm"><p className="text-sm font-bold text-slate-500">{label}</p><p className="mt-2 text-4xl font-black text-slate-950">{value}</p></div>;
}

function Card({ title, text, href }: { title: string; text: string; href: string }) {
  return <Link href={href} className="rounded-3xl border border-slate-200 bg-white p-7 shadow-sm transition hover:-translate-y-0.5 hover:border-orange-200"><h2 className="text-xl font-black text-slate-950">{title}</h2><p className="mt-2 text-sm leading-6 text-slate-500">{text}</p><span className="mt-5 inline-flex text-sm font-bold text-orange-600">Open →</span></Link>;
}
