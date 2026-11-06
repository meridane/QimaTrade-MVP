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
  expect(result).toEqual(expectedResult);
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

const inheritedActionDefinitionCases: Array<{
  label: string;
  inheritedKey: "actionKey" | "version" | "status";
  definition: ActionDefinition;
}> = [
  {
    label: "actionKey",
    inheritedKey: "actionKey",
    definition: Object.assign(Object.create({ actionKey: "CREATE_OFFER" }), {
      version: 1,
      status: "published",
    }) as ActionDefinition,
  },
  {
    label: "version",
    inheritedKey: "version",
    definition: Object.assign(Object.create({ version: 1 }), {
      actionKey: "CREATE_OFFER",
      status: "published",
    }) as ActionDefinition,
  },
  {
    label: "status",
    inheritedKey: "status",
    definition: Object.assign(Object.create({ status: "published" }), {
      actionKey: "CREATE_OFFER",
      version: 1,
    }) as ActionDefinition,
  },
];

for (const inheritedCase of inheritedActionDefinitionCases) {
  test(`executeAction rejects a definition with inherited ${inheritedCase.inheritedKey}`, async () => {
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

    expect(Object.prototype.hasOwnProperty.call(inheritedCase.definition, inheritedCase.inheritedKey)).toBe(false);

    await expect(
      executeAction(context, input, {
        getDefinition: async () => {
          definitionLookups += 1;
          return inheritedCase.definition;
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

test("executeAction accepts an own-field ActionDefinition with a null prototype", async () => {
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
  const definition = Object.assign(Object.create(null), {
    actionKey: "CREATE_OFFER",
    version: 1,
    status: "published",
  }) as ActionDefinition;

  const result = await executeAction(context, input, {
    getDefinition: async () => definition,
    handlers: {
      CREATE_OFFER: async () => ({
        executionId: "execution-1",
        status: "succeeded",
      }),
    },
  });

  expect(result).toMatchObject({ executionId: "execution-1", status: "succeeded" });
});


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
  {
    label: "non-string objectId",
    result: { executionId: "execution-1", status: "succeeded", objectId: 42 },
  },
  {
    label: "null result payload",
    result: { executionId: "execution-1", status: "succeeded", result: null },
  },
  {
    label: "array result payload",
    result: { executionId: "execution-1", status: "succeeded", result: [] },
  },
  {
    label: "primitive result payload",
    result: { executionId: "execution-1", status: "succeeded", result: "not-an-object" },
  },
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

const inheritedOptionalActionResultCases: Array<{ label: string; prototype: object }> = [
  { label: "objectId", prototype: { objectId: 42 } },
  { label: "result", prototype: { result: "not-an-object" } },
];

for (const invalidCase of inheritedOptionalActionResultCases) {
  test(`executeAction rejects an ActionResult with inherited ${invalidCase.label}`, async () => {
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
    const invalidResult = Object.assign(
      Object.create(invalidCase.prototype),
      {
        executionId: "execution-1",
        status: "succeeded",
      },
    ) as ActionResult;
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
            return invalidResult;
          },
        },
      }),
    ).rejects.toThrow("ACTION_RESULT_INVALID");

    expect(definitionLookups).toBe(1);
    expect(handlerCalls).toBe(1);
  });
}

test("executeAction accepts a valid null-prototype ActionResult", async () => {
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
  const expectedResult = Object.assign(Object.create(null), {
    executionId: "execution-null-prototype",
    status: "succeeded",
    objectId: null,
    result: { source: "regression-test" },
  }) as ActionResult;
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
  expect(result).toEqual(expectedResult);
  expect(result).not.toBe(expectedResult);
  expect(Object.getPrototypeOf(result)).toBe(Object.prototype);
  expect(result.objectId).toBeNull();
  expect(result.result).toEqual({ source: "regression-test" });
});


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
    objectId: null,
    result: {},
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
  expect(result).toEqual(expectedResult);
});


const accessorBackedActionResultFields: Array<keyof ActionResult> = [
  "executionId",
  "status",
  "objectId",
  "result",
];

