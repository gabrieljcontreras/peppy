"use client";

import { useMemo, useState } from "react";
import {
  helpCategories,
  helpEntries,
  type HelpCategory,
} from "@/lib/help-content";

export function HelpSearch() {
  const [activeCategory, setActiveCategory] = useState<HelpCategory | "All">("All");
  const [query, setQuery] = useState("");
  const normalizedQuery = query.trim().toLocaleLowerCase();

  const results = useMemo(() => {
    return helpEntries.filter((entry) => {
      if (normalizedQuery) {
        const searchableText = [
          entry.question,
          entry.answer,
          ...entry.keywords,
        ]
          .join(" ")
          .toLocaleLowerCase();
        return searchableText.includes(normalizedQuery);
      }

      return activeCategory === "All" || entry.category === activeCategory;
    });
  }, [activeCategory, normalizedQuery]);

  const categories: Array<HelpCategory | "All"> = ["All", ...helpCategories];

  return (
    <div>
      <label htmlFor="help-search" className="sr-only">
        Search help articles
      </label>
      <input
        id="help-search"
        type="search"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="Search help articles"
        className="w-full border-b border-border-subtle bg-transparent px-0 py-3 text-[16px] text-ink-900 outline-none placeholder:text-ink-500 focus:border-rust-500"
      />

      <div className="mt-5 flex gap-2 overflow-x-auto pb-1">
        {categories.map((category) => (
          <button
            key={category}
            type="button"
            aria-pressed={activeCategory === category}
            onClick={() => setActiveCategory(category)}
            className={`shrink-0 rounded-full px-3 py-2 text-[13px] font-medium transition-colors ${
              activeCategory === category
                ? "bg-ink-900 text-cream-50"
                : "bg-cream-50 text-ink-700 hover:bg-cream-100"
            }`}
          >
            {category}
          </button>
        ))}
      </div>

      <div
        role="group"
        aria-label="Help Center results"
        aria-live="polite"
        className="mt-8"
      >
        <p className="text-[14px] text-ink-500">
          {results.length} {results.length === 1 ? "result" : "results"}
        </p>

        {results.length > 0 ? (
          <div className="mt-3 divide-y divide-border-subtle">
            {results.map((entry) => (
              <details key={entry.question} className="py-5">
                <summary className="cursor-pointer list-none pr-8 text-[16px] font-semibold text-ink-900 marker:hidden">
                  {entry.question}
                </summary>
                <p className="mt-3 text-[15px] leading-[1.65] text-ink-700">
                  {entry.answer}
                </p>
              </details>
            ))}
          </div>
        ) : (
          <p className="mt-5 text-[15px] text-ink-700">
            No help articles match your search. Try a different term or contact
            support.
          </p>
        )}
      </div>
    </div>
  );
}
