export type Primitive = string | number | boolean | null;

export type NodeKind =
  | "category"
  | "subcategory"
  | "question"
  | "decision"
  | "terminal"
  | "review";

export type RuleOperator =
  | "equals"
  | "not_equals"
  | "contains"
  | "in"
  | "not_in"
  | "gt"
  | "gte"
  | "lt"
  | "lte"
  | "exists";

export type Rule = {
  id: string;
  sourceNodeId: string;
  operator: RuleOperator;
  field: string;
  value: string;
  targetNodeId: string;
  priority?: number;
  comparisonValue?: Primitive | Primitive[] | null;
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
  description?: string | null;
  imageUrl?: string | null;
  rules: Rule[];
  canonicalCategoryId?: string | null;
  canonicalSubcategoryId?: string | null;
  metadata?: Record<string, unknown>;
};

export type DecisionTree = {
  id: string;
  version: string;
  title: string;
  entryNodeId: string;
  nodes: DecisionNode[];
  status?: "draft" | "published" | "archived";
};

export type DecisionContext = {
  values: Record<string, Primitive | Primitive[]>;
  metadata?: Record<string, unknown>;
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

export type DecisionTraceStep = {
  nodeId: string;
  matchedRuleId: string | null;
  reason?: string;
};

export type DecisionResult = {
  status: "terminal" | "needs_input" | "review" | "error";
  terminalNodeId?: string | null;
  nextNodeId?: string | null;
  trace: DecisionTraceStep[];
  errors?: string[];
};
