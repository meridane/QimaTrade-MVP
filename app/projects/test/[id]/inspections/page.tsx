import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  createInspection,
  createFinding,
  updateInspectionStatus,
  updateFindingStatus,
} from "./actions";

const types = [
  "pre_purchase",
  "pickup",
  "warehouse_receipt",
  "repair",
  "pre_loading",
  "final_delivery",
] as const;

const statuses = [
  "draft",
  "in_progress",
  "completed",
  "approved",
  "rejected",
] as const;

const findingStatuses = [
  "open",
  "in_progress",
  "resolved",
  "accepted",
] as const;

const severities = [
  "low",
  "medium",
  "high",
  "critical",
] as const;

type Props = {
  params: Promise<{ id: string }>;
};

type Actor = {
  id: string;
  actor_id: string;
  name: string;
};

export default async function InspectionsPage({ params }: Props) {
  const { id } = await params;
  const supabase = await createSupabaseServerClient();

  const { data: project } = await supabase
    .from("projects")
    .select("id, name, project_id")
    .eq("id", id)
    .maybeSingle();

  if (!project) {
    return (
      <main className="min-h-screen bg-slate-50 p-8">
        <div className="mx-auto max-w-4xl rounded-3xl bg-white p-8">
          <h1 className="text-2xl font-black text-red-600">
            Project introuvable
          </h1>
        </div>
      </main>
    );
  }

  const { data: participants } = await supabase
    .from("project_participants")
    .select("actor_id, role")
    .eq("project_id", id)
    .order("created_at");

  const participantActorIds = (participants ?? []).map(
    (participant) => participant.actor_id
  );

  let actors: Actor[] = [];

  if (participantActorIds.length) {
    const { data, error } = await supabase
      .from("actors")
      .select("id, actor_id, name")
      .in("id", participantActorIds);

    if (error) {
      throw new Error(error.message);
    }

    actors = (data ?? []) as Actor[];
  }

  const actorMap = new Map(
    actors.map((actor) => [actor.id, actor])
  );

  const actorKeyMap = new Map(
    actors.map((actor) => [actor.actor_id, actor])
  );

  const { data: orders } = await supabase
    .from("project_orders")
    .select("id, order_id, title")
    .eq("project_id", id)
    .order("created_at", { ascending: false });

  const { data: shipments } = await supabase
    .from("project_shipments")
    .select("id, shipment_id")
    .eq("project_id", id)
    .order("created_at", { ascending: false });

  const { data: inspections, error } = await supabase
    .from("project_inspections")
    .select(
      "id, inspection_id, order_id, shipment_id, inspector_actor_id, type, status, summary, recommendation, created_at, completed_at"
    )
    .eq("project_id", id)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  const inspectionIds = (inspections ?? []).map(
    (inspection) => inspection.id
  );

  const { data: findings } = inspectionIds.length
    ? await supabase
        .from("project_inspection_findings")
        .select(
          "id, inspection_id, title, description, severity, status, recommendation, evidence_url, created_at, resolved_at"
        )
        .in("inspection_id", inspectionIds)
        .order("created_at", { ascending: false })
    : { data: [] as any[] };

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-8">
      <div className="mx-auto max-w-7xl">
        <header className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-sm">
          <div>
            <p className="font-black">QimaTrade</p>
            <p className="text-xs text-slate-500">
              Inspection & Quality · functional test
            </p>
          </div>

          <div className="flex gap-4 text-sm font-bold">
            <Link
              href={`/projects/test/${id}`}
              className="text-orange-600"
            >
              ← Project
            </Link>

            <Link
              href={`/projects/test/${id}/orders`}
              className="text-slate-600"
            >
              Orders
            </Link>
          </div>
        </header>

        <section className="mt-5 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <p className="text-xs font-black uppercase tracking-wider text-orange-600">
            INSPECTION & QUALITY
          </p>

          <h1 className="mt-1 text-3xl font-black text-slate-950">
            Inspections — {project.name}
          </h1>

          <p className="mt-1 text-sm text-slate-500">
            Pre-purchase · pickup · warehouse receipt · repair · pre-loading · final delivery
          </p>
        </section>

        <div className="mt-6 grid gap-6 lg:grid-cols-3">
          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-xl font-black">Create inspection</h2>

            <form
              action={createInspection.bind(null, id)}
              className="mt-5 space-y-4"
            >
              <label className="block text-sm font-bold">
                Type
                <select
                  name="type"
                  required
                  className="mt-1 w-full rounded-xl border px-3 py-3"
                >
                  <option value="">Select type</option>
                  {types.map((type) => (
                    <option key={type} value={type}>
                      {type}
                    </option>
                  ))}
                </select>
              </label>

              <label className="block text-sm font-bold">
                Inspector
                <select
                  name="inspector_actor_id"
                  className="mt-1 w-full rounded-xl border px-3 py-3"
                >
                  <option value="">Not assigned</option>
                  {(participants ?? []).map((participant) => {
                    const actor = actorMap.get(participant.actor_id);

                    if (!actor) return null;

                    return (
                      <option
                        key={participant.actor_id}
                        value={actor.actor_id}
                      >
                        {actor.name} — {participant.role}
                      </option>
                    );
                  })}
                </select>
              </label>

              <label className="block text-sm font-bold">
                Order
                <select
                  name="order_id"
                  className="mt-1 w-full rounded-xl border px-3 py-3"
                >
                  <option value="">None</option>
                  {(orders ?? []).map((order) => (
                    <option key={order.id} value={order.id}>
                      {order.order_id} · {order.title}
                    </option>
                  ))}
                </select>
              </label>

              <label className="block text-sm font-bold">
                Shipment
                <select
                  name="shipment_id"
                  className="mt-1 w-full rounded-xl border px-3 py-3"
                >
                  <option value="">None</option>
                  {(shipments ?? []).map((shipment) => (
                    <option key={shipment.id} value={shipment.id}>
                      {shipment.shipment_id}
                    </option>
                  ))}
                </select>
              </label>

              <label className="block text-sm font-bold">
                Summary
                <textarea
                  name="summary"
                  rows={3}
                  className="mt-1 w-full rounded-xl border px-3 py-3"
                />
              </label>

              <label className="block text-sm font-bold">
                Recommendation
                <textarea
                  name="recommendation"
                  rows={3}
                  className="mt-1 w-full rounded-xl border px-3 py-3"
                />
              </label>

              <button
                type="submit"
                className="w-full rounded-xl bg-orange-500 px-4 py-3 font-black text-white hover:bg-orange-600"
              >
                Create inspection
              </button>
            </form>
          </section>

          <section className="space-y-5 lg:col-span-2">
            {(inspections ?? []).map((inspection) => {
              const inspectionFindings = (findings ?? []).filter(
                (finding) => finding.inspection_id === inspection.id
              );

              const inspectorActor = inspection.inspector_actor_id
                ? actorKeyMap.get(inspection.inspector_actor_id)
                : undefined;

              return (
                <article
                  key={inspection.id}
                  className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"
                >
                  <div className="flex flex-wrap justify-between gap-3">
                    <div>
                      <p className="text-lg font-black">
                        {inspection.inspection_id}
                      </p>

                      <p className="text-xs text-slate-500">
                        {inspection.type} · Inspector: {inspectorActor?.name ?? "Not assigned"}
                      </p>
                    </div>

                    <span className="rounded-full bg-orange-50 px-3 py-1 text-xs font-black text-orange-700">
                      {inspection.status}
                    </span>
                  </div>

                  {inspection.summary && (
                    <p className="mt-4 text-sm text-slate-700">
                      {inspection.summary}
                    </p>
                  )}

                  {inspection.recommendation && (
                    <p className="mt-2 rounded-xl bg-slate-50 p-3 text-sm text-slate-600">
                      Recommendation: {inspection.recommendation}
                    </p>
                  )}

                  <div className="mt-4 flex flex-wrap gap-2 border-t pt-4">
                    {statuses.map((status) => (
                      <form
                        key={status}
                        action={updateInspectionStatus.bind(
                          null,
                          id,
                          inspection.id,
                          status
                        )}
                      >
                        <button
                          type="submit"
                          disabled={inspection.status === status}
                          className="rounded-xl border px-3 py-2 text-xs font-bold disabled:opacity-30"
                        >
                          {status}
                        </button>
                      </form>
                    ))}
                  </div>

                  <div className="mt-5 rounded-2xl bg-slate-50 p-4">
                    <h3 className="font-black">
                      Findings ({inspectionFindings.length})
                    </h3>

                    <form
                      action={createFinding.bind(null, id, inspection.id)}
                      className="mt-3 grid gap-3 md:grid-cols-2"
                    >
                      <input
                        name="title"
                        required
                        placeholder="Finding title"
                        className="rounded-xl border px-3 py-3 text-sm"
                      />

                      <select
                        name="severity"
                        className="rounded-xl border px-3 py-3 text-sm"
                      >
                        {severities.map((severity) => (
                          <option key={severity} value={severity}>
                            {severity}
                          </option>
                        ))}
                      </select>

                      <textarea
                        name="description"
                        placeholder="Description"
                        className="rounded-xl border px-3 py-3 text-sm md:col-span-2"
                      />

                      <input
                        name="recommendation"
                        placeholder="Recommendation"
                        className="rounded-xl border px-3 py-3 text-sm"
                      />

                      <input
                        name="evidence_url"
                        placeholder="Evidence URL (optional)"
                        className="rounded-xl border px-3 py-3 text-sm"
                      />

                      <button
                        type="submit"
                        className="rounded-xl bg-slate-950 px-4 py-3 text-sm font-black text-white md:col-span-2"
                      >
                        Add finding
                      </button>
                    </form>

                    <div className="mt-4 space-y-3">
                      {inspectionFindings.map((finding) => (
                        <div
                          key={finding.id}
                          className="rounded-2xl border bg-white p-4"
                        >
                          <div className="flex flex-wrap justify-between gap-2">
                            <p className="font-black">{finding.title}</p>
                            <span className="rounded-full bg-orange-50 px-2 py-1 text-xs font-black">
                              {finding.severity}
                            </span>
                          </div>

                          {finding.description && (
                            <p className="mt-1 text-sm text-slate-600">
                              {finding.description}
                            </p>
                          )}

                          {finding.recommendation && (
                            <p className="mt-1 text-xs text-slate-500">
                              {finding.recommendation}
                            </p>
                          )}

                          <div className="mt-3 flex flex-wrap gap-2">
                            {findingStatuses.map((status) => (
                              <form
                                key={status}
                                action={updateFindingStatus.bind(
                                  null,
                                  id,
                                  finding.id,
                                  status
                                )}
                              >
                                <button
                                  type="submit"
                                  disabled={finding.status === status}
                                  className="rounded-xl border px-2 py-1 text-xs font-bold disabled:opacity-30"
                                >
                                  {status}
                                </button>
                              </form>
                            ))}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </article>
              );
            })}

            {!inspections?.length && (
              <div className="rounded-3xl border border-dashed p-12 text-center">
                <p className="font-black">No inspections yet</p>
                <p className="mt-1 text-sm text-slate-500">
                  Create the first inspection.
                </p>
              </div>
            )}
          </section>
        </div>
      </div>
    </main>
  );
}
