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

  // scroll through the page so IntersectionObserver reveals fire
  // (behavior: "instant" — the site sets scroll-behavior: smooth, which
  // would otherwise animate past sections without ever landing on them)
  await page.evaluate(async () => {
    const step = window.innerHeight / 2;
    for (let y = 0; y <= document.body.scrollHeight; y += step) {
      window.scrollTo({ top: y, behavior: "instant" });
      await new Promise((r) => setTimeout(r, 150));
    }
    window.scrollTo({ top: 0, behavior: "instant" });
  });
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
      ["more", "#more"],
      ["privacy", "#privacy"],
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
