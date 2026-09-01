import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { DecisionNode, DecisionTree, ProductMaster, Rule, SessionState } from "@/lib/decision-tree/types";

type NodeRow = { id: string; node_key: string; kind: DecisionNode["kind"]; title: string; description: string; image_url: string; canonical_category_id: string | null; canonical_subcategory_id: string | null };
type RuleRow = { id: string; source_node_id: string; field: string; operator: Rule["operator"]; value: string; target_node_id: string; priority: number };
type ProductMasterRow = { id: string; code: string; name: string; canonical_name: string; description: string | null; product_role: string | null; classification_status: string | null; confidence: number | null };
type SessionRow = { id: string; tree_version_id: string; current_node_id: string; revision: number; status: "active" | "completed" | "abandoned"; selected_product_master_id: string | null };
type DecisionContext = { userId: string; tenantId: string };

async function getClient() { return createSupabaseServerClient(); }

export async function getCurrentUser() {
  const supabase = await getClient();
  const { data, error } = await supabase.auth.getUser();
  if (error) throw error;
  return data.user;
}

export async function getTenantForUser(userId: string) {
  const supabase = await getClient();
  const { data, error } = await supabase.from("dt_memberships").select("tenant_id, role").eq("user_id", userId).limit(1).maybeSingle();
  if (error) throw error;
  return data as { tenant_id: string; role: string } | null;
}

export async function loadPublishedTree(treeKey = "product-classification", context?: DecisionContext) {
  const supabase = await getClient();
  const userId = context?.userId ?? (await getCurrentUser())?.id;
  if (!userId) throw new Error("UNAUTHENTICATED");
  const tenantId = context?.tenantId ?? (await getTenantForUser(userId))?.tenant_id;
  if (!tenantId) throw new Error("TENANT_MEMBERSHIP_REQUIRED");

  const { data: tree, error: treeError } = await supabase.from("dt_trees").select("id, title, tree_key").eq("tenant_id", tenantId).eq("tree_key", treeKey).single();
  if (treeError) throw treeError;

  const { data: version, error: versionError } = await supabase.from("dt_tree_versions").select("id, version, status, entry_node_id").eq("tree_id", tree.id).eq("status", "published").order("published_at", { ascending: false, nullsFirst: false }).limit(1).single();
  if (versionError) throw versionError;
  if (!version.entry_node_id) throw new Error("TREE_ENTRY_NODE_MISSING");

  const [{ data: nodes, error: nodesError }, { data: rules, error: rulesError }] = await Promise.all([
    supabase.from("dt_nodes").select("id, node_key, kind, title, description, image_url, canonical_category_id, canonical_subcategory_id").eq("tree_version_id", version.id),
    supabase.from("dt_rules").select("id, source_node_id, field, operator, value, target_node_id, priority").eq("tree_version_id", version.id).order("priority", { ascending: true }),
  ]);
  if (nodesError) throw nodesError;
  if (rulesError) throw rulesError;

  const rulesByNode = new Map<string, Rule[]>();
  for (const row of (rules ?? []) as RuleRow[]) {
    const list = rulesByNode.get(row.source_node_id) ?? [];
    list.push({ id: row.id, sourceNodeId: row.source_node_id, operator: row.operator, field: row.field, value: row.value, targetNodeId: row.target_node_id, priority: row.priority });
    rulesByNode.set(row.source_node_id, list);
  }

  const decisionNodes = ((nodes ?? []) as NodeRow[]).map((row) => ({
    id: row.id, kind: row.kind, title: row.title, description: row.description, imageUrl: row.image_url,
    rules: rulesByNode.get(row.id) ?? [], canonicalCategoryId: row.canonical_category_id, canonicalSubcategoryId: row.canonical_subcategory_id,
  }));

  return { tenantId, userId, tree: { id: tree.id, version: version.version, title: tree.title, entryNodeId: version.entry_node_id, nodes: decisionNodes } satisfies DecisionTree, treeVersionId: version.id };
}

export async function getProductMastersForNode(nodeId: string): Promise<ProductMaster[]> {
  const supabase = await getClient();
  const user = await getCurrentUser();
  if (!user) throw new Error("UNAUTHENTICATED");
  const membership = await getTenantForUser(user.id);
  if (!membership) throw new Error("TENANT_MEMBERSHIP_REQUIRED");

  const { data: node, error: nodeError } = await supabase.from("dt_nodes").select("canonical_subcategory_id").eq("id", nodeId).maybeSingle();
  if (nodeError) throw nodeError;
  if (!node?.canonical_subcategory_id) return [];

  const { data, error } = await supabase.from("product_masters").select("id, code, name, canonical_name, description, product_role, classification_status, confidence").eq("subcategory_id", node.canonical_subcategory_id).eq("status", "active").order("code", { ascending: true }).limit(24);
  if (error) throw error;
  return ((data ?? []) as ProductMasterRow[]).map((row) => ({ id: row.id, code: row.code, name: row.name, canonicalName: row.canonical_name, description: row.description, productRole: row.product_role, classificationStatus: row.classification_status, confidence: row.confidence }));
}

