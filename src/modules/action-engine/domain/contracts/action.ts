export type ActionStatus = "draft" | "published" | "deprecated";

export interface ActionDefinition {
  id: string;
  actionKey: string;
  name: string;
  version: number;
  status: ActionStatus;
  parentActionId?: string | null;
  objectType: string;
  actorType: string;
  contextType: string;
  workflowId?: string | null;
}

export interface ActionRuntimeRequest {
  actionKey: string;
  actionVersion?: number;
  actor: { id: string; type: string };
  organizationId?: string;
  object?: { type: string; id?: string; masterId?: string };
  context?: { type: string; values?: Record<string, unknown> };
  input?: Record<string, unknown>;
  idempotencyKey: string;
  correlationId?: string;
}

export interface ResolvedAction extends ActionDefinition {
  permissions: string[];
}
