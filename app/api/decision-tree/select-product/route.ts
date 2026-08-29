import { NextRequest, NextResponse } from "next/server";
import { selectProductMaster } from "@/lib/decision-tree/server";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const sessionId = typeof body.sessionId === "string" ? body.sessionId : "";
    const productMasterId = typeof body.productMasterId === "string" ? body.productMasterId : "";

    if (!sessionId || !productMasterId) {
      return NextResponse.json({ error: "sessionId and productMasterId are required" }, { status: 400 });
    }

    const result = await selectProductMaster(sessionId, productMasterId);
    return NextResponse.json(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to select product master";
    const status =
      message === "UNAUTHENTICATED" ? 401 :
      message === "TENANT_MEMBERSHIP_REQUIRED" ? 403 :
      message === "SESSION_NOT_FOUND" || message === "PRODUCT_MASTER_NOT_FOUND" || message === "PRODUCT_MASTER_NOT_IN_CLASSIFICATION" ? 400 :
      500;
    return NextResponse.json({ error: message }, { status });
  }
}
