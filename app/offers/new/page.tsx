import { ArrowLeft, Check, Send } from "lucide-react";
import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export type OfferAttribute = {
  key: string;
  name: string;
  valueType: "text" | "number" | "boolean" | "select";
  unit: string | null;
  required: boolean;
  options: string[];
};

async function loadProductContext(productMasterId: string) {
  const supabase = await createSupabaseServerClient();
  const [{ data: product, error: productError }, { data: rows, error: rowsError }] = await Promise.all([
    supabase.from("product_masters").select("id, code, name, canonical_name").eq("id", productMasterId).single(),
    supabase.from("product_master_attributes").select("attribute_key, is_required, attribute_definition_id, unit_id").eq("product_master_id", productMasterId).order("attribute_key", { ascending: true }),
  ]);
  if (productError || !product) throw new Error("Product Master not found.");
  if (rowsError) throw new Error(rowsError.message);

  const definitionIds = (rows ?? []).map((row) => row.attribute_definition_id).filter((id): id is string => typeof id === "string");
  const unitIds = (rows ?? []).map((row) => row.unit_id).filter((id): id is string => typeof id === "string");
  const [definitionsResult, optionsResult, unitsResult] = await Promise.all([
    definitionIds.length ? supabase.from("attribute_definitions").select("id, name, value_type").in("id", definitionIds) : Promise.resolve({ data: [], error: null }),
    definitionIds.length ? supabase.from("attribute_options").select("attribute_definition_id, label, code, sort_order").in("attribute_definition_id", definitionIds).eq("is_active", true).order("sort_order", { ascending: true }) : Promise.resolve({ data: [], error: null }),
    unitIds.length ? supabase.from("attribute_units").select("id, symbol, name").in("id", unitIds) : Promise.resolve({ data: [], error: null }),
  ]);
  if (definitionsResult.error || optionsResult.error || unitsResult.error) throw new Error(definitionsResult.error?.message || optionsResult.error?.message || unitsResult.error?.message || "Unable to load product attributes.");
  const definitions = new Map((definitionsResult.data ?? []).map((row) => [row.id, row]));
  const options = new Map<string, string[]>();
  for (const row of optionsResult.data ?? []) {
    const list = options.get(row.attribute_definition_id) ?? [];
    list.push(row.label || row.code);
    options.set(row.attribute_definition_id, list);
  }
  const units = new Map((unitsResult.data ?? []).map((row) => [row.id, row.symbol || row.name]));
  const attributes: OfferAttribute[] = (rows ?? []).map((row) => {
    const definition = definitions.get(row.attribute_definition_id);
    const valueType = definition?.value_type === "number" || definition?.value_type === "boolean" || definition?.value_type === "select" ? definition.value_type : "text";
    return { key: row.attribute_key, name: definition?.name || row.attribute_key, valueType, unit: row.unit_id ? units.get(row.unit_id) ?? null : null, required: Boolean(row.is_required), options: row.attribute_definition_id ? options.get(row.attribute_definition_id) ?? [] : [] };
  });
  return { product, attributes };
}

