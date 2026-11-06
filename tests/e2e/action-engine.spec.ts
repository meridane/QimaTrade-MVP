import { expect, test } from "@playwright/test";
import { executeAction, type ActionDefinition, type ActionHandler, type ActionInput } from "../../lib/actions/engine";
import type { ActionContext, ActionResult } from "../../lib/actions/types";

test("executeAction rejects a published action when no handler is registered", async () => {
  const context: ActionContext = {
    userId: "user-1",
    tenantId: "tenant-1",
    actionKey: "UNREGISTERED_ACTION",
    actionVersion: 1,
    objectType: "TestObject",
    objectId: "object-1",
    correlationId: "correlation-1",
    idempotencyKey: "idempotency-1",
  };
  const input: ActionInput = { sample: "value" };
  let definitionLookups = 0;
  let otherHandlerCalls = 0;

  await expect(
    executeAction(context, input, {
      getDefinition: async (actionKey, version) => {
        definitionLookups += 1;
        return { actionKey, version, status: "published" };
      },
      handlers: {
        SOME_OTHER_ACTION: async () => {
          otherHandlerCalls += 1;
          return { executionId: "unexpected", status: "succeeded" };
        },
      },
    }),
  ).rejects.toThrow("ACTION_HANDLER_NOT_FOUND");

  expect(definitionLookups).toBe(1);
  expect(otherHandlerCalls).toBe(0);
});


test("executeAction invokes a registered handler once with the original context and input", async () => {
  const context: ActionContext = {
    userId: "user-1",
    tenantId: "tenant-1",
    actionKey: "TEST_CREATE_OFFER_V2",
    actionVersion: 7,
    objectType: "TestObject",
    objectId: "object-1",
    correlationId: "correlation-1",
    idempotencyKey: "idempotency-1",
  };
  const input: ActionInput = { demandId: "demand-1", quantity: 3 };
  const expectedResult: ActionResult = {
    executionId: "execution-1",
    status: "succeeded",
    objectId: "offer-1",
    result: { offerId: "offer-1", accepted: true },
  };
  let definitionLookups = 0;
  let receivedDefinitionActionKey: string | undefined;
  let receivedDefinitionVersion: number | undefined;
  let handlerCalls = 0;
  let receivedContext: ActionContext | undefined;
  let receivedInput: ActionInput | undefined;

  const result = await executeAction(context, input, {
    getDefinition: async (actionKey, version) => {
      definitionLookups += 1;
      receivedDefinitionActionKey = actionKey;
      receivedDefinitionVersion = version;
      return { actionKey, version, status: "published" };
    },
    handlers: {
      TEST_CREATE_OFFER_V2: async (handlerContext, handlerInput) => {
        handlerCalls += 1;
        receivedContext = handlerContext;
        receivedInput = handlerInput;
        return expectedResult;
      },
    },
  });

  expect(definitionLookups).toBe(1);
  expect(receivedDefinitionActionKey).toBe(context.actionKey);
  expect(receivedDefinitionVersion).toBe(context.actionVersion);
  expect(handlerCalls).toBe(1);
  expect(receivedContext).toBe(context);
  expect(receivedInput).toBe(input);
  expect(result).toBe(expectedResult);
});

test("executeAction propagates a registered handler rejection without retrying", async () => {
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
  const input: ActionInput = { demandId: "demand-1", quantity: 3 };
  const expectedError = new Error("CREATE_OFFER backend unavailable");
  let definitionLookups = 0;
  let handlerCalls = 0;
  let caughtError: unknown;

  try {
    await executeAction(context, input, {
      getDefinition: async (actionKey, version) => {
        definitionLookups += 1;
        return { actionKey, version, status: "published" };
      },
      handlers: {
        CREATE_OFFER: async () => {
          handlerCalls += 1;
          throw expectedError;
        },
      },
    });
  } catch (error) {
    caughtError = error;
  }

  expect(definitionLookups).toBe(1);
  expect(handlerCalls).toBe(1);
  expect(caughtError).toBe(expectedError);
});

