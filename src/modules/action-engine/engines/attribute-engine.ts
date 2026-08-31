import type { ResolvedAction } from "../domain/contracts/action";
import type { DecisionResult, ResolvedContext, ResolvedObject, SchemaField } from "../domain/contracts/runtime";
import type { AttributeEngine } from "../ports";

export interface AttributeDefinition {
  key: string;
  label?: string;
  dataType: string;
  ownerType: string;
  ownerSchema: string;
  required?: boolean;
  editable?: boolean;
  validation?: Record<string, unknown>;
  condition?: (object: ResolvedObject, context: ResolvedContext, decision: DecisionResult) => boolean;
}

export class CanonicalAttributeEngine implements AttributeEngine {
  constructor(private readonly definitions: AttributeDefinition[]) {}

  async resolve(
    action: ResolvedAction,
    object: ResolvedObject,
    context: ResolvedContext,
    decision: DecisionResult,
  ): Promise<SchemaField[]> {
    return this.definitions
      .filter((definition) => definition.ownerType === object.type)
      .filter((definition) => !definition.condition || definition.condition(object, context, decision))
      .map((definition) => ({
        key: definition.key,
        label: definition.label,
        kind: "attribute" as const,
        dataType: definition.dataType,
        required: definition.required ?? false,
        editable: definition.editable ?? false,
        source: definition.ownerSchema,
        validation: definition.validation,
      }));
  }
}
