import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { DecisionNode, DecisionTree, Rule } from "@/lib/decision-tree/types";

type NodeRow = {
  id: string;
  node_key: string;
  kind: DecisionNode["kind"];
  title: string;
  description: string | null;
  image_url: string | null;
  canonical_category_id: string | null;
  canonical_subcategory_id: string | null;
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

/**
 * Loads the exact published tree used by an existing decision session.
 * This is intentionally session/version based: answer processing must never
 * silently fall back to the product-classification tree.
 */
export async function loadTreeForSession(sessionId: string) {
  const supabase = await createSupabaseServerClient();

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError) throw userError;
  if (!userData.user) throw new Error("UNAUTHENTICATED");

  const { data: session, error: sessionError } = await supabase
    .from("dt_sessions")
    .select("id, tenant_id, tree_version_id")
    .eq("id", sessionId)
    .eq("user_id", userData.user.id)
    .single();
  if (sessionError) throw sessionError;

  const { data: membership, error: membershipError } = await supabase
    .from("dt_memberships")
    .select("tenant_id")
    .eq("tenant_id", session.tenant_id)
    .eq("user_id", userData.user.id)
    .maybeSingle();
  if (membershipError) throw membershipError;
  if (!membership) throw new Error("TENANT_MEMBERSHIP_REQUIRED");

  const { data: version, error: versionError } = await supabase
    .from("dt_tree_versions")
    .select("id, tree_id, version, status, entry_node_id")
    .eq("id", session.tree_version_id)
    .eq("status", "published")
    .single();
  if (versionError) throw versionError;
  if (!version.entry_node_id) throw new Error("TREE_ENTRY_NODE_MISSING");

  const { data: tree, error: treeError } = await supabase
    .from("dt_trees")
    .select("id, title, tree_key, tenant_id")
    .eq("id", version.tree_id)
    .eq("tenant_id", session.tenant_id)
    .single();
  if (treeError) throw treeError;

  const [{ data: nodes, error: nodesError }, { data: rules, error: rulesError }] = await Promise.all([
    supabase
      .from("dt_nodes")
      .select("id, node_key, kind, title, description, image_url, canonical_category_id, canonical_subcategory_id")
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
      sourceNodeId: row.source_node_id,
      operator: row.operator,
      field: row.field,
      value: row.value,
      targetNodeId: row.target_node_id,
      priority: row.priority,
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
    canonicalCategoryId: row.canonical_category_id,
    canonicalSubcategoryId: row.canonical_subcategory_id,
  }));

  return {
    treeVersionId: version.id,
    tree: {
      id: tree.id,
      version: version.version,
      title: tree.title,
      entryNodeId: version.entry_node_id,
      nodes: decisionNodes,
      status: "published",
    } satisfies DecisionTree,
  };
}