test("executeAction propagates a getDefinition rejection without invoking a handler", async () => {
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
  const input: ActionInput = { demandId: "demand-1", quantity: 3 };
  const expectedError = new Error("CREATE_OFFER definition lookup unavailable");
  let definitionLookups = 0;
  let handlerCalls = 0;

  await expect(
    executeAction(context, input, {
      getDefinition: async () => {
        definitionLookups += 1;
        throw expectedError;
      },
      handlers: {
        CREATE_OFFER: async () => {
          handlerCalls += 1;
          return { executionId: "unexpected", status: "succeeded" };
        },
      },
    }),
  ).rejects.toBe(expectedError);

  expect(definitionLookups).toBe(1);
  expect(handlerCalls).toBe(0);
});

const invalidActionDefinitions: Array<{ label: string; definition: ActionDefinition | null }> = [
  { label: "missing", definition: null },
  {
    label: "draft",
    definition: { actionKey: "CREATE_OFFER", version: 1, status: "draft" },
  },
  {
    label: "retired",
    definition: { actionKey: "CREATE_OFFER", version: 1, status: "retired" },
  },
];

for (const invalidCase of invalidActionDefinitions) {
  test(`executeAction rejects ${invalidCase.label} definitions before invoking a handler`, async () => {
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
    const input: ActionInput = { demandId: "demand-1", quantity: 3 };
    let definitionLookups = 0;
    let handlerCalls = 0;

    await expect(
      executeAction(context, input, {
        getDefinition: async () => {
          definitionLookups += 1;
          return invalidCase.definition;
        },
        handlers: {
          CREATE_OFFER: async () => {
            handlerCalls += 1;
            return { executionId: "unexpected", status: "succeeded" };
          },
        },
      }),
    ).rejects.toThrow("ACTION_NOT_PUBLISHED");

    expect(definitionLookups).toBe(1);
    expect(handlerCalls).toBe(0);
  });
}

const mismatchedActionDefinitions: Array<{ label: string; definition: ActionDefinition }> = [
  {
    label: "different action key",
    definition: { actionKey: "PUBLISH_PRODUCT_REQUEST", version: 1, status: "published" },
  },
  {
    label: "different action version",
    definition: { actionKey: "CREATE_OFFER", version: 2, status: "published" },
  },
];

for (const mismatchCase of mismatchedActionDefinitions) {
  test(`executeAction rejects a published definition with a ${mismatchCase.label} before invoking a handler`, async () => {
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
    const input: ActionInput = { demandId: "demand-1", quantity: 3 };
    let definitionLookups = 0;
    let receivedLookup: { actionKey: string; version: number } | undefined;
    let handlerCalls = 0;

    await expect(
      executeAction(context, input, {
        getDefinition: async (actionKey, version) => {
          definitionLookups += 1;
          receivedLookup = { actionKey, version };
          return mismatchCase.definition;
        },
        handlers: {
          CREATE_OFFER: async () => {
            handlerCalls += 1;
            return { executionId: "unexpected", status: "succeeded" };
          },
        },
      }),
    ).rejects.toThrow("ACTION_NOT_PUBLISHED");

    expect(definitionLookups).toBe(1);
    expect(receivedLookup).toEqual({
      actionKey: context.actionKey,
      version: context.actionVersion,
    });
    expect(handlerCalls).toBe(0);
  });
}


const inheritedObjectPrototypeHandlerKeys = ["toString", "constructor", "__proto__", "hasOwnProperty"] as const;

for (const actionKey of inheritedObjectPrototypeHandlerKeys) {
  test(`executeAction rejects inherited Object.prototype handler key "${actionKey}"`, async () => {
    const context: ActionContext = {
      userId: "user-1",
      tenantId: "tenant-1",
      actionKey,
      actionVersion: 1,
      objectType: "TestObject",
      objectId: "object-1",
      correlationId: "correlation-1",
      idempotencyKey: "idempotency-1",
    };
    const input: ActionInput = { sample: "value" };
    let definitionLookups = 0;
    let otherHandlerCalls = 0;
    const handlers = {
      REGISTERED_OTHER_ACTION: async () => {
        otherHandlerCalls += 1;
        return { executionId: "unexpected", status: "succeeded" as const };
      },
    };

    expect(Object.prototype.hasOwnProperty.call(handlers, actionKey)).toBe(false);

    await expect(
      executeAction(context, input, {
        getDefinition: async (requestedActionKey, version) => {
          definitionLookups += 1;
          return { actionKey: requestedActionKey, version, status: "published" };
        },
        handlers,
      }),
    ).rejects.toThrow("ACTION_HANDLER_NOT_FOUND");

    expect(definitionLookups).toBe(1);
    expect(otherHandlerCalls).toBe(0);
  });
}


