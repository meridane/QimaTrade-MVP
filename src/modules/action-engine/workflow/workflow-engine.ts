import type { ActionDefinition } from "../domain/contracts/action";
import { ActionEngineError } from "../domain/errors";

export interface WorkflowState {
  state: string;
  version: number;
}

export interface WorkflowTransition {
  from: string;
  event: string;
  to: string;
}

export interface WorkflowEngine {
  transition(action: ActionDefinition, current: WorkflowState, event: string): Promise<WorkflowState>;
}

export class ConfiguredWorkflowEngine implements WorkflowEngine {
  constructor(private readonly transitions: WorkflowTransition[]) {}

  async transition(action: ActionDefinition, current: WorkflowState, event: string): Promise<WorkflowState> {
    const transition = this.transitions.find(
      (item) => item.from === current.state && item.event === event,
    );
    if (!transition) {
      throw new ActionEngineError(
        "WORKFLOW_TRANSITION_NOT_ALLOWED",
        `Event ${event} is not allowed from state ${current.state} for ${action.actionKey}.`,
      );
    }
    return { state: transition.to, version: current.version + 1 };
  }
}
