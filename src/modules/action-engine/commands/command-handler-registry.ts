import type { ActionDefinition } from "../domain/contracts/action";
import type { ActionCommand } from "../domain/contracts/runtime";
import type { CommandHandler, CommandHandlerRegistry } from "../ports";
import { ActionEngineError } from "../domain/errors";

export class ConfiguredCommandHandlerRegistry implements CommandHandlerRegistry {
  constructor(private readonly handlers: Record<string, CommandHandler>) {}

  resolve(action: ActionDefinition): CommandHandler {
    const handler = this.handlers[action.actionKey];
    if (!handler) {
      throw new ActionEngineError("COMMAND_HANDLER_NOT_FOUND", `No command handler registered for ${action.actionKey}.`);
    }
    return handler;
  }
}

export interface ActionCommandExecutor {
  execute(command: ActionCommand, action: ActionDefinition): Promise<Record<string, unknown>>;
}
