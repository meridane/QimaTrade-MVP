"use client";

import { useEffect, useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export default function ProjectTestAuthBar() {
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const supabase = createSupabaseBrowserClient();

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      setUser(data.user ?? null);
      setLoading(false);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
      setLoading(false);
    });
    return () => listener.subscription.unsubscribe();
  }, []);

  async function login() {
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}/projects/test` },
    });
  }

  async function logout() {
    await supabase.auth.signOut();
    window.location.reload();
  }

  const name = user?.user_metadata?.full_name || user?.user_metadata?.name || user?.email?.split("@")[0] || "Compte";

  return (
    <div className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-[11px] font-bold uppercase tracking-wider text-slate-400">Compte de test</p>
          {loading ? <p className="mt-1 text-sm font-bold text-slate-500">Vérification...</p> : user ? <><p className="mt-1 text-base font-black text-slate-950">🟢 Connecté : {name}</p><p className="text-xs text-slate-500">{user.email}</p></> : <p className="mt-1 text-base font-black text-slate-950">🔴 Aucun compte connecté</p>}
        </div>
        {user ? <button onClick={logout} className="rounded-xl bg-red-500 px-5 py-2.5 text-sm font-black text-white">Logout</button> : <button onClick={login} className="rounded-xl bg-orange-500 px-5 py-2.5 text-sm font-black text-white">Login avec Google</button>}
      </div>
    </div>
  );
}
