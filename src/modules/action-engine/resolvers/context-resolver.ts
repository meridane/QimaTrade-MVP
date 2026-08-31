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
    const tenantId = request.tenantId;

    if (!tenantId) {
      throw new ActionEngineError("TENANT_CONTEXT_REQUIRED", "A tenant context is required for action execution.");
    }

    for (const candidate of [actor.tenantId, object.tenantId]) {
      if (candidate && candidate !== tenantId) {
        throw new ActionEngineError("TENANT_CONTEXT_MISMATCH", "Actor, object and request must belong to the same tenant.");
      }
    }

    return {
      type: request.context?.type ?? action.contextType,
      tenantId,
      values: {
        ...(request.context?.values ?? {}),
        actorId: actor.id,
        tenantId,
        objectType: object.type,
        objectId: object.id ?? object.masterId,
      },
    };
  }
}
