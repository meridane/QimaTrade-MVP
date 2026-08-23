"use client";

import { useFormStatus } from "react-dom";

type Props = {
  children: React.ReactNode;
  loadingText?: string;
  className?: string;
  disabled?: boolean;
};

export default function SubmitButton({
  children,
  loadingText = "Loading...",
  className = "",
  disabled = false,
}: Props) {
  const { pending } = useFormStatus();
  const isDisabled = disabled || pending;

  return (
    <button
      type="submit"
      disabled={isDisabled}
      aria-disabled={isDisabled}
      className={`relative inline-flex items-center justify-center transition-all duration-200 ${
        pending ? "cursor-wait opacity-80" : ""
      } ${className}`}
    >
      {pending && (
        <span
          aria-hidden="true"
          className="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"
        />
      )}
      <span className={pending ? "animate-pulse" : ""}>
        {pending ? loadingText : children}
      </span>
    </button>
  );
}
