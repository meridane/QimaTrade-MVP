export interface IdempotencyRecord {
  key: string;
  actionKey: string;
  actorId: string;
  requestHash: string;
  status: "IN_PROGRESS" | "COMPLETED" | "FAILED";
  result?: Record<string, unknown>;
}

export interface IdempotencyStore {
  get(key: string): Promise<IdempotencyRecord | null>;
  begin(record: IdempotencyRecord): Promise<boolean>;
  complete(key: string, result: Record<string, unknown>): Promise<void>;
  fail(key: string): Promise<void>;
}

export class InMemoryIdempotencyStore implements IdempotencyStore {
  private readonly records = new Map<string, IdempotencyRecord>();

  async get(key: string) { return this.records.get(key) ?? null; }

  async begin(record: IdempotencyRecord) {
    if (this.records.has(record.key)) return false;
    this.records.set(record.key, record);
    return true;
  }

  async complete(key: string, result: Record<string, unknown>) {
    const record = this.records.get(key);
    if (!record) return;
    this.records.set(key, { ...record, status: "COMPLETED", result });
  }

  async fail(key: string) {
    const record = this.records.get(key);
    if (!record) return;
    this.records.set(key, { ...record, status: "FAILED" });
  }
}
