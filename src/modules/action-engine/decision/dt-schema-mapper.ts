import type { DecisionNode, DecisionRule, DecisionTreeDefinition } from "./server-decision-engine";

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

const OPERATOR_MAP: Record<string, DecisionRule["operator"]> = {
  "=": "=",
  "equals": "=",
  "==": "=",
  "!=": "!=",
  "not_equals": "!=",
  "IN": "IN",
  "in": "IN",
  "NOT_IN": "NOT_IN",
  "not_in": "NOT_IN",
  "EXISTS": "EXISTS",
  "exists": "EXISTS",
  "NOT_EXISTS": "NOT_EXISTS",
  "not_exists": "NOT_EXISTS",
};

function mapOperator(operator: string): DecisionRule["operator"] {
  const mapped = OPERATOR_MAP[operator.trim()];
  if (!mapped) throw new Error(`Unsupported canonical Decision Tree operator: ${operator}`);
  return mapped;
}

export function mapCanonicalDt(
  tree: { id: string; version: number; status: "draft" | "published" | "deprecated"; entryNodeId: string },
  nodes: CanonicalDtNodeRecord[],
  rules: CanonicalDtRuleRecord[],
): DecisionTreeDefinition {
  const nodeIds = new Set(nodes.map((node) => node.id));
  if (!nodeIds.has(tree.entryNodeId)) throw new Error("Decision Tree entry node is not present in its version.");

  const mappedRules: DecisionRule[] = rules.map((rule) => ({
    id: rule.id,
    sourceNodeId: rule.source_node_id,
    field: rule.field,
    operator: mapOperator(rule.operator),
    value: rule.value,
    targetNodeId: rule.target_node_id,
    priority: rule.priority,
  }));

  for (const rule of mappedRules) {
    if (!nodeIds.has(rule.sourceNodeId) || !nodeIds.has(rule.targetNodeId)) {
      throw new Error(`Decision rule ${rule.id} references a node outside its tree version.`);
    }
  }

  const rulesBySource = new Map<string, DecisionRule[]>();
  for (const rule of mappedRules) {
    const list = rulesBySource.get(rule.sourceNodeId) ?? [];
    list.push(rule);
    rulesBySource.set(rule.sourceNodeId, list);
  }
  for (const list of rulesBySource.values()) list.sort((a, b) => a.priority - b.priority);

  const mapped: DecisionNode[] = nodes.map((node) => {
    const nodeRules = rulesBySource.get(node.id) ?? [];
    const isTerminal = node.kind === "terminal";
    const isQuestion = node.kind === "question" || nodeRules.length > 0;
    return {
      id: node.id,
      type: isTerminal ? "terminal" : isQuestion ? "question" : "rule",
      question: isQuestion && !isTerminal ? node.node_key : undefined,
      terminalDecision: isTerminal
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

  return { id: tree.id, version: tree.version, status: tree.status, rootNodeId: tree.entryNodeId, nodes: mapped, rules: mappedRules };
}
