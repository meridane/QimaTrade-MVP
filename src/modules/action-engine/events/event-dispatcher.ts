export interface ActionEvent {
  eventId: string;
  eventType: string;
  actionKey: string;
  actionVersion: number;
  actorId: string;
  objectType: string;
  objectId?: string;
  correlationId: string;
  occurredAt: string;
  payload: Record<string, unknown>;
}

export interface EventDispatcher {
  dispatch(event: ActionEvent): Promise<void>;
}

export class InMemoryEventDispatcher implements EventDispatcher {
  readonly events: ActionEvent[] = [];

  async dispatch(event: ActionEvent) {
    this.events.push(Object.freeze({ ...event }));
  }
}
