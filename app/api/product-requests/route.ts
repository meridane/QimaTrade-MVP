import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const title = typeof body.title === "string" ? body.title.trim() : "";
    const description = typeof body.description === "string" ? body.description.trim() : null;
    const quantity = body.quantity === null || body.quantity === undefined || body.quantity === "" ? null : Number(body.quantity);
    const unit = typeof body.unit === "string" ? body.unit.trim() : null;
    const productMasterId = typeof body.productMasterId === "string" ? body.productMasterId : "";
    const decisionSessionId = typeof body.decisionSessionId === "string" ? body.decisionSessionId : "";

    if (!title || !productMasterId || !decisionSessionId) {
      return NextResponse.json({ error: "title, productMasterId and decisionSessionId are required" }, { status: 400 });
    }
    if (quantity !== null && (!Number.isFinite(quantity) || quantity <= 0)) {
      return NextResponse.json({ error: "quantity must be a positive number" }, { status: 400 });
    }

    const supabase = await createSupabaseServerClient();
    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData.user) return NextResponse.json({ error: "UNAUTHENTICATED" }, { status: 401 });

    const { data: membership, error: membershipError } = await supabase
      .from("dt_memberships")
      .select("tenant_id")
      .eq("user_id", authData.user.id)
      .limit(1)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return NextResponse.json({ error: "TENANT_MEMBERSHIP_REQUIRED" }, { status: 403 });

    const { data: session, error: sessionError } = await supabase
      .from("dt_sessions")
      .select("id")
      .eq("id", decisionSessionId)
      .eq("tenant_id", membership.tenant_id)
      .eq("user_id", authData.user.id)
      .single();
    if (sessionError || !session) return NextResponse.json({ error: "INVALID_DECISION_SESSION" }, { status: 400 });

    const { data: product, error: productError } = await supabase
      .from("product_masters")
      .select("id")
      .eq("id", productMasterId)
      .eq("status", "active")
      .single();
    if (productError || !product) return NextResponse.json({ error: "PRODUCT_MASTER_NOT_FOUND" }, { status: 400 });

    const { data, error } = await supabase
      .from("product_requests")
      .insert({
        tenant_id: membership.tenant_id,
        user_id: authData.user.id,
        decision_session_id: decisionSessionId,
        product_master_id: productMasterId,
        title,
        description,
        quantity,
        unit,
        status: "draft",
      })
      .select("id, title, description, quantity, unit, status, product_master_id, decision_session_id, created_at")
      .single();
    if (error) throw error;

    return NextResponse.json({ request: data }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to create product request";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