const invalidOwnHandlerValues: Array<{ label: string; value: unknown }> = [
  { label: "string", value: "not-a-handler" },
  { label: "object", value: { invoke: true } },
  { label: "null", value: null },
  { label: "undefined", value: undefined },
];

for (const invalidCase of invalidOwnHandlerValues) {
  test(`executeAction rejects an own handler property with a ${invalidCase.label} value`, async () => {
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
    let definitionLookups = 0;
    let otherHandlerCalls = 0;
    const handlers = {
      CREATE_OFFER: invalidCase.value,
      REGISTERED_OTHER_ACTION: async () => {
        otherHandlerCalls += 1;
        return { executionId: "unexpected", status: "succeeded" as const };
      },
    } as unknown as Record<string, ActionHandler>;

    expect(Object.prototype.hasOwnProperty.call(handlers, "CREATE_OFFER")).toBe(true);

    await expect(
      executeAction(context, input, {
        getDefinition: async (actionKey, version) => {
          definitionLookups += 1;
          return { actionKey, version, status: "published" };
        },
        handlers,
      }),
    ).rejects.toThrow("ACTION_HANDLER_NOT_FOUND");

    expect(definitionLookups).toBe(1);
    expect(otherHandlerCalls).toBe(0);
  });
}


const malformedHandlerRegistries: Array<{ label: string; value: unknown }> = [
  { label: "undefined", value: undefined },
  { label: "null", value: null },
  { label: "string", value: "not-a-handler-registry" },
  {
    label: "array with an own callable handler",
    value: Object.assign([], {
      CREATE_OFFER: async () => ({
        executionId: "unexpected",
        status: "succeeded" as const,
      }),
    }),
  },
];

for (const malformedCase of malformedHandlerRegistries) {
  test(`executeAction rejects a malformed handler registry: ${malformedCase.label}`, async () => {
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
    let definitionLookups = 0;
    let handlerCalls = 0;
    const invalidHandlers =
      malformedCase.label === "array with an own callable handler"
        ? Object.assign([], {
            CREATE_OFFER: async () => {
              handlerCalls += 1;
              return { executionId: "unexpected", status: "succeeded" as const };
            },
          })
        : malformedCase.value;

    const dependencies = {
      getDefinition: async (actionKey: string, version: number) => {
        definitionLookups += 1;
        return { actionKey, version, status: "published" as const };
      },
      handlers: invalidHandlers,
    } as unknown as import("../../lib/actions/engine").ActionEngineDependencies;

    await expect(executeAction(context, input, dependencies)).rejects.toThrow(
      "ACTION_HANDLER_NOT_FOUND",
    );

    expect(definitionLookups).toBe(1);
    expect(handlerCalls).toBe(0);
  });
}

test("executeAction supports a valid null-prototype handler registry", async () => {
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
  const handlers = Object.create(null) as Record<string, ActionHandler>;
  let handlerCalls = 0;

  handlers.CREATE_OFFER = async () => {
    handlerCalls += 1;
    return { executionId: "execution-1", status: "succeeded" };
  };

  const result = await executeAction(context, input, {
    getDefinition: async (actionKey, version) => ({
      actionKey,
      version,
      status: "published",
    }),
    handlers,
  });

  expect(handlerCalls).toBe(1);
  expect(result).toMatchObject({ executionId: "execution-1", status: "succeeded" });
});


