export function Logo({ size = 22 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
    >
      <path d="M4 18 12 4l8 14H4Z" fill="#1E2026" />
      <path d="M9 18l3-6 3 6H9Z" fill="#E07A5F" />
    </svg>
  );
}

export function Wordmark({ className = "" }: { className?: string }) {
  return (
    <span
      className={`font-wordmark text-rust-500 leading-none tracking-tight ${className}`}
      style={{ letterSpacing: "-0.04em" }}
    >
      peppy
    </span>
  );
}
