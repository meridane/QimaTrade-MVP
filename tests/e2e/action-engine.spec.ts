import { expect, test } from "@playwright/test";
import { executeAction, type ActionDefinition, type ActionInput } from "../../lib/actions/engine";
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


const inheritedObjectPrototypeHandlerKeys = ["toString", "constructor"] as const;

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
