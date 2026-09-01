"use client";

import { ArrowRight, CheckCircle2, Loader2, RotateCcw } from "lucide-react";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import type {
  DecisionNode,
  DecisionTree,
  SessionState,
} from "@/lib/decision-tree/types";

type SessionResponse = {
  tree: DecisionTree;
  session: SessionState & { treeVersion: string };
  error?: string;
};

type AnswerResponse = {
  duplicate: boolean;
  revision: number;
  currentNodeId: string;
  error?: string;
};

export default function ServiceProviderDecisionTreePage() {
  const [tree, setTree] = useState<DecisionTree | null>(null);
  const [session, setSession] = useState<
    (SessionState & { treeVersion: string }) | null
  >(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [selectedProfession, setSelectedProfession] = useState("");
  const [completedNode, setCompletedNode] = useState<DecisionNode | null>(null);

  const startSession = useCallback(async () => {
    setLoading(true);
    setError("");
    setSelectedProfession("");
    setCompletedNode(null);

    try {
      const response = await fetch("/api/decision-tree/service-provider/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        cache: "no-store",
      });
      const data = (await response.json()) as SessionResponse;

      if (!response.ok) {
        setTree(null);
        setSession(null);
        setError(data.error || "Unable to start the Service Provider journey.");
        return;
      }

      setTree(data.tree);
      setSession(data.session);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Unable to start the Service Provider journey.",
      );
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

  const options = useMemo(() => {
    if (!tree || !currentNode) return [];
    return currentNode.rules
      .map((rule) => ({
        value: rule.value,
        node: tree.nodes.find((candidate) => candidate.id === rule.targetNodeId) ?? null,
      }))
      .filter((option) => option.node !== null) as Array<{
      value: string;
      node: DecisionNode;
    }>;
  }, [currentNode, tree]);

  async function chooseProfession(value: string) {
    if (!session || !currentNode || submitting || currentNode.kind !== "category") return;

    setSubmitting(true);
    setError("");

    try {
      const response = await fetch("/api/decision-tree/answer", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          sessionId: session.sessionId,
          nodeId: session.currentNodeId,
          field: "category",
          value,
          expectedRevision: session.revision,
          clientCommandId: crypto.randomUUID(),
        }),
      });

      const data = (await response.json()) as AnswerResponse;

      if (!response.ok) {
        setError(data.error || "Unable to save your professional service.");
        return;
      }

      const nextNode = tree?.nodes.find((node) => node.id === data.currentNodeId) ?? null;
      setSelectedProfession(value);
      setCompletedNode(nextNode);
      setSession((current) =>
        current
          ? {
              ...current,
              currentNodeId: data.currentNodeId,
              revision: data.revision,
              answers: { ...current.answers, category: value },
              status: nextNode?.kind === "terminal" ? "completed" : current.status,
            }
          : current,
      );
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Unable to save your professional service.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  const isProfessionSelection = currentNode?.kind === "category";
  const isCompleted = currentNode?.kind === "terminal";

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8 sm:px-8 lg:px-10">
      <div className="mx-auto max-w-6xl">
        <header className="mb-10 flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="text-sm font-bold uppercase tracking-[0.16em] text-orange-600">
              QimaTrade · Service Provider Decision Tree V1
            </p>
            <h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950 sm:text-4xl">
              Offer professional services
            </h1>
            <p className="mt-2 max-w-2xl text-sm text-slate-500">
              Tell QIMA which professional service you want to offer. The platform will
              then activate the journey required for that activity.
            </p>
          </div>

          <button
            onClick={() => void startSession()}
            disabled={loading || submitting}
            className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-bold text-slate-700 shadow-sm transition hover:border-orange-200 hover:text-orange-600 disabled:opacity-50"
          >
            <RotateCcw size={16} /> Restart
          </button>
        </header>

        <div className="mb-10 grid grid-cols-2 gap-3">
          {["Professional service", "Profession-specific journey"].map((step, index) => {
            const active = index === 0 ? Boolean(selectedProfession) || isCompleted : isCompleted;
            return (
              <div
                key={step}
                className={`rounded-2xl border px-4 py-3 ${
                  active ? "border-orange-200 bg-orange-50" : "border-slate-200 bg-white"
                }`}
              >
                <p
                  className={`text-[11px] font-bold uppercase tracking-wide ${
                    active ? "text-orange-600" : "text-slate-400"
                  }`}
                >
                  Step {index + 1}
                </p>
                <p className="mt-1 text-sm font-bold text-slate-800">{step}</p>
              </div>
            );
          })}
        </div>

        {loading && (
          <div className="flex min-h-[420px] items-center justify-center rounded-3xl border border-slate-200 bg-white shadow-sm">
            <div className="flex items-center gap-3 text-sm font-semibold text-slate-500">
              <Loader2 className="animate-spin" size={20} />
              Loading Service Provider Decision Tree...
            </div>
          </div>
        )}

        {!loading && error && !tree && (
          <section className="mx-auto max-w-xl rounded-3xl border border-red-200 bg-white p-8 text-center shadow-sm">
            <h2 className="text-xl font-black text-slate-950">Service journey unavailable</h2>
            <p className="mt-3 text-sm leading-6 text-slate-500">{error}</p>
            <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-center">
              {error.includes("UNAUTHENTICATED") && (
                <Link
                  href="/login"
                  className="rounded-xl bg-orange-500 px-5 py-3 text-sm font-bold text-white"
                >
                  Sign in with Google
                </Link>
              )}
              <button
                onClick={() => void startSession()}
                className="rounded-xl border border-slate-200 px-5 py-3 text-sm font-bold text-slate-700"
              >
                Try again
              </button>
            </div>
          </section>
        )}

        {!loading && tree && session && currentNode && (
          <section>
            <div className="mb-6">
              <p className="text-sm font-semibold text-slate-500">
                {isProfessionSelection ? currentNode.title : "Profession selected"}
              </p>
              <p className="mt-1 text-xs text-slate-400">
                Persistent V1 session · revision {session.revision}
              </p>
            </div>

            {error && (
              <div
                role="alert"
                className="mb-6 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm font-medium text-amber-800"
              >
                {error}
              </div>
            )}

            {isProfessionSelection && (
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {options.map((option) => (
                  <button
                    key={option.value}
                    type="button"
                    onClick={() => void chooseProfession(option.value)}
                    disabled={submitting}
                    className="group rounded-3xl border border-slate-200 bg-white p-6 text-left shadow-sm transition hover:-translate-y-1 hover:border-orange-300 hover:shadow-xl disabled:pointer-events-none disabled:opacity-70"
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <p className="text-xs font-bold uppercase tracking-[0.14em] text-orange-500">
                          Professional service
                        </p>
                        <h2 className="mt-2 text-xl font-black tracking-tight text-slate-950">
                          {option.value}
                        </h2>
                        <p className="mt-3 text-sm leading-6 text-slate-500">
                          Start the professional journey for this activity.
                        </p>
                      </div>
                      <span className="mt-1 flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-orange-50 text-orange-600 transition group-hover:bg-orange-500 group-hover:text-white">
                        <ArrowRight size={18} />
                      </span>
                    </div>
                  </button>
                ))}
              </div>
            )}

            {isCompleted && (
              <section className="rounded-3xl border border-emerald-200 bg-white p-8 shadow-sm sm:p-10">
                <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600">
                  <CheckCircle2 size={30} />
                </div>
                <p className="mt-6 text-sm font-bold uppercase tracking-[0.16em] text-emerald-600">
                  Professional service selected
                </p>
                <h2 className="mt-2 text-3xl font-black tracking-tight text-slate-950">
                  {completedNode?.title || selectedProfession}
                </h2>
                <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-500">
                  {completedNode?.description}
                </p>
                <div className="mt-8 rounded-2xl bg-slate-50 p-5">
                  <p className="text-xs font-bold uppercase tracking-wide text-slate-400">
                    Saved Decision Tree answer
                  </p>
                  <p className="mt-2 font-bold text-slate-900">{selectedProfession}</p>
                </div>
                <p className="mt-6 text-sm text-slate-500">
                  The next implementation step is to attach the profession-specific modules
                  defined by QIMA: required information, verification, skills, service area,
                  availability and trust level.
                </p>
              </section>
            )}
          </section>
        )}
      </div>
    </main>
  );
}
