import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

async function getProviderActor(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>) {
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) return { error: "UNAUTHENTICATED", status: 401 as const };

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("actor_id")
    .eq("auth_user_id", authData.user.id)
    .maybeSingle();
  if (profileError) throw profileError;
  if (!profile?.actor_id) return { error: "ACTOR_REQUIRED", status: 403 as const };

  const { data: actor, error: actorError } = await supabase
    .from("actors")
    .select("id, actor_id, name, actor_type, status")
    .eq("id", profile.actor_id)
    .maybeSingle();
  if (actorError) throw actorError;
  if (!actor) return { error: "ACTOR_NOT_FOUND", status: 403 as const };
  if (actor.status !== "active") return { error: "ACTOR_NOT_ACTIVE", status: 403 as const };

  return { actor };
}

export async function GET() {
  try {
    const supabase = await createSupabaseServerClient();
    const provider = await getProviderActor(supabase);
    if ("error" in provider) return NextResponse.json({ error: provider.error }, { status: provider.status });

    const { data, error } = await supabase
      .from("capabilities")
      .select("id, capability_id, name, capability_type, capacity, geography, markets_served, documentation_status, version, created_at, updated_at")
      .eq("provider_actor_id", provider.actor.id)
      .order("created_at", { ascending: false });
    if (error) throw error;

    return NextResponse.json({ capabilities: data ?? [] });
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : "Unable to load capabilities" }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const name = typeof body.name === "string" ? body.name.trim() : "";
    const capabilityType = typeof body.capabilityType === "string" ? body.capabilityType.trim() : null;
    const geography = typeof body.geography === "string" ? body.geography.trim() : null;
    const marketsServed = typeof body.marketsServed === "string" ? body.marketsServed.trim() : null;
    const capacity = body.capacity === "" || body.capacity === null || body.capacity === undefined ? null : Number(body.capacity);

    if (!name) return NextResponse.json({ error: "name is required" }, { status: 400 });
    if (capacity !== null && (!Number.isFinite(capacity) || capacity < 0)) return NextResponse.json({ error: "capacity must be a non-negative number" }, { status: 400 });

    const supabase = await createSupabaseServerClient();
    const provider = await getProviderActor(supabase);
    if ("error" in provider) return NextResponse.json({ error: provider.error }, { status: provider.status });

    const capabilityId = `CAP-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
    const { data, error } = await supabase
      .from("capabilities")
      .insert({
        capability_id: capabilityId,
        name,
        capability_type: capabilityType,
        capacity,
        geography,
        markets_served: marketsServed,
        documentation_status: "not_documented",
        version: 1,
        provider_actor_id: provider.actor.id,
      })
      .select("id, capability_id, name, capability_type, capacity, geography, markets_served, documentation_status, version, created_at, updated_at")
      .single();
    if (error) throw error;

    return NextResponse.json({ capability: data }, { status: 201 });
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : "Unable to create capability" }, { status: 500 });
  }
}
