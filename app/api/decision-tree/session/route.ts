import { NextResponse } from "next/server";
import { createDecisionSession, getCurrentUser, getTenantForUser, loadPublishedTree } from "@/lib/decision-tree/server";

export async function POST() {
  try {
    const user = await getCurrentUser();
    if (!user) return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });
    const membership = await getTenantForUser(user.id);
    if (!membership) return NextResponse.json({ error: "TENANT_MEMBERSHIP_REQUIRED" }, { status: 403 });

    const { tree, treeVersionId } = await loadPublishedTree("product-classification", { userId: user.id, tenantId: membership.tenant_id });
    const session = await createDecisionSession(treeVersionId, tree.entryNodeId, { userId: user.id, tenantId: membership.tenant_id });
    return NextResponse.json({ tree, session });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to create decision session";
    const status = message === "UNAUTHENTICATED" ? 401 : message === "TENANT_MEMBERSHIP_REQUIRED" ? 403 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
