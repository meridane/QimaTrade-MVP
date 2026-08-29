export type NodeKind = "category" | "subcategory" | "terminal";

export type RuleOperator = "equals";

export type Rule = {
  id: string;
  operator: RuleOperator;
  field: string;
  value: string;
  targetNodeId: string;
};

export type DecisionNode = {
  id: string;
  kind: NodeKind;
  title: string;
  description: string;
  imageUrl: string;
  rules: Rule[];
};

export type DecisionTree = {
  id: string;
  version: string;
  title: string;
  entryNodeId: string;
  nodes: DecisionNode[];
};

export type SessionState = {
  sessionId: string;
  treeId: string;
  treeVersion: string;
  currentNodeId: string;
  revision: number;
  answers: Record<string, string>;
};

export type EvaluationResult = {
  matchedRuleId: string | null;
  nextNodeId: string | null;
};
