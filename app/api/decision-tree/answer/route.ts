import { NextRequest, NextResponse } from "next/server";
import { getProductMastersForNode, loadPublishedTree, loadSession, submitAnswer } from "@/lib/decision-tree/server";

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

    // Load the published tree/session only for authorization, current-node
    // validation and response shaping. The database RPC is authoritative for
    // rule matching and target-node selection.
    const { tree } = await loadPublishedTree();
    const session = await loadSession(sessionId);

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
