import type { DecisionContext, Primitive, Rule } from "./types";

function asArray(value: Primitive | Primitive[]): Primitive[] {
  return Array.isArray(value) ? value : [value];
}

function primitiveEquals(a: Primitive, b: Primitive): boolean {
  return a === b;
}

/** Deterministic, side-effect-free evaluation of one universal DT rule. */
export function evaluateRule(rule: Rule, context: DecisionContext): boolean {
  if (!rule.field) return true;

  const actual = context.values[rule.field];
  const expected: Primitive | Primitive[] = rule.comparisonValue ?? rule.value;

  if (rule.operator === "exists") {
    return actual !== undefined && actual !== null;
  }

  if (actual === undefined || actual === null) return false;

  const actualValues = asArray(actual);
  const expectedValues = asArray(expected);

  switch (rule.operator) {
    case "equals":
      return actualValues.some((value) => expectedValues.some((item) => primitiveEquals(value, item)));
    case "not_equals":
      return actualValues.every((value) => expectedValues.every((item) => !primitiveEquals(value, item)));
    case "contains":
      return actualValues.some((value) =>
        typeof value === "string" &&
        expectedValues.some((item) => typeof item === "string" && value.includes(item)),
      );
    case "in":
      return actualValues.some((value) => expectedValues.some((item) => primitiveEquals(value, item)));
    case "not_in":
      return actualValues.every((value) => expectedValues.every((item) => !primitiveEquals(value, item)));
    case "gt":
      return typeof actual === "number" && typeof expected === "number" && actual > expected;
    case "gte":
      return typeof actual === "number" && typeof expected === "number" && actual >= expected;
    case "lt":
      return typeof actual === "number" && typeof expected === "number" && actual < expected;
    case "lte":
      return typeof actual === "number" && typeof expected === "number" && actual <= expected;
    default:
      return false;
  }
}

export function sortRulesDeterministically(rules: Rule[]): Rule[] {
  return [...rules].sort((a, b) => (a.priority ?? 0) - (b.priority ?? 0) || a.id.localeCompare(b.id));
}