for (const field of accessorBackedActionResultFields) {
  test(`executeAction rejects an accessor-backed ActionResult ${field} without invoking its getter`, async () => {
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
    let getterCalls = 0;
    const invalidResult = {
      executionId: "execution-accessor",
      status: "succeeded" as const,
      objectId: null,
      result: { source: "accessor-regression" },
    };

    Object.defineProperty(invalidResult, field, {
      configurable: true,
      enumerable: true,
      get: () => {
        getterCalls += 1;
        throw new Error(`ACTION_RESULT_${String(field).toUpperCase()}_GETTER_INVOKED`);
      },
    });

    const handlerResult = Promise.resolve(invalidResult as ActionResult);
    await expect(
      executeAction(context, input, {
        getDefinition: async (actionKey, version) => {
          definitionLookups += 1;
          return { actionKey, version, status: "published" };
        },
        handlers: {
          CREATE_OFFER: () => {
            handlerCalls += 1;
            return handlerResult;
          },
        },
      }),
    ).rejects.toThrow("ACTION_RESULT_INVALID");

    expect(definitionLookups).toBe(1);
    expect(handlerCalls).toBe(1);
    expect(getterCalls).toBe(0);
  });
}

test("executeAction snapshots a Proxy ActionResult without invoking its get trap", async () => {
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
  const target: ActionResult & { objectType: string } = {
    executionId: "execution-proxy-result",
    status: "succeeded",
    objectId: "offer-1",
    objectType: "Offer",
    result: { source: "proxy-regression" },
  };
  let getTrapCalls = 0;
  let handlerCalls = 0;
  const proxy = new Proxy(target, {
    get(_object, property) {
      // Promise resolution probes "then" before the engine receives the value.
      if (property === "then") return undefined;
      getTrapCalls += 1;
      throw new Error("ACTION_RESULT_GET_TRAP_INVOKED");
    },
  });
  const handlerResult = Promise.resolve(proxy);

  const result = await executeAction(context, input, {
    getDefinition: async (actionKey, version) => ({
      actionKey,
      version,
      status: "published",
    }),
    handlers: {
      CREATE_OFFER: () => {
        handlerCalls += 1;
        return handlerResult;
      },
    },
  });

  // Capture trap activity before assertion helpers inspect either value.
  const getTrapCallsAtReturn = getTrapCalls;
  const resultIsDetached = !Object.is(result, proxy);
  expect(getTrapCallsAtReturn).toBe(0);
  expect(resultIsDetached).toBe(true);
  expect(result).toEqual(target);
  expect(result.objectId).toBe("offer-1");
  expect((result as ActionResult & { objectType: string }).objectType).toBe("Offer");
  expect(handlerCalls).toBe(1);
});

test("executeAction rejects a revoked Proxy ActionResult without leaking reflection errors", async () => {
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
  const target: ActionResult = {
    executionId: "execution-revoked-result",
    status: "succeeded",
  };
  const revocable = Proxy.revocable(target, {});
  // Fulfill while live, then revoke before executeAction inspects the result.
  const handlerResult = Promise.resolve(revocable.proxy);
  revocable.revoke();
  let handlerCalls = 0;

  await expect(
    executeAction(context, input, {
      getDefinition: async (actionKey, version) => ({
        actionKey,
        version,
        status: "published",
      }),
      handlers: {
        CREATE_OFFER: () => {
          handlerCalls += 1;
          return handlerResult;
        },
      },
    }),
  ).rejects.toThrow("ACTION_RESULT_INVALID");

  expect(handlerCalls).toBe(1);
});


