"use client";

import { useEffect, useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

type Profile = { name: string | null; profile_id: string | null };

export default function ProjectTestAuthBar() {
  const [user, setUser] = useState<any>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const supabase = createSupabaseBrowserClient();

  async function loadUser() {
    const { data } = await supabase.auth.getUser();
    const currentUser = data.user ?? null;
    setUser(currentUser);

    if (currentUser) {
      const { data: profileData } = await supabase
        .from("profiles")
        .select("name, profile_id")
        .eq("auth_user_id", currentUser.id)
        .maybeSingle();
      setProfile(profileData ?? null);
    } else {
      setProfile(null);
    }
    setLoading(false);
  }

  useEffect(() => {
    void loadUser();
    const { data: listener } = supabase.auth.onAuthStateChange(() => {
      void loadUser();
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

  const name = profile?.name || user?.user_metadata?.full_name || user?.user_metadata?.name || user?.email?.split("@")[0] || "Compte";

  return (
    <div className="rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-[11px] font-bold uppercase tracking-wider text-slate-400">Compte de test</p>
          {loading ? (
            <p className="mt-1 text-sm font-bold text-slate-500">Vérification...</p>
          ) : user ? (
            <>
              <p className="mt-1 text-base font-black text-slate-950">🟢 Connecté : {name}</p>
              <p className="text-xs text-slate-500">{user.email}</p>
              {profile?.profile_id && <p className="text-[10px] text-slate-400">{profile.profile_id}</p>}
            </>
          ) : (
            <p className="mt-1 text-base font-black text-slate-950">🔴 Aucun compte connecté</p>
          )}
        </div>
        {user ? (
          <button onClick={logout} className="rounded-xl bg-red-500 px-5 py-2.5 text-sm font-black text-white">Logout</button>
        ) : (
          <button onClick={login} className="rounded-xl bg-orange-500 px-5 py-2.5 text-sm font-black text-white">Login avec Google</button>
        )}
      </div>
    </div>
  );
}
