import { strict as assert } from "node:assert";
import { ConfiguredActionResolver } from "../resolvers/action-resolver";
import { ConfiguredObjectResolver } from "../resolvers/object-resolver";
import { ConfiguredActorResolver } from "../resolvers/actor-resolver";
import { RequestContextResolver } from "../resolvers/context-resolver";
import { ConfiguredDecisionEngine } from "../engines/decision-engine";
import { ConfiguredParameterEngine } from "../engines/parameter-engine";
import { CanonicalAttributeEngine } from "../engines/attribute-engine";
import { DefaultSchemaComposer } from "../engines/schema-composer";
import { SchemaValidationEngine } from "../engines/validation-engine";
import {
  createOfferProductMasterAction,
  createOfferProductMasterAttributes,
  createOfferProductMasterParameters,
} from "../config/create-offer-product-master";
import { ActionRuntime } from "../runtime/action-runtime";

async function run() {
  const runtime = new ActionRuntime({
    actionResolver: new ConfiguredActionResolver([createOfferProductMasterAction]),
    objectResolver: new ConfiguredObjectResolver({ "pm-001": { brand: "Example", model: "CNC-1" } }),
    actorResolver: new ConfiguredActorResolver({
      "supplier-001": { id: "supplier-001", type: "Supplier", permissions: ["create:offer"] },
    }),
    contextResolver: new RequestContextResolver(),
    decisionEngine: new ConfiguredDecisionEngine(async () => ({
      type: "COMPLETE",
      result: {
        domain: "industry_infrastructure",
        category: "industrial_machinery",
        subcategory: "cnc_machine_tools",
      },
    })),
    parameterEngine: new ConfiguredParameterEngine(createOfferProductMasterParameters),
    attributeEngine: new CanonicalAttributeEngine(createOfferProductMasterAttributes),
    schemaComposer: new DefaultSchemaComposer(),
    validationEngine: new SchemaValidationEngine(),
  });

  const result = await runtime.prepareSchema({
    actionKey: "CREATE_OFFER",
    actor: { id: "supplier-001", type: "Supplier" },
    object: { type: "ProductMaster", masterId: "pm-001" },
    context: { type: "Trade", values: {} },
    idempotencyKey: "test-001",
  });

  assert.equal(result.status, "SCHEMA_READY");
  assert.equal(result.schema?.fields.filter((field) => field.kind === "attribute").length, 7);
  assert.equal(result.schema?.fields.filter((field) => field.kind === "parameter").length, 5);
  assert.equal(result.schema?.fields.find((field) => field.key === "power")?.source, "ProductMaster");
  assert.equal(result.schema?.fields.find((field) => field.key === "price")?.source, "ActionDefinition");

  const validation = await new SchemaValidationEngine().validate(
    result.schema!,
    { quantity: 1, price: 25000, currency: "USD" },
    { id: "supplier-001", type: "Supplier", permissions: ["create:offer"] },
    result.schema!.context,
  );
  assert.deepEqual(validation, { valid: true });

  console.log("PASS: CREATE_OFFER + ProductMaster vertical schema");
}

void run();
