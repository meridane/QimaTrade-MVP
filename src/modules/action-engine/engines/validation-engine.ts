import type { ResolvedActor } from "../domain/contracts/runtime";
import type { ComposedSchema, ResolvedContext, ValidationResult } from "../domain/contracts/runtime";
import type { ValidationEngine } from "../ports";

export class SchemaValidationEngine implements ValidationEngine {
  async validate(
    schema: ComposedSchema,
    input: Record<string, unknown>,
    actor: ResolvedActor,
    _context: ResolvedContext,
  ): Promise<ValidationResult> {
    if (!actor.permissions.includes(`${schema.action.actionKey.toLowerCase().replaceAll("_", ":")}`) && actor.permissions.length === 0) {
      return { valid: false, errors: [{ code: "ACTOR_NOT_AUTHORIZED", message: "Actor is not authorized for this action." }] };
    }

    const errors: { field?: string; code: string; message: string }[] = [];

    for (const field of schema.fields) {
      const value = input[field.key];
      if (field.required && (value === undefined || value === null || value === "")) {
        errors.push({ field: field.key, code: "REQUIRED", message: `${field.key} is required.` });
        continue;
      }
      if (value === undefined || value === null) continue;

      if (field.dataType === "integer" && (!Number.isInteger(value))) {
        errors.push({ field: field.key, code: "INVALID_TYPE", message: `${field.key} must be an integer.` });
      }
      if (field.dataType === "number" && (typeof value !== "number" || !Number.isFinite(value))) {
        errors.push({ field: field.key, code: "INVALID_TYPE", message: `${field.key} must be a finite number.` });
      }

      const validation = field.validation ?? {};
      if (typeof validation.min === "number" && typeof value === "number" && value < validation.min) {
        errors.push({ field: field.key, code: "MIN_VALUE", message: `${field.key} is below the minimum allowed value.` });
      }
    }

    return errors.length ? { valid: false, errors } : { valid: true };
  }
}
