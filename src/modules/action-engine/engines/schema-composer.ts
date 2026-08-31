import type { SchemaComposer } from "../ports";
import type { ComposedSchema } from "../domain/contracts/runtime";

export class DefaultSchemaComposer implements SchemaComposer {
  async compose(input: {
    action: Parameters<SchemaComposer["compose"]>[0]["action"];
    object: Parameters<SchemaComposer["compose"]>[0]["object"];
    actor: Parameters<SchemaComposer["compose"]>[0]["actor"];
    context: Parameters<SchemaComposer["compose"]>[0]["context"];
    decision: Parameters<SchemaComposer["compose"]>[0]["decision"];
    parameters: unknown[];
    attributes: unknown[];
  }): Promise<ComposedSchema> {
    return {
      action: { actionKey: input.action.actionKey, version: input.action.version },
      object: input.object,
      context: input.context,
      fields: [],
      validation: {},
      workflow: input.action.workflowId ? { id: input.action.workflowId } : undefined,
    };
  }
}
