import type { ResolvedAction } from "../domain/contracts/action";
import type { ResolvedActor, ResolvedContext, ResolvedObject } from "../domain/contracts/runtime";
import type { DecisionTreeDefinition } from "./server-decision-engine";
import type { CanonicalDecisionTreeRepository } from "./dt-decision-provider";
import type { CanonicalDtNodeRecord, CanonicalDtRuleRecord } from "./dt-schema-mapper";
import { mapCanonicalDt } from "./dt-schema-mapper";

export interface CanonicalDtStore {
  findTreeForAction(input: {
    actionId: string;
    tenantId: string;
    objectType: string;
    contextType: string;
  }): Promise<{
    id: string;
    version: string;
    status: "draft" | "published" | "deprecated";
    entryNodeId: string;
  } | null>;
  listNodes(versionId: string, tenantId: string): Promise<CanonicalDtNodeRecord[]>;
  listRules(versionId: string, tenantId: string): Promise<CanonicalDtRuleRecord[]>;
}

function parseVersion(version: string): number {
  const major = Number.parseInt(version.split(".")[0] ?? "", 10);
  if (!Number.isInteger(major)) throw new Error(`Invalid Decision Tree version: ${version}`);
  return major;
}

export class SupabaseCanonicalDtRepository implements CanonicalDecisionTreeRepository {
  constructor(private readonly store: CanonicalDtStore) {}

  async findPublishedTree(input: {
    action: ResolvedAction;
    object: ResolvedObject;
    actor: ResolvedActor;
    context: ResolvedContext;
  }): Promise<DecisionTreeDefinition | null> {
    const binding = await this.store.findTreeForAction({
      actionId: input.action.id,
      tenantId: input.context.tenantId,
      objectType: input.object.type,
      contextType: input.context.type,
    });
    if (!binding || binding.status !== "published") return null;

    const [nodes, rules] = await Promise.all([
      this.store.listNodes(binding.id, input.context.tenantId),
      this.store.listRules(binding.id, input.context.tenantId),
    ]);

    if (!nodes.some((node) => node.id === binding.entryNodeId)) {
      throw new Error("Decision Tree entry node is outside the loaded tenant/version scope.");
    }

    return mapCanonicalDt(
      {
        id: binding.id,
        version: parseVersion(binding.version),
        status: binding.status,
        entryNodeId: binding.entryNodeId,
      },
      nodes,
      rules,
    );
  }
}
