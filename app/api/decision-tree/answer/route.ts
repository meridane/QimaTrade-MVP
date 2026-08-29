import { NextRequest, NextResponse } from "next/server";
import { loadPublishedTree, loadSession, submitAnswer } from "@/lib/decision-tree/server";
import { evaluateAnswer } from "@/lib/decision-tree/engine";

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

    const { tree } = await loadPublishedTree();
    const session = await loadSession(sessionId);

    if (session.revision !== expectedRevision || session.currentNodeId !== nodeId) {
      return NextResponse.json({ error: "CONCURRENCY_CONFLICT" }, { status: 409 });
    }

    const result = evaluateAnswer(tree, {
      sessionId: session.sessionId,
      treeId: tree.id,
      treeVersion: tree.version,
      currentNodeId: session.currentNodeId,
      revision: session.revision,
      answers: session.answers,
    }, field, value);

    if (!result.nextNodeId || !result.matchedRuleId) {
      return badRequest("No valid transition for this answer");
    }

    const persisted = await submitAnswer({
      sessionId,
      expectedRevision,
      nodeId,
      field,
      value,
      targetNodeId: result.nextNodeId,
      ruleId: result.matchedRuleId,
      clientCommandId,
    });

    const nextNode = tree.nodes.find((node) => node.id === persisted.currentNodeId) ?? null;

    return NextResponse.json({
      ...persisted,
      nextNode,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to submit answer";
    const status = message === "UNAUTHENTICATED" ? 401 : message === "TENANT_MEMBERSHIP_REQUIRED" ? 403 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
