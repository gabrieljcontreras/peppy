import Link from "next/link";
import { ButtonHTMLAttributes, AnchorHTMLAttributes } from "react";

type ButtonVariant = "primary" | "secondary" | "tertiary";
type ButtonSize = "md" | "lg";

interface ButtonBaseProps {
  variant?: ButtonVariant;
  size?: ButtonSize;
  children: React.ReactNode;
  className?: string;
}

type ButtonAsButton = ButtonBaseProps &
  ButtonHTMLAttributes<HTMLButtonElement> & {
    href?: never;
  };

type ButtonAsLink = ButtonBaseProps &
  Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "href"> & {
    href: string;
  };

type ButtonProps = ButtonAsButton | ButtonAsLink;

export function Button({
  variant = "primary",
  size = "md",
  children,
  className = "",
  ...props
}: ButtonProps) {
  const base =
    "group inline-flex items-center justify-center gap-2 rounded-full font-semibold tracking-[-0.005em] cursor-pointer select-none transition-[background-color,color,border-color,transform] duration-200 ease-out will-change-transform active:scale-[0.98] disabled:opacity-40 disabled:pointer-events-none";

  const variants: Record<ButtonVariant, string> = {
    primary:
      "bg-[var(--color-ink-900)] text-[var(--color-cream-100)] hover:bg-[var(--color-ink-600)]",
    secondary:
      "bg-transparent text-[var(--color-ink-900)] border-[1.5px] border-[var(--color-ink-200)] hover:border-[var(--color-ink-900)] hover:bg-[var(--color-cream-50)]",
    tertiary:
      "bg-transparent text-[var(--color-rust-500)] hover:text-[var(--color-rust-700)]",
  };

  const sizes: Record<ButtonSize, string> = {
    md: "h-11 px-6 text-[15px]",
    lg: "h-[52px] px-7 text-base",
  };

  const cn = `${base} ${variants[variant]} ${sizes[size]} ${className}`;

  if ("href" in props && props.href) {
    const { href, ...rest } = props as ButtonAsLink;
    return (
      <Link href={href} className={cn} {...rest}>
        {children}
      </Link>
    );
  }

  return (
    <button className={cn} {...(props as ButtonAsButton)}>
      {children}
    </button>
  );
}
