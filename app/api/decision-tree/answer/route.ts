import { NextRequest, NextResponse } from "next/server";
import { getProductMastersForNode, loadSession, submitAnswer } from "@/lib/decision-tree/server";
import { loadTreeForSession } from "@/lib/decision-tree/session-tree";

function badRequest(message: string) {
  return NextResponse.json({ error: message }, { status: 400 });
}

function mapPublicError(error: unknown): { code: string; status: number } {
  const message = error instanceof Error ? error.message : "";

  switch (message) {
    case "UNAUTHENTICATED":
      return { code: "UNAUTHENTICATED", status: 401 };
    case "TENANT_MEMBERSHIP_REQUIRED":
      return { code: "TENANT_MEMBERSHIP_REQUIRED", status: 403 };
    case "SESSION_NOT_FOUND":
      return { code: "SESSION_NOT_FOUND", status: 404 };
    case "CONCURRENCY_CONFLICT":
      return { code: "CONCURRENCY_CONFLICT", status: 409 };
    case "CURRENT_NODE_CONFLICT":
      return { code: "CURRENT_NODE_CONFLICT", status: 409 };
    case "SESSION_NOT_ACTIVE":
      return { code: "SESSION_NOT_ACTIVE", status: 409 };
    case "NO_VALID_TRANSITION":
    case "INVALID_FIELD":
    case "INVALID_VALUE":
    case "NODE_VERSION_MISMATCH":
    case "TARGET_NODE_VERSION_MISMATCH":
    case "TREE_TENANT_MISMATCH":
      return { code: "INVALID_ANSWER_TRANSITION", status: 400 };
    default:
      return { code: "INTERNAL_ERROR", status: 500 };
  }
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
      return badRequest("INVALID_ANSWER_COMMAND");
    }

    // Resolve the exact tree/version from the session; never silently fall back
    // to another tree when processing an answer.
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
    const mapped = mapPublicError(error);
    // Do not expose raw database/implementation exception messages to clients.
    return NextResponse.json({ error: mapped.code }, { status: mapped.status });
  }
}
