import type { ActionContext, ActionPrimitive, ActionResult } from "./types";

export type ActionInputValue =
  | ActionPrimitive
  | Record<string, unknown>
  | ActionPrimitive[]
  | null;

export type ActionInput = Record<string, ActionInputValue>;

export type ActionHandler = (
  context: ActionContext,
  input: ActionInput,
) => Promise<ActionResult>;

export type ActionDefinition = {
  actionKey: string;
  version: number;
  status: "draft" | "published" | "retired";
};

export type ActionEngineDependencies = {
  getDefinition: (actionKey: string, version: number) => Promise<ActionDefinition | null>;
  handlers: Record<string, ActionHandler>;
};

function isActionResult(value: unknown): value is ActionResult {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return false;

  const candidate = value as Record<string, unknown>;
  return (
    Object.prototype.hasOwnProperty.call(candidate, "executionId") &&
    typeof candidate.executionId === "string" &&
    candidate.executionId.trim().length > 0 &&
    Object.prototype.hasOwnProperty.call(candidate, "status") &&
    (candidate.status === "succeeded" || candidate.status === "failed")
  );
}

export async function executeAction(
  context: ActionContext,
  input: ActionInput,
  dependencies: ActionEngineDependencies,
): Promise<ActionResult> {
  const definition = await dependencies.getDefinition(context.actionKey, context.actionVersion);
  if (
    !definition ||
    definition.status !== "published" ||
    definition.actionKey !== context.actionKey ||
    definition.version !== context.actionVersion
  ) {
    throw new Error("ACTION_NOT_PUBLISHED");
  }

  const handlers = dependencies.handlers;
  if (!handlers || typeof handlers !== "object" || Array.isArray(handlers)) {
    throw new Error("ACTION_HANDLER_NOT_FOUND");
  }

  const hasOwnHandler = Object.prototype.hasOwnProperty.call(handlers, context.actionKey);
  const handler = hasOwnHandler ? handlers[context.actionKey] : undefined;
  if (typeof handler !== "function") throw new Error("ACTION_HANDLER_NOT_FOUND");

  const result: unknown = await handler(context, input);
  if (!isActionResult(result)) throw new Error("ACTION_RESULT_INVALID");

  return result;
}
