import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { DecisionNode, DecisionTree, Rule, SessionState } from "@/lib/decision-tree/types";

type TreeRow = {
  id: string;
  title: string;
  tree_key: string;
};

type VersionRow = {
  id: string;
  version: string;
  status: "draft" | "published" | "archived";
  entry_node_id: string | null;
};

type NodeRow = {
  id: string;
  node_key: string;
  kind: DecisionNode["kind"];
  title: string;
  description: string;
  image_url: string;
};

type RuleRow = {
  id: string;
  source_node_id: string;
  field: string;
  operator: Rule["operator"];
  value: string;
  target_node_id: string;
  priority: number;
};

type SessionRow = {
  id: string;
  tree_version_id: string;
  current_node_id: string;
  revision: number;
  status: "active" | "completed" | "abandoned";
};

type ObservationInsert = {
  tenant_id: string;
  session_id: string;
  node_id: string;
  field: string;
  value: string | null;
  client_command_id: string;
};

function isMissing(value: string | undefined | null): value is undefined | null {
  return value == null || value === "";
}

async function getClient() {
  return createSupabaseServerClient();
}

export async function getCurrentUser() {
  const supabase = await getClient();
  const { data, error } = await supabase.auth.getUser();
  if (error) throw error;
  return data.user;
}

export async function getTenantForUser(userId: string) {
  const supabase = await getClient();
  const { data, error } = await supabase
    .from("dt_memberships")
    .select("tenant_id, role")
    .eq("user_id", userId)
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data as { tenant_id: string; role: string } | null;
}

export async function loadPublishedTree(treeKey = "product-classification") {
  const supabase = await getClient();
  const user = await getCurrentUser();
  if (!user) throw new Error("UNAUTHENTICATED");

  const membership = await getTenantForUser(user.id);
  if (!membership) throw new Error("TENANT_MEMBERSHIP_REQUIRED");

  const { data: tree, error: treeError } = await supabase
    .from("dt_trees")
    .select("id, title, tree_key")
    .eq("tenant_id", membership.tenant_id)
    .eq("tree_key", treeKey)
    .single();
  if (treeError) throw treeError;

  const { data: version, error: versionError } = await supabase
    .from("dt_tree_versions")
    .select("id, version, status, entry_node_id")
    .eq("tree_id", tree.id)
    .eq("status", "published")
    .order("published_at", { ascending: false, nullsFirst: false })
    .limit(1)
    .single();
  if (versionError) throw versionError;
  if (!version.entry_node_id) throw new Error("TREE_ENTRY_NODE_MISSING");

  const [{ data: nodes, error: nodesError }, { data: rules, error: rulesError }] = await Promise.all([
    supabase
      .from("dt_nodes")
      .select("id, node_key, kind, title, description, image_url")
      .eq("tree_version_id", version.id),
    supabase
      .from("dt_rules")
      .select("id, source_node_id, field, operator, value, target_node_id, priority")
      .eq("tree_version_id", version.id)
      .order("priority", { ascending: true }),
  ]);

  if (nodesError) throw nodesError;
  if (rulesError) throw rulesError;

  const rulesByNode = new Map<string, Rule[]>();
  for (const row of (rules ?? []) as RuleRow[]) {
    const list = rulesByNode.get(row.source_node_id) ?? [];
    list.push({
      id: row.id,
      operator: row.operator,
      field: row.field,
      value: row.value,
      targetNodeId: row.target_node_id,
    });
    rulesByNode.set(row.source_node_id, list);
  }

  const decisionNodes = ((nodes ?? []) as NodeRow[]).map((row) => ({
    id: row.id,
    kind: row.kind,
    title: row.title,
    description: row.description,
    imageUrl: row.image_url,
    rules: rulesByNode.get(row.id) ?? [],
  }));

  return {
    tenantId: membership.tenant_id,
    tree: {
      id: tree.id,
      version: version.version,
      title: tree.title,
      entryNodeId: version.entry_node_id,
      nodes: decisionNodes,
    } satisfies DecisionTree,
    treeVersionId: version.id,
  };
}

