import type { DecisionNode, Rule } from "./types";

type DecisionTreeVersion = {
  id: string;
  version: string;
  status: "draft" | "published" | "archived";
  title?: string;
  entryNodeId?: string;
};

export interface DecisionTreeDataSource {
  getTreeId(treeKey: string, tenantId?: string): Promise<string | null>;
  getPublishedVersion(
    treeId: string,
    requestedVersion?: string | null,
  ): Promise<DecisionTreeVersion | null>;
  getNodes(treeVersionId: string): Promise<DecisionNode[]>;
  getRules(treeVersionId: string): Promise<Rule[]>;
}

export async function loadPublishedTree(
  source: DecisionTreeDataSource,
  treeKey: string,
  tenantId?: string,
  requestedVersion?: string | null,
): Promise<DecisionTreeVersion & { nodes: DecisionNode[]; rules: Rule[] }> {
  const treeId = await source.getTreeId(treeKey, tenantId);
  if (!treeId) throw new Error(`Decision tree not found: ${treeKey}`);

  const version = await source.getPublishedVersion(treeId, requestedVersion);
  if (!version || version.status !== "published") {
    throw new Error(`No published decision tree version available: ${treeKey}`);
  }

  const [nodes, rules] = await Promise.all([
    source.getNodes(version.id),
    source.getRules(version.id),
  ]);

  return { ...version, nodes, rules };
}
