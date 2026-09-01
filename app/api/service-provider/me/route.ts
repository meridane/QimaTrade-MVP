import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function GET() {
  try {
    const supabase = await createSupabaseServerClient();

    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData.user) {
      return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id, name, status, actor_id")
      .eq("auth_user_id", authData.user.id)
      .maybeSingle();

    if (profileError) throw profileError;
    if (!profile) {
      return NextResponse.json({ error: "PROFILE_REQUIRED" }, { status: 403 });
    }
    if (!profile.actor_id) {
      return NextResponse.json({ error: "ACTOR_REQUIRED" }, { status: 403 });
    }

    const { data: actor, error: actorError } = await supabase
      .from("actors")
      .select("id, actor_id, name, actor_type, status")
      .eq("id", profile.actor_id)
      .maybeSingle();

    if (actorError) throw actorError;
    if (!actor) {
      return NextResponse.json({ error: "ACTOR_NOT_FOUND" }, { status: 403 });
    }

    if (actor.status !== "active") {
      return NextResponse.json({
        error: "ACTOR_NOT_ACTIVE",
        actor: { name: actor.name, actor_type: actor.actor_type, status: actor.status },
      }, { status: 403 });
    }

    const [{ count: capabilitiesCount, error: capabilitiesError }, { count: servicesCount, error: servicesError }] = await Promise.all([
      supabase
        .from("capabilities")
        .select("id", { count: "exact", head: true })
        .eq("provider_actor_id", actor.id),
      supabase
        .from("services")
        .select("id", { count: "exact", head: true })
        .eq("provider_actor_id", actor.id),
    ]);

    if (capabilitiesError) throw capabilitiesError;
    if (servicesError) throw servicesError;

    // Requests are represented by demands linked to a service/capability.
    // Keep this count scoped to the provider's published capabilities/services.
    const { data: providerCapabilities, error: providerCapabilitiesError } = await supabase
      .from("capabilities")
      .select("id")
      .eq("provider_actor_id", actor.id);
    if (providerCapabilitiesError) throw providerCapabilitiesError;

    const { data: providerServices, error: providerServicesError } = await supabase
      .from("services")
      .select("id")
      .eq("provider_actor_id", actor.id);
    if (providerServicesError) throw providerServicesError;

    const capabilityIds = (providerCapabilities ?? []).map((row) => row.id);
    const serviceIds = (providerServices ?? []).map((row) => row.id);

    let requestsCount = 0;
    if (capabilityIds.length > 0 || serviceIds.length > 0) {
      const filters = [
        ...capabilityIds.map((id) => `capability_id.eq.${id}`),
        ...serviceIds.map((id) => `service_id.eq.${id}`),
      ].join(",");

      const { count, error: demandsError } = await supabase
        .from("demands")
        .select("id", { count: "exact", head: true })
        .or(filters);

      if (demandsError) throw demandsError;
      requestsCount = count ?? 0;
    }

    return NextResponse.json({
      profile: {
        id: profile.id,
        name: profile.name,
        status: profile.status,
      },
      actor: {
        id: actor.id,
        actor_id: actor.actor_id,
        name: actor.name,
        actor_type: actor.actor_type,
        status: actor.status,
      },
      capabilitiesCount: capabilitiesCount ?? 0,
      servicesCount: servicesCount ?? 0,
      requestsCount,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to load provider profile";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
