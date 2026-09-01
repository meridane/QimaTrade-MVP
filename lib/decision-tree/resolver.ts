import type {
  DecisionContext,
  DecisionNode,
  DecisionResult,
  DecisionRule,
  DecisionTraceStep,
} from "./types";
import { evaluateRule, sortRulesDeterministically } from "./evaluator";

export interface ResolveInput {
  entryNodeId: string;
  nodes: DecisionNode[];
  rules: DecisionRule[];
  context: DecisionContext;
  maxSteps?: number;
}

const DEFAULT_MAX_STEPS = 100;

export function resolveDecisionTree(input: ResolveInput): DecisionResult {
  const nodes = new Map(input.nodes.map((node) => [node.id, node]));
  const rulesBySource = new Map<string, DecisionRule[]>();

  for (const rule of input.rules) {
    const list = rulesBySource.get(rule.sourceNodeId) ?? [];
    list.push(rule);
    rulesBySource.set(rule.sourceNodeId, list);
  }

  let currentNodeId = input.entryNodeId;
  const trace: DecisionTraceStep[] = [];
  const visited = new Set<string>();
  const maxSteps = input.maxSteps ?? DEFAULT_MAX_STEPS;

  for (let step = 0; step < maxSteps; step += 1) {
    const node = nodes.get(currentNodeId);
    if (!node) {
      return { status: "error", trace, errors: [`Unknown node: ${currentNodeId}`] };
    }

    if (visited.has(currentNodeId)) {
      return { status: "error", trace, errors: [`Cycle detected at node: ${currentNodeId}`] };
    }
    visited.add(currentNodeId);

    if (node.kind === "terminal") {
      trace.push({ nodeId: node.id, nodeKey: node.key, reason: "terminal" });
      return {
        status: "terminal",
        terminalNodeId: node.id,
        terminalNodeKey: node.key,
        trace,
      };
    }

    if (node.kind === "review") {
      trace.push({ nodeId: node.id, nodeKey: node.key, reason: "human_review" });
      return { status: "review", trace };
    }

    const rules = sortRulesDeterministically(rulesBySource.get(node.id) ?? []);
    const matched = rules.find((rule) => evaluateRule(rule, input.context));

    if (!matched) {
      trace.push({ nodeId: node.id, nodeKey: node.key, reason: "no_matching_rule" });
      return { status: "needs_input", nextNodeId: node.id, trace };
    }

    trace.push({
      nodeId: node.id,
      nodeKey: node.key,
      matchedRuleId: matched.id,
      reason: "rule_matched",
    });

    currentNodeId = matched.targetNodeId;
  }

  return { status: "error", trace, errors: [`Maximum traversal depth exceeded: ${maxSteps}`] };
}
