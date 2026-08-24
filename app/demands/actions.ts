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

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, actor_id")
    .eq("id", user.id)
    .maybeSingle();

  const actorId = profile?.actor_id ?? null;

  const payload: Record<string, unknown> = {
    title,
    category,
    quantity,
    unit,
    destination,
    description,
    requirements,
    created_by_user_id: user.id,
  };

  if (actorId) payload.created_by_actor_id = actorId;

  const { data, error } = await supabase
    .from("demands")
    .insert(payload)
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
