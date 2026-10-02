// Usage: node record.mjs <outDir> [from] [to] [step]
import { createRequire } from 'module';
import fs from 'fs';
// Playwright wird aus dem Projekt oder einer globalen Installation geladen (PLAYWRIGHT_DIR überschreibt).
const require = createRequire(process.env.PLAYWRIGHT_DIR || import.meta.url);
const { chromium } = require('playwright');
const [outDir, fromArg, toArg, stepArg] = process.argv.slice(2);
fs.mkdirSync(`${outDir}/frames`, { recursive: true });
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
await page.goto(process.env.TRAILER_URL || 'http://localhost:4173/?trailer');
await page.waitForFunction(() => window.__trailer?.ready, null, { timeout: 120000 });
const total = await page.evaluate(() => window.__trailer.frames);
const from = Number(fromArg ?? 0), to = Math.min(Number(toArg ?? total), total), step = Number(stepArg ?? 1);
const t0 = Date.now();
for (let i = 0; i < to; i++) {
  await page.evaluate((i) => window.__trailer.frame(i), i);
  if (i >= from && (i - from) % step === 0) {
    await page.screenshot({ path: `${outDir}/frames/${String(i).padStart(5, '0')}.jpg`, type: 'jpeg', quality: 92, timeout: 120000 });
  }
  if (i % 30 === 0) console.log(`frame ${i}/${to} ${((Date.now() - t0) / 1000).toFixed(0)}s`);
}
fs.writeFileSync(`${outDir}/events.json`, JSON.stringify(await page.evaluate(() => window.__trailer.events)));
console.log(JSON.stringify({ errors: errors.slice(0, 10), total }));
await browser.close();
