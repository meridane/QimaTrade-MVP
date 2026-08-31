import type { ActionRuntimeRequest, ResolvedAction } from "../domain/contracts/action";
import type { ActorResolver } from "../ports";
import type { ResolvedActor } from "../domain/contracts/runtime";
import { ActionEngineError } from "../domain/errors";

export class ConfiguredActorResolver implements ActorResolver {
  constructor(private readonly actors: Record<string, ResolvedActor>) {}

  async resolve(request: ActionRuntimeRequest, action: ResolvedAction): Promise<ResolvedActor> {
    const actor = this.actors[request.actor.id];
    if (!actor) throw new ActionEngineError("ACTOR_NOT_FOUND", `Actor ${request.actor.id} was not found.`);
    if (actor.type !== request.actor.type || actor.type !== action.actorType) {
      throw new ActionEngineError("ACTOR_TYPE_MISMATCH", `Actor type ${request.actor.type} is not allowed for ${action.actionKey}.`);
    }
    return actor;
  }
}
