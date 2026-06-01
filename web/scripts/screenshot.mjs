import { chromium } from "playwright";
import { mkdirSync, existsSync, readdirSync } from "node:fs";
import { resolve, join } from "node:path";

const url = process.env.URL ?? "http://localhost:3000";
const root = resolve(process.cwd(), "screenshots");
mkdirSync(root, { recursive: true });

// Pick the next run-N folder
const runs = existsSync(root)
  ? readdirSync(root).filter((d) => /^run-\d+$/.test(d))
  : [];
const next =
  runs
    .map((r) => Number(r.split("-")[1]))
    .reduce((a, b) => Math.max(a, b), 0) + 1;
const tag = process.env.TAG ?? `run-${next}`;
const out = join(root, tag);
mkdirSync(out, { recursive: true });

const viewports = [
  { name: "desktop", width: 1440, height: 900 },
  { name: "tablet", width: 900, height: 1200 },
  { name: "mobile", width: 390, height: 844 },
];

const browser = await chromium.launch();

for (const v of viewports) {
  const ctx = await browser.newContext({
    viewport: { width: v.width, height: v.height },
    deviceScaleFactor: 1,
  });
  const page = await ctx.newPage();
  console.log(`[${tag}] ${v.name} — loading ${url}`);
  await page.goto(url, { waitUntil: "networkidle" });
  // give fonts + fade-ins a moment to settle
  await page.waitForTimeout(900);

  await page.screenshot({
    path: join(out, `${v.name}-full.png`),
    fullPage: true,
  });
  await page.screenshot({
    path: join(out, `${v.name}-fold.png`),
    fullPage: false,
  });

  if (v.name === "desktop") {
    const sectionSelectors = [
      ["hero", "header"],
      ["features", "#features"],
      ["records", "#records"],
      ["more", "#more"],
      ["testimonials", "#testimonials"],
      ["cta", "#download"],
      ["footer", "footer"],
    ];
    for (const [name, sel] of sectionSelectors) {
      const el = await page.$(sel);
      if (el) {
        try {
          await el.screenshot({ path: join(out, `${v.name}-${name}.png`) });
        } catch (e) {
          console.log(`  skip ${name}: ${e.message}`);
        }
      }
    }
  }

  await ctx.close();
}

await browser.close();
console.log(`\n✓ Saved to ${out}\n`);
