import type { ResolvedAction } from "../domain/contracts/action";
import type { DecisionResult, ResolvedActor, ResolvedContext, ResolvedObject } from "../domain/contracts/runtime";
import type { DecisionEngine } from "../ports";

export class ConfiguredDecisionEngine implements DecisionEngine {
  constructor(
    private readonly resolver: (
      action: ResolvedAction,
      object: ResolvedObject,
      actor: ResolvedActor,
      context: ResolvedContext,
    ) => Promise<DecisionResult>,
  ) {}

  resolve(action: ResolvedAction, object: ResolvedObject, actor: ResolvedActor, context: ResolvedContext) {
    return this.resolver(action, object, actor, context);
  }
}
