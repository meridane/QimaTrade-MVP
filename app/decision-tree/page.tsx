"use client";

import { ArrowLeft, ArrowRight, CheckCircle2 } from "lucide-react";
import { useMemo, useState } from "react";
import { applyAnswer, createSession, getNode } from "@/lib/decision-tree/engine";
import { V1_DECISION_TREE } from "@/lib/decision-tree/seed";

const tree = V1_DECISION_TREE;

export default function DecisionTreePage() {
  const [session, setSession] = useState(() => createSession(tree));
  const [selectedCategory, setSelectedCategory] = useState("");
  const [selectedSubcategory, setSelectedSubcategory] = useState("");

  const currentNode = getNode(tree, session.currentNodeId);
  const isCategoryStep = currentNode.id === "category";
  const isSubcategoryStep = currentNode.kind === "subcategory";
  const isTerminal = currentNode.kind === "terminal";

  const options = useMemo(() => {
    if (isCategoryStep) return currentNode.rules.map((rule) => ({ value: rule.value, target: rule.targetNodeId }));
    if (isSubcategoryStep) return currentNode.rules.map((rule) => ({ value: rule.value, target: rule.targetNodeId }));
    return [];
  }, [currentNode, isCategoryStep, isSubcategoryStep]);

  function choose(value: string) {
    const field = isCategoryStep ? "category" : "subcategory";
    const next = applyAnswer(tree, session, field, value);
    setSession(next);
    if (isCategoryStep) setSelectedCategory(value);
    else setSelectedSubcategory(value);
  }

  function reset() {
    setSession(createSession(tree));
    setSelectedCategory("");
    setSelectedSubcategory("");
  }

  function back() {
    if (isSubcategoryStep) {
      setSession({ ...session, currentNodeId: "category", revision: Math.max(0, session.revision - 1), answers: {} });
      setSelectedSubcategory("");
      return;
    }
    reset();
  }

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8 sm:px-8 lg:px-10">
      <div className="mx-auto max-w-6xl">
        <header className="mb-10 flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="text-sm font-bold uppercase tracking-[0.16em] text-orange-600">QimaTrade · Decision Tree V1</p>
            <h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950 sm:text-4xl">What are you looking for?</h1>
            <p className="mt-2 text-sm text-slate-500">Choose the category that best matches your product.</p>
          </div>
          <button onClick={reset} className="rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-bold text-slate-700 shadow-sm transition hover:border-orange-200 hover:text-orange-600">Restart</button>
        </header>

        <div className="mb-10 grid grid-cols-3 gap-3">
          {["Trade Domain", "Category", "Subcategory"].map((step, index) => {
            const active = index === 0 || (index === 1 && !isCategoryStep) || (index === 2 && isTerminal);
            return (
              <div key={step} className={`rounded-2xl border px-4 py-3 ${active ? "border-orange-200 bg-orange-50" : "border-slate-200 bg-white"}`}>
                <p className={`text-[11px] font-bold uppercase tracking-wide ${active ? "text-orange-600" : "text-slate-400"}`}>Step {index + 1}</p>
                <p className="mt-1 text-sm font-bold text-slate-800">{step}</p>
              </div>
            );
          })}
        </div>

        {!isTerminal && (
          <section>
            <div className="mb-6 flex items-center justify-between gap-4">
              <div>
                <p className="text-sm font-semibold text-slate-500">{isCategoryStep ? "Select a category" : currentNode.title}</p>
                <p className="mt-1 text-xs text-slate-400">Visual selection · V1 test dataset</p>
              </div>
              {isSubcategoryStep && <button onClick={back} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-bold text-slate-700"><ArrowLeft size={16} /> Back</button>}
            </div>

            <div className="grid gap-6 md:grid-cols-2">
              {options.map((option) => {
                const optionNode = getNode(tree, option.target);
                return (
                  <button key={option.value} onClick={() => choose(option.value)} className="group overflow-hidden rounded-3xl border border-slate-200 bg-white text-left shadow-sm transition hover:-translate-y-1 hover:border-orange-300 hover:shadow-xl">
                    <div className="aspect-[16/9] overflow-hidden bg-slate-100">
                      <img src={optionNode.imageUrl} alt={option.value} className="h-full w-full object-cover transition duration-500 group-hover:scale-105" />
                    </div>
                    <div className="p-6">
                      <div className="flex items-start justify-between gap-4">
                        <div>
                          <h2 className="text-xl font-black tracking-tight text-slate-950">{option.value}</h2>
                          <p className="mt-2 text-sm leading-6 text-slate-500">{optionNode.description}</p>
                        </div>
                        <span className="mt-1 flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-orange-50 text-orange-600 transition group-hover:bg-orange-500 group-hover:text-white"><ArrowRight size={18} /></span>
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>
          </section>
        )}

        {isTerminal && (
          <section className="mx-auto max-w-3xl rounded-3xl border border-emerald-200 bg-white p-8 shadow-sm sm:p-10">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600"><CheckCircle2 size={30} /></div>
            <p className="mt-6 text-sm font-bold uppercase tracking-[0.16em] text-emerald-600">Classification complete</p>
            <h2 className="mt-2 text-3xl font-black tracking-tight text-slate-950">{currentNode.title}</h2>
            <p className="mt-3 text-sm leading-6 text-slate-500">{currentNode.description}</p>
            <div className="mt-8 grid gap-3 sm:grid-cols-2">
              <div className="rounded-2xl bg-slate-50 p-4"><p className="text-xs font-bold uppercase tracking-wide text-slate-400">Category</p><p className="mt-1 font-bold text-slate-900">{selectedCategory}</p></div>
              <div className="rounded-2xl bg-slate-50 p-4"><p className="text-xs font-bold uppercase tracking-wide text-slate-400">Subcategory</p><p className="mt-1 font-bold text-slate-900">{selectedSubcategory}</p></div>
            </div>
            <button onClick={reset} className="mt-8 rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600">Start another classification</button>
          </section>
        )}
      </div>
    </main>
  );
}