test("executeAction accepts the CREATE_OFFER SQL result shape without optional result", async () => {
  const context: ActionContext = {
    userId: "user-1",
    tenantId: "tenant-1",
    actionKey: "CREATE_OFFER",
    actionVersion: 1,
    objectType: "Demand",
    objectId: "demand-1",
    correlationId: "correlation-1",
    idempotencyKey: "idempotency-1",
  };
  const input: ActionInput = { demandId: "demand-1" };
  const expectedResult: ActionResult & { objectType: string } = {
    executionId: "10000000-0000-4000-8000-000000000001",
    status: "succeeded",
    objectType: "Offer",
    objectId: "70000000-0000-4000-8000-000000000001",
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
  expect(result).toEqual(expectedResult);
  expect(Object.prototype.hasOwnProperty.call(result, "result")).toBe(false);
});


const accessorBackedActionDefinitionFields: Array<keyof ActionDefinition> = [
  "actionKey",
  "version",
  "status",
];

for (const field of accessorBackedActionDefinitionFields) {
  test(`executeAction rejects an accessor-backed ActionDefinition ${field} without invoking its getter`, async () => {
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
    let getterCalls = 0;
    let handlerCalls = 0;
    const definition = {
      actionKey: "CREATE_OFFER",
      version: 1,
      status: "published",
    } as ActionDefinition;

    Object.defineProperty(definition, field, {
      configurable: true,
      enumerable: true,
      get: () => {
        getterCalls += 1;
        throw new Error(`ACTION_DEFINITION_${field.toUpperCase()}_GETTER_INVOKED`);
      },
    });

    await expect(
      executeAction(context, input, {
        getDefinition: async () => {
          definitionLookups += 1;
          return definition;
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
    expect(getterCalls).toBe(0);
    expect(handlerCalls).toBe(0);
  });
}


test("executeAction rejects an ActionDefinition when a proxy descriptor trap throws", async () => {
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
  const target: ActionDefinition = {
    actionKey: "CREATE_OFFER",
    version: 1,
    status: "published",
  };
  let definitionLookups = 0;
  let descriptorTrapCalls = 0;
  let handlerCalls = 0;
  const definition = new Proxy(target, {
    getOwnPropertyDescriptor(object, property) {
      if (property === "actionKey") {
        descriptorTrapCalls += 1;
        throw new Error("ACTION_DEFINITION_DESCRIPTOR_TRAP_THROWN");
      }
      return Reflect.getOwnPropertyDescriptor(object, property);
    },
  });

  await expect(
    executeAction(context, input, {
      getDefinition: async () => {
        definitionLookups += 1;
        return definition;
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
  expect(descriptorTrapCalls).toBe(1);
  expect(handlerCalls).toBe(0);
});

test("executeAction validates a proxy ActionDefinition without invoking its get trap", async () => {
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
  const target: ActionDefinition = {
    actionKey: "CREATE_OFFER",
    version: 1,
    status: "published",
  };
  let getTrapCalls = 0;
  let handlerCalls = 0;
  const definition = new Proxy(target, {
    get(_object, property) {
      // Promise resolution probes "then"; keep that protocol lookup harmless.
      if (property === "then") return undefined;
      getTrapCalls += 1;
      throw new Error("ACTION_DEFINITION_GET_TRAP_INVOKED");
    },
  });
  const expectedResult: ActionResult = {
    executionId: "execution-proxy-definition",
    status: "succeeded",
  };

  const result = await executeAction(context, input, {
    getDefinition: async () => definition,
    handlers: {
      CREATE_OFFER: async () => {
        handlerCalls += 1;
        return expectedResult;
      },
    },
  });

  expect(result).toEqual(expectedResult);
  expect(getTrapCalls).toBe(0);
  expect(handlerCalls).toBe(1);
});

test("executeAction normalizes a revoked proxy ActionDefinition as unpublished", async () => {
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
  const revocableTarget: ActionDefinition = {
    actionKey: "CREATE_OFFER",
    version: 1,
    status: "published",
  };
  const revocable = Proxy.revocable(revocableTarget, {});
  // Fulfill while the proxy is live so Promise's "then" probe does not itself
  // throw; revoke before executeAction resumes and inspects the value.
  const revokedDefinition = Promise.resolve(revocable.proxy);
  revocable.revoke();
  let handlerCalls = 0;

  await expect(
    executeAction(context, input, {
      getDefinition: () => revokedDefinition,
      handlers: {
        CREATE_OFFER: async () => {
          handlerCalls += 1;
          return { executionId: "unexpected", status: "succeeded" };
        },
      },
    }),
  ).rejects.toThrow("ACTION_NOT_PUBLISHED");

  expect(handlerCalls).toBe(0);
});


test("executeAction rejects an accessor-backed handler registry entry without invoking its getter", async () => {
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
  let getterCalls = 0;
  let handlerCalls = 0;
  const handlers = {} as Record<string, ActionHandler>;

  Object.defineProperty(handlers, "CREATE_OFFER", {
    configurable: true,
    enumerable: true,
    get: () => {
      getterCalls += 1;
      return async () => {
        handlerCalls += 1;
        return { executionId: "unexpected", status: "succeeded" as const };
      };
    },
  });

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
  expect(getterCalls).toBe(0);
  expect(handlerCalls).toBe(0);
});

test("executeAction resolves a Proxy handler registry without invoking its get trap", async () => {
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
  let getTrapCalls = 0;
  let handlerCalls = 0;
  const target: Record<string, ActionHandler> = {
    CREATE_OFFER: async () => {
      handlerCalls += 1;
      return { executionId: "execution-proxy-registry", status: "succeeded" };
    },
  };
  const handlers = new Proxy(target, {
    get() {
      getTrapCalls += 1;
      throw new Error("ACTION_HANDLER_REGISTRY_GET_TRAP_INVOKED");
    },
  });

  const result = await executeAction(context, input, {
    getDefinition: async (actionKey, version) => ({
      actionKey,
      version,
      status: "published",
    }),
    handlers,
  });

  const getTrapCallsAtReturn = getTrapCalls;
  expect(getTrapCallsAtReturn).toBe(0);
  expect(handlerCalls).toBe(1);
  expect(result).toMatchObject({
    executionId: "execution-proxy-registry",
    status: "succeeded",
  });
});

test("executeAction rejects a handler registry when its descriptor trap throws", async () => {
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
  let descriptorTrapCalls = 0;
  let handlerCalls = 0;
  const target: Record<string, ActionHandler> = {
    CREATE_OFFER: async () => {
      handlerCalls += 1;
      return { executionId: "unexpected", status: "succeeded" };
    },
  };
  const handlers = new Proxy(target, {
    getOwnPropertyDescriptor(object, property) {
      if (property === "CREATE_OFFER") {
        descriptorTrapCalls += 1;
        throw new Error("ACTION_HANDLER_REGISTRY_DESCRIPTOR_TRAP_THROWN");
      }
      return Reflect.getOwnPropertyDescriptor(object, property);
    },
  });

  await expect(
    executeAction(context, input, {
      getDefinition: async (actionKey, version) => ({
        actionKey,
        version,
        status: "published",
      }),
      handlers,
    }),
  ).rejects.toThrow("ACTION_HANDLER_NOT_FOUND");

  expect(descriptorTrapCalls).toBe(1);
  expect(handlerCalls).toBe(0);
});

test("executeAction rejects a revoked Proxy handler registry without leaking reflection errors", async () => {
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
  let handlerCalls = 0;
  const revocable = Proxy.revocable(
    {
      CREATE_OFFER: async () => {
        handlerCalls += 1;
        return { executionId: "unexpected", status: "succeeded" as const };
      },
    },
    {},
  );
  revocable.revoke();

  await expect(
    executeAction(context, input, {
      getDefinition: async (actionKey, version) => ({
        actionKey,
        version,
        status: "published",
      }),
      handlers: revocable.proxy as unknown as Record<string, ActionHandler>,
    }),
  ).rejects.toThrow("ACTION_HANDLER_NOT_FOUND");

  expect(handlerCalls).toBe(0);
});


const actionResultReflectionTrapScenarios: Array<{
  name: string;
  createProxy: (target: ActionResult, onTrap: () => void) => ActionResult;
}> = [
  {
    name: "has trap",
    createProxy: (target, onTrap) =>
      new Proxy(target, {
        has(object, property) {
          if (property === "objectId") {
            onTrap();
            throw new Error("ACTION_RESULT_HAS_TRAP_THROWN");
          }
          return Reflect.has(object, property);
        },
      }),
  },
  {
    name: "ownKeys trap",
    createProxy: (target, onTrap) =>
      new Proxy(target, {
        ownKeys() {
          onTrap();
          throw new Error("ACTION_RESULT_OWN_KEYS_TRAP_THROWN");
        },
      }),
  },
  {
    name: "getOwnPropertyDescriptor trap",
    createProxy: (target, onTrap) =>
      new Proxy(target, {
        getOwnPropertyDescriptor(object, property) {
          if (property === "executionId") {
            onTrap();
            throw new Error("ACTION_RESULT_DESCRIPTOR_TRAP_THROWN");
          }
          return Reflect.getOwnPropertyDescriptor(object, property);
        },
      }),
  },
];

for (const scenario of actionResultReflectionTrapScenarios) {
  test(`executeAction normalizes ActionResult ${scenario.name} failures`, async () => {
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
    const target: ActionResult = {
      executionId: "execution-reflection-trap",
      status: "succeeded",
      objectId: "offer-1",
    };
    let definitionLookups = 0;
    let reflectionTrapCalls = 0;
    let handlerCalls = 0;
    const proxy = scenario.createProxy(target, () => {
      reflectionTrapCalls += 1;
    });
    // Resolve while the proxy is live; Promise's thenable probe uses the
    // ordinary get path and does not trigger the reflection traps under test.
    const handlerResult = Promise.resolve(proxy);

    await expect(
      executeAction(context, input, {
        getDefinition: async (actionKey, version) => {
          definitionLookups += 1;
          return { actionKey, version, status: "published" };
        },
        handlers: {
          CREATE_OFFER: async () => {
            handlerCalls += 1;
            return handlerResult;
          },
        },
      }),
    ).rejects.toThrow("ACTION_RESULT_INVALID");

    expect(definitionLookups).toBe(1);
    expect(handlerCalls).toBe(1);
    expect(reflectionTrapCalls).toBe(1);
  });
}


test("executeAction awaits a custom handler thenable before normalizing its resolved result", async () => {
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
  const expectedResult: ActionResult = {
    executionId: "execution-custom-thenable",
    status: "succeeded",
    objectId: "offer-thenable",
  };
  let definitionLookups = 0;
  let handlerCalls = 0;
  let thenCalls = 0;
  const thenable = {
    then(resolve: (value: ActionResult) => void) {
      thenCalls += 1;
      resolve(expectedResult);
    },
  };
  const handler = (() => {
    handlerCalls += 1;
    return thenable as unknown as Promise<ActionResult>;
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
  expect(thenCalls).toBe(1);
  expect(result).toEqual(expectedResult);
  expect(result).not.toBe(expectedResult);
});

test("executeAction validates the ActionResult resolved by a custom handler thenable", async () => {
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
  const invalidResult = {
    executionId: "execution-invalid-thenable",
    status: "running",
  } as unknown as ActionResult;
  let definitionLookups = 0;
  let handlerCalls = 0;
  let thenCalls = 0;
  const thenable = {
    then(resolve: (value: ActionResult) => void) {
      thenCalls += 1;
      resolve(invalidResult);
    },
  };
  const handler = (() => {
    handlerCalls += 1;
    return thenable as unknown as Promise<ActionResult>;
  }) as ActionHandler;

  await expect(
    executeAction(context, input, {
      getDefinition: async (actionKey, version) => {
        definitionLookups += 1;
        return { actionKey, version, status: "published" };
      },
      handlers: { CREATE_OFFER: handler },
    }),
  ).rejects.toThrow("ACTION_RESULT_INVALID");

  expect(definitionLookups).toBe(1);
  expect(handlerCalls).toBe(1);
  expect(thenCalls).toBe(1);
});

test("executeAction preserves a throwing handler then accessor without retrying", async () => {
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
  const expectedError = new Error("HANDLER_THENABLE_GETTER_THROWN");
  let definitionLookups = 0;
  let handlerCalls = 0;
  let thenGetterCalls = 0;
  const thenable = Object.defineProperty({}, "then", {
    configurable: true,
    get: () => {
      thenGetterCalls += 1;
      throw expectedError;
    },
  });
  const handler = (() => {
    handlerCalls += 1;
    return thenable as unknown as Promise<ActionResult>;
  }) as ActionHandler;

  await expect(
    executeAction(context, input, {
      getDefinition: async (actionKey, version) => {
        definitionLookups += 1;
        return { actionKey, version, status: "published" };
      },
      handlers: { CREATE_OFFER: handler },
    }),
  ).rejects.toBe(expectedError);

  expect(definitionLookups).toBe(1);
  expect(handlerCalls).toBe(1);
  expect(thenGetterCalls).toBe(1);
});


test("executeAction preserves explicitly undefined optional ActionResult fields", async () => {
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
  const expectedResult = {
    executionId: "execution-undefined-optionals",
    status: "succeeded" as const,
    objectId: undefined,
    result: undefined,
  } as unknown as ActionResult;
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
  expect(result).not.toBe(expectedResult);
  expect(Object.prototype.hasOwnProperty.call(result, "objectId")).toBe(true);
  expect(Object.prototype.hasOwnProperty.call(result, "result")).toBe(true);
  expect(Object.getOwnPropertyDescriptor(result, "objectId")?.value).toBeUndefined();
  expect(Object.getOwnPropertyDescriptor(result, "result")?.value).toBeUndefined();
});

test("executeAction preserves non-enumerable optional fields and extra SQL result metadata", async () => {
  const context: ActionContext = {
    userId: "user-1",
    tenantId: "tenant-1",
    actionKey: "CREATE_OFFER",
    actionVersion: 1,
    objectType: "Demand",
    objectId: "demand-1",
    correlationId: "correlation-1",
    idempotencyKey: "idempotency-1",
  };
  const input: ActionInput = { demandId: "demand-1" };
  const expectedNestedResult = {
    offerId: "offer-non-enumerable",
    source: "CREATE_OFFER",
  };
  const expectedResult: ActionResult & { objectType: string } = {
    executionId: "execution-non-enumerable-optionals",
    status: "succeeded",
    objectType: "Offer",
  };
  Object.defineProperties(expectedResult, {
    objectId: {
      configurable: false,
      enumerable: false,
      value: "offer-non-enumerable",
      writable: false,
    },
    result: {
      configurable: false,
      enumerable: false,
      value: expectedNestedResult,
      writable: false,
    },
  });
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
  expect(result).not.toBe(expectedResult);
  expect(result.objectId).toBe("offer-non-enumerable");
  expect(result.result).toEqual(expectedNestedResult);
  expect((result as ActionResult & { objectType: string }).objectType).toBe("Offer");
  expect(Object.getOwnPropertyDescriptor(result, "objectId")).toMatchObject({
    enumerable: false,
    value: "offer-non-enumerable",
  });
  expect(Object.getOwnPropertyDescriptor(result, "result")).toMatchObject({
    enumerable: false,
    value: expectedNestedResult,
  });
  expect(Object.keys(result)).toEqual(["executionId", "status", "objectType"]);
});


test("executeAction preserves symbol-keyed own data metadata during ActionResult normalization", async () => {
  const context: ActionContext = {
    userId: "user-1",
    tenantId: "tenant-1",
    actionKey: "CREATE_OFFER",
    actionVersion: 1,
    objectType: "Demand",
    objectId: "demand-1",
    correlationId: "correlation-1",
    idempotencyKey: "idempotency-1",
  };
  const input: ActionInput = { demandId: "demand-1" };
  const metadataKey = Symbol("resultMetadata");
  const expectedResult: ActionResult & { [metadataKey]: string } = {
    executionId: "execution-symbol-metadata",
    status: "succeeded",
    result: { offerId: "offer-symbol-metadata" },
    [metadataKey]: "source:CREATE_OFFER",
  };
  Object.defineProperty(expectedResult, metadataKey, {
    configurable: false,
    enumerable: false,
    value: "source:CREATE_OFFER",
    writable: false,
  });
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
  expect(result).not.toBe(expectedResult);
  expect(Object.getOwnPropertySymbols(result)).toContain(metadataKey);
  expect(Object.getOwnPropertyDescriptor(result, metadataKey)).toMatchObject({
    enumerable: false,
    value: "source:CREATE_OFFER",
  });
});

test("executeAction keeps nested ActionResult payload references during shallow normalization", async () => {
  const context: ActionContext = {
    userId: "user-1",
    tenantId: "tenant-1",
    actionKey: "CREATE_OFFER",
    actionVersion: 1,
    objectType: "Demand",
    objectId: "demand-1",
    correlationId: "correlation-1",
    idempotencyKey: "idempotency-1",
  };
  const input: ActionInput = { demandId: "demand-1" };
  const nestedAudit = { source: "CREATE_OFFER", revision: 1 };
  const nestedPayload = {
    offerId: "offer-shallow-copy",
    audit: nestedAudit,
  };
  const expectedResult: ActionResult = {
    executionId: "execution-shallow-payload",
    status: "succeeded",
    result: nestedPayload,
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
  expect(result).not.toBe(expectedResult);
  expect(result.result).toBe(nestedPayload);
  expect((result.result as typeof nestedPayload).audit).toBe(nestedAudit);
});


test("executeAction copies an own __proto__ data field without changing the normalized result prototype", async () => {
  const context: ActionContext = {
    userId: "user-1",
    tenantId: "tenant-1",
    actionKey: "CREATE_OFFER",
    actionVersion: 1,
    objectType: "Demand",
    objectId: "demand-1",
    correlationId: "correlation-1",
    idempotencyKey: "idempotency-1",
  };
  const input: ActionInput = { demandId: "demand-1" };
  const protoMetadata = { marker: "ordinary-own-data" };
  const expectedResult: ActionResult = {
    executionId: "execution-proto-key",
    status: "succeeded",
  };
  Object.defineProperty(expectedResult, "__proto__", {
    configurable: false,
    enumerable: true,
    value: protoMetadata,
    writable: false,
  });
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
  expect(result).not.toBe(expectedResult);
  expect(Object.getPrototypeOf(result)).toBe(Object.prototype);
  expect(Object.prototype.hasOwnProperty.call(result, "__proto__")).toBe(true);
  expect(Object.getOwnPropertyDescriptor(result, "__proto__")).toMatchObject({
    enumerable: true,
    value: protoMetadata,
  });
  expect(Object.getPrototypeOf(result)).not.toBe(protoMetadata);
});
