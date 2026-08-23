"use client";

import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";

export default function GlobalActionLoader() {
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let hideTimer: ReturnType<typeof setTimeout> | null = null;

    const startLoading = () => {
      if (hideTimer) {
        clearTimeout(hideTimer);
        hideTimer = null;
      }

      setLoading(true);

      // Safety fallback in case a request fails without navigation.
      hideTimer = setTimeout(() => {
        setLoading(false);
      }, 15000);
    };

    const handleSubmit = (event: Event) => {
      const form = event.target;

      if (!(form instanceof HTMLFormElement)) {
        return;
      }

      if (form.dataset.noLoading === "true") {
        return;
      }

      startLoading();
    };

    const handleClick = (event: MouseEvent) => {
      const target = event.target;

      if (!(target instanceof Element)) {
        return;
      }

      const button = target.closest("button");

      if (!button || button.disabled) {
        return;
      }

      if (button.dataset.noLoading === "true") {
        return;
      }

      // Form submissions are handled by the submit listener above.
      if (button.form) {
        return;
      }

      // Opt-in for standalone async buttons.
      if (button.dataset.loading === "true") {
        startLoading();
      }
    };

    const handlePageShow = () => {
      setLoading(false);
    };

    document.addEventListener("submit", handleSubmit, true);
    document.addEventListener("click", handleClick, true);
    window.addEventListener("pageshow", handlePageShow);

    return () => {
      document.removeEventListener("submit", handleSubmit, true);
      document.removeEventListener("click", handleClick, true);
      window.removeEventListener("pageshow", handlePageShow);

      if (hideTimer) {
        clearTimeout(hideTimer);
      }
    };
  }, []);

  if (!loading) {
    return null;
  }

  return (
    <div
      className="fixed inset-0 z-[9999] flex items-center justify-center bg-slate-950/30 backdrop-blur-[2px]"
      aria-live="polite"
      aria-busy="true"
    >
      <div className="animate-[qimaLoaderFadeIn_180ms_ease-out] rounded-3xl border border-slate-200 bg-white px-8 py-7 shadow-2xl">
        <div className="flex flex-col items-center justify-center text-center">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-orange-50">
            <Loader2
              className="h-8 w-8 animate-spin text-orange-500"
              strokeWidth={2.5}
            />
          </div>

          <p className="mt-4 text-base font-black text-slate-950">
            Traitement en cours…
          </p>

          <p className="mt-1 text-sm text-slate-500">
            Merci de patienter quelques secondes.
          </p>
        </div>
      </div>
    </div>
  );
}
