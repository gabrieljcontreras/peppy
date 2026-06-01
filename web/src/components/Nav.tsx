import { Logo, Wordmark } from "./Logo";

export function Nav() {
  return (
    <div className="sticky top-4 z-50 flex justify-center px-4 pointer-events-none">
      <nav className="peppy-fade peppy-fade-1 pointer-events-auto flex items-center gap-2 rounded-full border border-border-subtle bg-cream-50/85 backdrop-blur-md py-2 pl-5 pr-2 shadow-[0_2px_24px_rgba(30,32,38,0.06)]">
        <a href="#" className="inline-flex items-center gap-2">
          <Logo />
          <Wordmark className="text-[20px]" />
        </a>
        <div className="ml-4 hidden items-center gap-1 sm:flex">
          <a
            className="rounded-full px-3.5 py-2 text-[15px] whitespace-nowrap text-ink-700 transition-colors hover:text-rust-500"
            href="#features"
          >
            Features
          </a>
          <a
            className="rounded-full px-3.5 py-2 text-[15px] whitespace-nowrap text-ink-700 transition-colors hover:text-rust-500"
            href="#more"
          >
            More
          </a>
        </div>
        <a
          href="#download"
          className="ml-2 inline-flex items-center gap-2 rounded-full bg-ink-900 px-4 py-2.5 text-[14px] font-medium text-cream-50 transition-all hover:bg-ink-700 hover:-translate-y-px active:translate-y-0"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M17.6 13.1c-.04-3.1 2.53-4.6 2.65-4.67-1.45-2.12-3.7-2.4-4.5-2.44-1.92-.2-3.74 1.13-4.71 1.13-.98 0-2.48-1.1-4.07-1.07-2.1.03-4.04 1.22-5.12 3.1-2.18 3.78-.56 9.37 1.57 12.44 1.04 1.5 2.28 3.18 3.9 3.12 1.56-.06 2.15-1.01 4.03-1.01 1.87 0 2.4 1.01 4.06.98 1.67-.03 2.74-1.52 3.77-3.04 1.18-1.74 1.67-3.43 1.7-3.52-.04-.02-3.26-1.25-3.3-4.92ZM14.7 4.06c.86-1.04 1.44-2.49 1.28-3.93-1.24.05-2.74.82-3.62 1.86-.79.93-1.48 2.4-1.3 3.82 1.38.1 2.78-.7 3.64-1.75Z" />
          </svg>
          Get the app
        </a>
      </nav>
    </div>
  );
}
