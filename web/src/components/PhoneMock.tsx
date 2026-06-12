import Image from "next/image";

/* Real app screens exported from Peppy IOS.fig (853×1844). */
const SCREEN_W = 853;
const SCREEN_H = 1844;

type PhoneFrameProps = {
  src: string;
  alt: string;
  width?: number;
  priority?: boolean;
  className?: string;
  style?: React.CSSProperties;
};

export function PhoneFrame({
  src,
  alt,
  width = 300,
  priority = false,
  className = "",
  style,
}: PhoneFrameProps) {
  const pad = Math.max(8, Math.round(width * 0.032));
  const outer = Math.round(width * 0.155);

  return (
    <div
      className={`flex-none bg-ink-900 shadow-[0_32px_64px_-24px_rgba(33,33,38,0.4),0_12px_24px_-12px_rgba(33,33,38,0.25)] ${className}`}
      style={{ width, padding: pad, borderRadius: outer, ...style }}
    >
      <div
        className="overflow-hidden bg-cream-100"
        style={{ borderRadius: outer - pad }}
      >
        <Image
          src={src}
          alt={alt}
          width={SCREEN_W}
          height={SCREEN_H}
          priority={priority}
          sizes={`${width}px`}
          quality={90}
          className="block h-auto w-full"
        />
      </div>
    </div>
  );
}
