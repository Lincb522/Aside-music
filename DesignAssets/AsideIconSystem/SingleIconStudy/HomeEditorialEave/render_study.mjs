import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const sharp = require("/Users/linchengbo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp/dist/index.cjs");
const root = path.dirname(new URL(import.meta.url).pathname);
const source = fs.readFileSync(path.join(root, "home.svg"), "utf8");

const esc = (s) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const label = (text, width, height, color, size, weight = 700, tracking = 0) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><text x="0" y="${size + 2}" fill="${color}" font-family="-apple-system,BlinkMacSystemFont,Arial,sans-serif" font-size="${size}" font-weight="${weight}" letter-spacing="${tracking}">${esc(text)}</text></svg>`);
const colored = (color) => Buffer.from(source.replaceAll("currentColor", color));

async function render(mode) {
  const dark = mode === "dark";
  const bg = dark ? "#0C0C0E" : "#F6F6F4";
  const ink = dark ? "#F7F4EE" : "#151515";
  const soft = dark ? "#8F8F95" : "#74746F";
  const rule = dark ? "#303036" : "#D8D6CF";
  const width = 1500, height = 820;
  const c = [];

  c.push({ input: label("ASIDE / SINGLE FUNCTIONAL ICON", 900, 50, ink, 29, 800, 1), left: 54, top: 42 });
  c.push({ input: label("HOME — EDITORIAL EAVE", 600, 35, soft, 12, 750, 1.4), left: 54, top: 88 });
  c.push({ input: await sharp(colored(ink)).resize(320, 320).png().toBuffer(), left: 112, top: 190 });

  c.push({ input: Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1" height="570"><path d="M.5 0v570" stroke="${rule}"/></svg>`), left: 560, top: 160 });
  c.push({ input: label("RECOGNITION FIRST / CHARACTER SECOND", 720, 30, ink, 14, 800, 1.1), left: 640, top: 175 });
  c.push({ input: label("Familiar roof + room + entrance · character lives in eave tension and proportion", 780, 30, soft, 12, 600), left: 640, top: 211 });

  let x = 640;
  for (const size of [48, 32, 24, 20, 16]) {
    c.push({ input: await sharp(colored(ink)).resize(size, size).png().toBuffer(), left: x, top: 304 + (48 - size) });
    c.push({ input: label(String(size), 40, 18, soft, 10, 700), left: x, top: 375 });
    x += 112;
  }

  c.push({ input: label("TAB-BAR SCALE", 300, 26, ink, 13, 800, 1.1), left: 640, top: 470 });
  c.push({ input: Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="700" height="140"><rect x=".5" y=".5" width="699" height="139" rx="28" fill="${dark ? "#17171A" : "#FFFFFF"}" stroke="${rule}"/></svg>`), left: 640, top: 515 });
  c.push({ input: await sharp(colored(ink)).resize(24, 24).png().toBuffer(), left: 700, top: 550 });
  c.push({ input: label("首页", 60, 22, ink, 11, 700), left: 701, top: 586 });
  for (let i = 0; i < 4; i++) {
    const px = 848 + i * 112;
    c.push({ input: Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect x="4" y="5" width="16" height="14" rx="7" fill="${soft}" opacity=".18"/></svg>`), left: px, top: 550 });
    c.push({ input: Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="3"><rect width="32" height="3" rx="1.5" fill="${soft}" opacity=".18"/></svg>`), left: px - 4, top: 592 });
  }

  await sharp({ create: { width, height, channels: 4, background: bg } }).composite(c).png().toFile(path.join(root, `home-editorial-eave-${mode}.png`));
}

await render("light");
await render("dark");
console.log("rendered editorial eave study");
