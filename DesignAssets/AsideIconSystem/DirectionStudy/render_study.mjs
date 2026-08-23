import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const sharp = require("/Users/linchengbo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp/dist/index.cjs");
const root = path.dirname(new URL(import.meta.url).pathname);
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));

const esc = (s) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const textSvg = (text, width, height, color, size, weight = 700, tracking = 0) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><text x="0" y="${size + 2}" fill="${color}" font-family="-apple-system,BlinkMacSystemFont,Arial,sans-serif" font-size="${size}" font-weight="${weight}" letter-spacing="${tracking}">${esc(text)}</text></svg>`);
const iconSvg = (file, color) => Buffer.from(fs.readFileSync(file, "utf8").replaceAll("currentColor", color));

async function render(mode) {
  const dark = mode === "dark";
  const bg = dark ? "#0C0C0E" : "#F6F6F4";
  const ink = dark ? "#F6F4EE" : "#151515";
  const soft = dark ? "#8E8E94" : "#777771";
  const rule = dark ? "#2C2C31" : "#D7D5CE";
  const width = 1500, height = 1040;
  const left = 42, top = 160, labelW = 250, cellW = 225, rowH = 270;
  const composites = [];

  composites.push({ input: textSvg("ASIDE / THREE LANGUAGE STUDY", 900, 50, ink, 30, 800, 1), left: 42, top: 36 });
  composites.push({ input: textSvg("SAME 5 SEMANTICS · DIFFERENT METAPHOR / SILHOUETTE / CONSTRUCTION", 1000, 30, soft, 12, 700, 1.15), left: 42, top: 83 });

  for (let r = 0; r < manifest.directions.length; r++) {
    const dir = manifest.directions[r];
    const y = top + r * rowH;
    const ruleSvg = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1416" height="1"><path d="M0 .5H1416" stroke="${rule}"/></svg>`);
    composites.push({ input: ruleSvg, left, top: y - 22 });
    composites.push({ input: textSvg(dir.title, 235, 34, ink, 20, 800, 0.3), left, top: y + 4 });
    composites.push({ input: textSvg(dir.summary, 235, 66, soft, 12, 600, 0), left, top: y + 46 });

    for (let c = 0; c < dir.icons.length; c++) {
      const name = dir.icons[c];
      const x = left + labelW + c * cellW;
      const file = path.join(root, dir.id, "src", `${name}.svg`);
      const hero = await sharp(iconSvg(file, ink)).resize(72, 72).png().toBuffer();
      const i24 = await sharp(iconSvg(file, ink)).resize(24, 24).png().toBuffer();
      const i16 = await sharp(iconSvg(file, ink)).resize(16, 16).png().toBuffer();
      composites.push({ input: hero, left: x + 5, top: y + 4 });
      composites.push({ input: textSvg(name.toUpperCase(), 150, 22, ink, 11, 800, 1), left: x + 5, top: y + 92 });
      composites.push({ input: i24, left: x + 5, top: y + 144 });
      composites.push({ input: i16, left: x + 53, top: y + 152 });
      composites.push({ input: textSvg("24", 24, 16, soft, 9, 700), left: x + 5, top: y + 180 });
      composites.push({ input: textSvg("16", 24, 16, soft, 9, 700), left: x + 53, top: y + 180 });
    }
  }

  await sharp({ create: { width, height, channels: 4, background: bg } }).composite(composites).png().toFile(path.join(root, `direction-study-${mode}.png`));
}

await render("light");
await render("dark");
console.log("rendered direction study");
