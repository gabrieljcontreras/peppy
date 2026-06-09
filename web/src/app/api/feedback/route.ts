import { NextResponse } from "next/server";

const ROUTING: Record<string, string> = {
  feature: "business@get-peppy.com",
  bug: "business@get-peppy.com",
  contact: "business@get-peppy.com",
  legal: "legal@get-peppy.com",
};

const SUBJECT_PREFIX: Record<string, string> = {
  feature: "[Feature Request]",
  bug: "[Bug Report]",
  contact: "[Contact]",
  legal: "[Legal]",
};

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { type, name, email, message } = body;

    if (!message || typeof message !== "string" || !message.trim()) {
      return NextResponse.json(
        { detail: "Message is required." },
        { status: 400 },
      );
    }

    if (!["feature", "bug", "contact", "legal"].includes(type)) {
      return NextResponse.json(
        { detail: "Invalid feedback type." },
        { status: 400 },
      );
    }

    const to = ROUTING[type];
    const subject = `${SUBJECT_PREFIX[type]} ${name || "Anonymous"}`;
    const text = [
      `From: ${name || "Anonymous"}${email ? ` <${email}>` : ""}`,
      `Type: ${type}`,
      "",
      message,
    ].join("\n");

    const apiUrl = process.env.API_URL || "http://localhost:8001";

    try {
      await fetch(`${apiUrl}/api/v1/feedback/email`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ to, subject, text, reply_to: email || undefined }),
      });
    } catch {
      console.log("[feedback]", { to, subject, type, name, email, message: message.slice(0, 100) });
    }

    return NextResponse.json({ status: "ok" });
  } catch {
    return NextResponse.json(
      { detail: "Invalid request." },
      { status: 400 },
    );
  }
}
