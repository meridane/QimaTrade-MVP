import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import * as ts from "typescript";

function findNodes<T extends ts.Node>(
  root: ts.Node,
  predicate: (node: ts.Node) => node is T,
): T[] {
  const matches: T[] = [];
  const visit = (node: ts.Node) => {
    if (predicate(node)) matches.push(node);
    ts.forEachChild(node, visit);
  };
  visit(root);
  return matches;
}

function isFromCall(node: ts.Node): node is ts.CallExpression {
  return ts.isCallExpression(node)
    && ts.isPropertyAccessExpression(node.expression)
    && node.expression.name.text === "from";
}

function isMapCall(node: ts.Node): node is ts.CallExpression {
  return ts.isCallExpression(node)
    && ts.isPropertyAccessExpression(node.expression)
    && node.expression.name.text === "map";
}

function isPromiseAllCall(node: ts.Node): node is ts.CallExpression {
  return ts.isCallExpression(node)
    && ts.isPropertyAccessExpression(node.expression)
    && node.expression.name.text === "all"
    && ts.isIdentifier(node.expression.expression)
    && node.expression.expression.text === "Promise";
}

function isInCall(node: ts.Node): node is ts.CallExpression {
  return ts.isCallExpression(node)
    && ts.isPropertyAccessExpression(node.expression)
    && node.expression.name.text === "in";
}

function isSelectCall(node: ts.Node): node is ts.CallExpression {
  return ts.isCallExpression(node)
    && ts.isPropertyAccessExpression(node.expression)
    && node.expression.name.text === "select";
}

test("getOfferContext keeps Supabase reads grouped outside per-attribute map callbacks", () => {
  const source = readFileSync(
    `${process.cwd()}/app/offers/actions.ts`,
    "utf8",
  );
  const sourceFile = ts.createSourceFile(
    "app/offers/actions.ts",
    source,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
  const getOfferContext = findNodes(
    sourceFile,
    (node): node is ts.FunctionDeclaration =>
      ts.isFunctionDeclaration(node) && node.name?.text === "getOfferContext",
  )[0];

  if (!getOfferContext) throw new Error("getOfferContext function must remain discoverable");

  const fromCalls = findNodes(getOfferContext, isFromCall);
  const tables = fromCalls.map((call) =>
    call.arguments[0] && ts.isStringLiteral(call.arguments[0]) ? call.arguments[0].text : "<dynamic>",
  ).sort();

  expect(tables).toEqual([
    "attribute_definitions",
    "attribute_options",
    "attribute_units",
    "demands",
    "product_master_attributes",
    "product_masters",
  ]);

  const projections = findNodes(getOfferContext, isSelectCall).map((call) => {
    const projection = call.arguments[0];
    return projection && ts.isStringLiteral(projection) ? projection.text : "<dynamic>";
  }).sort();

  expect(projections).toEqual([
    "attribute_definition_id, label, code, sort_order",
    "attribute_key, attribute_value, value_type, is_required, attribute_definition_id, unit_id",
    "id, code, name, canonical_name",
    "id, name, value_type",
    "id, symbol, name",
    "scope",
  ]);
  expect(projections).not.toContain("*");

  const mapCallbacks = findNodes(getOfferContext, isMapCall)
    .flatMap((call) => call.arguments.filter(
      (argument): argument is ts.ArrowFunction | ts.FunctionExpression =>
        ts.isArrowFunction(argument) || ts.isFunctionExpression(argument),
    ));
  const nestedReads = mapCallbacks.flatMap((callback) => findNodes(callback, isFromCall));

  expect(nestedReads, "Supabase reads must not be issued once per attribute").toHaveLength(0);
  const parallelWaves = findNodes(getOfferContext, isPromiseAllCall);
  expect(parallelWaves).toHaveLength(2);
  expect(findNodes(parallelWaves[0], isFromCall).map((call) =>
    call.arguments[0] && ts.isStringLiteral(call.arguments[0]) ? call.arguments[0].text : "<dynamic>",
  ).sort()).toEqual(["product_master_attributes", "product_masters"]);
  expect(findNodes(parallelWaves[1], isFromCall).map((call) =>
    call.arguments[0] && ts.isStringLiteral(call.arguments[0]) ? call.arguments[0].text : "<dynamic>",
  ).sort()).toEqual(["attribute_definitions", "attribute_options", "attribute_units"]);
  expect(findNodes(parallelWaves[1], isInCall)).toHaveLength(3);
  expect(findNodes(getOfferContext, isInCall)).toHaveLength(3);
});


test("getCurrentProfile keeps authentication and tenant lookups bounded", () => {
  const source = readFileSync(
    `${process.cwd()}/app/offers/actions.ts`,
    "utf8",
  );
  const sourceFile = ts.createSourceFile(
    "app/offers/actions.ts",
    source,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
  const getCurrentProfile = findNodes(
    sourceFile,
    (node): node is ts.FunctionDeclaration =>
      ts.isFunctionDeclaration(node) && node.name?.text === "getCurrentProfile",
  )[0];

  if (!getCurrentProfile) throw new Error("getCurrentProfile function must remain discoverable");

  const tables = findNodes(getCurrentProfile, isFromCall).map((call) =>
    call.arguments[0] && ts.isStringLiteral(call.arguments[0]) ? call.arguments[0].text : "<dynamic>",
  ).sort();
  expect(tables).toEqual(["dt_memberships", "profiles"]);

  const projections = findNodes(getCurrentProfile, isSelectCall).map((call) => {
    const projection = call.arguments[0];
    return projection && ts.isStringLiteral(projection) ? projection.text : "<dynamic>";
  }).sort();
  expect(projections).toEqual(["actor_id", "tenant_id"]);
  expect(findNodes(getCurrentProfile, isFromCall)).toHaveLength(2);
  expect(getCurrentProfile.getText(sourceFile).split("supabase.auth.getUser()")).toHaveLength(2);

  const mapCallbacks = findNodes(getCurrentProfile, isMapCall)
    .flatMap((call) => call.arguments.filter(
      (argument): argument is ts.ArrowFunction | ts.FunctionExpression =>
        ts.isArrowFunction(argument) || ts.isFunctionExpression(argument),
    ));
  expect(mapCallbacks.flatMap((callback) => findNodes(callback, isFromCall))).toHaveLength(0);
});
