"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

type OfferAttributeInput = { key: string; value: string };

type CreateOfferInput = {
  demandId: string;
  name: string;
  quantity: string;
  price: string;
  currency: string;
  conditions: string;
  market: string;
  geography: string;
  attributes: OfferAttributeInput[];
};

type CreateOfferResult =
  | { ok: true; offerId: string }
  | { ok: false; error: string };

export type OfferAttribute = {
  key: string;
  name: string;
  valueType: "text" | "number" | "boolean" | "select";
  unit: string | null;
  required: boolean;
  options: string[];
};

export type OfferContext = {
  product: { id: string; code: string; name: string; canonicalName: string };
  attributes: OfferAttribute[];
};

const currencies = new Set(["USD", "EUR", "KRW", "MAD", "CNY"]);

function parseScope(scope: unknown): Record<string, unknown> {
  if (typeof scope === "string") {
    try {
      const parsed = JSON.parse(scope);
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed as Record<string, unknown> : {};
    } catch { return {}; }
  }
  return scope && typeof scope === "object" && !Array.isArray(scope) ? scope as Record<string, unknown> : {};
}

function getProductMasterId(scope: unknown) {
  const value = parseScope(scope);
  const id = value.product_master_id;
  return typeof id === "string" && id ? id : null;
}

async function getCurrentProfile() {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return { supabase, profile: null, error: "You must be signed in." };
  const { data: profile, error: profileError } = await supabase.from("profiles").select("actor_id").eq("auth_user_id", user.id).single();
  if (profileError || !profile?.actor_id) return { supabase, profile: null, error: "Your account is not linked to a QimaTrade actor yet." };
  return { supabase, profile, error: null };
}

export async function getOfferContext(demandId: string): Promise<{ ok: true; data: OfferContext } | { ok: false; error: string }> {
  const { supabase, profile, error } = await getCurrentProfile();
  if (!profile) return { ok: false, error: error ?? "Authentication failed." };
  const { data: demand, error: demandError } = await supabase.from("demands").select("scope").eq("id", demandId.trim()).single();
  if (demandError || !demand) return { ok: false, error: "Demand not found or unavailable." };
  const productMasterId = getProductMasterId(demand.scope);
  if (!productMasterId) return { ok: false, error: "This demand is not linked to a canonical Product Master yet." };

  const [{ data: product, error: productError }, { data: rows, error: rowsError }] = await Promise.all([
    supabase.from("product_masters").select("id, code, name, canonical_name").eq("id", productMasterId).single(),
    supabase.from("product_master_attributes").select("attribute_key, attribute_value, value_type, is_required, attribute_definition_id, unit_id").eq("product_master_id", productMasterId).order("attribute_key", { ascending: true }),
  ]);
  if (productError || !product) return { ok: false, error: "Product Master not found." };
  if (rowsError) return { ok: false, error: rowsError.message };

  const definitionIds = (rows ?? []).map((row) => row.attribute_definition_id).filter((id): id is string => typeof id === "string");
  const unitIds = (rows ?? []).map((row) => row.unit_id).filter((id): id is string => typeof id === "string");
  const [definitionsResult, optionsResult, unitsResult] = await Promise.all([
    definitionIds.length ? supabase.from("attribute_definitions").select("id, name, value_type").in("id", definitionIds) : Promise.resolve({ data: [], error: null }),
    definitionIds.length ? supabase.from("attribute_options").select("attribute_definition_id, label, code, sort_order").in("attribute_definition_id", definitionIds).eq("is_active", true).order("sort_order", { ascending: true }) : Promise.resolve({ data: [], error: null }),
    unitIds.length ? supabase.from("attribute_units").select("id, symbol, name").in("id", unitIds) : Promise.resolve({ data: [], error: null }),
  ]);
  if (definitionsResult.error || optionsResult.error || unitsResult.error) return { ok: false, error: definitionsResult.error?.message || optionsResult.error?.message || unitsResult.error?.message || "Unable to load product attributes." };
  const definitions = new Map((definitionsResult.data ?? []).map((row) => [row.id, row]));
  const optionsByDefinition = new Map<string, string[]>();
  for (const option of optionsResult.data ?? []) {
    const list = optionsByDefinition.get(option.attribute_definition_id) ?? [];
    list.push(option.label || option.code);
    optionsByDefinition.set(option.attribute_definition_id, list);
  }
  const units = new Map((unitsResult.data ?? []).map((row) => [row.id, row.symbol || row.name]));
  return {
    ok: true,
    data: {
      product: { id: product.id, code: product.code, name: product.name, canonicalName: product.canonical_name },
      attributes: (rows ?? []).map((row) => {
        const definition = definitions.get(row.attribute_definition_id);
        const valueType = definition?.value_type === "number" || definition?.value_type === "boolean" || definition?.value_type === "select" ? definition.value_type : "text";
        return { key: row.attribute_key, name: definition?.name || row.attribute_key, valueType, unit: row.unit_id ? units.get(row.unit_id) ?? null : null, required: Boolean(row.is_required), options: row.attribute_definition_id ? optionsByDefinition.get(row.attribute_definition_id) ?? [] : [] } satisfies OfferAttribute;
      }),
    },
  };
}

