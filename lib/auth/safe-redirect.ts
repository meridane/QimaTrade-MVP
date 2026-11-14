export function getSafeRedirectUrl(next: string | null, origin: string): URL {
  const fallback = new URL("/demands", origin);

  if (!next || !next.startsWith("/") || next.startsWith("//")) {
    return fallback;
  }

  try {
    const candidate = new URL(next, origin);
    return candidate.origin === origin ? candidate : fallback;
  } catch {
    return fallback;
  }
}
