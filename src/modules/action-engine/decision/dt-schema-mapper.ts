import type { DecisionNode, DecisionTreeDefinition } from "./server-decision-engine";

export interface CanonicalDtNodeRecord {
  id: string;
  node_key: string;
  kind: string;
  title: string;
  description: string;
  canonical_category_id?: string | null;
  canonical_subcategory_id?: string | null;
}

export interface CanonicalDtRuleRecord {
  id: string;
  source_node_id: string;
  field: string;
  operator: string;
  value: string;
  target_node_id: string;
  priority: number;
}

export function mapCanonicalDt(
  tree: { id: string; version: number; status: "draft" | "published" | "deprecated"; entryNodeId: string },
  nodes: CanonicalDtNodeRecord[],
  rules: CanonicalDtRuleRecord[],
): DecisionTreeDefinition {
  const rulesBySource = new Map<string, CanonicalDtRuleRecord[]>();
  for (const rule of rules) {
    const list = rulesBySource.get(rule.source_node_id) ?? [];
    list.push(rule);
    rulesBySource.set(rule.source_node_id, list);
  }

  const mapped: DecisionNode[] = nodes.map((node) => {
    const nodeRules = (rulesBySource.get(node.id) ?? []).sort((a, b) => a.priority - b.priority);
    const firstRule = nodeRules[0];
    const kind = node.kind === "question" ? "question" : node.kind === "terminal" || nodeRules.length === 0 ? "terminal" : "rule";

    return {
      id: node.id,
      type: kind,
      question: kind === "question" ? node.node_key : undefined,
      nextNodeId: firstRule?.target_node_id,
      terminalDecision: kind === "terminal"
        ? {
            type: "COMPLETE",
            result: {
              nodeKey: node.node_key,
              canonicalCategoryId: node.canonical_category_id ?? null,
              canonicalSubcategoryId: node.canonical_subcategory_id ?? null,
            },
          }
        : undefined,
    };
  });

  return {
    id: tree.id,
    version: tree.version,
    status: tree.status,
    rootNodeId: tree.entryNodeId,
    nodes: mapped,
  };
}
