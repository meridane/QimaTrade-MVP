#!/usr/bin/env node
/**
 * Safety gate for local QIMA security testing.
 * This script deliberately refuses remote Supabase URLs, including production.
 */
const rawUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;

if (!rawUrl) {
  console.error("BLOCKED: Set SUPABASE_URL to the local Supabase API URL before running security tests.");
  console.error("Expected: http://127.0.0.1:54321 or http://localhost:54321");
  process.exit(1);
}

let url;
try {
  url = new URL(rawUrl);
} catch {
  console.error("BLOCKED: SUPABASE_URL is not a valid URL.");
  process.exit(1);
}

const allowedHosts = new Set(["127.0.0.1", "localhost"]);
const isLocalSupabase = allowedHosts.has(url.hostname) && url.protocol === "http:" && url.port === "54321";

if (!isLocalSupabase) {
  console.error("BLOCKED: QIMA security tests may only run against local Supabase.");
  console.error("Refusing remote URL: " + url.origin);
  process.exit(1);
}

console.log("PASS: Supabase endpoint is local (" + url.origin + ").");
