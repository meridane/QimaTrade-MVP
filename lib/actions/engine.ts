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

function normalizeActionDefinition(value: unknown): ActionDefinition | null {
  if (value === null || typeof value !== "object") return null;

  try {
    // Array.isArray can throw for a revoked Proxy, so keep every reflective
    // operation inside this boundary.
    if (Array.isArray(value)) return null;

    const actionKey = Object.getOwnPropertyDescriptor(value, "actionKey");
    const version = Object.getOwnPropertyDescriptor(value, "version");
    const status = Object.getOwnPropertyDescriptor(value, "status");

    // Definitions are data contracts, not executable accessor surfaces. Read
    // descriptor values and copy them so later checks never invoke Proxy get traps.
    if (
      actionKey === undefined ||
      !Object.prototype.hasOwnProperty.call(actionKey, "value") ||
      typeof actionKey.value !== "string" ||
      version === undefined ||
      !Object.prototype.hasOwnProperty.call(version, "value") ||
      typeof version.value !== "number" ||
      status === undefined ||
      !Object.prototype.hasOwnProperty.call(status, "value") ||
      (status.value !== "draft" &&
        status.value !== "published" &&
        status.value !== "retired")
    ) {
      return null;
    }

    return {
      actionKey: actionKey.value,
      version: version.value,
      status: status.value,
    };
  } catch {
    // Revoked proxies and throwing descriptor traps are invalid definitions.
    return null;
  }
}

function isActionResult(value: unknown): value is ActionResult {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return false;

  const candidate = value as Record<string, unknown>;
  const hasOwn = (key: string) => Object.prototype.hasOwnProperty.call(candidate, key);

  if (
    !hasOwn("executionId") ||
    typeof candidate.executionId !== "string" ||
    candidate.executionId.trim().length === 0 ||
    !hasOwn("status") ||
    (candidate.status !== "succeeded" && candidate.status !== "failed")
  ) {
    return false;
  }

  // Optional contract fields must be own properties when present. Otherwise
  // callers can observe inherited values that JSON serialization omits.
  if (
    ("objectId" in candidate && !hasOwn("objectId")) ||
    ("result" in candidate && !hasOwn("result"))
  ) {
    return false;
  }

  if (
    hasOwn("objectId") &&
    candidate.objectId !== undefined &&
    candidate.objectId !== null &&
    typeof candidate.objectId !== "string"
  ) {
    return false;
  }

  if (
    hasOwn("result") &&
    candidate.result !== undefined &&
    (candidate.result === null ||
      typeof candidate.result !== "object" ||
      Array.isArray(candidate.result))
  ) {
    return false;
  }

  return true;
}

export async function executeAction(
  context: ActionContext,
  input: ActionInput,
  dependencies: ActionEngineDependencies,
): Promise<ActionResult> {
  const rawDefinition: unknown = await dependencies.getDefinition(
    context.actionKey,
    context.actionVersion,
  );
  const definition = normalizeActionDefinition(rawDefinition);
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