export async function createOffer(input: CreateOfferInput): Promise<CreateOfferResult> {
  const demandId = input.demandId.trim();
  const name = input.name.trim();
  const quantity = Number(input.quantity);
  const price = input.price.trim() ? Number(input.price) : null;
  const currency = input.currency.trim();
  const conditions = input.conditions.trim();
  const market = input.market.trim();
  const geography = input.geography.trim();
  const attributes = Array.isArray(input.attributes)
    ? input.attributes.filter((item) => item && typeof item.key === "string" && typeof item.value === "string" && item.value.trim()).map((item) => ({ key: item.key.trim(), value: item.value.trim() }))
    : [];

  if (!demandId || !name || !Number.isFinite(quantity) || quantity <= 0) return { ok: false, error: "Please provide a valid demand, offer name and quantity." };
  if (price !== null && (!Number.isFinite(price) || price < 0)) return { ok: false, error: "Price must be a valid positive number." };
  if (price !== null && !currencies.has(currency)) return { ok: false, error: "Please select a valid currency." };

  const { supabase, profile, error } = await getCurrentProfile();
  if (!profile) return { ok: false, error: error ?? "Authentication failed." };
  const { data: demand, error: demandError } = await supabase.from("demands").select("id, target_market, scope").eq("id", demandId).single();
  if (demandError || !demand) return { ok: false, error: "Demand not found or unavailable." };
  const productMasterId = getProductMasterId(demand.scope);
  if (!productMasterId) return { ok: false, error: "This demand is not linked to a canonical Product Master yet." };

  const { data, error: actionError } = await supabase.rpc("execute_create_offer_v1", {
    p_tenant_id: null,
    p_idempotency_key: crypto.randomUUID(),
    p_input: { demandId, productMasterId, quantity, price, currency, conditions, market, geography, attributes },
    p_name: name,
    p_demand_id: demand.id,
    p_product_master_id: productMasterId,
    p_provider_actor_id: profile.actor_id,
    p_quantity: quantity,
    p_price: price ?? 0,
    p_currency: price === null ? "USD" : currency,
    p_conditions: conditions || null,
    p_market: market || demand.target_market || null,
    p_geography: geography || null,
    p_attributes: Object.fromEntries(attributes.map((item) => [item.key, item.value])),
    p_documentation_status: "incomplete",
    p_lifecycle: "draft",
    p_offer_type: "supplier_offer",
    p_pricing_model: price === null ? null : "fixed",
  });

  if (actionError) return { ok: false, error: actionError.message };
  const result = data as { offerId?: string; objectId?: string; status?: string } | null;
  const offerId = result?.offerId ?? result?.objectId;
  if (!offerId) return { ok: false, error: "Action completed without an offer identifier." };
  return { ok: true, offerId };
}
