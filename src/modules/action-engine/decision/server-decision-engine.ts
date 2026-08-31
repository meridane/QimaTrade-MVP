import type { ResolvedAction } from "../domain/contracts/action";
import type { DecisionResult, ResolvedActor, ResolvedContext, ResolvedObject } from "../domain/contracts/runtime";
import type { DecisionEngine } from "../ports";
import { ActionEngineError } from "../domain/errors";

export type DecisionOperator = "=" | "!=" | "IN" | "NOT_IN" | "EXISTS" | "NOT_EXISTS";

export interface DecisionNode {
  id: string;
  type: "question" | "rule" | "terminal";
  question?: string;
  allowedOptions?: string[];
  nextNodeId?: string;
  terminalDecision?: DecisionResult;
}

export interface DecisionRule {
  id: string;
  sourceNodeId: string;
  field: string;
  operator: DecisionOperator;
  value?: string;
  targetNodeId: string;
  priority: number;
}

export interface DecisionTreeDefinition {
  id: string;
  version: number;
  status: "draft" | "published" | "deprecated";
  rootNodeId: string;
  nodes: DecisionNode[];
  rules?: DecisionRule[];
}

export interface DecisionInput { answers?: Record<string, unknown> }

function evaluateRule(rule: DecisionRule, answers: Record<string, unknown>): boolean {
  const exists = Object.prototype.hasOwnProperty.call(answers, rule.field);
  const actual = answers[rule.field];
  switch (rule.operator) {
    case "EXISTS": return exists;
    case "NOT_EXISTS": return !exists;
    case "=": return exists && String(actual) === String(rule.value ?? "");
    case "!=": return exists && String(actual) !== String(rule.value ?? "");
    case "IN": return exists && (rule.value ?? "").split(",").map((v) => v.trim()).includes(String(actual));
    case "NOT_IN": return exists && !(rule.value ?? "").split(",").map((v) => v.trim()).includes(String(actual));
    default: throw new ActionEngineError("DECISION_OPERATOR_UNSUPPORTED", `Unsupported operator for rule ${rule.id}.`);
  }
}

export class ServerDecisionEngine implements DecisionEngine {
  constructor(
    private readonly treeProvider: (action: ResolvedAction, object: ResolvedObject, actor: ResolvedActor, context: ResolvedContext) => Promise<DecisionTreeDefinition>,
    private readonly inputProvider?: (context: ResolvedContext) => DecisionInput,
  ) {}

  async resolve(action: ResolvedAction, object: ResolvedObject, actor: ResolvedActor, context: ResolvedContext): Promise<DecisionResult> {
    const tree = await this.treeProvider(action, object, actor, context);
    if (tree.status !== "published") throw new ActionEngineError("DECISION_TREE_NOT_PUBLISHED", `Decision tree ${tree.id} is not published.`);

    const answers = this.inputProvider?.(context).answers ?? {};
    const nodeById = new Map(tree.nodes.map((node) => [node.id, node]));
    const rulesBySource = new Map<string, DecisionRule[]>();
    for (const rule of tree.rules ?? []) {
      if (!nodeById.has(rule.sourceNodeId) || !nodeById.has(rule.targetNodeId)) throw new ActionEngineError("DECISION_RULE_REFERENCE_INVALID", `Rule ${rule.id} references a node outside the tree.`);
      const list = rulesBySource.get(rule.sourceNodeId) ?? [];
      list.push(rule);
      rulesBySource.set(rule.sourceNodeId, list);
    }
    for (const rules of rulesBySource.values()) rules.sort((a, b) => a.priority - b.priority);

    let nodeId: string | undefined = tree.rootNodeId;
    const visited = new Set<string>();
    for (let depth = 0; depth < 100 && nodeId; depth += 1) {
      if (visited.has(nodeId)) throw new ActionEngineError("DECISION_TREE_CYCLE", "Decision tree contains a cycle.");
      visited.add(nodeId);
      const node = nodeById.get(nodeId);
      if (!node) throw new ActionEngineError("DECISION_NODE_NOT_FOUND", `Decision node ${nodeId} was not found.`);

      if (node.type === "terminal") {
        if (!node.terminalDecision) throw new ActionEngineError("DECISION_TERMINAL_INVALID", `Terminal node ${node.id} has no decision.`);
        return node.terminalDecision;
      }

      if (node.type === "question") {
        if (!node.question) throw new ActionEngineError("DECISION_QUESTION_INVALID", `Question node ${node.id} has no question key.`);
        if (!(node.question in answers)) return { type: "ASK_QUESTION", nodeId: node.id };
        if (node.allowedOptions && !node.allowedOptions.includes(String(answers[node.question]))) throw new ActionEngineError("DECISION_OPTION_INVALID", `Answer is not allowed for ${node.question}.`);
      }

      const matchingRule = (rulesBySource.get(node.id) ?? []).find((rule) => evaluateRule(rule, answers));
      if (!matchingRule) {
        if (node.nextNodeId) nodeId = node.nextNodeId;
        else return { type: "BLOCKED_BY_RULE", reason: `No matching rule for decision node ${node.id}.` };
      } else {
        nodeId = matchingRule.targetNodeId;
      }
    }

    throw new ActionEngineError("DECISION_TREE_DEPTH_EXCEEDED", "Decision tree did not reach a terminal decision.");
  }
}
