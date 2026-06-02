"use client";

import { useScrollReveal } from "@/hooks/useScrollReveal";

type Direction = "up" | "down" | "left" | "right" | "none";

interface RevealProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  direction?: Direction;
  duration?: number;
}

const offsets: Record<Direction, string> = {
  up: "translateY(24px)",
  down: "translateY(-24px)",
  left: "translateX(24px)",
  right: "translateX(-24px)",
  none: "none",
};

export function Reveal({
  children,
  className = "",
  delay = 0,
  direction = "up",
  duration = 600,
}: RevealProps) {
  const { ref, isVisible } = useScrollReveal();

  return (
    <div
      ref={ref}
      className={className}
      style={{
        opacity: isVisible ? 1 : 0,
        transform: isVisible ? "none" : offsets[direction],
        transition: `opacity ${duration}ms cubic-bezier(0.19, 1, 0.22, 1) ${delay}ms, transform ${duration}ms cubic-bezier(0.19, 1, 0.22, 1) ${delay}ms`,
        willChange: isVisible ? "auto" : "opacity, transform",
      }}
    >
      {children}
    </div>
  );
}
