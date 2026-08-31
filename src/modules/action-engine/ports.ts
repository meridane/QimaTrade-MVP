import type {
  ActionDefinition,
  ActionRuntimeRequest,
  ResolvedAction,
} from "./domain/contracts/action";
import type {
  ActionCommand,
  ComposedSchema,
  DecisionResult,
  ResolvedActor,
  ResolvedContext,
  ResolvedObject,
  ValidationResult,
} from "./domain/contracts/runtime";

export interface ActionResolver {
  resolve(request: ActionRuntimeRequest): Promise<ResolvedAction>;
}

export interface ObjectResolver {
  resolve(request: ActionRuntimeRequest, action: ResolvedAction): Promise<ResolvedObject>;
}

export interface ActorResolver {
  resolve(request: ActionRuntimeRequest, action: ResolvedAction): Promise<ResolvedActor>;
}

export interface ContextResolver {
  resolve(
    request: ActionRuntimeRequest,
    action: ResolvedAction,
    object: ResolvedObject,
    actor: ResolvedActor,
  ): Promise<ResolvedContext>;
}

export interface DecisionEngine {
  resolve(
    action: ResolvedAction,
    object: ResolvedObject,
    actor: ResolvedActor,
    context: ResolvedContext,
  ): Promise<DecisionResult>;
}

export interface ParameterEngine {
  resolve(
    action: ResolvedAction,
    context: ResolvedContext,
    decision: DecisionResult,
  ): Promise<unknown[]>;
}

export interface AttributeEngine {
  resolve(
    action: ResolvedAction,
    object: ResolvedObject,
    context: ResolvedContext,
    decision: DecisionResult,
  ): Promise<unknown[]>;
}

export interface SchemaComposer {
  compose(input: {
    action: ResolvedAction;
    object: ResolvedObject;
    actor: ResolvedActor;
    context: ResolvedContext;
    decision: DecisionResult;
    parameters: unknown[];
    attributes: unknown[];
  }): Promise<ComposedSchema>;
}

export interface ValidationEngine {
  validate(
    schema: ComposedSchema,
    input: Record<string, unknown>,
    actor: ResolvedActor,
    context: ResolvedContext,
  ): Promise<ValidationResult>;
}

export interface CommandHandler {
  execute(command: ActionCommand): Promise<Record<string, unknown>>;
}

export interface CommandHandlerRegistry {
  resolve(action: ActionDefinition): CommandHandler;
}
