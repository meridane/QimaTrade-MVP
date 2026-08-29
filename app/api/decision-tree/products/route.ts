import { NextRequest, NextResponse } from "next/server";
import { getProductMastersForNode } from "@/lib/decision-tree/server";

export async function GET(request: NextRequest) {
  try {
    const nodeId = request.nextUrl.searchParams.get("nodeId") ?? "";
    if (!nodeId) {
      return NextResponse.json({ error: "nodeId is required" }, { status: 400 });
    }

    const productMasters = await getProductMastersForNode(nodeId);
    return NextResponse.json({ productMasters });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to load product masters";
    const status = message === "UNAUTHENTICATED" ? 401 : message === "TENANT_MEMBERSHIP_REQUIRED" ? 403 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
