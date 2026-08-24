"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

async function getActorId(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>, userId: string) {
  const { data: profile } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", userId)
    .single();

  return profile?.actor_id ?? null;
}

export async function getDemand(demandId: string) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return { ok: false as const, error: "You must be signed in." };

  const actorId = await getActorId(supabase, user.id);
  if (!actorId) return { ok: false as const, error: "Your account is not linked to a QimaTrade actor yet." };

  const { data, error } = await supabase
    .from("demands")
    .select("id, name, quantity, target_market, scope, demand_status")
    .eq("id", demandId)
    .eq("requester_actor_id", actorId)
    .single();

  if (error || !data) return { ok: false as const, error: error?.message || "Demand not found." };

  let scope: { category?: string; unit?: string; description?: string; requirements?: string[] } = {};
  try {
    scope = data.scope ? JSON.parse(data.scope) : {};
  } catch {
    scope = {};
  }

  return {
    ok: true as const,
    demand: {
      id: data.id,
      title: data.name,
      category: scope.category || "",
      quantity: String(data.quantity ?? ""),
      unit: scope.unit || "tonnes",
      destination: data.target_market || "",
      description: scope.description || "",
      requirements: Array.isArray(scope.requirements) ? scope.requirements : [],
      status: data.demand_status || "draft",
    },
  };
}

export async function updateDemand(demandId: string, input: {
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

  const actorId = await getActorId(supabase, user.id);
  if (!actorId) return { ok: false as const, error: "Your account is not linked to a QimaTrade actor yet." };

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

  const scope = JSON.stringify({ category, unit, description, requirements });

  const { error } = await supabase
    .from("demands")
    .update({
      name: title,
      quantity,
      scope,
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
