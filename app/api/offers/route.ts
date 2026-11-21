import { NextRequest } from "next/server";
import { createLegacyOfferHandler } from "@/lib/offers/create-legacy-offer";

const handleLegacyOffer = createLegacyOfferHandler();

export async function POST(request: NextRequest) {
  return handleLegacyOffer(request);
}
