"use client";

import { ArrowLeft, ArrowRight, CheckCircle2, Loader2, RotateCcw } from "lucide-react";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { DecisionNode, DecisionTree, ProductMaster, SessionState } from "@/lib/decision-tree/types";

type SessionResponse = {
  tree: DecisionTree;
  session: SessionState & { treeVersion: string };
};

type AnswerResponse = {
  duplicate: boolean;
  observationId?: string;
  revision: number;
  currentNodeId: string;
  nextNode: DecisionNode | null;
  error?: string;
};

type ProductResponse = {
  productMasters: ProductMaster[];
  error?: string;
};

export default function DecisionTreePage() {
  const [tree, setTree] = useState<DecisionTree | null>(null);
  const [session, setSession] = useState<(SessionState & { treeVersion: string }) | null>(null);
  const [selectedCategory, setSelectedCategory] = useState("");
  const [selectedSubcategory, setSelectedSubcategory] = useState("");
  const [products, setProducts] = useState<ProductMaster[]>([]);
  const [productsLoading, setProductsLoading] = useState(false);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const startSession = useCallback(async () => {
    setLoading(true);
    setError("");
    setProducts([]);

    try {
      const response = await fetch("/api/decision-tree/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        cache: "no-store",
      });

      const data = (await response.json()) as SessionResponse & { error?: string };
      if (!response.ok) {
        setError(data.error || "Unable to start the decision tree.");
        setTree(null);
        setSession(null);
        return;
      }

      setTree(data.tree);
      setSession(data.session);
      setSelectedCategory("");
      setSelectedSubcategory("");
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Unable to start the decision tree.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void startSession();
  }, [startSession]);

  const currentNode = useMemo(() => {
    if (!tree || !session) return null;
    return tree.nodes.find((node) => node.id === session.currentNodeId) ?? null;
  }, [tree, session]);

  const isCategoryStep = currentNode?.kind === "category";
  const isSubcategoryStep = currentNode?.kind === "subcategory";
  const isTerminal = currentNode?.kind === "terminal";

  const options = useMemo(() => {
    if (!currentNode) return [];
    return currentNode.rules.map((rule) => ({
      value: rule.value,
      target: rule.targetNodeId,
      node: tree?.nodes.find((candidate) => candidate.id === rule.targetNodeId) ?? null,
    }));
  }, [currentNode, tree]);

  const loadProducts = useCallback(async (nodeId: string) => {
    setProductsLoading(true);
    try {
      const response = await fetch(`/api/decision-tree/products?nodeId=${encodeURIComponent(nodeId)}`, {
        cache: "no-store",
      });
      const data = (await response.json()) as ProductResponse;
      if (!response.ok) {
        setError(data.error || "Unable to load product masters.");
        setProducts([]);
        return;
      }
      setProducts(data.productMasters ?? []);
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Unable to load product masters.");
      setProducts([]);
    } finally {
      setProductsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (currentNode?.kind === "terminal") {
      void loadProducts(currentNode.id);
    } else {
      setProducts([]);
    }
  }, [currentNode, loadProducts]);

  async function choose(value: string, field: "category" | "subcategory") {
    if (!tree || !session || !currentNode || submitting) return;

    setSubmitting(true);
    setError("");

    try {
      const response = await fetch("/api/decision-tree/answer", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          sessionId: session.sessionId,
          nodeId: session.currentNodeId,
          field,
          value,
          expectedRevision: session.revision,
          clientCommandId: crypto.randomUUID(),
        }),
      });

      const data = (await response.json()) as AnswerResponse;
      if (!response.ok) {
        if (response.status === 409) {
          await startSession();
          setError("Your session changed. A fresh session has been started.");
        } else {
          setError(data.error || "Unable to submit this answer.");
        }
        return;
      }

      setSession((current) => current ? {
        ...current,
        currentNodeId: data.currentNodeId,
        revision: data.revision,
        answers: { ...current.answers, [field]: value },
      } : current);

      if (field === "category") setSelectedCategory(value);
      else setSelectedSubcategory(value);
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Unable to submit this answer.");
    } finally {
      setSubmitting(false);
    }
  }

  function back() {
    if (!tree || !session || submitting) return;

    if (isSubcategoryStep) {
      setSession((current) => current ? {
        ...current,
        currentNodeId: tree.entryNodeId,
        revision: 0,
        answers: {},
      } : current);
      setSelectedCategory("");
      setSelectedSubcategory("");
      return;
    }

    if (isTerminal) {
      const categoryValue = session.answers.category;
      const categoryRule = tree.nodes
        .find((node) => node.id === tree.entryNodeId)
        ?.rules.find((rule) => rule.value === categoryValue);

      if (categoryRule) {
        setSession((current) => current ? {
          ...current,
          currentNodeId: categoryRule.targetNodeId,
          revision: Math.max(1, current.revision - 1),
          answers: { category: categoryValue },
        } : current);
        setSelectedSubcategory("");
        setProducts([]);
      }
    }
  }

  const activeStep = currentNode?.kind === "category" ? 1 : currentNode?.kind === "subcategory" ? 2 : 3;

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8 sm:px-8 lg:px-10">
      <div className="mx-auto max-w-6xl">
        <header className="mb-10 flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="text-sm font-bold uppercase tracking-[0.16em] text-orange-600">QimaTrade · Decision Tree V1</p>
            <h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950 sm:text-4xl">What are you looking for?</h1>
            <p className="mt-2 text-sm text-slate-500">Choose the category that best matches your product.</p>
          </div>
          <button onClick={() => void startSession()} disabled={loading || submitting} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-bold text-slate-700 shadow-sm transition hover:border-orange-200 hover:text-orange-600 disabled:opacity-50">
            <RotateCcw size={16} /> Restart
          </button>
        </header>

        <div className="mb-10 grid grid-cols-3 gap-3">
          {["Trade Domain", "Category", "Subcategory"].map((step, index) => {
            const active = index < activeStep;
            return (
              <div key={step} className={`rounded-2xl border px-4 py-3 ${active ? "border-orange-200 bg-orange-50" : "border-slate-200 bg-white"}`}>
                <p className={`text-[11px] font-bold uppercase tracking-wide ${active ? "text-orange-600" : "text-slate-400"}`}>Step {index + 1}</p>
                <p className="mt-1 text-sm font-bold text-slate-800">{step}</p>
              </div>
            );
          })}
        </div>

        {loading && (
          <div className="flex min-h-[360px] items-center justify-center rounded-3xl border border-slate-200 bg-white shadow-sm">
            <div className="flex items-center gap-3 text-sm font-semibold text-slate-500"><Loader2 className="animate-spin" size={20} /> Loading Decision Tree...</div>
          </div>
        )}

        {!loading && error && !tree && (
          <section className="mx-auto max-w-xl rounded-3xl border border-red-200 bg-white p-8 text-center shadow-sm">
            <h2 className="text-xl font-black text-slate-950">Classification unavailable</h2>
            <p className="mt-3 text-sm leading-6 text-slate-500">{error}</p>
            <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-center">
              {error.includes("UNAUTHENTICATED") && <Link href="/login" className="rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white">Sign in with Google</Link>}
              <button onClick={() => void startSession()} className="rounded-xl border border-slate-200 px-5 py-3 text-sm font-bold text-slate-700">Try again</button>
            </div>
          </section>
        )}

        {!loading && tree && session && currentNode && (
          <section>
            <div className="mb-6 flex items-center justify-between gap-4">
              <div>
                <p className="text-sm font-semibold text-slate-500">{isCategoryStep ? "Select a category" : currentNode.title}</p>
                <p className="mt-1 text-xs text-slate-400">Persistent V1 session · revision {session.revision}</p>
              </div>
              {(isSubcategoryStep || isTerminal) && <button onClick={back} disabled={submitting} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-bold text-slate-700 disabled:opacity-50"><ArrowLeft size={16} /> Back</button>}
            </div>

            {error && <div role="alert" className="mb-6 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm font-medium text-amber-800">{error}</div>}

            {!isTerminal && (
              <div className="grid gap-6 md:grid-cols-2">
                {options.map((option) => {
                  if (!option.node) return null;
                  const field = isCategoryStep ? "category" : "subcategory";
                  return (
                    <button key={option.value} onClick={() => void choose(option.value, field)} disabled={submitting} className="group overflow-hidden rounded-3xl border border-slate-200 bg-white text-left shadow-sm transition hover:-translate-y-1 hover:border-orange-300 hover:shadow-xl disabled:pointer-events-none disabled:opacity-70">
                      <div className="aspect-[16/9] overflow-hidden bg-slate-100">
                        {option.node.imageUrl ? <img src={option.node.imageUrl} alt={option.value} className="h-full w-full object-cover transition duration-500 group-hover:scale-105" /> : <div className="h-full w-full bg-slate-200" />}
                      </div>
                      <div className="p-6">
                        <div className="flex items-start justify-between gap-4">
                          <div>
                            <h2 className="text-xl font-black tracking-tight text-slate-950">{option.value}</h2>
                            <p className="mt-2 text-sm leading-6 text-slate-500">{option.node.description}</p>
                          </div>
                          <span className="mt-1 flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-orange-50 text-orange-600 transition group-hover:bg-orange-500 group-hover:text-white"><ArrowRight size={18} /></span>
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            )}

            {isTerminal && (
              <div className="space-y-6">
                <section className="rounded-3xl border border-emerald-200 bg-white p-8 shadow-sm sm:p-10">
                  <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600"><CheckCircle2 size={30} /></div>
                  <p className="mt-6 text-sm font-bold uppercase tracking-[0.16em] text-emerald-600">Classification complete</p>
                  <h2 className="mt-2 text-3xl font-black tracking-tight text-slate-950">{currentNode.title}</h2>
                  <p className="mt-3 text-sm leading-6 text-slate-500">{currentNode.description}</p>
                  <div className="mt-8 grid gap-3 sm:grid-cols-2">
                    <div className="rounded-2xl bg-slate-50 p-4"><p className="text-xs font-bold uppercase tracking-wide text-slate-400">Category</p><p className="mt-1 font-bold text-slate-900">{selectedCategory || session.answers.category}</p></div>
                    <div className="rounded-2xl bg-slate-50 p-4"><p className="text-xs font-bold uppercase tracking-wide text-slate-400">Subcategory</p><p className="mt-1 font-bold text-slate-900">{selectedSubcategory || session.answers.subcategory}</p></div>
                  </div>
                </section>

                <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
                  <div className="flex flex-wrap items-end justify-between gap-3">
                    <div>
                      <p className="text-xs font-bold uppercase tracking-[0.16em] text-slate-400">Canonical Product Master</p>
                      <h3 className="mt-1 text-2xl font-black tracking-tight text-slate-950">Matching products</h3>
                    </div>
                    <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold text-slate-600">{products.length} available</span>
                  </div>

                  {productsLoading ? (
                    <div className="mt-6 flex items-center gap-3 rounded-2xl bg-slate-50 p-5 text-sm font-semibold text-slate-500"><Loader2 className="animate-spin" size={18} /> Resolving canonical products…</div>
                  ) : products.length === 0 ? (
                    <div className="mt-6 rounded-2xl bg-slate-50 p-5 text-sm text-slate-500">No active Product Masters are mapped to this classification yet.</div>
                  ) : (
                    <div className="mt-6 grid gap-3 md:grid-cols-2">
                      {products.map((product) => (
                        <article key={product.id} className="rounded-2xl border border-slate-200 p-4 transition hover:border-orange-200 hover:shadow-sm">
                          <div className="flex items-start justify-between gap-3">
                            <div>
                              <p className="text-xs font-bold uppercase tracking-wide text-orange-600">{product.code}</p>
                              <h4 className="mt-1 font-black text-slate-950">{product.canonicalName || product.name}</h4>
                            </div>
                            <span className="rounded-lg bg-slate-100 px-2 py-1 text-[10px] font-bold uppercase tracking-wide text-slate-500">{product.productRole || "Product"}</span>
                          </div>
                          {product.description && <p className="mt-2 text-sm leading-5 text-slate-500">{product.description}</p>}
                        </article>
                      ))}
                    </div>
                  )}
                </section>

                <button onClick={() => void startSession()} disabled={submitting} className="rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white shadow-lg shadow-orange-500/20 transition hover:bg-orange-600 disabled:opacity-50">Start another classification</button>
              </div>
            )}
          </section>
        )}
      </div>
    </main>
  );
}