async function createOfferAction(formData: FormData) {
  "use server";
  const productMasterId = String(formData.get("productMasterId") ?? "").trim() || null;
  const name = String(formData.get("name") ?? "").trim();
  const quantity = Number(formData.get("quantity") ?? 0);
  const priceRaw = String(formData.get("price") ?? "").trim();
  const price = priceRaw ? Number(priceRaw) : null;
  const currency = String(formData.get("currency") ?? "USD").trim();
  const market = String(formData.get("market") ?? "").trim();
  const geography = String(formData.get("geography") ?? "").trim();
  const conditions = String(formData.get("conditions") ?? "").trim();
  const demandId = String(formData.get("demandId") ?? "").trim() || null;

  if (!name || !Number.isFinite(quantity) || quantity <= 0) throw new Error("Offer name and quantity are required.");
  if (price !== null && (!Number.isFinite(price) || price < 0)) throw new Error("Price must be a valid positive number.");

  const attributes: Record<string, string> = {};
  for (const [key, value] of formData.entries()) {
    if (key.startsWith("attribute:")) {
      const cleanKey = key.slice("attribute:".length);
      const cleanValue = String(value).trim();
      if (cleanKey && cleanValue) attributes[cleanKey] = cleanValue;
    }
  }

  if (productMasterId) {
    const context = await loadProductContext(productMasterId);
    for (const attribute of context.attributes) {
      if (attribute.required && !attributes[attribute.key]) throw new Error(`Please complete required attribute: ${attribute.name}.`);
    }
  }

  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) throw new Error("You must be signed in to create an offer.");
  const { data: profile, error: profileError } = await supabase.from("profiles").select("actor_id").eq("auth_user_id", user.id).single();
  if (profileError || !profile?.actor_id) throw new Error("Your account is not linked to a QimaTrade actor yet.");

  const { data: offer, error } = await supabase.from("offers").insert({
    product_master_id: productMasterId,
    demand_id: demandId,
    provider_actor_id: profile.actor_id,
    name,
    quantity,
    price,
    currency: price === null ? null : currency,
    market: market || null,
    geography: geography || null,
    conditions: conditions || null,
    attributes,
    lifecycle: "draft",
    documentation_status: "incomplete",
    offer_type: "supplier_offer",
    pricing_model: price === null ? null : "fixed",
  }).select("id").single();
  if (error || !offer) throw new Error(error?.message ?? "Unable to create the offer.");

  const url = new URL("/offers/new", process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000");
  url.searchParams.set("created", offer.id);
  return url.pathname + url.search;
}

