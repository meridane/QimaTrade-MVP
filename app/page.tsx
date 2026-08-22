"use client";

import { FormEvent, useEffect, useState } from "react";
import { ArrowRight, Building2, Loader2, MessageCircle, SearchCheck, Send } from "lucide-react";
import Link from "next/link";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

const TEST_DEMAND_ID = "1e7ee478-fa2b-4ca4-8849-30eff5bfa5ef";
const TEST_OFFER_ID = "89850a29-50ad-4988-a78b-d74691e974aa";
const MAHDI_ACTOR_ID = "b052b287-135b-40c6-b1f8-53bbdc1e0a4e";
const YASSER_ACTOR_ID = "b899a65f-a614-4141-a4d4-622a26c39cb7";

const steps = [
  { icon: SearchCheck, number: "01", title: "Demand", text: "Create and qualify a buyer demand with the essential commercial criteria." },
  { icon: Building2, number: "02", title: "Match", text: "Identify relevant suppliers and explain why each match is recommended." },
  { icon: MessageCircle, number: "03", title: "Conversation", text: "Open a controlled conversation after a relevant match is accepted." },
];

type ChatMessage = {
  id: string;
  body: string;
  sender_actor_id: string;
  demand_id: string;
  offer_id: string;
  created_at: string;
};

