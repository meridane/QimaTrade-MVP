"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

async function getActorId(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  userId: string,
) {
  const { data: profile } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", userId)
    .single();

  return profile?.actor_id ?? null;
}

function parseScope(scope: unknown): Record<string, unknown> {
  if (!scope) return {};

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

  if (typeof scope === "object" && !Array.isArray(scope)) {
    return scope as Record<string, unknown>;
  }

  return {};
}

export async function getDemand(demandId: string) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return { ok: false as const, error: "You must be signed in." };

  const actorId = await getActorId(supabase, user.id);
  if (!actorId) {
    return { ok: false as const, error: "Your account is not linked to a QimaTrade actor yet." };
  }

  const { data, error } = await supabase
    .from("demands")
    .select("id, name, quantity, target_market, scope, demand_status")
    .eq("id", demandId)
    .eq("requester_actor_id", actorId)
    .single();

  if (error || !data) {
    return { ok: false as const, error: error?.message || "Demand not found." };
  }

  const scope = parseScope(data.scope);
  const requirements = Array.isArray(scope.requirements)
    ? scope.requirements.filter((item): item is string => typeof item === "string")
    : [];

  return {
    ok: true as const,
    demand: {
      id: data.id,
      title: data.name,
      category: typeof scope.category === "string" ? scope.category : "",
      quantity: String(data.quantity ?? ""),
      unit: typeof scope.unit === "string" ? scope.unit : "tonnes",
      destination: data.target_market || "",
      description: typeof scope.description === "string" ? scope.description : "",
      requirements,
      status: data.demand_status || "draft",
    },
  };
}

export async function updateDemand(
  demandId: string,
  input: {
    title: string;
    category: string;
    quantity: string;
    unit: string;
    destination: string;
    description: string;
    requirements: string[];
  },
) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return { ok: false as const, error: "You must be signed in." };

  const actorId = await getActorId(supabase, user.id);
  if (!actorId) {
    return { ok: false as const, error: "Your account is not linked to a QimaTrade actor yet." };
  }

  const title = input.title.trim();
  const category = input.category.trim();
  const quantity = Number(input.quantity);
  const unit = input.unit.trim();
  const destination = input.destination.trim();
  const description = input.description.trim();
  const requirements = input.requirements.map((item) => item.trim()).filter(Boolean);

  if (!title || !category || !Number.isFinite(quantity) || quantity <= 0 || !description) {
    return { ok: false as const, error: "Please complete all required fields." };
  }

  // Preserve the existing scope, especially qualification/commercial_terms.
  const { data: existingDemand, error: existingDemandError } = await supabase
    .from("demands")
    .select("scope")
    .eq("id", demandId)
    .eq("requester_actor_id", actorId)
    .single();

  if (existingDemandError || !existingDemand) {
    return {
      ok: false as const,
      error: existingDemandError?.message || "Demand not found.",
    };
  }

  const existingScope = parseScope(existingDemand.scope);
  const nextScope = {
    ...existingScope,
    category,
    unit,
    description,
    requirements,
  };

  const { error } = await supabase
    .from("demands")
    .update({
      name: title,
      quantity,
      scope: JSON.stringify(nextScope),
      target_market: destination || null,
    })
    .eq("id", demandId)
    .eq("requester_actor_id", actorId);

  if (error) return { ok: false as const, error: error.message };

  return { ok: true as const, demandId };
}

export async function createDemand(input: {
  title: string;
  category: string;
  quantity: string;
  unit: string;
  destination: string;
  description: string;
  requirements: string[];
}) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return { ok: false as const, error: "You must be signed in." };

  const title = input.title.trim();
  const category = input.category.trim();
  const quantity = Number(input.quantity);
  const unit = input.unit.trim();
  const destination = input.destination.trim();
  const description = input.description.trim();
  const requirements = input.requirements.map((item) => item.trim()).filter(Boolean);

  if (!title || !category || !Number.isFinite(quantity) || quantity <= 0 || !description) {
    return { ok: false as const, error: "Please complete all required fields." };
  }

  const actorId = await getActorId(supabase, user.id);
  if (!actorId) {
    return { ok: false as const, error: "Your account is not linked to a QimaTrade actor yet." };
  }

  const scope = JSON.stringify({ category, unit, description, requirements });

  const { data, error } = await supabase
    .from("demands")
    .insert({
      name: title,
      demand_status: "draft",
      documentation_status: "incomplete",
      quantity,
      scope,
      source: "qimatrade_mvp",
      target_market: destination || null,
      requester_actor_id: actorId,
    })
    .select("id")
    .single();

  if (error) {
    if (error.code === "42501") {
      return {
        ok: false as const,
        error: "Your account is authenticated but is not allowed to create a demand yet. Please verify your profile/actor association.",
      };
    }
    return { ok: false as const, error: error.message };
  }

  return { ok: true as const, demandId: data.id };
}
