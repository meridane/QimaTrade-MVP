import type { ResolvedAction } from "../domain/contracts/action";
import type { ActionCommand } from "../domain/contracts/runtime";
import { ActionEngineError } from "../domain/errors";
import type { AuthorizationPolicy } from "../security/authorization";
import { assertAuthorized } from "../security/authorization";
import type { IdempotencyStore } from "../security/idempotency";
import type { CommandHandlerRegistry } from "../ports";

export class IdempotentCommandExecutor {
  constructor(
    private readonly registry: CommandHandlerRegistry,
    private readonly authorization: AuthorizationPolicy,
    private readonly idempotency: IdempotencyStore,
  ) {}

  async execute(
    command: ActionCommand,
    action: ResolvedAction,
    actor: { id: string; type: string; permissions: string[] },
    object: { type: string; id?: string; masterId?: string },
  ) {
    if (command.actionKey !== action.actionKey || command.actionVersion !== action.version) {
      throw new ActionEngineError(
        "COMMAND_ACTION_MISMATCH",
        "Command does not match the resolved action definition.",
      );
    }
    if (command.actorId !== actor.id) {
      throw new ActionEngineError(
        "COMMAND_ACTOR_MISMATCH",
        "Command actor does not match the resolved actor.",
      );
    }
    if (command.objectType !== object.type || command.objectId !== (object.id ?? object.masterId)) {
      throw new ActionEngineError(
        "COMMAND_OBJECT_MISMATCH",
        "Command object does not match the resolved object.",
      );
    }

    await assertAuthorized(this.authorization, actor, action, object);

    const existing = await this.idempotency.get(command.idempotencyKey);
    if (existing) {
      if (existing.actionKey !== command.actionKey || existing.actorId !== command.actorId) {
        throw new ActionEngineError(
          "IDEMPOTENCY_KEY_CONFLICT",
          "Idempotency key is already bound to another command.",
        );
      }
      if (existing.status === "COMPLETED" && existing.result) return existing.result;
      throw new ActionEngineError(
        "COMMAND_ALREADY_PROCESSED",
        "A command with this idempotency key is already being processed.",
      );
    }

    const started = await this.idempotency.begin({
      key: command.idempotencyKey,
      actionKey: command.actionKey,
      actorId: command.actorId,
      requestHash: JSON.stringify(command.payload),
      status: "IN_PROGRESS",
    });
    if (!started) {
      throw new ActionEngineError(
        "IDEMPOTENCY_RACE",
        "Command processing was started concurrently.",
      );
    }

    try {
      const result = await this.registry.resolve(action).execute(command);
      await this.idempotency.complete(command.idempotencyKey, result);
      return result;
    } catch (error) {
      await this.idempotency.fail(command.idempotencyKey);
      throw error;
    }
  }
}
