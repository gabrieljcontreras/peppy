interface CardProps {
  children: React.ReactNode;
  className?: string;
  padding?: "sm" | "md" | "lg";
}

const paddingStyles = {
  sm: "p-4",
  md: "p-5 md:p-6",
  lg: "p-6 md:p-8",
};

export function Card({ children, className = "", padding = "md" }: CardProps) {
  return (
    <div
      className={`bg-[var(--color-card)] rounded-[var(--radius-md)] border border-[var(--color-ink-100)] ${paddingStyles[padding]} ${className}`}
    >
      {children}
    </div>
  );
}
