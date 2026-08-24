"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

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

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", user.id)
    .single();

  if (profileError || !profile?.actor_id) {
    return {
      ok: false as const,
      error: "Your account is not linked to a QimaTrade actor yet.",
    };
  }

  const scope = JSON.stringify({
    category,
    unit,
    description,
    requirements,
  });

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
      requester_actor_id: profile.actor_id,
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
