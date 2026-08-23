import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const sharp = require("/Users/linchengbo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp/dist/index.cjs");

const root = path.dirname(new URL(import.meta.url).pathname);
const srcDir = path.join(root, "src");
const distDir = path.join(root, "dist");
const reportsDir = path.join(root, "reports");
const iconNames = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8")).icons.map((x) => x.id);

const xmlEscape = (s) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const textSvg = (text, width, height, color, size = 14, weight = 700, tracking = 0) => Buffer.from(`
  <svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">
    <text x="0" y="${size + 2}" fill="${color}" font-family="-apple-system,BlinkMacSystemFont,Arial,sans-serif" font-size="${size}" font-weight="${weight}" letter-spacing="${tracking}">${xmlEscape(text)}</text>
  </svg>`);

function coloredSvg(file, color) {
  return Buffer.from(fs.readFileSync(file, "utf8").replaceAll("currentColor", color));
}

async function renderSheet(mode) {
  const dark = mode === "dark";
  const bg = dark ? "#0C0C0E" : "#F6F6F4";
  const ink = dark ? "#F6F4EE" : "#141414";
  const soft = dark ? "#88888E" : "#777771";
  const border = dark ? "#2A2A2E" : "#DAD9D3";
  const width = 1500;
  const height = 760;
  const cellW = 230;
  const cellH = 290;
  const gapX = 12;
  const gapY = 18;
  const startX = 49;
  const startY = 135;
  const composites = [];

  composites.push({ input: textSvg("ASIDE / EDITORIAL CUT", 600, 45, ink, 28, 800, 1.2), left: 50, top: 38 });
  composites.push({ input: textSvg("SOLID + NEGATIVE SPACE · CURRENTCOLOR · 16 / 20 / 24 / 48 PX", 900, 30, soft, 12, 700, 1.1), left: 50, top: 82 });

  for (let index = 0; index < iconNames.length; index++) {
    const name = iconNames[index];
    const col = index % 6;
    const row = Math.floor(index / 6);
    const x = startX + col * (cellW + gapX);
    const y = startY + row * (cellH + gapY);
    const card = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${cellW}" height="${cellH}"><rect x=".5" y=".5" width="${cellW - 1}" height="${cellH - 1}" rx="12" fill="${bg}" stroke="${border}"/></svg>`);
    composites.push({ input: card, left: x, top: y });

    const file = path.join(srcDir, `${name}.svg`);
    const hero = await sharp(coloredSvg(file, ink)).resize(64, 64).png().toBuffer();
    composites.push({ input: hero, left: x + 24, top: y + 26 });
    composites.push({ input: textSvg(name.toUpperCase(), 180, 24, ink, 12, 800, 1.1), left: x + 24, top: y + 112 });

    let sx = x + 24;
    for (const size of [16, 20, 24, 48]) {
      const icon = await sharp(coloredSvg(file, ink)).resize(size, size).png().toBuffer();
      composites.push({ input: icon, left: sx, top: y + 178 - size });
      composites.push({ input: textSvg(String(size), 34, 18, soft, 10, 700, 0), left: sx, top: y + 193 });
      sx += size === 48 ? 68 : 54;
    }
  }

  await sharp({ create: { width, height, channels: 4, background: bg } })
    .composite(composites)
    .png()
    .toFile(path.join(root, `contact-sheet-${mode}.png`));
}

async function compareRenders() {
  const results = [];
  for (const name of iconNames) {
    const raw = await sharp(coloredSvg(path.join(srcDir, `${name}.svg`), "#111111")).resize(96, 96).png().toBuffer();
    const optimized = await sharp(coloredSvg(path.join(distDir, `${name}.svg`), "#111111")).resize(96, 96).png().toBuffer();
    results.push({ icon: name, pixelIdentical: raw.equals(optimized) });
  }
  const report = { size: 96, allPixelIdentical: results.every((x) => x.pixelIdentical), results };
  fs.mkdirSync(reportsDir, { recursive: true });
  fs.writeFileSync(path.join(reportsDir, "render-comparison.json"), JSON.stringify(report, null, 2) + "\n");
}

await renderSheet("light");
await renderSheet("dark");
await compareRenders();
console.log(`rendered ${iconNames.length} icons`);
