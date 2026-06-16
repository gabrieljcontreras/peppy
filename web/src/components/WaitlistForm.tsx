"use client";

import { useMemo, useState } from "react";
import {
  randomPhoneSample,
  randomEmailSample,
} from "@/lib/placeholders";

type Status = "idle" | "loading" | "success" | "error";

const PHONE_RE = /^\+?[1-9]\d{6,14}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function normalizePhone(raw: string): string {
  return raw.replace(/[\s\-().]+/g, "");
}

export function WaitlistForm() {
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [errorMsg, setErrorMsg] = useState("");

  const phonePlaceholder = useMemo(() => randomPhoneSample(), []);
  const emailPlaceholder = useMemo(() => randomEmailSample(), []);

  const trimmedName = name.trim();
  const normalizedPhone = phone ? normalizePhone(phone) : "";
  const trimmedEmail = email.trim();

  const hasValidPhone = normalizedPhone !== "" && PHONE_RE.test(normalizedPhone);
  const hasValidEmail = trimmedEmail !== "" && EMAIL_RE.test(trimmedEmail);

  const phoneFieldValid = normalizedPhone === "" || hasValidPhone;
  const emailFieldValid = trimmedEmail === "" || hasValidEmail;

  const canSubmit =
    trimmedName.length > 0 &&
    phoneFieldValid &&
    emailFieldValid &&
    (hasValidPhone || hasValidEmail);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;

    setStatus("loading");
    setErrorMsg("");

    try {
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: trimmedName,
          phone: normalizedPhone,
          email: trimmedEmail,
        }),
      });

      if (!res.ok) {
        const data = await res
          .json()
          .catch(() => ({ detail: "Something went wrong." }));
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
      <div className="rounded-2xl border border-success/30 bg-success/10 p-6 text-center">
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
    <form
      onSubmit={handleSubmit}
      className="rounded-2xl border border-border-default bg-cream-50 p-6 text-left"
    >
      <div className="flex flex-col gap-4">
        <Field
          id="waitlist-name"
          label="Your name"
          value={name}
          onChange={setName}
          placeholder="Your full name"
          type="text"
          autoComplete="name"
          required
        />

        <Field
          id="waitlist-phone"
          label="Phone number"
          value={phone}
          onChange={setPhone}
          placeholder={phonePlaceholder}
          type="tel"
          autoComplete="tel"
        />

        <Field
          id="waitlist-email"
          label="Email"
          value={email}
          onChange={setEmail}
          placeholder={emailPlaceholder}
          type="email"
          autoComplete="email"
        />

        <p className="text-[13px] text-ink-500">
          We&apos;ll use whatever you prefer.
        </p>

        <button
          type="submit"
          disabled={!canSubmit || status === "loading"}
          className="w-full rounded-xl bg-ink-900 px-6 py-3.5 text-[15px] font-semibold text-cream-50 transition-all hover:bg-ink-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {status === "loading" ? "Joining..." : "Join the waitlist"}
        </button>

        {status === "error" && (
          <p className="text-[13px] text-rust-600">{errorMsg}</p>
        )}
      </div>
    </form>
  );
}

type FieldProps = {
  id: string;
  label: string;
  value: string;
  onChange: (next: string) => void;
  placeholder: string;
  type: "text" | "tel" | "email";
  autoComplete?: string;
  required?: boolean;
};

function Field({
  id,
  label,
  value,
  onChange,
  placeholder,
  type,
  autoComplete,
  required,
}: FieldProps) {
  return (
    <div className="flex flex-col gap-1.5">
      <label
        htmlFor={id}
        className="text-[13px] font-medium text-ink-700"
      >
        {label}
      </label>
      <input
        id={id}
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        autoComplete={autoComplete}
        required={required}
        className="rounded-xl border border-border-default bg-cream-50 px-4 py-3 text-[15px] text-ink-900 placeholder:text-ink-500 outline-none transition-colors focus:border-rust-500 focus:ring-2 focus:ring-rust-500/20"
      />
    </div>
  );
}
