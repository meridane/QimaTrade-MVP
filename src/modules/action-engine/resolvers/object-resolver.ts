import type { ActionRuntimeRequest, ResolvedAction } from "../domain/contracts/action";
import type { ObjectResolver } from "../ports";
import type { ResolvedObject } from "../domain/contracts/runtime";
import { ActionEngineError } from "../domain/errors";

export class ConfiguredObjectResolver implements ObjectResolver {
  constructor(private readonly objects: Record<string, Record<string, unknown>>) {}

  async resolve(request: ActionRuntimeRequest, action: ResolvedAction): Promise<ResolvedObject> {
    const reference = request.object;
    if (!reference || reference.type !== action.objectType) {
      throw new ActionEngineError("OBJECT_TYPE_MISMATCH", `Action ${action.actionKey} expects object type ${action.objectType}.`);
    }

    const id = reference.id ?? reference.masterId;
    const data = id ? this.objects[id] : undefined;
    if (id && !data) {
      throw new ActionEngineError("OBJECT_NOT_FOUND", `Object ${id} was not found.`);
    }

    return { type: reference.type, id: reference.id, masterId: reference.masterId, data };
  }
}
