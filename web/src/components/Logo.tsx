export function Logo({ size = 22 }: { size?: number }) {
  return (
    <img
      src="/peppy-logo.png"
      alt="peppy"
      width={size}
      height={size}
      aria-hidden="true"
      style={{ objectFit: "contain" }}
    />
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
