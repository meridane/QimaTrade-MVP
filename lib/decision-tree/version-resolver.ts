import type { DecisionTreeVersion } from "./types";

export interface VersionCandidate extends DecisionTreeVersion {
  publishedAt?: string | null;
}

export interface VersionResolutionInput {
  treeId: string;
  requestedVersion?: string | null;
  candidates: VersionCandidate[];
}

/** Resolves only published versions; never executes draft or archived trees. */
export function resolvePublishedVersion(input: VersionResolutionInput): VersionCandidate {
  const published = input.candidates.filter(
    (candidate) => candidate.treeId === input.treeId && candidate.status === "published",
  );

  if (published.length === 0) {
    throw new Error(`No published version available for tree: ${input.treeId}`);
  }

  if (input.requestedVersion) {
    const exact = published.find((candidate) => candidate.version === input.requestedVersion);
    if (!exact) {
      throw new Error(
        `Requested published version not found: ${input.treeId}@${input.requestedVersion}`,
      );
    }
    return exact;
  }

  return [...published].sort((a, b) => {
    const dateA = a.publishedAt ? Date.parse(a.publishedAt) : 0;
    const dateB = b.publishedAt ? Date.parse(b.publishedAt) : 0;
    return dateB - dateA || b.version.localeCompare(a.version, undefined, { numeric: true });
  })[0];
}
