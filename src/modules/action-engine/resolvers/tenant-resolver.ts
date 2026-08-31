import { ActionEngineError } from "../domain/errors";

export interface TenantMembershipRepository {
  findTenantIdsForUser(userId: string): Promise<string[]>;
}

export class TenantResolver {
  constructor(private readonly memberships: TenantMembershipRepository) {}

  async resolveAuthenticatedTenant(userId: string, requestedTenantId?: string): Promise<string> {
    if (!userId) {
      throw new ActionEngineError("AUTHENTICATION_REQUIRED", "An authenticated user is required.");
    }

    const tenantIds = await this.memberships.findTenantIdsForUser(userId);
    if (tenantIds.length === 0) {
      throw new ActionEngineError("TENANT_MEMBERSHIP_REQUIRED", "The authenticated user has no tenant membership.");
    }

    if (requestedTenantId && !tenantIds.includes(requestedTenantId)) {
      throw new ActionEngineError("TENANT_ACCESS_DENIED", "The requested tenant is not accessible by the authenticated user.");
    }

    if (requestedTenantId) return requestedTenantId;
    if (tenantIds.length === 1) return tenantIds[0];

    throw new ActionEngineError("TENANT_SELECTION_REQUIRED", "A tenant must be selected for users belonging to multiple tenants.");
  }
}
