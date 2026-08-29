import { NextResponse } from "next/server";
import { createDecisionSession, loadPublishedTree } from "@/lib/decision-tree/server";

export async function POST() {
  try {
    const { tree, treeVersionId } = await loadPublishedTree();
    const session = await createDecisionSession(treeVersionId, tree.entryNodeId);
    return NextResponse.json({ tree, session });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to create decision session";
    const status = message === "UNAUTHENTICATED" ? 401 : message === "TENANT_MEMBERSHIP_REQUIRED" ? 403 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