export default async function NewOfferPage({ searchParams }: { searchParams: Promise<{ productMasterId?: string | string[]; created?: string | string[] }> }) {
  const params = await searchParams;
  const productMasterId = Array.isArray(params.productMasterId) ? params.productMasterId[0] ?? "" : params.productMasterId ?? "";
  const createdId = Array.isArray(params.created) ? params.created[0] ?? "" : params.created ?? "";

  let context: { product: { id: string; code: string; name: string; canonical_name: string }; attributes: OfferAttribute[] } | null = null;
  let loadError = "";
  if (productMasterId) {
    try {
      context = await loadProductContext(productMasterId);
    } catch (error) {
      loadError = error instanceof Error ? error.message : "Unable to load Product Master.";
    }
  }

  return <main className="min-h-screen bg-slate-50 px-5 py-8 sm:px-8"><div className="mx-auto max-w-6xl"><Link href="/" className="text-sm font-bold text-orange-600">← Back</Link><div className="mt-5 grid gap-6 lg:grid-cols-[1fr_330px]"><section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8"><p className="text-xs font-bold uppercase tracking-[0.16em] text-orange-600">QimaTrade · Supplier</p><h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950">Create a new offer</h1><p className="mt-2 text-sm leading-6 text-slate-500">Start an offer independently. A Product Master and buyer demand are optional at this stage.</p>
{createdId ? <div className="mt-7 rounded-2xl border border-emerald-200 bg-emerald-50 p-5 text-emerald-800"><div className="flex items-center gap-3"><Check size={20}/><div><p className="font-bold">Offer created successfully.</p><p className="mt-1 text-xs break-all">Offer ID: {createdId}</p></div></div></div> : <form action={createOfferAction} className="mt-7 space-y-6">
{loadError && <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">{loadError}</div>}
<div><label className="text-sm font-bold text-slate-800">Product Master <span className="font-normal text-slate-400">(optional)</span></label><input name="productMasterId" defaultValue={productMasterId} placeholder="Paste Product Master ID only when known" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400"/><p className="mt-1 text-xs text-slate-400">Leave empty to create a standalone offer. It can be classified later.</p></div>
{context && <><div className="rounded-2xl border border-orange-100 bg-orange-50/60 p-4"><p className="text-xs font-bold uppercase tracking-wide text-orange-700">Product Master</p><p className="mt-1 text-lg font-black text-slate-950">{context.product.canonical_name}</p><p className="mt-1 font-mono text-xs text-slate-400">{context.product.code}</p></div>{context.attributes.length > 0 && <div className="rounded-2xl border border-slate-200 p-5"><p className="text-sm font-black text-slate-950">Product attributes</p><div className="mt-4 grid gap-4 sm:grid-cols-2">{context.attributes.map((attribute)=><label key={attribute.key} className="block"><span className="text-sm font-bold text-slate-800">{attribute.name}{attribute.required && <span className="ml-1 text-orange-500">*</span>}</span><span className="mt-1 block text-xs text-slate-400">{attribute.valueType}{attribute.unit ? ` · ${attribute.unit}` : ""}</span>{attribute.valueType === "select" && attribute.options.length > 0 ? <select name={`attribute:${attribute.key}`} required={attribute.required} className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm"><option value="">Select</option>{attribute.options.map((option)=><option key={option}>{option}</option>)}</select> : attribute.valueType === "boolean" ? <select name={`attribute:${attribute.key}`} required={attribute.required} className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm"><option value="">Select</option><option value="true">Yes</option><option value="false">No</option></select> : <input name={`attribute:${attribute.key}`} required={attribute.required} type={attribute.valueType === "number" ? "number" : "text"} step={attribute.valueType === "number" ? "any" : undefined} className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm"/>}</label>)}</div></div></>}
<div><label className="text-sm font-bold text-slate-800">Offer name</label><input name="name" required placeholder="e.g. Used CNC Vertical Machining Center" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-orange-400"/></div>
<div className="grid gap-4 sm:grid-cols-3"><label className="block"><span className="text-sm font-bold">Quantity</span><input name="quantity" required type="number" min="0.000001" step="any" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm"/></label><label className="block"><span className="text-sm font-bold">Price</span><input name="price" type="number" min="0" step="any" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm"/></label><label className="block"><span className="text-sm font-bold">Currency</span><select name="currency" defaultValue="USD" className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm"><option>USD</option><option>EUR</option><option>KRW</option><option>MAD</option><option>CNY</option></select></label></div>
<div className="grid gap-4 sm:grid-cols-2"><label className="block"><span className="text-sm font-bold">Target market</span><input name="market" placeholder="Morocco" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm"/></label><label className="block"><span className="text-sm font-bold">Supplier geography</span><input name="geography" placeholder="South Korea" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm"/></label></div>
<div><label className="text-sm font-bold text-slate-800">Commercial terms</label><textarea name="conditions" rows={4} placeholder="Payment terms, Incoterm, delivery conditions, documentation..." className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm"/></div>
<div><label className="text-sm font-bold text-slate-800">Buyer demand <span className="font-normal text-slate-400">(optional)</span></label><input name="demandId" placeholder="Leave empty for a standalone supplier offer" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm"/></div>
<button type="submit" className="inline-flex items-center gap-2 rounded-xl bg-orange-500 px-6 py-3 text-sm font-bold text-white hover:bg-orange-600"><Send size={17}/> Create offer</button>
</form>}</section><aside className="h-fit rounded-3xl bg-slate-950 p-6 text-white"><p className="text-xs font-bold uppercase tracking-[0.16em] text-orange-400">Supplier flow</p><div className="mt-5 space-y-3"><div className="rounded-xl bg-white/10 p-3 font-semibold">01 · Create offer</div><div className="rounded-xl p-3 text-slate-300">02 · Classify product</div><div className="rounded-xl p-3 text-slate-300">03 · Product attributes</div><div className="rounded-xl p-3 text-slate-500">04 · Match</div><div className="rounded-xl p-3 text-slate-500">05 · Conversation</div></div><div className="mt-7 border-t border-white/10 pt-5"><p className="text-sm font-bold">V1 rule</p><p className="mt-2 text-xs leading-5 text-slate-400">A supplier can create an offer without a Product Master or buyer demand. Matching becomes available once the offer is classified.</p></div></aside></div></div></main>;
}