export async function createDecisionSession(treeVersionId: string, entryNodeId: string, context?: DecisionContext) {
  const supabase = await getClient();
  const userId = context?.userId ?? (await getCurrentUser())?.id;
  if (!userId) throw new Error("UNAUTHENTICATED");
  const tenantId = context?.tenantId ?? (await getTenantForUser(userId))?.tenant_id;
  if (!tenantId) throw new Error("TENANT_MEMBERSHIP_REQUIRED");

  const { data, error } = await supabase.from("dt_sessions").insert({ tenant_id: tenantId, tree_version_id: treeVersionId, user_id: userId, current_node_id: entryNodeId, revision: 0, status: "active", selected_product_master_id: null }).select("id, tree_version_id, current_node_id, revision, status, selected_product_master_id").single();
  if (error) throw error;
  const row = data as SessionRow;
  return { sessionId: row.id, treeId: treeVersionId, treeVersion: row.tree_version_id, currentNodeId: row.current_node_id, revision: row.revision, answers: {}, selectedProductMasterId: row.selected_product_master_id, status: row.status } satisfies SessionState;
}

export async function loadSession(sessionId: string) {
  const supabase = await getClient();
  const user = await getCurrentUser();
  if (!user) throw new Error("UNAUTHENTICATED");
  const { data, error } = await supabase.from("dt_sessions").select("id, tree_version_id, current_node_id, revision, status, selected_product_master_id").eq("id", sessionId).eq("user_id", user.id).single();
  if (error) throw error;
  const { data: observations, error: observationsError } = await supabase.from("dt_observations").select("field, value").eq("session_id", sessionId).order("created_at", { ascending: true });
  if (observationsError) throw observationsError;
  const answers: Record<string, string> = {};
  for (const row of (observations ?? []) as Array<{ field: string; value: unknown }>) if (typeof row.value === "string") answers[row.field] = row.value;
  const row = data as SessionRow;
  return { sessionId: row.id, treeVersion: row.tree_version_id, currentNodeId: row.current_node_id, revision: row.revision, answers, selectedProductMasterId: row.selected_product_master_id, status: row.status };
}

export async function submitAnswer(params: { sessionId: string; expectedRevision: number; nodeId: string; field: "category" | "subcategory"; value: string; targetNodeId: string; ruleId: string; clientCommandId: string }) {
  const supabase = await getClient();
  const user = await getCurrentUser();
  if (!user) throw new Error("UNAUTHENTICATED");
  const { data, error } = await supabase.rpc("dt_submit_answer", { p_session_id: params.sessionId, p_user_id: user.id, p_expected_revision: params.expectedRevision, p_node_id: params.nodeId, p_field: params.field, p_value: params.value, p_client_command_id: params.clientCommandId, p_rule_id: params.ruleId, p_target_node_id: params.targetNodeId });
  if (error) { if (error.message.includes("CONCURRENCY_CONFLICT")) throw new Error("CONCURRENCY_CONFLICT"); if (error.message.includes("SESSION_NOT_FOUND")) throw new Error("SESSION_NOT_FOUND"); throw error; }
  return data as { duplicate: boolean; observationId: string; revision: number; currentNodeId: string };
}

export async function selectProductMaster(sessionId: string, productMasterId: string) {
  const supabase = await getClient();
  const user = await getCurrentUser();
  if (!user) throw new Error("UNAUTHENTICATED");
  const { data, error } = await supabase.rpc("dt_select_product_master", { p_session_id: sessionId, p_user_id: user.id, p_product_master_id: productMasterId });
  if (error) { if (error.message.includes("SESSION_NOT_FOUND")) throw new Error("SESSION_NOT_FOUND"); if (error.message.includes("PRODUCT_MASTER_NOT_FOUND")) throw new Error("PRODUCT_MASTER_NOT_FOUND"); if (error.message.includes("PRODUCT_MASTER_NOT_IN_CLASSIFICATION")) throw new Error("PRODUCT_MASTER_NOT_IN_CLASSIFICATION"); throw error; }
  return data as { sessionId: string; productMasterId: string; productMasterCode: string; status: "completed" };
}
