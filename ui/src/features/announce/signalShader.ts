/* The announcement signal: a pixelated cyber sound wave hanging at the top centre of the
   screen. Everything is drawn on a coarse pixel grid (uCell px cells): an oscilloscope
   trace that follows the live voice, a mirrored LED equalizer behind it (yellow segments,
   red at the peaks), dotted radar rings pulsing out of the centre with a slow sweep,
   scanlines and a rare row glitch while the speaker talks. Calm on purpose: the trace and
   the bars grow gently with the level (the user found the liquid halo too violent).
   Units: canvas heights, origin at the top centre, y down. GLSL ES 1.0 (WebGL 1). */

export const VERTEX = `
attribute vec2 aPos;
void main() { gl_Position = vec4(aPos, 0.0, 1.0); }
`;

export const FRAGMENT = `
precision highp float;
uniform vec2 uRes;
uniform float uTime;
uniform float uLevel;    // fast voice envelope 0..1
uniform float uEnergy;   // slow envelope 0..1
uniform float uTalk;     // talking 0..1, smoothed
uniform float uPresence; // on air 0..1 (open / close)
uniform float uCell;     // pixel cell, device px

const vec3 CYAN = vec3(0.35, 0.96, 1.0);
const vec3 YELLOW = vec3(1.0, 0.8, 0.0);
const vec3 RED = vec3(1.0, 0.18, 0.24);
const float CY = 0.42;      // the signal's centre line
const float PI = 3.14159265;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
  vec2 frag = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y);
  // the row glitch: a few cell rows slide sideways for a beat while talking
  float row = floor(frag.y / uCell);
  float beat = floor(uTime * 7.0);
  float glitch = step(0.985 - 0.02 * uTalk, hash(vec2(row, beat))) * uTalk;
  frag.x += glitch * uCell * (hash(vec2(beat, row + 3.0)) > 0.5 ? 3.0 : -3.0);
  // snap to the pixel grid
  vec2 q = (floor(frag / uCell) + 0.5) * uCell;
  vec2 uv = vec2((q.x - uRes.x * 0.5) / uRes.y, q.y / uRes.y);
  float px = uCell / uRes.y;           // one cell, in canvas heights
  float halfW = 0.5 * uRes.x / uRes.y;
  float span = halfW * 0.86;
  float ax = abs(uv.x);
  float bell = clamp(1.0 - (ax / span) * (ax / span), 0.0, 1.0);
  bell *= bell;

  vec3 col = vec3(0.0);
  float alpha = 0.0;

  // ── radar rings: dotted, pulsing out of the centre, flattened ──
  vec2 rc = (uv - vec2(0.0, CY)) * vec2(0.55, 1.0);
  float d = length(rc);
  float ang = atan(rc.y, rc.x);
  float dots = step(0.45, fract(ang * 18.0 / PI + uTime * 0.15));
  for (int k = 0; k < 3; k++) {
    float ph = fract(uTime * (0.22 + 0.18 * uTalk) + float(k) / 3.0);
    float r = 0.06 + ph * 0.46;
    float ring = 1.0 - step(px * 0.9, abs(d - r));
    float a = ring * dots * (1.0 - ph) * (1.0 - ph) * (0.28 + 0.5 * uTalk);
    col += CYAN * a; alpha += a;
  }
  // the sweep: a faint wedge turning around the centre
  float sweep = fract((ang / (2.0 * PI)) - uTime * 0.12);
  float wedge = smoothstep(0.88, 1.0, sweep) * step(d, 0.5) * step(0.05, d) * 0.16;
  col += CYAN * wedge * 0.6; alpha += wedge * 0.6;

  // ── LED equalizer, mirrored around the centre line ──
  float barW = 4.0 * px;
  float bi = floor(uv.x / barW);
  float inBar = step(px * 1.0, mod(uv.x, barW));          // one cell gap between bars
  float n1 = hash(vec2(bi, floor(uTime * 9.0)));
  float n2 = hash(vec2(bi + 17.0, floor(uTime * 9.0) - 1.0));
  float wobble = mix(n2, n1, fract(uTime * 9.0));
  float barH = (0.025 + 0.045 * uEnergy + (0.05 + 0.2 * wobble) * uLevel) * bell;
  float dy = abs(uv.y - CY);
  float seg = step(px * 1.0, mod(dy, px * 3.0));          // segments: 2 cells lit, 1 dark
  float lit = inBar * seg * step(dy, barH) * step(ax, span);
  float top = smoothstep(barH * 0.55, barH, dy);           // red near the peaks
  vec3 barCol = mix(YELLOW, RED, top);
  float ba = lit * (0.42 + 0.3 * uTalk);
  col += barCol * ba; alpha += ba;

  // ── the oscilloscope trace (on top) ──
  float amp = (0.012 + 0.11 * uLevel + 0.02 * uEnergy) * bell;
  float w = sin(uv.x * 26.0 - uTime * 5.0) * 0.55 + sin(uv.x * 57.0 + uTime * 8.3) * 0.28
          + sin(uv.x * 11.0 - uTime * 2.1) * 0.17;
  float trace = CY + amp * w;
  float on = (1.0 - step(px * 1.1, abs(uv.y - trace))) * step(ax, span);
  float glow = (1.0 - smoothstep(px, px * 4.0, abs(uv.y - trace))) * step(ax, span) * 0.25;
  col += CYAN * on + CYAN * glow * 0.5; alpha += on * 0.95 + glow * 0.3;
  // the end ticks of the trace
  float tick = step(abs(ax - span), px * 0.6) * step(dy, px * 4.5);
  col += YELLOW * tick; alpha += tick;

  // ── scanlines, a faint dark band for contrast, the open/close ──
  float scan = 0.78 + 0.22 * step(0.5, fract(frag.y / (uCell * 2.0)));
  float band = (1.0 - smoothstep(0.0, 0.3, dy)) * bell * 0.22;
  alpha = clamp(alpha, 0.0, 1.0);
  col = min(col, vec3(1.0)) * scan;
  float a = max(alpha * scan, band) * uPresence;
  // premultiplied: the dark band adds coverage, no colour
  gl_FragColor = vec4(col * uPresence, a);
}
`;
