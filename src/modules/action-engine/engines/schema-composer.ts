import type { SchemaComposer } from "../ports";
import type { ComposedSchema, SchemaField } from "../domain/contracts/runtime";
import type { ParameterDefinition } from "./parameter-engine";

function isSchemaField(value: unknown): value is SchemaField {
  if (!value || typeof value !== "object") return false;
  const field = value as Partial<SchemaField>;
  return (
    typeof field.key === "string" &&
    (field.kind === "attribute" || field.kind === "parameter") &&
    typeof field.dataType === "string" &&
    typeof field.required === "boolean" &&
    typeof field.editable === "boolean"
  );
}

function isParameterDefinition(value: unknown): value is ParameterDefinition {
  if (!value || typeof value !== "object") return false;
  const parameter = value as Partial<ParameterDefinition>;
  return typeof parameter.key === "string" && typeof parameter.dataType === "string" && typeof parameter.required === "boolean";
}

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
    const attributeFields = input.attributes.filter(isSchemaField);
    const parameterFields = input.parameters.filter(isParameterDefinition).map((parameter) => ({
      key: parameter.key,
      label: parameter.label,
      kind: "parameter" as const,
      dataType: parameter.dataType,
      required: parameter.required,
      editable: parameter.editable ?? true,
      source: "ActionDefinition",
      validation: parameter.validation,
    }));

    return {
      action: { actionKey: input.action.actionKey, version: input.action.version },
      object: input.object,
      context: input.context,
      fields: [...attributeFields, ...parameterFields],
      validation: {
        action: input.action.actionKey,
        version: input.action.version,
      },
      workflow: input.action.workflowId ? { id: input.action.workflowId } : undefined,
    };
  }
}
