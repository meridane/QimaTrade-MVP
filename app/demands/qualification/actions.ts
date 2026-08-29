"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

type AttributeInput = {
  key: string;
  value: string;
};

type QualificationInput = {
  demandId: string;
  budget: string;
  currency: string;
  deadline: string;
  geography: string;
  commercialTerms: string;
  documentation: string;
  attributes: AttributeInput[];
};

type QualificationResult =
  | { ok: true }
  | { ok: false; error: string };

export type QualificationAttribute = {
  key: string;
  name: string;
  valueType: "text" | "number" | "boolean" | "select";
  unit: string | null;
  required: boolean;
  options: string[];
  value: string;
};

export type QualificationDemandData = {
  demand: {
    id: string;
    name: string;
    quantity: number | null;
    budget: number | null;
    currency: string | null;
    deadline: string | null;
    geography: string | null;
    targetMarket: string | null;
    category: string | null;
    unit: string | null;
    description: string | null;
    requirements: string[];
  };
  qualification: {
    budget: number | null;
    currency: string;
    deadline: string;
    geography: string;
    commercialTerms: string;
    documentation: string;
    attributes: AttributeInput[];
  };
  product: {
    id: string;
    code: string;
    name: string;
    canonicalName: string;
  } | null;
  attributes: QualificationAttribute[];
};

const currencies = new Set(["USD", "EUR", "KRW", "MAD", "CNY"]);

async function getCurrentActorId() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return { supabase, actorId: null as string | null, error: "You must be signed in." };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .single();

  if (profileError || !profile?.actor_id) {
    return {
      supabase,
      actorId: null as string | null,
      error: "Your account is not linked to a QimaTrade actor yet.",
    };
  }

  return { supabase, actorId: profile.actor_id as string, error: null };
}

