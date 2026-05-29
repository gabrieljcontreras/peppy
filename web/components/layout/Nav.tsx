"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "motion/react";

export function Nav() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <motion.nav
      initial={{ y: -24, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.5, ease: [0.2, 0.8, 0.2, 1] }}
      className={`fixed top-0 left-0 right-0 z-50 transition-[background-color,border-color,backdrop-filter] duration-300 ${
        scrolled
          ? "bg-[var(--color-cream-100)]/85 backdrop-blur-xl border-b border-[var(--color-ink-100)]"
          : "bg-transparent border-b border-transparent"
      }`}
    >
      <div className="max-w-6xl mx-auto px-6 md:px-8 h-16 flex items-center justify-between">
        <Link
          href="/"
          className="peppy-wordmark text-2xl transition-transform duration-200 hover:scale-[1.03] active:scale-[0.98]"
        >
          peppy
        </Link>

        <div className="hidden md:flex items-center gap-1">
          <NavLink href="/features">Features</NavLink>
          <NavLink href="/about">About</NavLink>
          <Link
            href="/waitlist"
            className="ml-3 inline-flex h-10 items-center justify-center rounded-full bg-[var(--color-ink-900)] px-5 text-sm font-semibold text-[var(--color-cream-100)] transition-colors duration-200 hover:bg-[var(--color-ink-600)]"
          >
            Join waitlist
          </Link>
        </div>

        <button
          className="md:hidden -mr-2 p-2 cursor-pointer"
          onClick={() => setMobileMenuOpen((v) => !v)}
          aria-label="Toggle menu"
          aria-expanded={mobileMenuOpen}
        >
          <svg
            className="w-6 h-6 text-[var(--color-ink-900)]"
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            viewBox="0 0 24 24"
          >
            {mobileMenuOpen ? (
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            ) : (
              <path strokeLinecap="round" strokeLinejoin="round" d="M4 7h16M4 12h16M4 17h16" />
            )}
          </svg>
        </button>
      </div>

      <AnimatePresence>
        {mobileMenuOpen && (
          <motion.div
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.18, ease: [0.2, 0.8, 0.2, 1] }}
            className="md:hidden bg-[var(--color-cream-100)] border-t border-[var(--color-ink-100)] px-6 md:px-8 py-4"
          >
            <div className="flex flex-col gap-1">
              <MobileLink href="/features" onClick={() => setMobileMenuOpen(false)}>
                Features
              </MobileLink>
              <MobileLink href="/about" onClick={() => setMobileMenuOpen(false)}>
                About
              </MobileLink>
              <Link
                href="/waitlist"
                className="mt-3 inline-flex h-12 items-center justify-center rounded-full bg-[var(--color-ink-900)] text-base font-semibold text-[var(--color-cream-100)]"
                onClick={() => setMobileMenuOpen(false)}
              >
                Join waitlist
              </Link>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.nav>
  );
}

function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="relative px-4 py-2 text-sm font-medium text-[var(--color-ink-500)] transition-colors duration-200 hover:text-[var(--color-ink-900)] rounded-full"
    >
      {children}
    </Link>
  );
}

function MobileLink({
  href,
  children,
  onClick,
}: {
  href: string;
  children: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <Link
      href={href}
      onClick={onClick}
      className="py-3 text-base font-medium text-[var(--color-ink-900)]"
    >
      {children}
    </Link>
  );
}
