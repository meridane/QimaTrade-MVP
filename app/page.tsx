import { ArrowRight, Building2, MessageSquare, SearchCheck } from "lucide-react";

const steps = [
  {
    icon: SearchCheck,
    number: "01",
    title: "Demand",
    text: "Create and qualify a buyer demand with the essential commercial criteria.",
  },
  {
    icon: Building2,
    number: "02",
    title: "Match",
    text: "Identify relevant suppliers and explain why each match is recommended.",
  },
  {
    icon: MessageSquare,
    number: "03",
    title: "Conversation",
    text: "Open a controlled conversation after a relevant match is accepted.",
  },
];

export default function HomePage() {
  return (
    <main className="min-h-screen bg-slate-50">
      <section className="mx-auto flex min-h-screen max-w-7xl flex-col px-6 py-8 lg:px-10">
        <header className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-soft">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-500 text-lg font-black text-white">
              Q
            </div>
            <div>
              <p className="text-base font-bold tracking-tight text-slate-950">QimaTrade</p>
              <p className="text-xs text-slate-500">Marketplace MVP</p>
            </div>
          </div>
          <span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-semibold text-orange-700">
            MVP Foundation
          </span>
        </header>

        <div className="flex flex-1 items-center py-16 lg:py-20">
          <div className="grid w-full gap-14 lg:grid-cols-[1.05fr_0.95fr] lg:items-center">
            <div>
              <div className="mb-5 inline-flex items-center gap-2 rounded-full border border-orange-100 bg-orange-50 px-3 py-1.5 text-sm font-semibold text-orange-700">
                <span className="h-2 w-2 rounded-full bg-orange-500" />
                Demand → Match → Conversation
              </div>

              <h1 className="max-w-3xl text-5xl font-black tracking-tight text-slate-950 sm:text-6xl">
                The foundation of the QimaTrade marketplace.
              </h1>

              <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-600">
                A focused MVP built around one measurable flow: understand a demand,
                find qualified suppliers, explain the match, then enable a controlled
                conversation.
              </p>

              <div className="mt-8 flex flex-wrap gap-3">
                <button className="inline-flex items-center gap-2 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600">
                  Start MVP flow
                  <ArrowRight size={17} />
                </button>
                <span className="inline-flex items-center rounded-xl border border-slate-200 bg-white px-5 py-3 text-sm font-semibold text-slate-600">
                  Foundation ready
                </span>
              </div>
            </div>

            <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-soft sm:p-8">
              <div className="mb-6 flex items-center justify-between">
                <div>
                  <p className="text-sm font-bold text-slate-950">Core MVP flow</p>
                  <p className="mt-1 text-xs text-slate-500">First vertical slice</p>
                </div>
                <div className="rounded-lg bg-slate-100 px-2.5 py-1 text-xs font-bold text-slate-500">
                  P0
                </div>
              </div>

              <div className="space-y-4">
                {steps.map((step) => {
                  const Icon = step.icon;
                  return (
                    <div
                      key={step.number}
                      className="group rounded-2xl border border-slate-200 p-4 transition hover:border-orange-200 hover:bg-orange-50/40"
                    >
                      <div className="flex gap-4">
                        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-orange-50 text-orange-600">
                          <Icon size={21} />
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center justify-between gap-3">
                            <h2 className="font-bold text-slate-950">{step.title}</h2>
                            <span className="text-xs font-bold text-slate-400">{step.number}</span>
                          </div>
                          <p className="mt-1 text-sm leading-6 text-slate-500">{step.text}</p>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </div>

        <footer className="border-t border-slate-200 pt-5 text-xs text-slate-400">
          QimaTrade MVP · Foundation v0.1 · Built for the validated MVP scope
        </footer>
      </section>
    </main>
  );
}
