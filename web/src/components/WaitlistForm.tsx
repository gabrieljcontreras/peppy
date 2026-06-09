"use client";

import { useState } from "react";

type Status = "idle" | "loading" | "success" | "error";

const PHONE_RE = /^\+?[1-9]\d{6,14}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function WaitlistForm() {
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [showEmail, setShowEmail] = useState(false);
  const [status, setStatus] = useState<Status>("idle");
  const [errorMsg, setErrorMsg] = useState("");

  const digits = phone.replace(/[\s\-().]+/g, "");
  const isValidPhone = PHONE_RE.test(digits);
  const isValidEmail = !email || EMAIL_RE.test(email);
  const canSubmit = isValidPhone && isValidEmail;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;

    setStatus("loading");
    setErrorMsg("");

    try {
      const payload: { phone: string; email?: string } = { phone: digits };
      if (email) payload.email = email;

      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => ({ detail: "Something went wrong." }));
        throw new Error(data.detail || "Something went wrong.");
      }

      setStatus("success");
    } catch (err) {
      setStatus("error");
      setErrorMsg(err instanceof Error ? err.message : "Something went wrong.");
    }
  }

  if (status === "success") {
    return (
      <div className="rounded-2xl border border-success/30 bg-success/10 px-6 py-8 text-center">
        <div className="text-[28px]">&#10003;</div>
        <h3 className="mt-2 text-[20px] font-semibold text-ink-900">
          You&apos;re on the list
        </h3>
        <p className="mt-1 text-[15px] text-ink-700">
          We&apos;ll reach out when your spot is ready.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3">
      <div className="flex flex-col gap-3 sm:flex-row">
        <input
          type="tel"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="+1 (555) 123-4567"
          required
          className="flex-1 rounded-full border border-border-default bg-cream-50 px-5 py-3.5 text-[15px] text-ink-900 placeholder:text-ink-500 outline-none transition-colors focus:border-rust-500 focus:ring-2 focus:ring-rust-500/20"
        />
        <button
          type="submit"
          disabled={!canSubmit || status === "loading"}
          className="rounded-full bg-ink-900 px-6 py-3.5 text-[15px] font-semibold text-cream-50 transition-all hover:bg-ink-700 hover:-translate-y-px disabled:opacity-50 disabled:hover:translate-y-0 disabled:cursor-not-allowed"
        >
          {status === "loading" ? "Joining..." : "Join the waitlist"}
        </button>
      </div>

      {!showEmail && (
        <button
          type="button"
          onClick={() => setShowEmail(true)}
          className="self-start text-[13px] text-ink-500 underline decoration-ink-300 underline-offset-2 transition-colors hover:text-rust-500 hover:decoration-rust-400"
        >
          + Add an email too
        </button>
      )}

      {showEmail && (
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@example.com (optional)"
          className="rounded-full border border-border-default bg-cream-50 px-5 py-3.5 text-[15px] text-ink-900 placeholder:text-ink-500 outline-none transition-colors focus:border-rust-500 focus:ring-2 focus:ring-rust-500/20"
        />
      )}

      {status === "error" && (
        <p className="text-[13px] text-rust-600">{errorMsg}</p>
      )}
    </form>
  );
}
