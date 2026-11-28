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
