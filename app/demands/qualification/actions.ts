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

const currencies = new Set(["USD", "EUR", "KRW", "MAD", "CNY"]);

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

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return { ok: false, error: "You must be signed in to qualify a demand." };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .single();

  if (profileError || !profile?.actor_id) {
    return { ok: false, error: "Your account is not linked to a QimaTrade actor yet." };
  }

  const { data: demand, error: demandError } = await supabase
    .from("demands")
    .select("id, scope, requester_actor_id")
    .eq("id", demandId)
    .eq("requester_actor_id", profile.actor_id)
    .single();

  if (demandError || !demand) {
    return { ok: false, error: "Demand not found or you do not have access to it." };
  }

  let existingScope: Record<string, unknown> = {};
  if (typeof demand.scope === "string") {
    try {
      const parsed = JSON.parse(demand.scope);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        existingScope = parsed as Record<string, unknown>;
      }
    } catch {
      existingScope = {};
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
      documentation_status: documentation ? "incomplete" : "incomplete",
      demand_status: "draft",
    })
    .eq("id", demand.id)
    .eq("requester_actor_id", profile.actor_id);

  if (updateError) {
    return { ok: false, error: updateError.message };
  }

  return { ok: true };
}