test("executeAction rejects an inherited handler from a custom prototype", async () => {
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
  let definitionLookups = 0;
  let inheritedHandlerCalls = 0;
  const customPrototype = {
    CREATE_OFFER: async () => {
      inheritedHandlerCalls += 1;
      return { executionId: "unexpected", status: "succeeded" as const };
    },
  };
  const handlers = Object.create(customPrototype) as Record<string, ActionHandler>;

  expect(Object.getPrototypeOf(handlers)).toBe(customPrototype);
  expect(Object.prototype.hasOwnProperty.call(handlers, "CREATE_OFFER")).toBe(false);
  expect(typeof handlers.CREATE_OFFER).toBe("function");

  await expect(
    executeAction(context, input, {
      getDefinition: async (actionKey, version) => {
        definitionLookups += 1;
        return { actionKey, version, status: "published" };
      },
      handlers,
    }),
  ).rejects.toThrow("ACTION_HANDLER_NOT_FOUND");

  expect(definitionLookups).toBe(1);
  expect(inheritedHandlerCalls).toBe(0);
});

test("executeAction preserves an object rejection from getDefinition without invoking a handler", async () => {
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
  const input: ActionInput = { demandId: "demand-1", quantity: 3 };
  const expectedRejection = { code: "DEFINITION_LOOKUP_REJECTED" };
  let definitionLookups = 0;
  let handlerCalls = 0;

  await expect(
    executeAction(context, input, {
      getDefinition: async () => {
        definitionLookups += 1;
        throw expectedRejection;
      },
      handlers: {
        CREATE_OFFER: async () => {
          handlerCalls += 1;
          return { executionId: "unexpected", status: "succeeded" };
        },
      },
    }),
  ).rejects.toBe(expectedRejection);

  expect(definitionLookups).toBe(1);
  expect(handlerCalls).toBe(0);
});

test("executeAction preserves a string rejection from a handler without retrying", async () => {
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
  const input: ActionInput = { demandId: "demand-1", quantity: 3 };
  const expectedRejection = "CREATE_OFFER_HANDLER_REJECTED";
  let definitionLookups = 0;
  let handlerCalls = 0;

  await expect(
    executeAction(context, input, {
      getDefinition: async (actionKey, version) => {
        definitionLookups += 1;
        return { actionKey, version, status: "published" };
      },
      handlers: {
        CREATE_OFFER: async () => {
          handlerCalls += 1;
          throw expectedRejection;
        },
      },
    }),
  ).rejects.toBe(expectedRejection);

  expect(definitionLookups).toBe(1);
  expect(handlerCalls).toBe(1);
});


const invalidActionResults: Array<{ label: string; result: unknown }> = [
  { label: "null", result: null },
  { label: "missing executionId", result: { status: "succeeded" } },
  { label: "blank executionId", result: { executionId: "   ", status: "succeeded" } },
  { label: "unsupported status", result: { executionId: "execution-1", status: "running" } },
];

for (const invalidCase of invalidActionResults) {
  test(`executeAction rejects a handler result with ${invalidCase.label}`, async () => {
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
    const input: ActionInput = { demandId: "demand-1", quantity: 3 };
    let definitionLookups = 0;
    let handlerCalls = 0;

    const handlers: Record<string, ActionHandler> = {
      CREATE_OFFER: async () => {
        handlerCalls += 1;
        return invalidCase.result as ActionResult;
      },
    };

    await expect(
      executeAction(context, input, {
        getDefinition: async (actionKey, version) => {
          definitionLookups += 1;
          return { actionKey, version, status: "published" };
        },
        handlers,
      }),
    ).rejects.toThrow("ACTION_RESULT_INVALID");

    expect(definitionLookups).toBe(1);
    expect(handlerCalls).toBe(1);
  });
}

test("executeAction accepts a valid failed ActionResult", async () => {
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
  const input: ActionInput = { demandId: "demand-1", quantity: 3 };
  const expectedResult: ActionResult = {
    executionId: "execution-failed-1",
    status: "failed",
  };
  let handlerCalls = 0;

  const result = await executeAction(context, input, {
    getDefinition: async (actionKey, version) => ({
      actionKey,
      version,
      status: "published",
    }),
    handlers: {
      CREATE_OFFER: async () => {
        handlerCalls += 1;
        return expectedResult;
      },
    },
  });

  expect(handlerCalls).toBe(1);
  expect(result).toBe(expectedResult);
});
