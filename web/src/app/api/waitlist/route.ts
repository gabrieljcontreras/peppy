import { apiFetch, ApiError } from "@/lib/api";

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

    const data = await apiFetch("/api/v1/waitlist", {
      method: "POST",
      body: JSON.stringify(payload),
    });

    return Response.json(data);
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
