import type { ActionRuntimeRequest, ResolvedAction } from "../domain/contracts/action";
import type { ActionResolver } from "../ports";
import { ActionEngineError } from "../domain/errors";

export class ConfiguredActionResolver implements ActionResolver {
  constructor(private readonly definitions: ResolvedAction[]) {}

  async resolve(request: ActionRuntimeRequest): Promise<ResolvedAction> {
    const version = request.actionVersion;
    const match = this.definitions.find(
      (definition) =>
        definition.actionKey === request.actionKey &&
        (version === undefined || definition.version === version) &&
        definition.status === "published",
    );

    if (!match) {
      throw new ActionEngineError(
        version === undefined ? "ACTION_NOT_FOUND" : "ACTION_VERSION_NOT_FOUND",
        `No published action definition found for ${request.actionKey}${version === undefined ? "" : ` v${version}`}.`,
      );
    }

    return match;
  }
}
