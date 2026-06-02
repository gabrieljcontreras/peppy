import Link from "next/link";
import { Logo, Wordmark } from "./Logo";
import { NavShell } from "./NavShell";

export function Nav() {
  return (
    <NavShell>
      <Link href="/" className="inline-flex items-center gap-2">
        <Logo />
        <Wordmark className="text-[20px]" />
      </Link>
      <div className="ml-4 hidden items-center gap-1 sm:flex">
        <Link
          className="rounded-full px-3.5 py-2 text-[15px] whitespace-nowrap text-ink-700 transition-colors hover:text-rust-500"
          href="/#features"
        >
          Features
        </Link>
        <Link
          className="rounded-full px-3.5 py-2 text-[15px] whitespace-nowrap text-ink-700 transition-colors hover:text-rust-500"
          href="/#more"
        >
          More
        </Link>
      </div>
      <Link
        href="/waitlist"
        className="ml-2 inline-flex items-center gap-2 rounded-full bg-ink-900 px-4 py-2.5 text-[14px] font-medium text-cream-50 transition-all hover:bg-ink-700 hover:-translate-y-px hover:shadow-[0_4px_16px_rgba(30,32,38,0.2)] active:translate-y-0"
      >
        Join waitlist
      </Link>
    </NavShell>
  );
}
