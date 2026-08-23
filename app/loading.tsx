import { Loader2 } from "lucide-react";

export default function Loading() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50">
      <div className="animate-[qimaLoaderFadeIn_180ms_ease-out] rounded-3xl border border-slate-200 bg-white px-8 py-7 text-center shadow-xl">
        <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-orange-50">
          <Loader2
            className="h-8 w-8 animate-spin text-orange-500"
            strokeWidth={2.5}
          />
        </div>

        <p className="mt-4 text-base font-black text-slate-950">
          Chargement…
        </p>

        <p className="mt-1 text-sm text-slate-500">
          QimaTrade prépare votre page.
        </p>
      </div>
    </main>
  );
}
