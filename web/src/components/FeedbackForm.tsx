"use client";

import { useState } from "react";

type Status = "idle" | "loading" | "success" | "error";

type FeedbackFormProps = {
  type: "feature" | "bug" | "contact";
  successMessage: string;
  placeholder?: string;
  buttonLabel?: string;
};

export function FeedbackForm({
  type,
  successMessage,
  placeholder = "Tell us more...",
  buttonLabel = "Send",
}: FeedbackFormProps) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [status, setStatus] = useState<Status>("idle");

  const isValid = message.trim().length > 0;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!isValid) return;

    setStatus("loading");

    try {
      const res = await fetch("/api/feedback", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type, name, email, message }),
      });

      if (!res.ok) {
        throw new Error("Something went wrong.");
      }

      setStatus("success");
    } catch {
      setStatus("error");
    }
  }

  if (status === "success") {
    return (
      <div className="rounded-2xl border border-success/30 bg-success/10 px-6 py-10 text-center">
        <div className="text-[32px]">&#10003;</div>
        <p className="mt-3 text-[17px] leading-relaxed text-ink-900">
          {successMessage}
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div className="grid gap-4 sm:grid-cols-2">
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Name (optional)"
          className="rounded-xl border border-border-default bg-cream-50 px-4 py-3.5 text-[15px] text-ink-900 placeholder:text-ink-500 outline-none transition-colors focus:border-rust-500 focus:ring-2 focus:ring-rust-500/20"
        />
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="Email (optional)"
          className="rounded-xl border border-border-default bg-cream-50 px-4 py-3.5 text-[15px] text-ink-900 placeholder:text-ink-500 outline-none transition-colors focus:border-rust-500 focus:ring-2 focus:ring-rust-500/20"
        />
      </div>
      <textarea
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        placeholder={placeholder}
        required
        rows={6}
        className="resize-none rounded-xl border border-border-default bg-cream-50 px-4 py-3.5 text-[15px] text-ink-900 placeholder:text-ink-500 outline-none transition-colors focus:border-rust-500 focus:ring-2 focus:ring-rust-500/20"
      />
      <button
        type="submit"
        disabled={!isValid || status === "loading"}
        className="self-start rounded-full bg-ink-900 px-6 py-3.5 text-[15px] font-semibold text-cream-50 transition-all hover:bg-ink-700 hover:-translate-y-px disabled:opacity-50 disabled:hover:translate-y-0 disabled:cursor-not-allowed"
      >
        {status === "loading" ? "Sending..." : buttonLabel}
      </button>
      {status === "error" && (
        <p className="text-[13px] text-rust-600">
          Something went wrong. Please try again.
        </p>
      )}
    </form>
  );
}
