import type { ResolvedAction } from "./action";

export interface ResolvedObject {
  type: string;
  id?: string;
  masterId?: string;
  data?: Record<string, unknown>;
}

export interface ResolvedActor {
  id: string;
  type: string;
  permissions: string[];
}

export interface ResolvedContext {
  type: string;
  values: Record<string, unknown>;
}

export type DecisionResult =
  | { type: "ASK_QUESTION"; nodeId: string; schema?: unknown }
  | { type: "REQUEST_EVIDENCE"; requirements: unknown[] }
  | { type: "REQUIRE_VERIFICATION"; requirements: unknown[] }
  | { type: "REQUIRE_REVIEW"; reason: string }
  | { type: "PROPOSE_DECISION"; result: Record<string, unknown> }
  | { type: "BLOCKED_BY_RULE"; reason: string }
  | { type: "COMPLETE"; result: Record<string, unknown> };

export interface SchemaField {
  key: string;
  label?: string;
  kind: "attribute" | "parameter";
  dataType: string;
  required: boolean;
  editable: boolean;
  source?: string;
  validation?: Record<string, unknown>;
}

export interface ComposedSchema {
  action: Pick<ResolvedAction, "actionKey" | "version">;
  object: ResolvedObject;
  context: ResolvedContext;
  fields: SchemaField[];
  validation: Record<string, unknown>;
  workflow?: { id: string; version?: number };
}

export interface ValidationError {
  field?: string;
  code: string;
  message: string;
}

export type ValidationResult =
  | { valid: true }
  | { valid: false; errors: ValidationError[] };

export interface ActionCommand {
  commandId: string;
  actionKey: string;
  actionVersion: number;
  actorId: string;
  objectType: string;
  objectId?: string;
  payload: Record<string, unknown>;
  idempotencyKey: string;
  correlationId: string;
}

export type RuntimeStatus =
  | "SCHEMA_READY"
  | "WAITING_FOR_INPUT"
  | "WAITING_FOR_VERIFICATION"
  | "WAITING_FOR_REVIEW"
  | "COMPLETED"
  | "BLOCKED"
  | "FAILED";

export interface ActionRuntimeResult {
  success: boolean;
  status: RuntimeStatus;
  action: Pick<ResolvedAction, "actionKey" | "version">;
  object: ResolvedObject;
  schema?: ComposedSchema;
  decision?: DecisionResult;
  validation?: ValidationResult;
  command?: ActionCommand;
  workflow?: Record<string, unknown>;
  event?: Record<string, unknown>;
}
