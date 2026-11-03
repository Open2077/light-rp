/* The announcement halo: a drop of molten gold hanging from the top edge of the screen.
   One signed distance field (units: canvas heights, origin at the top centre, y down
   negative): a sheet pouring along the top edge, the hanging drop that swells with the
   voice, droplets that fall from it and melt back, all merged with a smooth minimum and
   warped by flowing noise. Shaded as liquid (deep gold -> hot core, a bright rim) with a
   glow and ripples running outward while the speaker talks. GLSL ES 1.0 (WebGL 1). */

export const VERTEX = `
attribute vec2 aPos;
void main() { gl_Position = vec4(aPos, 0.0, 1.0); }
`;

export const FRAGMENT = `
precision highp float;
uniform vec2 uRes;
uniform float uTime;
uniform float uLevel;    // fast voice envelope 0..1
uniform float uEnergy;   // slow envelope 0..1 (ripples, drips)
uniform float uTalk;     // talking 0..1, smoothed
uniform float uPresence; // on air 0..1 (open / close)

// Simplex noise 3D (Ashima Arts, MIT).
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
float snoise(vec3 v) {
  const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
  vec3 i = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy;
  vec3 x3 = x0 - D.yyy;
  i = mod289(i);
  vec4 p = permute(permute(permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));
  float n_ = 0.142857142857;
  vec3 ns = n_ * D.wyz - D.xzx;
  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_);
  vec4 x = x_ * ns.x + ns.yyyy;
  vec4 y = y_ * ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);
  vec4 b0 = vec4(x.xy, y.xy);
  vec4 b1 = vec4(x.zw, y.zw);
  vec4 s0 = floor(b0) * 2.0 + 1.0;
  vec4 s1 = floor(b1) * 2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));
  vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(a1.xy, h.z);
  vec3 p3 = vec3(a1.zw, h.w);
  vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
  p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
  vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
  m = m * m;
  return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float ellipse(vec2 p, vec2 r) {
  // a cheap, well-behaved ellipse distance (exact on the axes)
  float k0 = length(p / r);
  float k1 = length(p / (r * r));
  return k0 * (k0 - 1.0) / max(k1, 1e-4);
}

void main() {
  vec2 p = (gl_FragCoord.xy - vec2(uRes.x * 0.5, uRes.y)) / uRes.y;
  float pres = uPresence;
  float lvl = uLevel;
  float t = uTime;
  float flowSpeed = 0.3 + 0.35 * uEnergy;

  // the liquid wobbles: a flowing warp, stronger with the voice
  vec2 q = p;
  float wx = snoise(vec3(q * 3.2, t * flowSpeed));
  float wy = snoise(vec3(q * 3.2 + 11.7, t * flowSpeed * 1.1));
  q += vec2(wx, wy) * (0.009 + 0.012 * lvl + 0.005 * uEnergy) * pres;

  // the hanging drop: grows with presence, swells with the voice
  float h = (0.085 + 0.13 * lvl + 0.03 * uEnergy) * pres;
  float w = (0.17 + 0.03 * lvl + 0.015 * uEnergy) * pres + 0.0001;
  // a heavier bottom: liquid sags
  vec2 dq = q;
  dq.x *= 1.0 + 0.35 * smoothstep(0.0, -h, q.y);
  float d = ellipse(dq, vec2(w, max(h, 0.0001)));

  // the sheet pouring along the top edge
  float sheetH = (0.018 + 0.012 * lvl) * pres;
  float sheetW = (0.55 + 0.1 * uEnergy) * pres;
  vec2 sq = vec2(q.x, q.y);
  float sheet = ellipse(sq, vec2(max(sheetW, 0.0001), max(sheetH, 0.0001)));
  d = smin(d, sheet, 0.06 * pres + 0.0001);

  // droplets falling from the drop and melting back
  for (int i = 0; i < 4; i++) {
    float fi = float(i);
    float speed = 0.12 + 0.04 * fi + 0.08 * uEnergy;
    float ph = fract(t * speed + fi * 0.29);
    float fall = ph * ph;
    float x = (fi - 1.5) * w * 0.38 + 0.015 * sin(t * 0.9 + fi * 2.3);
    float y = -h * 0.82 - fall * (0.06 + 0.1 * uEnergy);
    float r = (0.018 + 0.012 * lvl + 0.006 * uEnergy) * (1.0 - 0.6 * ph) * pres * (0.4 + 0.6 * uTalk);
    float dd = length(q - vec2(x, y)) - r;
    d = smin(d, dd, 0.045);
  }

  // shading
  float aa = 1.6 / uRes.y;
  float inside = 1.0 - smoothstep(-aa, aa, d);
  float depth = clamp(-d / max(h * 0.55 + 0.02, 0.02), 0.0, 1.0);
  float flow = snoise(vec3(q * vec2(6.0, 3.0) + vec2(0.0, t * 0.5), t * 0.45));
  vec3 deep = vec3(0.42, 0.26, 0.0);
  vec3 gold = vec3(1.0, 0.80, 0.0);
  vec3 hot = vec3(1.0, 0.97, 0.82);
  vec3 col = mix(deep, gold, smoothstep(0.0, 0.45, depth + flow * 0.12));
  col = mix(col, hot, smoothstep(0.5, 1.0, depth + flow * 0.1) * (0.25 + 0.45 * lvl));
  // a highlight sliding on the surface
  float spec = smoothstep(0.75, 1.0, snoise(vec3(q * 9.0 + vec2(t * 0.3, 0.0), t * 0.2))) * depth;
  col += hot * spec * 0.35;
  float rim = exp(-abs(d) * 160.0) * smoothstep(0.0, -0.004, d);
  col = mix(col, hot, rim * 0.55);

  // the glow and the rings running out while the voice is on
  float outside = max(d, 0.0);
  float glow = exp(-outside * (12.0 - 3.0 * lvl)) * (0.2 + 0.28 * lvl + 0.1 * uEnergy);
  // two pulses leaving the drop and fading as they spread
  float rings = 0.0;
  for (int k = 0; k < 2; k++) {
    float ph = fract(t * (0.4 + 0.15 * uEnergy) + float(k) * 0.5);
    float radius = 0.01 + ph * 0.32;
    float ring = exp(-abs(outside - radius) * (95.0 - 40.0 * ph));
    rings += ring * (1.0 - ph) * (1.0 - ph);
  }
  rings *= (0.1 + 0.35 * uEnergy) * uTalk * step(0.0, d);
  float halo = clamp(glow * 0.6 + rings * 0.55, 0.0, 1.0) * pres;
  vec3 haloCol = mix(gold, hot, rings * 0.5);

  float a = max(inside * pres, halo);
  vec3 c = inside > 0.0 ? mix(haloCol, col, inside) : haloCol;
  // soft borders of the canvas
  float edge = smoothstep(0.0, 0.12, 1.0 + p.y) * smoothstep(0.0, 0.18, 0.5 * uRes.x / uRes.y - abs(p.x));
  a *= edge;
  gl_FragColor = vec4(c * a, a);
}
`;
