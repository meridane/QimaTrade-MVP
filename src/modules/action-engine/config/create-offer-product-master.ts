import type { ResolvedAction } from "../domain/contracts/action";
import type { SchemaField } from "../domain/contracts/runtime";
import type { AttributeDefinition } from "../engines/attribute-engine";
import type { ParameterDefinition } from "../engines/parameter-engine";

export const createOfferProductMasterAction: ResolvedAction = {
  id: "action-create-offer-product-master-v1",
  actionKey: "CREATE_OFFER",
  name: "Create Offer",
  version: 1,
  status: "published",
  parentActionId: null,
  objectType: "ProductMaster",
  actorType: "Supplier",
  contextType: "Trade",
  workflowId: "offer-lifecycle-v1",
  permissions: ["offer:create"],
};

export const createOfferProductMasterAttributes: AttributeDefinition[] = [
  { key: "brand", label: "Brand", dataType: "string", ownerType: "ProductMaster", ownerSchema: "ProductMaster", editable: false },
  { key: "model", label: "Model", dataType: "string", ownerType: "ProductMaster", ownerSchema: "ProductMaster", editable: false },
  { key: "year", label: "Year", dataType: "integer", ownerType: "ProductMaster", ownerSchema: "ProductMaster", editable: false },
  { key: "machine_type", label: "Machine Type", dataType: "string", ownerType: "ProductMaster", ownerSchema: "ProductMaster", editable: false },
  { key: "control_system", label: "Control System", dataType: "string", ownerType: "ProductMaster", ownerSchema: "ProductMaster", editable: false },
  { key: "power", label: "Power", dataType: "number", ownerType: "ProductMaster", ownerSchema: "ProductMaster", editable: false },
  { key: "dimensions", label: "Dimensions", dataType: "object", ownerType: "ProductMaster", ownerSchema: "ProductMaster", editable: false },
];

export const createOfferProductMasterParameters: ParameterDefinition[] = [
  { key: "quantity", label: "Quantity", dataType: "integer", required: true, editable: true, validation: { min: 1 } },
  { key: "price", label: "Price", dataType: "number", required: true, editable: true, validation: { min: 0 } },
  { key: "currency", label: "Currency", dataType: "currency", required: true, editable: true },
  { key: "validity", label: "Validity", dataType: "date", required: false, editable: true },
  { key: "commercial_terms", label: "Commercial Terms", dataType: "text", required: false, editable: true },
];

export function fieldsForCreateOfferProductMaster(
  attributes: SchemaField[],
  parameters: ParameterDefinition[],
): SchemaField[] {
  return [
    ...attributes,
    ...parameters.map((parameter) => ({
      key: parameter.key,
      label: parameter.label,
      kind: "parameter" as const,
      dataType: parameter.dataType,
      required: parameter.required,
      editable: parameter.editable ?? true,
      source: "CREATE_OFFER",
      validation: parameter.validation,
    })),
  ];
}
