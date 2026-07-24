import assert from "node:assert/strict";
import { chromium } from "playwright";

const baseUrl = process.env.URL ?? "http://localhost:3000";
const destinations = [
  ["About", "/about"],
  ["Contact", "/contact"],
  ["Bug report", "/feedback/bug"],
  ["Feature request", "/feedback/feature"],
  ["Terms", "/terms"],
  ["Privacy", "/privacy"],
];

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();

try {
  const helpResponse = await page.goto(`${baseUrl}/help`);
  assert.equal(helpResponse?.status(), 200, "Help Center should return 200");
  await page.getByRole("heading", { name: "Help Center" }).waitFor();

  const notificationFilter = page.locator("button", { hasText: "Notifications" });
  await notificationFilter.click();
  assert.equal(
    await page.getByRole("tab").count(),
    0,
    "Help category filters should use native button semantics, not tab roles",
  );
  await page
    .getByRole("button", { name: "Notifications", pressed: true })
    .waitFor();
  assert.equal(
    await notificationFilter.getAttribute("aria-pressed"),
    "true",
    "The selected category filter should expose its pressed state",
  );
  await page.getByText("What information appears in notifications?").waitFor();
  assert.equal(
    await page.getByText("How do I delete my account?", { exact: true }).count(),
    0,
    "Notifications filtering should exclude account FAQs",
  );

  const search = page.getByLabel("Search help articles");
  await search.fill("WHAT CAN I EXPORT?");
  await page.getByText("What can I export?", { exact: true }).waitFor();
  await search.fill("PDF OR CSV ZIP");
  await page.getByText("What can I export?", { exact: true }).waitFor();
  await search.fill("TROUBLESHOOTING");
  await page.getByText("Why are my reminders not arriving?", { exact: true }).waitFor();
  await search.fill("no matching help phrase");
  await page.getByText("No help articles match your search.").waitFor();

  await search.fill("delete account");
  await page.getByRole("group", { name: "Help Center results" }).getByText("How do I delete my account?").click();
  await page.getByText("active systems").waitFor();

  for (const [name, path] of destinations) {
    const response = await page.goto(`${baseUrl}${path}`);
    assert.equal(response?.status(), 200, `${name} should return 200`);
    assert.notEqual(await page.title(), "", `${name} should have a title`);
  }

  const privacyText = await page.locator("body").innerText();
  const securitySection = page.locator("#security");
  assert.equal(
    await securitySection.count(),
    1,
    "Privacy should expose a stable security-section anchor",
  );
  assert.match(
    (await securitySection.getAttribute("class")) ?? "",
    /\bscroll-mt-/,
    "The security anchor should clear the sticky site header",
  );
  assert.match(privacyText, /third-party AI processing service/i);
  assert.doesNotMatch(privacyText, /openai/i);
  assert.match(
    privacyText,
    /Peppy does not currently represent that it has Business Associate Agreements covering the service\./i,
  );
  assert.doesNotMatch(privacyText, /\bBAA\b/i);
  assert.doesNotMatch(
    privacyText,
    /\b(?:we|Peppy)\s+(?:have|has|maintain|maintains|operate under)\s+(?:an?\s+)?Business Associate Agreements?/i,
  );
  assert.doesNotMatch(
    privacyText,
    /\b(?:covered|operat(?:e|es))\s+(?:by|under)\s+(?:an?\s+)?(?:Business Associate Agreement|BAA)/i,
  );
  assert.doesNotMatch(privacyText, /AES-256|TLS 1\.3/i);
} finally {
  await browser.close();
}
