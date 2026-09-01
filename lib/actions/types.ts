export type ActionPrimitive = string | number | boolean | null;

export type ActionStatus = "pending" | "running" | "succeeded" | "failed";

export type CreateOfferInput = {
  demandId: string;
  productMasterId: string;
  quantity: number;
  price: number;
  currency: string;
  pricingModel?: string | null;
  conditions?: string | null;
  market?: string | null;
  geography?: string | null;
};

export type ActionContext = {
  userId: string;
  tenantId: string;
  actionKey: string;
  actionVersion: number;
  objectType: string;
  objectId?: string | null;
  correlationId: string;
  idempotencyKey: string;
};

export type ActionExecution = {
  id: string;
  actionId: string;
  actionVersion: number;
  actorId: string;
  objectType: string;
  objectId: string | null;
  correlationId: string;
  idempotencyKey: string;
  status: ActionStatus;
  input: Record<string, ActionPrimitive | Record<string, unknown> | ActionPrimitive[]>;
  result: Record<string, unknown> | null;
};

export type ActionResult = {
  executionId: string;
  status: Exclude<ActionStatus, "pending" | "running">;
  objectId?: string | null;
  result?: Record<string, unknown>;
};