export default function HomePage() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [actorId, setActorId] = useState("");
  const [text, setText] = useState("");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");

  async function loadChat() {
    const supabase = createSupabaseBrowserClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      setError("Connecte-toi avec Mahdi ou Yasser pour tester le chat.");
      setLoading(false);
      return;
    }

    const { data: profile } = await supabase.from("profiles").select("actor_id").eq("auth_user_id", user.id).maybeSingle();
    setActorId(profile?.actor_id ?? "");

    const { data, error: messagesError } = await supabase
      .from("messages")
      .select("id, body, sender_actor_id, demand_id, offer_id, created_at")
      .eq("demand_id", TEST_DEMAND_ID)
      .eq("offer_id", TEST_OFFER_ID)
      .order("created_at", { ascending: true });

    if (messagesError) setError(messagesError.message);
    else setMessages((data as ChatMessage[]) ?? []);
    setLoading(false);
  }

  useEffect(() => {
    loadChat();
    const supabase = createSupabaseBrowserClient();
    const channel = supabase.channel("qimatrade-home-chat")
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `demand_id=eq.${TEST_DEMAND_ID}` }, (payload) => {
        const item = payload.new as ChatMessage;
        if (item.offer_id !== TEST_OFFER_ID) return;
        setMessages((current) => current.some((m) => m.id === item.id) ? current : [...current, item]);
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, []);

  async function sendMessage(event: FormEvent) {
    event.preventDefault();
    const body = text.trim();
    if (!body || !actorId) return;
    setSending(true);
    setError("");
    const supabase = createSupabaseBrowserClient();
    const { data, error: insertError } = await supabase.from("messages").insert({
      demand_id: TEST_DEMAND_ID,
      offer_id: TEST_OFFER_ID,
      sender_actor_id: actorId,
      body,
    }).select("id, body, sender_actor_id, demand_id, offer_id, created_at").single();

    if (insertError) setError(insertError.message);
    else if (data) {
      const message = data as ChatMessage;
      setMessages((current) => current.some((m) => m.id === message.id) ? current : [...current, message]);
      setText("");
    }
    setSending(false);
  }

  return (
    <main className="min-h-screen bg-slate-50">
      <section className="mx-auto max-w-7xl px-6 py-8 lg:px-10">
        <header className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-soft">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-500 text-lg font-black text-white">Q</div>
            <div><p className="text-base font-bold tracking-tight text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Marketplace MVP</p></div>
          </div>
          <div className="flex items-center gap-3">
            <a href="#chat-test" className="inline-flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600">
              <MessageCircle size={17} /> Ouvrir le chat
            </a>
            <span className="hidden rounded-full bg-orange-50 px-3 py-1 text-xs font-semibold text-orange-700 sm:inline-flex">Live chat test</span>
          </div>
        </header>

        <div className="mt-8 grid gap-8 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
          <div>
            <div className="mb-5 inline-flex items-center gap-2 rounded-full border border-orange-100 bg-orange-50 px-3 py-1.5 text-sm font-semibold text-orange-700"><span className="h-2 w-2 rounded-full bg-orange-500" />Demand → Match → Conversation</div>
            <h1 className="max-w-3xl text-5xl font-black tracking-tight text-slate-950 sm:text-6xl">The foundation of the QimaTrade marketplace.</h1>
            <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-600">Le test du chat est maintenant directement disponible sur la page d'accueil.</p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/demands" className="inline-flex items-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600">Start MVP flow <ArrowRight size={17} /></Link>
              <a href="#chat-test" className="inline-flex items-center gap-2 rounded-xl border border-orange-200 bg-white px-5 py-3 text-sm font-bold text-orange-600 transition hover:bg-orange-50"><MessageCircle size={17} /> Tester la conversation</a>
            </div>
          </div>

          <section id="chat-test" className="scroll-mt-6 overflow-hidden rounded-3xl border-2 border-orange-200 bg-white shadow-soft">
            <div className="flex items-center justify-between border-b border-slate-100 px-6 py-5">
              <div className="flex items-center gap-3"><div className="flex h-11 w-11 items-center justify-center rounded-xl bg-orange-50 text-orange-600"><MessageCircle size={21} /></div><div><h2 className="font-black text-slate-950">Direct conversation test</h2><p className="text-xs text-slate-500">Mahdi ↔ Yasser · real Supabase messages</p></div></div>
              <span className="rounded-full bg-green-50 px-3 py-1 text-xs font-bold text-green-700">LIVE</span>
            </div>
            <div className="flex min-h-[430px] flex-col bg-slate-50/70 p-5">
              <div className="mb-4 rounded-xl border border-orange-100 bg-orange-50 px-4 py-3 text-xs text-orange-800">Demand <b>{TEST_DEMAND_ID.slice(0, 8)}</b> · Offer <b>{TEST_OFFER_ID.slice(0, 8)}</b></div>
              <div className="flex-1 space-y-3 overflow-y-auto">
                {loading ? <div className="flex h-64 items-center justify-center"><Loader2 className="animate-spin text-orange-500" /></div> : messages.length === 0 ? <div className="flex h-64 items-center justify-center text-center"><div><MessageCircle className="mx-auto text-orange-500" size={28}/><p className="mt-3 font-bold text-slate-900">No messages yet</p><p className="mt-1 text-sm text-slate-500">Envoie le premier message depuis l'un des deux comptes.</p></div></div> : messages.map((item) => { const mine = item.sender_actor_id === actorId; return <div key={item.id} className={`flex ${mine ? "justify-end" : "justify-start"}`}><div className={`max-w-[78%] rounded-2xl px-4 py-3 text-sm leading-6 ${mine ? "bg-orange-500 text-white" : "bg-white text-slate-800 shadow-sm"}`}><div className={`mb-1 text-[10px] font-bold uppercase ${mine ? "text-orange-100" : "text-slate-400"}`}>{item.sender_actor_id === MAHDI_ACTOR_ID ? "Mahdi" : item.sender_actor_id === YASSER_ACTOR_ID ? "Yasser" : "Participant"}</div>{item.body}</div></div>; })}
              </div>
              {error && <div className="mt-3 rounded-xl border border-red-200 bg-red-50 p-3 text-xs text-red-700">{error}</div>}
              <form onSubmit={sendMessage} className="mt-4 flex gap-3"><input value={text} onChange={(e) => setText(e.target.value)} placeholder={actorId ? "Écrire un message..." : "Connecte-toi d'abord..."} disabled={!actorId || sending} className="min-w-0 flex-1 rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100"/><button type="submit" disabled={!actorId || sending || !text.trim()} className="inline-flex items-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white disabled:opacity-50">{sending ? <Loader2 size={17} className="animate-spin"/> : <Send size={17}/>}Send</button></form>
            </div>
          </section>
        </div>

        <div className="mt-10 grid gap-4 md:grid-cols-3">{steps.map((step) => { const Icon = step.icon; return <div key={step.number} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-soft"><div className="flex gap-4"><div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-orange-50 text-orange-600"><Icon size={21}/></div><div><div className="flex justify-between gap-3"><h2 className="font-bold text-slate-950">{step.title}</h2><span className="text-xs font-bold text-slate-400">{step.number}</span></div><p className="mt-1 text-sm leading-6 text-slate-500">{step.text}</p></div></div></div>; })}</div>
        <footer className="mt-10 border-t border-slate-200 pt-5 text-xs text-slate-400">QimaTrade MVP · Direct conversation test</footer>
      </section>
    </main>
  );
}
