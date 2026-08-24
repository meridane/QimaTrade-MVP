"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

type QualificationInput = {
  demandId: string;
  budget: string;
  currency: string;
  deadline: string;
  geography: string;
  commercialTerms: string;
  documentation: string;
};

type QualificationResult =
  | { ok: true }
  | { ok: false; error: string };

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
  };
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

  const deadline = demand.deadline ? new Date(demand.deadline).toISOString().slice(0, 10) : "";
  const qualificationDeadline = stringValue(qualification.deadline) || deadline;

  // Support both the current snake_case key and the legacy camelCase key.
  // Also fall back to values stored directly in the demand scope so older
  // qualifications are not lost when the form is reopened.
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
      documentation:
        stringValue(qualification.documentation) ||
        stringValue(scope.documentation),
    },
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

  const nextScope = {
    ...existingScope,
    qualification: {
      budget,
      currency: budget === null ? null : currency,
      deadline: deadline || null,
      geography,
      commercial_terms: commercialTerms,
      documentation: documentation || null,
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
