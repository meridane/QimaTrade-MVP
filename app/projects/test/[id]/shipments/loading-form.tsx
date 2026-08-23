"use client";

import { useState } from "react";

type Props = {
  action: (formData: FormData) => void | Promise<void>;
  children: React.ReactNode;
  loadingText?: string;
  className?: string;
};

export default function LoadingForm({ action, children, loadingText = "Loading...", className = "" }: Props) {
  const [pending, setPending] = useState(false);

  return (
    <form
      action={action}
      onSubmit={() => setPending(true)}
      className={className}
    >
      <fieldset disabled={pending} className="contents disabled:opacity-70">
        {children}
      </fieldset>
      {pending && (
        <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-slate-950/20 backdrop-blur-[2px] transition-opacity duration-200">
          <div className="flex items-center gap-3 rounded-2xl border border-slate-200 bg-white px-5 py-4 shadow-xl">
            <span aria-hidden="true" className="h-5 w-5 animate-spin rounded-full border-2 border-orange-500 border-t-transparent" />
            <span className="text-sm font-black text-slate-900">{loadingText}</span>
          </div>
        </div>
      )}
    </form>
  );
}
