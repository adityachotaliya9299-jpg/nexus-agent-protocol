"use client";

import { type ReactNode } from "react";

interface TxButtonProps {
  onClick: () => void;
  isPending: boolean;       // wallet signing
  isConfirming: boolean;    // waiting for block
  isSuccess: boolean;
  disabled?: boolean;
  className?: string;
  children: ReactNode;
  pendingText?: string;
  confirmingText?: string;
  successText?: string;
}

export function TxButton({
  onClick,
  isPending,
  isConfirming,
  isSuccess,
  disabled = false,
  className = "btn-primary",
  children,
  pendingText = "Sign in wallet...",
  confirmingText = "Confirming...",
  successText = "Done ✓",
}: TxButtonProps) {
  const busy = isPending || isConfirming;

  let label: ReactNode = children;
  if (isPending) label = (
    <span className="flex items-center gap-2">
      <span className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin" />
      {pendingText}
    </span>
  );
  else if (isConfirming) label = (
    <span className="flex items-center gap-2">
      <span className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin" />
      {confirmingText}
    </span>
  );
  else if (isSuccess) label = successText;

  return (
    <button
      onClick={onClick}
      disabled={disabled || busy}
      className={`${className} ${(disabled || busy) ? "opacity-60 cursor-not-allowed" : ""} ${isSuccess ? "!bg-emerald-500 !text-white" : ""} transition-all`}
    >
      {label}
    </button>
  );
}