function parseScope(scope: unknown): Record<string, unknown> {
  if (typeof scope === "string") {
    try {
      const parsed = JSON.parse(scope);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
    } catch {
      return {};
    }
  }

  if (scope && typeof scope === "object" && !Array.isArray(scope)) {
    return scope as Record<string, unknown>;
  }

  return {};
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function nullableString(value: unknown): string | null {
  const valueAsString = stringValue(value).trim();
  return valueAsString || null;
}

function requirementsValue(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string");
}

function attributeInputsValue(value: unknown): AttributeInput[] {
  if (!Array.isArray(value)) return [];
  return value.filter(
    (item): item is AttributeInput =>
      Boolean(item) &&
      typeof item === "object" &&
      typeof (item as { key?: unknown }).key === "string" &&
      typeof (item as { value?: unknown }).value === "string",
  );
}

function normalizeValueType(value: unknown): QualificationAttribute["valueType"] {
  if (value === "number" || value === "boolean" || value === "select") return value;
  return "text";
}

async function loadProductAttributes(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  productMasterId: string,
  savedAttributes: AttributeInput[],
): Promise<{
  product: QualificationDemandData["product"];
  attributes: QualificationAttribute[];
}> {
  const [{ data: product, error: productError }, { data: productAttributes, error: attributesError }] = await Promise.all([
    supabase
      .from("product_masters")
      .select("id, code, name, canonical_name")
      .eq("id", productMasterId)
      .eq("status", "active")
      .single(),
    supabase
      .from("product_master_attributes")
      .select("attribute_key, attribute_value, value_type, is_required, attribute_definition_id, value_number, value_boolean, value_date, unit_id")
      .eq("product_master_id", productMasterId)
      .order("attribute_key", { ascending: true }),
  ]);

  if (productError || !product) return { product: null, attributes: [] };
  if (attributesError) throw attributesError;

  const rows = productAttributes ?? [];
  const definitionIds = rows
    .map((row) => row.attribute_definition_id)
    .filter((value): value is string => typeof value === "string");
  const unitIds = rows
    .map((row) => row.unit_id)
    .filter((value): value is string => typeof value === "string");

  const [definitionsResult, optionsResult, unitsResult] = await Promise.all([
    definitionIds.length
      ? supabase.from("attribute_definitions").select("id, key, name, value_type").in("id", definitionIds)
      : Promise.resolve({ data: [], error: null }),
    definitionIds.length
      ? supabase.from("attribute_options").select("attribute_definition_id, label, code, sort_order, is_active").in("attribute_definition_id", definitionIds).eq("is_active", true).order("sort_order", { ascending: true })
      : Promise.resolve({ data: [], error: null }),
    unitIds.length
      ? supabase.from("attribute_units").select("id, symbol, name").in("id", unitIds)
      : Promise.resolve({ data: [], error: null }),
  ]);

  if (definitionsResult.error) throw definitionsResult.error;
  if (optionsResult.error) throw optionsResult.error;
  if (unitsResult.error) throw unitsResult.error;

  const definitions = new Map((definitionsResult.data ?? []).map((row) => [row.id, row]));
  const optionsByDefinition = new Map<string, string[]>();
  for (const option of optionsResult.data ?? []) {
    const list = optionsByDefinition.get(option.attribute_definition_id) ?? [];
    list.push(option.label || option.code);
    optionsByDefinition.set(option.attribute_definition_id, list);
  }
  const units = new Map((unitsResult.data ?? []).map((row) => [row.id, row.symbol || row.name]));
  const savedByKey = new Map(savedAttributes.map((item) => [item.key, item.value]));

  const attributes = rows.map((row) => {
    const definition = row.attribute_definition_id ? definitions.get(row.attribute_definition_id) : null;
    let value = savedByKey.get(row.attribute_key) ?? "";
    if (!value && row.attribute_value) value = row.attribute_value;
    if (!value && row.value_number !== null && row.value_number !== undefined) value = String(row.value_number);
    if (!value && row.value_boolean !== null && row.value_boolean !== undefined) value = row.value_boolean ? "true" : "false";
    if (!value && row.value_date) value = row.value_date;

    return {
      key: row.attribute_key,
      name: definition?.name || row.attribute_key,
      valueType: normalizeValueType(definition?.value_type || row.value_type),
      unit: row.unit_id ? (units.get(row.unit_id) ?? null) : null,
      required: Boolean(row.is_required),
      options: row.attribute_definition_id ? (optionsByDefinition.get(row.attribute_definition_id) ?? []) : [],
      value,
    } satisfies QualificationAttribute;
  });

  return {
    product: {
      id: product.id,
      code: product.code,
      name: product.name,
      canonicalName: product.canonical_name,
    },
    attributes,
  };
}

export async function getQualificationDemand(
  demandId: string,
): Promise<{ ok: true; data: QualificationDemandData } | { ok: false; error: string }> {
  const id = demandId.trim();
  if (!id) return { ok: false, error: "Demand ID is required." };

  const { supabase, actorId, error } = await getCurrentActorId();
  if (!actorId) return { ok: false, error: error ?? "Authentication failed." };

  const { data: demand, error: demandError } = await supabase
    .from("demands")
    .select("id, name, quantity, budget, currency, deadline, geography, target_market, scope")
    .eq("id", id)
    .eq("requester_actor_id", actorId)
    .single();

  if (demandError || !demand) {
    return { ok: false, error: "Demand not found or you do not have access to it." };
  }

  const scope = parseScope(demand.scope);
  const qualification = parseScope(scope.qualification);
  const savedAttributes = attributeInputsValue(qualification.attributes);
  const productMasterId = nullableString(scope.product_master_id);
  const attributeData = productMasterId
    ? await loadProductAttributes(supabase, productMasterId, savedAttributes)
    : { product: null, attributes: [] };

  const deadline = demand.deadline ? new Date(demand.deadline).toISOString().slice(0, 10) : "";
  const qualificationDeadline = stringValue(qualification.deadline) || deadline;

  const commercialTerms =
    stringValue(qualification.commercial_terms) ||
    stringValue(qualification.commercialTerms) ||
    stringValue(scope.commercial_terms) ||
    stringValue(scope.commercialTerms);

  const data: QualificationDemandData = {
    demand: {
      id: demand.id,
      name: demand.name ?? "",
      quantity: demand.quantity === null ? null : Number(demand.quantity),
      budget: demand.budget === null ? null : Number(demand.budget),
      currency: nullableString(demand.currency),
      deadline,
      geography: nullableString(demand.geography),
      targetMarket: nullableString(demand.target_market),
      category: nullableString(scope.category),
      unit: nullableString(scope.unit),
      description: nullableString(scope.description),
      requirements: requirementsValue(scope.requirements),
    },
    qualification: {
      budget:
        qualification.budget === null || qualification.budget === undefined
          ? demand.budget === null
            ? null
            : Number(demand.budget)
          : Number(qualification.budget),
      currency: stringValue(qualification.currency) || stringValue(demand.currency) || "USD",
      deadline: qualificationDeadline,
      geography: stringValue(qualification.geography) || stringValue(demand.geography),
      commercialTerms,
      documentation: stringValue(qualification.documentation) || stringValue(scope.documentation),
      attributes: savedAttributes,
    },
    product: attributeData.product,
    attributes: attributeData.attributes,
  };

  return { ok: true, data };
}

export async function qualifyDemand(input: QualificationInput): Promise<QualificationResult> {
  const demandId = input.demandId.trim();
  const budgetText = input.budget.trim();
  const currency = input.currency.trim();
  const deadline = input.deadline.trim();
  const geography = input.geography.trim();
  const commercialTerms = input.commercialTerms.trim();
  const documentation = input.documentation.trim();
  const attributes = attributeInputsValue(input.attributes);

  if (!demandId || !geography || !commercialTerms) {
    return { ok: false, error: "Please complete the required qualification fields." };
  }

  let budget: number | null = null;
  if (budgetText) {
    budget = Number(budgetText);
    if (!Number.isFinite(budget) || budget < 0) {
      return { ok: false, error: "Budget must be a valid positive number." };
    }
    if (!currencies.has(currency)) {
      return { ok: false, error: "Please select a valid currency." };
    }
  }

  const { supabase, actorId, error } = await getCurrentActorId();
  if (!actorId) return { ok: false, error: error ?? "Authentication failed." };

  const { data: demand, error: demandError } = await supabase
    .from("demands")
    .select("id, scope, requester_actor_id")
    .eq("id", demandId)
    .eq("requester_actor_id", actorId)
    .single();

  if (demandError || !demand) {
    return { ok: false, error: "Demand not found or you do not have access to it." };
  }

  const existingScope = parseScope(demand.scope);
  const productMasterId = nullableString(existingScope.product_master_id);

  if (productMasterId) {
    const attributeData = await loadProductAttributes(supabase, productMasterId, attributes);
    const missingRequired = attributeData.attributes.filter(
      (attribute) => attribute.required && !attributes.some((item) => item.key === attribute.key && item.value.trim()),
    );
    if (missingRequired.length > 0) {
      return { ok: false, error: `Please complete required attributes: ${missingRequired.map((item) => item.name).join(", ")}.` };
    }
  }

  const nextScope = {
    ...existingScope,
    qualification: {
      budget,
      currency: budget === null ? null : currency,
      deadline: deadline || null,
      geography,
      commercial_terms: commercialTerms,
      documentation: documentation || null,
      attributes,
    },
  };

  const { error: updateError } = await supabase
    .from("demands")
    .update({
      budget,
      currency: budget === null ? null : currency,
      deadline: deadline ? new Date(`${deadline}T23:59:59Z`).toISOString() : null,
      geography,
      scope: JSON.stringify(nextScope),
      documentation_status: "incomplete",
      demand_status: "draft",
    })
    .eq("id", demand.id)
    .eq("requester_actor_id", actorId);

  if (updateError) {
    return { ok: false, error: updateError.message };
  }

  return { ok: true };
}
