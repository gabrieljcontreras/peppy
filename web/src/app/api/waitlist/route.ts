import { appendToWaitlistSheet, SheetWriteError } from "@/lib/sheets";

const PHONE_RE = /^\+?[1-9]\d{6,14}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function normalizePhone(raw: string): string {
  return raw.replace(/[\s\-().]+/g, "");
}

export async function POST(request: Request) {
  let payload: { name?: unknown; phone?: unknown; email?: unknown };
  try {
    payload = await request.json();
  } catch {
    return Response.json({ detail: "Invalid request." }, { status: 400 });
  }

  const name = typeof payload.name === "string" ? payload.name.trim() : "";
  const rawPhone = typeof payload.phone === "string" ? payload.phone : "";
  const rawEmail = typeof payload.email === "string" ? payload.email : "";

  if (!name) {
    return Response.json(
      { detail: "Please enter your name." },
      { status: 400 },
    );
  }

  const phone = rawPhone ? normalizePhone(rawPhone) : "";
  if (phone && !PHONE_RE.test(phone)) {
    return Response.json(
      { detail: "Please enter a valid phone number." },
      { status: 400 },
    );
  }

  const email = rawEmail ? rawEmail.trim().toLowerCase() : "";
  if (email && !EMAIL_RE.test(email)) {
    return Response.json(
      { detail: "Please enter a valid email address." },
      { status: 400 },
    );
  }

  if (!phone && !email) {
    return Response.json(
      { detail: "Add a phone number or email so we can reach you." },
      { status: 400 },
    );
  }

  try {
    await appendToWaitlistSheet({ name, phone, email });
  } catch (err) {
    if (err instanceof SheetWriteError) {
      console.error("[waitlist]", err.message);
    } else {
      console.error("[waitlist] unexpected error", err);
    }
    return Response.json(
      { detail: "Unable to save your spot. Please try again." },
      { status: 503 },
    );
  }

  return Response.json({
    message: "You're on the list! We'll be in touch.",
    name,
  });
}
