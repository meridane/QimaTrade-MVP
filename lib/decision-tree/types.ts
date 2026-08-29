export type NodeKind = "category" | "subcategory" | "terminal";

export type RuleOperator = "equals";

export type Rule = {
  id: string;
  operator: RuleOperator;
  field: string;
  value: string;
  targetNodeId: string;
};

export type ProductMaster = {
  id: string;
  code: string;
  name: string;
  canonicalName: string;
  description: string | null;
  productRole: string | null;
  classificationStatus: string | null;
  confidence: number | null;
};

export type DecisionNode = {
  id: string;
  kind: NodeKind;
  title: string;
  description: string;
  imageUrl: string;
  rules: Rule[];
  canonicalCategoryId?: string | null;
  canonicalSubcategoryId?: string | null;
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
  selectedProductMasterId?: string | null;
  status?: "active" | "completed" | "abandoned";
};

export type EvaluationResult = {
  matchedRuleId: string | null;
  nextNodeId: string | null;
};