export async function createDecisionSession(treeVersionId: string, entryNodeId: string) {
  const supabase = await getClient();
  const user = await getCurrentUser();
  if (!user) throw new Error("UNAUTHENTICATED");
  const membership = await getTenantForUser(user.id);
  if (!membership) throw new Error("TENANT_MEMBERSHIP_REQUIRED");

  const { data, error } = await supabase
    .from("dt_sessions")
    .insert({
      tenant_id: membership.tenant_id,
      tree_version_id: treeVersionId,
      user_id: user.id,
      current_node_id: entryNodeId,
      revision: 0,
      status: "active",
    })
    .select("id, tree_version_id, current_node_id, revision, status")
    .single();

  if (error) throw error;
  const row = data as SessionRow;
  return {
    sessionId: row.id,
    treeVersion: row.tree_version_id,
    currentNodeId: row.current_node_id,
    revision: row.revision,
    answers: {},
  } satisfies Omit<SessionState, "treeId"> & { treeVersion: string };
}

export async function loadSession(sessionId: string) {
  const supabase = await getClient();
  const user = await getCurrentUser();
  if (!user) throw new Error("UNAUTHENTICATED");

  const { data, error } = await supabase
    .from("dt_sessions")
    .select("id, tree_version_id, current_node_id, revision, status")
    .eq("id", sessionId)
    .eq("user_id", user.id)
    .single();
  if (error) throw error;

  const { data: observations, error: observationsError } = await supabase
    .from("dt_observations")
    .select("field, value")
    .eq("session_id", sessionId)
    .order("created_at", { ascending: true });
  if (observationsError) throw observationsError;

  const answers: Record<string, string> = {};
  for (const row of (observations ?? []) as Array<{ field: string; value: unknown }>) {
    if (typeof row.value === "string") answers[row.field] = row.value;
  }

  const row = data as SessionRow;
  return {
    sessionId: row.id,
    treeVersion: row.tree_version_id,
    currentNodeId: row.current_node_id,
    revision: row.revision,
    status: row.status,
    answers,
  };
}

export async function recordAnswer(params: {
  sessionId: string;
  expectedRevision: number;
  nodeId: string;
  field: "category" | "subcategory";
  value: string;
  targetNodeId: string;
  ruleId: string;
  clientCommandId: string;
}) {
  const supabase = await getClient();
  const user = await getCurrentUser();
  if (!user) throw new Error("UNAUTHENTICATED");

  const { data: session, error: sessionError } = await supabase
    .from("dt_sessions")
    .select("id, tenant_id, current_node_id, revision, status")
    .eq("id", params.sessionId)
    .eq("user_id", user.id)
    .single();
  if (sessionError) throw sessionError;
  if (session.revision !== params.expectedRevision || session.current_node_id !== params.nodeId) {
    throw new Error("CONCURRENCY_CONFLICT");
  }

  const observation: ObservationInsert = {
    tenant_id: session.tenant_id,
    session_id: params.sessionId,
    node_id: params.nodeId,
    field: params.field,
    value: params.value,
    client_command_id: params.clientCommandId,
  };

  const { data: insertedObservation, error: observationError } = await supabase
    .from("dt_observations")
    .insert(observation)
    .select("id")
    .single();

  if (observationError) {
    if (observationError.code === "23505") {
      const { data: existing, error: existingError } = await supabase
        .from("dt_observations")
        .select("id, value")
        .eq("session_id", params.sessionId)
        .eq("client_command_id", params.clientCommandId)
        .single();
      if (existingError) throw existingError;
      return { duplicate: true, observationId: existing.id };
    }
    throw observationError;
  }

  const nextRevision = params.expectedRevision + 1;
  const { data: updated, error: updateError } = await supabase
    .from("dt_sessions")
    .update({ current_node_id: params.targetNodeId, revision: nextRevision })
    .eq("id", params.sessionId)
    .eq("user_id", user.id)
    .eq("revision", params.expectedRevision)
    .select("id, revision, current_node_id")
    .maybeSingle();

  if (updateError) throw updateError;
  if (!updated) throw new Error("CONCURRENCY_CONFLICT");

  const { error: transitionError } = await supabase.from("dt_transitions").insert({
    tenant_id: session.tenant_id,
    session_id: params.sessionId,
    observation_id: insertedObservation.id,
    rule_id: params.ruleId,
    from_node_id: params.nodeId,
    to_node_id: params.targetNodeId,
    from_revision: params.expectedRevision,
    to_revision: nextRevision,
  });

  if (transitionError) throw transitionError;

  return {
    duplicate: false,
    observationId: insertedObservation.id,
    revision: nextRevision,
    currentNodeId: params.targetNodeId,
  };
}

export function assertRequiredEnvironment() {
  if (isMissing(process.env.NEXT_PUBLIC_SUPABASE_URL)) {
    throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL");
  }
  if (isMissing(process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY)) {
    throw new Error("Missing NEXT_PUBLIC_SUPABASE_ANON_KEY");
  }
}
