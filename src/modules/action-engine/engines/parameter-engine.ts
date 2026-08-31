import type { ResolvedAction } from "../domain/contracts/action";
import type { DecisionResult, ResolvedContext } from "../domain/contracts/runtime";
import type { ParameterEngine } from "../ports";

export interface ParameterDefinition {
  key: string;
  label?: string;
  dataType: string;
  required: boolean;
  editable?: boolean;
  defaultValue?: unknown;
  validation?: Record<string, unknown>;
  condition?: (context: ResolvedContext, decision: DecisionResult) => boolean;
}

export class ConfiguredParameterEngine implements ParameterEngine {
  constructor(private readonly definitions: ParameterDefinition[]) {}

  async resolve(
    _action: ResolvedAction,
    context: ResolvedContext,
    decision: DecisionResult,
  ): Promise<ParameterDefinition[]> {
    return this.definitions.filter(
      (definition) => !definition.condition || definition.condition(context, decision),
    );
  }
}
