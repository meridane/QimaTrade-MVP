import { expect, test } from "@playwright/test";
import { executeAction, type ActionInput } from "../../lib/actions/engine";
import type { ActionContext } from "../../lib/actions/types";

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
