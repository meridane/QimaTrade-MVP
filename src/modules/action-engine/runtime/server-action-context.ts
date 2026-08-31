import type { ActionRuntimeRequest } from "../domain/contracts/action";
import { ActionEngineError } from "../domain/errors";
import { TenantResolver } from "../resolvers/tenant-resolver";

export interface AuthenticatedSession {
  userId: string;
}

export interface ServerActionContext {
  userId: string;
  tenantId: string;
}

/**
 * Builds the authoritative action context from the authenticated server session.
 * A tenant supplied by the client is treated only as a requested scope and must
 * be validated against the user's memberships.
 */
export async function buildServerActionContext(
  session: AuthenticatedSession | null,
  request: Pick<ActionRuntimeRequest, "tenantId">,
  tenantResolver: TenantResolver,
): Promise<ServerActionContext> {
  if (!session?.userId) {
    throw new ActionEngineError("AUTHENTICATION_REQUIRED", "An authenticated session is required.");
  }

  const tenantId = await tenantResolver.resolveAuthenticatedTenant(session.userId, request.tenantId);

  if (!tenantId) {
    throw new ActionEngineError("TENANT_CONTEXT_REQUIRED", "A canonical tenant could not be resolved.");
  }

  return { userId: session.userId, tenantId };
}
