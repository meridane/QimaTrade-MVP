import { NextRequest, NextResponse } from "next/server";
import { getProductMastersForNode, loadSession, submitAnswer } from "@/lib/decision-tree/server";
import { loadTreeForSession } from "@/lib/decision-tree/session-tree";

function badRequest(message: string) {
  return NextResponse.json({ error: message }, { status: 400 });
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const sessionId = typeof body.sessionId === "string" ? body.sessionId : "";
    const nodeId = typeof body.nodeId === "string" ? body.nodeId : "";
    const field = body.field === "category" || body.field === "subcategory" ? body.field : "";
    const value = typeof body.value === "string" ? body.value : "";
    const expectedRevision = Number.isInteger(body.expectedRevision) ? body.expectedRevision : -1;
    const clientCommandId = typeof body.clientCommandId === "string" ? body.clientCommandId : "";

    if (!sessionId || !nodeId || !field || !value || expectedRevision < 0 || !clientCommandId) {
      return badRequest("Invalid answer command");
    }

    // IMPORTANT: resolve the exact tree/version from the session. The previous
    // implementation always loaded product-classification, which made the
    // second tree unable to resolve its next node.
    const session = await loadSession(sessionId);
    const { tree } = await loadTreeForSession(sessionId);

    if (session.revision !== expectedRevision || session.currentNodeId !== nodeId) {
      return NextResponse.json({ error: "CONCURRENCY_CONFLICT" }, { status: 409 });
    }

    const persisted = await submitAnswer({
      sessionId,
      expectedRevision,
      nodeId,
      field,
      value,
      clientCommandId,
    });

    const nextNode = tree.nodes.find((node) => node.id === persisted.currentNodeId) ?? null;
    const productMasters = nextNode?.kind === "terminal"
      ? await getProductMastersForNode(nextNode.id)
      : [];

    return NextResponse.json({
      ...persisted,
      nextNode,
      productMasters,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to submit answer";
    const status = message === "UNAUTHENTICATED" ? 401
      : message === "TENANT_MEMBERSHIP_REQUIRED" ? 403
      : message === "CONCURRENCY_CONFLICT" ? 409
      : message === "CURRENT_NODE_CONFLICT" ? 409
      : message === "NO_VALID_TRANSITION" ? 400
      : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
