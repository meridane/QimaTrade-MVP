import { expect, test } from "@playwright/test";
import { executeAction, type ActionHandler, type ActionInput } from "../../lib/actions/engine";
import type { ActionContext, ActionResult } from "../../lib/actions/types";

test("executeAction preserves non-enumerable string and symbol ActionResult metadata", async () => {
  const context: ActionContext = {
    userId: "user-1",
    tenantId: "tenant-1",
    actionKey: "CREATE_OFFER",
    actionVersion: 1,
    objectType: "TestObject",
    objectId: "object-1",
    correlationId: "correlation-1",
    idempotencyKey: "idempotency-1",
  };
  const input: ActionInput = { demandId: "demand-1" };
  const metadataKey = Symbol("createOfferMetadata");
  const target = {
    executionId: "execution-symbol-metadata",
    status: "succeeded",
  } as ActionResult & { objectType: string; [metadataKey]: string };

  Object.defineProperties(target, {
    objectType: {
      configurable: true,
      enumerable: false,
      value: "Offer",
      writable: false,
    },
    [metadataKey]: {
      configurable: true,
      enumerable: false,
      value: "symbol-metadata",
      writable: false,
    },
  });

  let ownKeysCalls = 0;
  const descriptorTrapKeys: PropertyKey[] = [];
  const getTrapProperties: PropertyKey[] = [];
  const resultProxy = new Proxy(target, {
    ownKeys(object) {
      ownKeysCalls += 1;
      return Reflect.ownKeys(object);
    },
    getOwnPropertyDescriptor(object, property) {
      descriptorTrapKeys.push(property);
      return Reflect.getOwnPropertyDescriptor(object, property);
    },
    get(object, property, receiver) {
      getTrapProperties.push(property);
      // Await performs this native thenable probe before normalization.
      if (property === "then") return undefined;
      return Reflect.get(object, property, receiver);
    },
  });

  let definitionLookups = 0;
  let handlerCalls = 0;
  const handler = (() => {
    handlerCalls += 1;
    return resultProxy as unknown as Promise<ActionResult>;
  }) as ActionHandler;

  const result = await executeAction(context, input, {
    getDefinition: async (actionKey, version) => {
      definitionLookups += 1;
      return { actionKey, version, status: "published" };
    },
    handlers: { CREATE_OFFER: handler },
  });

  expect(definitionLookups).toBe(1);
  expect(handlerCalls).toBe(1);
  expect(ownKeysCalls).toBe(1);
  expect(descriptorTrapKeys).toEqual(["executionId", "status", "objectType", metadataKey]);
  expect(getTrapProperties).toEqual(["then"]);
  expect(result).not.toBe(resultProxy);
  expect(Reflect.ownKeys(result)).toContain(metadataKey);
  expect((result as ActionResult & { objectType: string }).objectType).toBe("Offer");
  expect((result as ActionResult & { [metadataKey]: string })[metadataKey]).toBe("symbol-metadata");
  expect(Object.getOwnPropertyDescriptor(result, "objectType")).toMatchObject({
    configurable: true,
    enumerable: false,
    value: "Offer",
    writable: true,
  });
  expect(Object.getOwnPropertyDescriptor(result, metadataKey)).toMatchObject({
    configurable: true,
    enumerable: false,
    value: "symbol-metadata",
    writable: true,
  });
});
