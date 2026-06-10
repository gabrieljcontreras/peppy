import { google } from "googleapis";

const SCOPES = ["https://www.googleapis.com/auth/spreadsheets"];

function getAuth() {
  const email = process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL;
  const key = process.env.GOOGLE_PRIVATE_KEY?.replace(/\\n/g, "\n");
  const sheetId = process.env.GOOGLE_SHEET_ID;

  if (!email || !key || !sheetId) return null;

  return {
    auth: new google.auth.JWT({ email, key, scopes: SCOPES }),
    sheetId,
  };
}

export async function appendToWaitlistSheet(phone: string, email?: string) {
  const config = getAuth();
  if (!config) return;

  const sheets = google.sheets({ version: "v4", auth: config.auth });

  await sheets.spreadsheets.values.append({
    spreadsheetId: config.sheetId,
    range: "Sheet1!A:C",
    valueInputOption: "USER_ENTERED",
    requestBody: {
      values: [[phone, email || "", new Date().toISOString()]],
    },
  });
}
