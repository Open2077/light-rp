/* Motion helpers of the installation sequence (ported from the holocall design):
   three easing curves, keyframe interpolation and the small text/colour tools
   the HUD is drawn with. Everything is a pure function of the clock. */

export type Ease = (t: number) => number;

export const Easing = {
  linear: (t: number) => t,
  easeInOutCubic: (t: number) => (t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1),
  easeOutExpo: (t: number) => (t === 1 ? 1 : 1 - Math.pow(2, -10 * t)),
  easeOutBack: (t: number) => {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
  },
};

export const clamp = (v: number, min: number, max: number) => Math.max(min, Math.min(max, v));
export const lerp = (a: number, b: number, u: number) => a + (b - a) * u;
export const prog = (T: number, s: number, e: number) => clamp((T - s) / Math.max(e - s, 1e-6), 0, 1);

/** The only three motion curves of the piece. */
export const MOTION = {
  enter: (T: number, s: number, e: number) => Easing.easeOutExpo(prog(T, s, e)),
  draw: (T: number, s: number, e: number) => Easing.easeInOutCubic(prog(T, s, e)),
  pop: (T: number, s: number, e: number) => Easing.easeOutBack(prog(T, s, e)),
};

/** Keyframes: maps T across `input` to `output`, one ease per segment (or one for all). */
export function interpolate(input: number[], output: number[], ease: Ease | Ease[] = Easing.linear) {
  return (t: number): number => {
    if (t <= input[0]!) return output[0]!;
    if (t >= input[input.length - 1]!) return output[output.length - 1]!;
    for (let i = 0; i < input.length - 1; i++) {
      const a = input[i]!, b = input[i + 1]!;
      if (t >= a && t <= b) {
        const local = b === a ? 0 : (t - a) / (b - a);
        const fn = Array.isArray(ease) ? (ease[i] ?? Easing.linear) : ease;
        return output[i]! + (output[i + 1]! - output[i]!) * fn(local);
      }
    }
    return output[output.length - 1]!;
  };
}

export const hash = (n: number) => { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); };
/** 1 at `s`, fading linearly to 0 over `d` seconds. */
export const spike = (T: number, s: number, d: number) => (T >= s && T < s + d ? 1 - (T - s) / d : 0);
/** The part of `str` typed so far at `cps` characters per second. */
export const typed = (str: string, T: number, start: number, cps = 40) => str.slice(0, Math.max(0, Math.floor((T - start) * cps)));

export function hexRgb(hex: string): [number, number, number] {
  let h = String(hex || "#ff3340").replace("#", "");
  if (h.length === 3) h = h.split("").map((c) => c + c).join("");
  const v = parseInt(h, 16);
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
}
export const rgba = (hex: string, a: number) => { const [r, g, b] = hexRgb(hex); return `rgba(${r},${g},${b},${a})`; };
export const mixHex = (a: string, b: string, u: number) => {
  const A = hexRgb(a), B = hexRgb(b);
  return "#" + [0, 1, 2].map((i) => Math.round(lerp(A[i]!, B[i]!, u)).toString(16).padStart(2, "0")).join("");
};
