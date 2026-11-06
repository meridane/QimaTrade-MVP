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

function normalizeActionResult(value: unknown): ActionResult | null {
  if (value === null || typeof value !== "object") return null;

  try {
    // Array checks, own-key enumeration, and descriptor inspection can all throw
    // for hostile or revoked Proxies. Keep the entire boundary exception-safe.
    if (Array.isArray(value)) return null;

    // Snapshot own data properties so subsequent consumers never read through
    // the handler's getters or Proxy get trap. Preserve extra SQL result fields
    // such as objectType, plus non-enumerable and symbol data properties.
    const normalized: Record<PropertyKey, unknown> = {};
    for (const key of Reflect.ownKeys(value)) {
      const descriptor = Object.getOwnPropertyDescriptor(value, key);
      if (
        descriptor === undefined ||
        !Object.prototype.hasOwnProperty.call(descriptor, "value")
      ) {
        return null;
      }

      Object.defineProperty(normalized, key, {
        value: descriptor.value,
        enumerable: descriptor.enumerable,
        configurable: true,
        writable: true,
      });
    }

    const hasOwn = (key: string) =>
      Object.prototype.hasOwnProperty.call(normalized, key);

    if (
      !hasOwn("executionId") ||
      typeof normalized.executionId !== "string" ||
      normalized.executionId.trim().length === 0 ||
      !hasOwn("status") ||
      (normalized.status !== "succeeded" && normalized.status !== "failed")
    ) {
      return null;
    }

    if (
      hasOwn("objectId") &&
      normalized.objectId !== undefined &&
      normalized.objectId !== null &&
      typeof normalized.objectId !== "string"
    ) {
      return null;
    }

    if (
      hasOwn("result") &&
      normalized.result !== undefined &&
      (normalized.result === null ||
        typeof normalized.result !== "object" ||
        Array.isArray(normalized.result))
    ) {
      return null;
    }

    return normalized as ActionResult;
  } catch {
    // Revoked proxies and throwing reflection traps are invalid results.
    return null;
  }
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

  const result = normalizeActionResult(await handler(context, input));
  if (!result) throw new Error("ACTION_RESULT_INVALID");

  return result;
}
