"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

type CreateDemandInput = {
  title: string;
  category: string;
  quantity: string;
  unit: string;
  destination: string;
  description: string;
  requirements: string[];
};

type CreateDemandResult =
  | { ok: true; demandId: string; businessDemandId: string }
  | { ok: false; error: string };

const allowedCategories = new Set([
  "Raw materials",
  "Industrial equipment",
  "Packaging",
  "Automotive",
  "Other",
]);

const allowedUnits = new Set(["tonnes", "kg", "units", "containers"]);

export async function createDemand(input: CreateDemandInput): Promise<CreateDemandResult> {
  const title = input.title.trim();
  const category = input.category.trim();
  const description = input.description.trim();
  const destination = input.destination.trim();
  const unit = input.unit.trim();
  const quantity = Number(input.quantity);
  const requirements = input.requirements
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 20);

  if (!title || !description || !category) {
    return { ok: false, error: "Please complete the required fields." };
  }

  if (!allowedCategories.has(category)) {
    return { ok: false, error: "Invalid demand category." };
  }

  if (!allowedUnits.has(unit)) {
    return { ok: false, error: "Invalid demand unit." };
  }

  if (!Number.isFinite(quantity) || quantity <= 0) {
    return { ok: false, error: "Quantity must be a positive number." };
  }

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return { ok: false, error: "You must be signed in to create a demand." };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .single();

  if (profileError || !profile?.actor_id) {
    return { ok: false, error: "Your account is not linked to a QimaTrade actor yet." };
  }

  const scope = JSON.stringify({
    category,
    unit,
    description,
    requirements,
  });

  const { data: demand, error: insertError } = await supabase
    .from("demands")
    .insert({
      name: title,
      quantity,
      target_market: destination || null,
      scope,
      requester_actor_id: profile.actor_id,
      demand_status: "draft",
      documentation_status: "incomplete",
      source: "qimatrade_mvp",
    })
    .select("id, demand_id")
    .single();

  if (insertError || !demand) {
    return {
      ok: false,
      error: insertError?.message ?? "Unable to create the demand.",
    };
  }

  return {
    ok: true,
    demandId: demand.id,
    businessDemandId: demand.demand_id,
  };
}
