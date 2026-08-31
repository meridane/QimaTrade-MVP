import type { ResolvedAction } from "../domain/contracts/action";
import type { DecisionResult, ResolvedActor, ResolvedContext, ResolvedObject } from "../domain/contracts/runtime";
import type { DecisionEngine } from "../ports";
import { ActionEngineError } from "../domain/errors";

export interface DecisionNode {
  id: string;
  type: "question" | "rule" | "terminal";
  question?: string;
  allowedOptions?: string[];
  condition?: (answers: Record<string, unknown>) => boolean;
  nextNodeId?: string;
  terminalDecision?: DecisionResult;
}

export interface DecisionTreeDefinition {
  id: string;
  version: number;
  status: "draft" | "published" | "deprecated";
  rootNodeId: string;
  nodes: DecisionNode[];
}

export interface DecisionInput {
  answers?: Record<string, unknown>;
}

export class ServerDecisionEngine implements DecisionEngine {
  constructor(
    private readonly treeProvider: (
      action: ResolvedAction,
      object: ResolvedObject,
      actor: ResolvedActor,
      context: ResolvedContext,
    ) => Promise<DecisionTreeDefinition>,
    private readonly inputProvider?: (context: ResolvedContext) => DecisionInput,
  ) {}

  async resolve(
    action: ResolvedAction,
    object: ResolvedObject,
    actor: ResolvedActor,
    context: ResolvedContext,
  ): Promise<DecisionResult> {
    const tree = await this.treeProvider(action, object, actor, context);
    if (tree.status !== "published") {
      throw new ActionEngineError("DECISION_TREE_NOT_PUBLISHED", `Decision tree ${tree.id} is not published.`);
    }

    const answers = this.inputProvider?.(context).answers ?? {};
    const nodeById = new Map(tree.nodes.map((node) => [node.id, node]));
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
        const answer = String(answers[node.question]);
        if (node.allowedOptions && !node.allowedOptions.includes(answer)) {
          throw new ActionEngineError("DECISION_OPTION_INVALID", `Answer is not allowed for ${node.question}.`);
        }
      }

      if (node.condition && !node.condition(answers)) return { type: "BLOCKED_BY_RULE", reason: `Decision rule ${node.id} blocked the action.` };
      nodeId = node.nextNodeId;
    }

    throw new ActionEngineError("DECISION_TREE_DEPTH_EXCEEDED", "Decision tree did not reach a terminal decision.");
  }
}
