import type { ResolvedAction } from "../domain/contracts/action";
import type { ResolvedActor, ResolvedContext, ResolvedObject } from "../domain/contracts/runtime";
import type { DecisionTreeDefinition } from "./server-decision-engine";

export interface CanonicalDecisionTreeRepository {
  findPublishedTree(input: {
    action: ResolvedAction;
    object: ResolvedObject;
    actor: ResolvedActor;
    context: ResolvedContext;
  }): Promise<DecisionTreeDefinition | null>;
}

export class CanonicalDtDecisionProvider {
  constructor(private readonly repository: CanonicalDecisionTreeRepository) {}

  async getPublishedTree(
    action: ResolvedAction,
    object: ResolvedObject,
    actor: ResolvedActor,
    context: ResolvedContext,
  ): Promise<DecisionTreeDefinition> {
    const tree = await this.repository.findPublishedTree({ action, object, actor, context });
    if (!tree) {
      throw new Error(`No published canonical Decision Tree is bound to ${action.actionKey}.`);
    }
    if (tree.status !== "published") {
      throw new Error(`Decision Tree ${tree.id} is not published.`);
    }
    return tree;
  }
}
