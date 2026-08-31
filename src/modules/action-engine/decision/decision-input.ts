import { ActionEngineError } from "../domain/errors";

export interface DecisionAnswerPayload {
  answers: Record<string, unknown>;
}

/** Client data accepted by the decision layer. Node/rule/next-node identifiers
 * are deliberately not accepted: the server owns the published tree. */
export function validateDecisionAnswers(input: unknown): DecisionAnswerPayload {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new ActionEngineError("DECISION_INPUT_INVALID", "Decision answers must be an object.");
  }

  const record = input as Record<string, unknown>;
  if (!record.answers || typeof record.answers !== "object" || Array.isArray(record.answers)) {
    throw new ActionEngineError("DECISION_INPUT_INVALID", "Decision answers must contain an answers object.");
  }

  const forbidden = ["nodeId", "ruleId", "nextNodeId", "decision", "result"];
  for (const key of forbidden) {
    if (key in record) throw new ActionEngineError("DECISION_INPUT_FORBIDDEN", `${key} is server-controlled.`);
  }

  return { answers: record.answers as Record<string, unknown> };
}
