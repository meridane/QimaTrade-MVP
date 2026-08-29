import type { DecisionTree, EvaluationResult, SessionState } from "@/lib/decision-tree/types";

export function getNode(tree: DecisionTree, nodeId: string) {
  const node = tree.nodes.find((candidate) => candidate.id === nodeId);
  if (!node) throw new Error(`Decision node not found: ${nodeId}`);
  return node;
}

export function evaluateAnswer(
  tree: DecisionTree,
  session: SessionState,
  field: "category" | "subcategory",
  value: string,
): EvaluationResult {
  const node = getNode(tree, session.currentNodeId);
  const matched = node.rules.find(
    (rule) => rule.field === field && rule.operator === "equals" && rule.value === value,
  );

  return {
    matchedRuleId: matched?.id ?? null,
    nextNodeId: matched?.targetNodeId ?? null,
  };
}

export function applyAnswer(
  tree: DecisionTree,
  session: SessionState,
  field: "category" | "subcategory",
  value: string,
): SessionState {
  const result = evaluateAnswer(tree, session, field, value);
  if (!result.nextNodeId) throw new Error("No valid transition for this answer");

  return {
    ...session,
    currentNodeId: result.nextNodeId,
    revision: session.revision + 1,
    answers: {
      ...session.answers,
      [field]: value,
    },
  };
}

export function createSession(tree: DecisionTree): SessionState {
  return {
    sessionId: crypto.randomUUID(),
    treeId: tree.id,
    treeVersion: tree.version,
    currentNodeId: tree.entryNodeId,
    revision: 0,
    answers: {},
  };
}
