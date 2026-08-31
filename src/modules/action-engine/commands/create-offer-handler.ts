import type { ActionCommand } from "../domain/contracts/runtime";
import type { CommandHandler } from "../ports";

export interface OfferMutationPort {
  create(input: {
    actorId: string;
    productMasterId: string;
    payload: Record<string, unknown>;
    correlationId: string;
  }): Promise<{ offerId: string; state: string }>;
}

export class CreateOfferHandler implements CommandHandler {
  constructor(private readonly mutation: OfferMutationPort) {}

  async execute(command: ActionCommand): Promise<Record<string, unknown>> {
    if (command.actionKey !== "CREATE_OFFER") {
      throw new Error("CreateOfferHandler received an unsupported action.");
    }
    if (command.objectType !== "ProductMaster" || !command.objectId) {
      throw new Error("CREATE_OFFER requires a resolved ProductMaster object.");
    }

    return this.mutation.create({
      actorId: command.actorId,
      productMasterId: command.objectId,
      payload: command.payload,
      correlationId: command.correlationId,
    });
  }
}
