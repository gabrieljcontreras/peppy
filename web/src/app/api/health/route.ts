export const dynamic = "force-dynamic";

export async function GET() {
  const apiUrl =
    process.env.API_URL ||
    process.env.NEXT_PUBLIC_API_URL ||
    "http://localhost:8001";

  try {
    const res = await fetch(`${apiUrl}/health`, {
      signal: AbortSignal.timeout(5000),
    });
    const data = await res.json();
    return Response.json({ web: "healthy", api: data.status ?? "healthy" });
  } catch {
    return Response.json({ web: "healthy", api: "unreachable" });
  }
}
