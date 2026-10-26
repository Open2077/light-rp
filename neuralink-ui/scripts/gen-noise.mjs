// Writes src/assets/noise.png: a 128x128 grey-alpha film grain tile (no data: URIs, CSP-safe).
import { deflateSync } from "node:zlib";
import { writeFileSync } from "node:fs";
const W = 128, H = 128;
const raw = Buffer.alloc((W * 2 + 1) * H);
let seed = 77;
const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
for (let y = 0; y < H; y++) {
  raw[y * (W * 2 + 1)] = 0;
  for (let x = 0; x < W; x++) {
    const o = y * (W * 2 + 1) + 1 + x * 2;
    raw[o] = rnd() > 0.5 ? 255 : 0;
    raw[o + 1] = Math.floor(rnd() * 22);
  }
}
const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = (buf) => { let c = 0xffffffff; for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 4; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
const png = Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0))]);
writeFileSync(new URL("../src/assets/noise.png", import.meta.url), png);
console.log("noise.png", png.length, "bytes");
