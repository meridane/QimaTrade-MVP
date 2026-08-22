"use client";

import { ArrowLeft, Loader2, MessageCircle, Send } from "lucide-react";
import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";

export default function ConversationPage() {
  const [message, setMessage] = useState("");
  const [messages, setMessages] = useState<{ id: number; text: string; mine: boolean }[]>([]);
  const [sending, setSending] = useState(false);
  const [matchId, setMatchId] = useState("");

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    setMatchId(params.get("match") ?? params.get("id") ?? "");
  }, []);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = message.trim();
    if (!text) return;

    setSending(true);
    setMessages((current) => [...current, { id: Date.now(), text, mine: true }]);
    setMessage("");
    setSending(false);
  }

  return (
    <main className="min-h-screen bg-slate-50">
      <div className="mx-auto max-w-5xl px-5 py-6 sm:px-8 lg:py-10">
        <header className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-soft">
          <div className="flex items-center gap-3">
            <Link href={matchId ? `/demands/match?id=${encodeURIComponent(matchId)}` : "/demands/match"} className="flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 text-slate-500 hover:border-orange-200 hover:text-orange-600" aria-label="Back"><ArrowLeft size={18} /></Link>
            <div><p className="text-base font-bold tracking-tight text-slate-950">QimaTrade</p><p className="text-xs text-slate-500">Matched conversation</p></div>
          </div>
          <span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-semibold text-orange-700">MVP · Conversation</span>
        </header>

        <div className="mt-8 grid gap-6 lg:grid-cols-[1fr_300px]">
          <section className="flex min-h-[620px] flex-col overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-soft">
            <div className="border-b border-slate-100 px-6 py-5"><div className="flex items-center gap-3"><div className="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-50 text-orange-600"><MessageCircle size={19} /></div><div><h1 className="font-black text-slate-950">Start the conversation</h1><p className="text-xs text-slate-500">Exchange structured commercial messages after a match.</p></div></div></div>
            <div className="flex-1 space-y-3 bg-slate-50/70 p-6">
              {messages.length === 0 ? <div className="flex h-full min-h-[360px] items-center justify-center text-center"><div><div className="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-white text-orange-500 shadow-sm"><MessageCircle size={22} /></div><p className="mt-4 font-bold text-slate-900">No messages yet</p><p className="mt-1 max-w-sm text-sm leading-6 text-slate-500">Send the first message to clarify price, delivery, documentation or commercial conditions.</p></div></div> : messages.map((item) => <div key={item.id} className={`flex ${item.mine ? "justify-end" : "justify-start"}`}><div className={`max-w-[80%] rounded-2xl px-4 py-3 text-sm leading-6 ${item.mine ? "bg-orange-500 text-white" : "bg-white text-slate-800 shadow-sm"}`}>{item.text}</div></div>)}
            </div>
            <form onSubmit={handleSubmit} className="border-t border-slate-100 bg-white p-4"><div className="flex gap-3"><input value={message} onChange={(event) => setMessage(event.target.value)} placeholder="Write a commercial message..." className="min-w-0 flex-1 rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100" /><button type="submit" disabled={sending || !message.trim()} className="inline-flex items-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white hover:bg-orange-600 disabled:cursor-not-allowed disabled:opacity-50">{sending ? <Loader2 size={17} className="animate-spin" /> : <Send size={17} />} Send</button></div></form>
          </section>

          <aside className="h-fit rounded-3xl border border-slate-200 bg-slate-950 p-6 text-white shadow-soft"><p className="text-xs font-bold uppercase tracking-[0.18em] text-orange-400">MVP flow</p><div className="mt-5 space-y-3">{[["01", "Demand"], ["02", "Qualification"], ["03", "Supplier offer"], ["04", "Match"], ["05", "Conversation"]].map(([number, label], index) => <div key={number} className={`flex items-center gap-3 rounded-xl px-3 py-3 ${index === 4 ? "bg-white/10" : "opacity-50"}`}><span className={`flex h-8 w-8 items-center justify-center rounded-lg text-xs font-black ${index === 4 ? "bg-orange-500 text-white" : "bg-white/10 text-slate-300"}`}>{number}</span><span className="text-sm font-semibold">{label}</span></div>)}</div><div className="mt-7 border-t border-white/10 pt-5"><p className="text-sm font-bold">Conversation purpose</p><p className="mt-2 text-xs leading-5 text-slate-400">Keep the first exchange focused on commercial clarification after an explainable match.</p></div></aside>
        </div>
      </div>
    </main>
  );
}
