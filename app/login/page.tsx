"use client";

import { ArrowRight, Loader2, ShieldCheck } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export default function LoginPage() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function signInWithGoogle() {
    setLoading(true);
    setError(null);

    const supabase = createSupabaseBrowserClient();
    const redirectTo = `${window.location.origin}/auth/callback?next=/demands`;
    const { error: signInError } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo },
    });

    if (signInError) {
      setError(signInError.message);
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8">
      <div className="mx-auto flex min-h-[calc(100vh-4rem)] max-w-md items-center justify-center">
        <section className="w-full rounded-3xl border border-slate-200 bg-white p-7 shadow-soft sm:p-9">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-orange-500 text-xl font-black text-white">Q</div>
          <p className="mt-6 text-sm font-bold text-orange-600">QimaTrade MVP</p>
          <h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950">Sign in to continue</h1>
          <p className="mt-3 text-sm leading-6 text-slate-500">Authentication is required before creating a demand. Your account will be linked to its QimaTrade actor.</p>

          <button onClick={signInWithGoogle} disabled={loading} className="mt-8 flex w-full items-center justify-center gap-3 rounded-xl bg-slate-950 px-5 py-3.5 text-sm font-bold text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60">
            {loading ? <Loader2 className="animate-spin" size={18} /> : <span className="flex h-5 w-5 items-center justify-center rounded bg-white text-xs font-black text-slate-950">G</span>}
            {loading ? "Connecting..." : "Continue with Google"}
            {!loading && <ArrowRight size={17} />}
          </button>

          {error && <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-3 text-sm text-red-700">{error}</div>}

          <div className="mt-6 flex items-center gap-2 text-xs text-slate-400"><ShieldCheck size={15} /> Supabase Auth · Google OAuth</div>
          <Link href="/" className="mt-6 block text-center text-sm font-semibold text-slate-500 hover:text-orange-600">Back to home</Link>
        </section>
      </div>
    </main>
  );
}
