import type { ActionRuntimeRequest, ResolvedAction } from "../domain/contracts/action";
import type { ResolvedActor, ResolvedContext, ResolvedObject } from "../domain/contracts/runtime";
import type { ContextResolver } from "../ports";
import { ActionEngineError } from "../domain/errors";

export class RequestContextResolver implements ContextResolver {
  async resolve(
    request: ActionRuntimeRequest,
    action: ResolvedAction,
    object: ResolvedObject,
    actor: ResolvedActor,
  ): Promise<ResolvedContext> {
    const organizationId = request.organizationId ?? actor.organizationId ?? object.organizationId;

    if (!organizationId) {
      throw new ActionEngineError("ORGANIZATION_CONTEXT_REQUIRED", "An organization context is required for action execution.");
    }

    for (const candidate of [actor.organizationId, object.organizationId]) {
      if (candidate && candidate !== organizationId) {
        throw new ActionEngineError("ORGANIZATION_CONTEXT_MISMATCH", "Actor, object and request must belong to the same organization.");
      }
    }

    return {
      type: request.context?.type ?? action.contextType,
      organizationId,
      values: {
        ...(request.context?.values ?? {}),
        actorId: actor.id,
        organizationId,
        objectType: object.type,
        objectId: object.id ?? object.masterId,
      },
    };
  }
}
