import { NextResponse } from "next/server";

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

    if (!["feature", "bug", "contact"].includes(type)) {
      return NextResponse.json(
        { detail: "Invalid feedback type." },
        { status: 400 },
      );
    }

    const apiUrl = process.env.API_URL || "http://localhost:8001";

    try {
      await fetch(`${apiUrl}/api/v1/feedback`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type, name, email, message }),
      });
    } catch {
      // Backend may not have this endpoint yet; that's fine, we log and succeed
      console.log("[feedback]", { type, name, email, message: message.slice(0, 100) });
    }

    return NextResponse.json({ status: "ok" });
  } catch {
    return NextResponse.json(
      { detail: "Invalid request." },
      { status: 400 },
    );
  }
}
