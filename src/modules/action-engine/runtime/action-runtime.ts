import type { ActionRuntimeRequest, ResolvedAction } from "../domain/contracts/action";
import type {
  ActionRuntimeResult,
  ResolvedActor,
  ResolvedContext,
  ResolvedObject,
} from "../domain/contracts/runtime";
import type {
  ActionResolver,
  ActorResolver,
  AttributeEngine,
  ContextResolver,
  DecisionEngine,
  ObjectResolver,
  ParameterEngine,
  SchemaComposer,
  ValidationEngine,
} from "../ports";

export interface ActionRuntimeDependencies {
  actionResolver: ActionResolver;
  objectResolver: ObjectResolver;
  actorResolver: ActorResolver;
  contextResolver: ContextResolver;
  decisionEngine: DecisionEngine;
  parameterEngine: ParameterEngine;
  attributeEngine: AttributeEngine;
  schemaComposer: SchemaComposer;
  validationEngine: ValidationEngine;
}

export class ActionRuntime {
  constructor(private readonly deps: ActionRuntimeDependencies) {}

  async prepareSchema(request: ActionRuntimeRequest): Promise<ActionRuntimeResult> {
    const action = await this.deps.actionResolver.resolve(request);
    const object = await this.deps.objectResolver.resolve(request, action);
    const actor = await this.deps.actorResolver.resolve(request, action);
    const context = await this.deps.contextResolver.resolve(request, action, object, actor);
    const decision = await this.deps.decisionEngine.resolve(action, object, actor, context);
    const parameters = await this.deps.parameterEngine.resolve(action, context, decision);
    const attributes = await this.deps.attributeEngine.resolve(action, object, context, decision);
    const schema = await this.deps.schemaComposer.compose({
      action,
      object,
      actor,
      context,
      decision,
      parameters,
      attributes,
    });

    return {
      success: true,
      status: "SCHEMA_READY",
      action,
      object,
      schema,
      decision,
    };
  }
}
