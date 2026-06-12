"use client";

import { useState } from "react";
import { PhoneFrame } from "./PhoneMock";
import { Reveal } from "./Reveal";

type AccordionItem = {
  title: string;
  body: string;
  src: string;
  alt: string;
};

const accordion: AccordionItem[] = [
  {
    title: "AI weekly summary",
    body: "A short, plain-English readout of how your week went and what to try next.",
    src: "/app/ai_insights.png",
    alt: "peppy home — AI weekly summary with key metrics and next steps",
  },
  {
    title: "Lab uploads",
    body: "Snap a photo or attach a PDF. peppy parses the values and tracks them over time.",
    src: "/app/lab_more.png",
    alt: "peppy lab uploads — attach a PDF or photo and track values over time",
  },
  {
    title: "Provider-ready exports",
    body: "Generate a clean PDF of your protocol and metrics to share with your clinician.",
    src: "/app/protocol-detail.webp",
    alt: "peppy protocol detail — clean export ready to share with your clinician",
  },
  {
    title: "Guided onboarding",
    body: "Answer a few questions and peppy sets up your protocol, reminders, and baselines for you.",
    src: "/app/onboarding_slide_1.png",
    alt: "peppy guided onboarding — quick setup of protocol, reminders, and baselines",
  },
];

export function NotAll() {
  const [activeIndex, setActiveIndex] = useState(0);

  return (
    <section className="py-24">
      <div className="mx-auto grid max-w-[1180px] items-center gap-16 px-6 md:grid-cols-[1.05fr_0.95fr]">
        <div>
          <Reveal>
            <h2 className="text-[clamp(32px,4.4vw,56px)] font-semibold leading-[1.05] tracking-[-0.02em] text-ink-900">
              And that&apos;s
              <br />
              <em className="font-serif italic font-medium">not all.</em>
            </h2>
            <p className="mt-3 text-ink-700">peppy also includes:</p>
          </Reveal>

          <div
            role="tablist"
            aria-label="Additional peppy features"
            className="mt-8 flex flex-col gap-3"
          >
            {accordion.map((row, i) => {
              const isActive = i === activeIndex;
              return (
                <Reveal key={row.title} delay={i * 80}>
                  <button
                    type="button"
                    role="tab"
                    id={`notall-tab-${i}`}
                    aria-selected={isActive}
                    aria-controls="notall-tabpanel"
                    tabIndex={isActive ? 0 : -1}
                    onClick={() => setActiveIndex(i)}
                    onKeyDown={(e) => {
                      if (e.key === "ArrowDown" || e.key === "ArrowRight") {
                        e.preventDefault();
                        setActiveIndex((i + 1) % accordion.length);
                      } else if (e.key === "ArrowUp" || e.key === "ArrowLeft") {
                        e.preventDefault();
                        setActiveIndex(
                          (i - 1 + accordion.length) % accordion.length,
                        );
                      } else if (e.key === "Home") {
                        e.preventDefault();
                        setActiveIndex(0);
                      } else if (e.key === "End") {
                        e.preventDefault();
                        setActiveIndex(accordion.length - 1);
                      }
                    }}
                    className={`group flex w-full items-start justify-between gap-4 rounded-2xl border p-6 text-left transition-all duration-300 focus:outline-none focus-visible:ring-2 focus-visible:ring-rust-500/40 focus-visible:ring-offset-2 focus-visible:ring-offset-cream-50 ${
                      isActive
                        ? "border-rust-500/30 bg-rust-500/10"
                        : "border-border-subtle bg-cream-50 hover:border-border-default hover:bg-cream-200/60"
                    }`}
                  >
                    <div>
                      <h3 className="text-[18px] font-semibold text-ink-900">
                        {row.title}
                      </h3>
                      <p className="mt-1 text-[14px] text-ink-700">{row.body}</p>
                    </div>
                    <span
                      aria-hidden="true"
                      className={`grid h-9 w-9 flex-none place-items-center rounded-full border transition-all ${
                        isActive
                          ? "border-ink-900 bg-ink-900 text-cream-50"
                          : "border-border-subtle text-ink-900 group-hover:border-ink-900 group-hover:bg-ink-900 group-hover:text-cream-50 group-hover:translate-x-1"
                      }`}
                    >
                      <svg
                        width="14"
                        height="14"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                      >
                        <path d="M5 12h14M13 6l6 6-6 6" />
                      </svg>
                    </span>
                  </button>
                </Reveal>
              );
            })}
          </div>
        </div>

        <Reveal direction="left" delay={150}>
          <div
            id="notall-tabpanel"
            role="tabpanel"
            aria-labelledby={`notall-tab-${activeIndex}`}
            className="flex justify-center"
          >
            <div className="relative" style={{ width: 300 }}>
              {accordion.map((row, i) => (
                <div
                  key={row.title}
                  className={`transition-opacity duration-500 ease-out ${
                    i === activeIndex
                      ? "relative opacity-100"
                      : "pointer-events-none absolute inset-0 opacity-0"
                  }`}
                  aria-hidden={i !== activeIndex}
                >
                  <PhoneFrame
                    src={row.src}
                    alt={row.alt}
                    width={300}
                    priority={i === 0}
                  />
                </div>
              ))}
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
