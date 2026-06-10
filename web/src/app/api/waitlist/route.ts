import { apiFetch, ApiError } from "@/lib/api";
import { appendToWaitlistSheet } from "@/lib/sheets";

const PHONE_RE = /^\+?[1-9]\d{6,14}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function POST(request: Request) {
  try {
    const { phone, email } = await request.json();

    const digits = (phone || "").replace(/[\s\-().]+/g, "");
    if (!digits || !PHONE_RE.test(digits)) {
      return Response.json(
        { detail: "Please enter a valid phone number." },
        { status: 400 },
      );
    }

    if (email && !EMAIL_RE.test(email)) {
      return Response.json(
        { detail: "Please enter a valid email address." },
        { status: 400 },
      );
    }

    const payload: { phone: string; email?: string } = { phone: digits };
    if (email) payload.email = email;

    // Write to Google Sheet (fire-and-forget — don't block the response)
    const sheetPromise = appendToWaitlistSheet(digits, email).catch(() => {});

    // Try the backend as well
    let backendOk = false;
    let data: unknown = null;
    try {
      data = await apiFetch("/api/v1/waitlist", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      backendOk = true;
    } catch {
      // Backend unreachable — sheet is the fallback
    }

    await sheetPromise;

    if (backendOk) {
      return Response.json(data);
    }

    return Response.json({
      message: "You're on the list! We'll be in touch.",
      phone: digits,
      email: email || null,
    });
  } catch (err) {
    if (err instanceof ApiError) {
      return Response.json(
        { detail: err.message },
        { status: err.status },
      );
    }
    return Response.json(
      { detail: "Unable to reach the server. Please try again later." },
      { status: 503 },
    );
  }
}
