import type { ActionRuntimeRequest, ResolvedAction } from "../domain/contracts/action";
import type { ResolvedActor, ResolvedContext, ResolvedObject } from "../domain/contracts/runtime";
import type { ContextResolver } from "../ports";

export class RequestContextResolver implements ContextResolver {
  async resolve(
    request: ActionRuntimeRequest,
    action: ResolvedAction,
    object: ResolvedObject,
    actor: ResolvedActor,
  ): Promise<ResolvedContext> {
    return {
      type: request.context?.type ?? action.contextType,
      values: {
        ...(request.context?.values ?? {}),
        actorId: actor.id,
        objectType: object.type,
        objectId: object.id ?? object.masterId,
      },
    };
  }
}
