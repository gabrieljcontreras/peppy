import Link from "next/link";

export function Footer() {
  return (
    <footer className="border-t border-[var(--color-ink-100)] bg-[var(--color-cream-100)] py-16">
      <div className="mx-auto max-w-6xl px-6 md:px-8">
        <div className="flex flex-col md:flex-row justify-between items-start gap-10">
          <div className="max-w-sm">
            <Link href="/" className="peppy-wordmark text-2xl">
              peppy
            </Link>
            <p className="mt-3 text-[15px] text-[var(--color-ink-500)] leading-relaxed">
              Track your protocol. Understand your body.
            </p>
          </div>

          <nav className="grid grid-cols-2 sm:grid-cols-3 gap-x-12 gap-y-3 text-sm">
            <FooterLink href="/features">Features</FooterLink>
            <FooterLink href="/about">About</FooterLink>
            <FooterLink href="/waitlist">Waitlist</FooterLink>
            <FooterLink href="/about">Privacy</FooterLink>
            <FooterLink href="/about">Terms</FooterLink>
            <FooterLink href="mailto:hi@peppy.app">Contact</FooterLink>
          </nav>
        </div>

        <div className="mt-12 pt-6 border-t border-[var(--color-ink-100)] flex flex-col sm:flex-row justify-between gap-2 text-[13px] text-[var(--color-ink-400)]">
          <p>© {new Date().getFullYear()} peppy. All rights reserved.</p>
          <p>Made with care in California.</p>
        </div>
      </div>
    </footer>
  );
}

function FooterLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="text-[var(--color-ink-500)] hover:text-[var(--color-ink-900)] transition-colors duration-200"
    >
      {children}
    </Link>
  );
}
