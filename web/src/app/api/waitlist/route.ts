import { apiFetch, ApiError } from "@/lib/api";

export async function POST(request: Request) {
  try {
    const { email } = await request.json();

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return Response.json(
        { detail: "Please enter a valid email address." },
        { status: 400 },
      );
    }

    const data = await apiFetch("/api/v1/waitlist", {
      method: "POST",
      body: JSON.stringify({ email }),
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
