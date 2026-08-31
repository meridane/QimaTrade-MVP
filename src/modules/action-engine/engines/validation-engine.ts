import type {
  ComposedSchema,
  ResolvedActor,
  ResolvedContext,
  ValidationError,
  ValidationResult,
} from "../domain/contracts/runtime";
import type { ValidationEngine } from "../ports";

export class SchemaValidationEngine implements ValidationEngine {
  async validate(
    schema: ComposedSchema,
    input: Record<string, unknown>,
    actor: ResolvedActor,
    _context: ResolvedContext,
  ): Promise<ValidationResult> {
    const errors: ValidationError[] = [];

    const requiredPermission = schema.action.actionKey.toLowerCase().replaceAll("_", ":");
    if (!actor.permissions.includes(requiredPermission)) {
      errors.push({ code: "ACTOR_NOT_AUTHORIZED", message: `Missing permission: ${requiredPermission}.` });
    }

    const knownKeys = new Set(schema.fields.map((field) => field.key));
    for (const key of Object.keys(input)) {
      if (!knownKeys.has(key)) {
        errors.push({ field: key, code: "UNKNOWN_FIELD", message: `${key} is not part of the resolved schema.` });
      }
    }

    for (const field of schema.fields) {
      const value = input[field.key];
      const missing = value === undefined || value === null || value === "";

      if (field.required && missing) {
        errors.push({ field: field.key, code: "REQUIRED", message: `${field.key} is required.` });
        continue;
      }
      if (missing) continue;

      if (!matchesDataType(value, field.dataType)) {
        errors.push({ field: field.key, code: "INVALID_TYPE", message: `${field.key} has an invalid type.` });
        continue;
      }

      const validation = field.validation ?? {};
      if (typeof validation.min === "number" && typeof value === "number" && value < validation.min) {
        errors.push({ field: field.key, code: "MIN_VALUE", message: `${field.key} is below the minimum allowed value.` });
      }
      if (typeof validation.max === "number" && typeof value === "number" && value > validation.max) {
        errors.push({ field: field.key, code: "MAX_VALUE", message: `${field.key} exceeds the maximum allowed value.` });
      }
      if (typeof validation.pattern === "string" && typeof value === "string") {
        try {
          if (!new RegExp(validation.pattern).test(value)) {
            errors.push({ field: field.key, code: "INVALID_FORMAT", message: `${field.key} has an invalid format.` });
          }
        } catch {
          errors.push({ field: field.key, code: "INVALID_VALIDATION_RULE", message: `${field.key} has an invalid validation rule.` });
        }
      }
    }

    return errors.length > 0 ? { valid: false, errors } : { valid: true };
  }
}

function matchesDataType(value: unknown, dataType: string): boolean {
  switch (dataType) {
    case "string":
    case "text":
    case "currency":
    case "date":
      return typeof value === "string";
    case "number":
      return typeof value === "number" && Number.isFinite(value);
    case "integer":
      return typeof value === "number" && Number.isInteger(value);
    case "boolean":
      return typeof value === "boolean";
    case "object":
      return typeof value === "object" && value !== null && !Array.isArray(value);
    default:
      return false;
  }
}
