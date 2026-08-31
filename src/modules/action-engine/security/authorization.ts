import type { ResolvedAction } from "../domain/contracts/action";
import type { ResolvedActor, ResolvedObject } from "../domain/contracts/runtime";
import { ActionEngineError } from "../domain/errors";

export interface AuthorizationPolicy {
  canExecute(actor: ResolvedActor, action: ResolvedAction, object: ResolvedObject): Promise<boolean>;
}

export class PermissionAuthorizationPolicy implements AuthorizationPolicy {
  async canExecute(actor: ResolvedActor, action: ResolvedAction, _object: ResolvedObject) {
    return action.permissions.every((permission) => actor.permissions.includes(permission));
  }
}

export async function assertAuthorized(
  policy: AuthorizationPolicy,
  actor: ResolvedActor,
  action: ResolvedAction,
  object: ResolvedObject,
) {
  if (!(await policy.canExecute(actor, action, object))) {
    throw new ActionEngineError("ACTION_NOT_AUTHORIZED", `Actor ${actor.id} is not authorized for ${action.actionKey}.`);
  }
}
