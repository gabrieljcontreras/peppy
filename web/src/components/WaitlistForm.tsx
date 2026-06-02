"use client";

import { useState } from "react";

type Status = "idle" | "loading" | "success" | "error";

export function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [errorMsg, setErrorMsg] = useState("");

  const isValidEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!isValidEmail) return;

    setStatus("loading");
    setErrorMsg("");

    try {
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
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
    <form onSubmit={handleSubmit} className="flex flex-col gap-3 sm:flex-row">
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="you@example.com"
        required
        className="flex-1 rounded-full border border-border-default bg-cream-50 px-5 py-3.5 text-[15px] text-ink-900 placeholder:text-ink-500 outline-none transition-colors focus:border-rust-500 focus:ring-2 focus:ring-rust-500/20"
      />
      <button
        type="submit"
        disabled={!isValidEmail || status === "loading"}
        className="rounded-full bg-ink-900 px-6 py-3.5 text-[15px] font-semibold text-cream-50 transition-all hover:bg-ink-700 hover:-translate-y-px disabled:opacity-50 disabled:hover:translate-y-0 disabled:cursor-not-allowed"
      >
        {status === "loading" ? "Joining..." : "Join the waitlist"}
      </button>
      {status === "error" && (
        <p className="text-[13px] text-rust-600 sm:absolute sm:mt-14">
          {errorMsg}
        </p>
      )}
    </form>
  );
}
