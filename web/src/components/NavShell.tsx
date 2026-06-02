"use client";

import { useEffect, useState } from "react";

export function NavShell({ children }: { children: React.ReactNode }) {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    let ticking = false;
    const onScroll = () => {
      if (!ticking) {
        requestAnimationFrame(() => {
          setScrolled(window.scrollY > 20);
          ticking = false;
        });
        ticking = true;
      }
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div className="sticky top-4 z-50 flex justify-center px-4 pointer-events-none">
      <nav
        className={`peppy-fade peppy-fade-1 pointer-events-auto flex items-center gap-2 rounded-full border py-2 pl-5 pr-2 backdrop-blur-md transition-all duration-300 ${
          scrolled
            ? "border-border-default bg-cream-50/95 shadow-[0_4px_24px_rgba(30,32,38,0.10)]"
            : "border-border-subtle bg-cream-50/85 shadow-[0_2px_24px_rgba(30,32,38,0.06)]"
        }`}
      >
        {children}
      </nav>
    </div>
  );
}
