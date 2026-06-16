export type WaitlistRow = {
  name: string;
  phone: string;
  email: string;
};

export class SheetWriteError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SheetWriteError";
  }
}

export async function appendToWaitlistSheet(row: WaitlistRow): Promise<void> {
  const url = process.env.WAITLIST_SHEET_WEBHOOK_URL;
  const secret = process.env.WAITLIST_SHEET_SECRET;

  if (!url || !secret) {
    throw new SheetWriteError("Waitlist sheet webhook is not configured.");
  }

  const body = {
    secret,
    name: row.name,
    phone: row.phone,
    email: row.email,
    timestamp: new Date().toISOString(),
  };

  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch (err) {
    throw new SheetWriteError(
      `Sheet webhook fetch failed: ${(err as Error).message}`,
    );
  }

  if (!res.ok) {
    throw new SheetWriteError(
      `Sheet webhook returned status ${res.status}`,
    );
  }
}
