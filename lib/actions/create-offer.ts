import type { ActionContext, ActionResult, CreateOfferInput } from "./types";

export type CreateOfferDependencies = {
  createOffer: (args: {
    context: ActionContext;
    input: CreateOfferInput;
  }) => Promise<ActionResult>;
};

export async function executeCreateOffer(
  context: ActionContext,
  input: CreateOfferInput,
  dependencies: CreateOfferDependencies,
): Promise<ActionResult> {
  if (context.actionKey !== "CREATE_OFFER") {
    throw new Error("INVALID_ACTION");
  }

  if (!input.demandId || !input.productMasterId) {
    throw new Error("MISSING_OBJECT_REFERENCE");
  }

  if (!Number.isFinite(input.quantity) || input.quantity <= 0) {
    throw new Error("INVALID_QUANTITY");
  }

  if (!Number.isFinite(input.price) || input.price < 0) {
    throw new Error("INVALID_PRICE");
  }

  if (!input.currency?.trim()) {
    throw new Error("INVALID_CURRENCY");
  }

  return dependencies.createOffer({ context, input });
}
