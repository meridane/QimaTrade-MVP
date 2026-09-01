import { createClient } from "@supabase/supabase-js";
import { executeAction, type ActionInput } from "./engine";
import type { ActionContext, ActionResult } from "./types";

export async function executeUniversalAction(
  context: ActionContext,
  input: ActionInput,
  accessToken: string,
): Promise<ActionResult> {
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    },
  );

  return executeAction(context, input, {
    getDefinition: async (actionKey, version) => {
      const { data, error } = await supabase
        .from("action_definitions")
        .select("action_key, version, status")
        .eq("action_key", actionKey)
        .eq("version", version)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!data) return null;
      return { actionKey: data.action_key, version: data.version, status: data.status };
    },
    handlers: {
      CREATE_OFFER: async (actionContext, actionInput) => {
        const { data, error } = await supabase.rpc("execute_create_offer_v1", {
          p_tenant_id: actionContext.tenantId,
          p_idempotency_key: actionContext.idempotencyKey,
          p_input: actionInput,
          p_name: String(actionInput.name ?? "Offer"),
          p_demand_id: String(actionInput.demandId),
          p_product_master_id: String(actionInput.productMasterId),
          p_provider_actor_id: String(actionInput.providerActorId),
          p_quantity: Number(actionInput.quantity),
          p_price: Number(actionInput.price),
          p_currency: String(actionInput.currency),
          p_conditions: actionInput.conditions == null ? null : String(actionInput.conditions),
          p_market: actionInput.market == null ? null : String(actionInput.market),
          p_geography: actionInput.geography == null ? null : String(actionInput.geography),
          p_attributes: actionInput.attributes ?? {},
          p_documentation_status: actionInput.documentationStatus == null ? null : String(actionInput.documentationStatus),
          p_lifecycle: actionInput.lifecycle == null ? null : String(actionInput.lifecycle),
          p_offer_type: actionInput.offerType == null ? null : String(actionInput.offerType),
          p_pricing_model: actionInput.pricingModel == null ? null : String(actionInput.pricingModel),
        });
        if (error) throw new Error(error.message);
        return data as ActionResult;
      },
      PUBLISH_PRODUCT_REQUEST: async (actionContext, actionInput) => {
        const requestId = String(actionInput.requestId ?? actionContext.objectId ?? "");
        if (!requestId) throw new Error("PRODUCT_REQUEST_ID_REQUIRED");
        const { data, error } = await supabase.rpc("dt_publish_product_request", {
          p_request_id: requestId,
          p_user_id: actionContext.userId,
        });
        if (error) throw new Error(error.message);
        const result = data as Record<string, unknown> | null;
        const demandId = typeof result?.demandId === "string" ? result.demandId : typeof result?.demand_id === "string" ? result.demand_id : null;
        return {
          executionId: actionContext.correlationId,
          status: "succeeded",
          objectId: demandId,
          result: { requestId, demandId, source: "dt_publish_product_request" },
        };
      },
    },
  });
}
