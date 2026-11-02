/* The Kiroshi Neural-Link installation (the HOLO-OS design): an ocular CRT
   powers on over the street, the Kiroshi emblem assembles ring by ring and
   the BIOS posts; HOLO-OS boots dmesg style, finds no module on the optic
   port and its installer asks. Install runs the network, cortex, nerve and
   flash stages in a terminal beside a TUI panel (stages, system meters,
   target); the self-test explodes the emblem into the emitter test pattern,
   the screen clears to the wordmark and the CRT powers off into the interface.

   One choreography clock T (timeline.ts) drives the terminal, the panel, the
   WebGL layer (HoloGL) and the Cyberpunk 2077 sound cues (sounds.ts, played
   by Lua); a wall clock W keeps spins, cursors and glitches alive while T
   waits. T stops at WAIT for the choice and before Done for the server's
   answer; `implant.install` leaves when the flash starts. A failure stops the
   clock on a terminal error (Retry restarts at the flash, Close drops it all). */
import { useEffect, useMemo, useReducer, useRef, type ReactNode } from "react";
import { request, RequestError } from "@/bridge/open77";
import { errorText } from "@/bridge/errors";
import type { ImplantState } from "@/bridge/protocol";
import { play } from "@/fx/sound";
import { userClose } from "@/store/actions";
import { getStore, useStore } from "@/store/store";
import { reducedMotion } from "@/shell/Stage";
import { HoloGL, HW, HH, RINGS, type GLParams } from "./HoloGL";
import { Easing, MOTION, clamp, hash, interpolate, lerp, prog, rgba, spike, typed } from "./motion";
import { INSTALL_CUES } from "./sounds";
import { ASK, CONFIRM, END, HOLD, REQUEST_AT, SCENES as C, WAIT } from "./timeline";

const FONT_M = '"IBM Plex Mono", "Share Tech Mono", ui-monospace, monospace';
const FONT_B = '"Chakra Petch", "IBM Plex Mono", sans-serif';
const FONT_JP = '"Noto Sans JP", "Yu Gothic UI", "Yu Gothic", "Meiryo", "MS Gothic", sans-serif';
const INK = "#dfe9ee", DIM = "rgba(223,233,238,0.5)", DIM2 = "rgba(223,233,238,0.22)", BG = "#05060a";
/** The design's accent pair: cyan, magenta. */
const A = "#2ee6e0", B = "#ff3fb8";
const PALETTE: [string, string] = [A, B];
const EASE = { enter: Easing.easeOutExpo, draw: Easing.easeInOutCubic, pop: Easing.easeOutBack };
const pad2 = (n: number) => String(n).padStart(2, "0");
/** The page gives up on the reply this long after asking (Lua's own timeout is 15-20 s). */
const REPLY_TIMEOUT_MS = 22_000;

interface Fault { slug: string; at: number }
interface View { T: number; W: number; holding: boolean; idle: number; fault: Fault | null; waiting: boolean; confirmed: boolean }
interface Ctx { selfInstall: boolean; model: string; name: string; number: string }

// ── choreography → GL parameters ──
const SPLASH: [number, number, number] = [960, 440, 230], CORNER: [number, number, number] = [1808, 64, 30];
const TEST: [number, number, number] = [698, 556, 270], FINAL: [number, number, number] = [960, 400, 190];
function glParams(v: View): GLParams {
  const { T, W } = v;
  const { Post: P, Kernel: K, Network: NW, Cortex: CX, Nerve: NV, Flash: FL, Verify: V, Done: D } = C;
  let glitch = 0.8 * spike(T, K, 0.35) + 0.3 * (spike(T, NW, 0.2) + spike(T, CX, 0.2) + spike(T, NV, 0.2) + spike(T, FL, 0.2))
    + spike(T, V + 0.85, 0.4) + 0.7 * spike(T, V + 2.3, 0.3) + spike(T, D, 0.4);
  glitch = clamp(glitch + v.idle + (v.fault ? spike(W, v.fault.at, 0.5) : 0), 0, 1.5);
  const toCorner = MOTION.draw(T, K - 0.1, K + 0.7), toTest = MOTION.draw(T, V + 0.3, V + 0.9), toFinal = MOTION.draw(T, D, D + 0.6);
  let pos = SPLASH.map((x, i) => lerp(x, CORNER[i]!, toCorner));
  pos = pos.map((x, i) => lerp(x, TEST[i]!, toTest));
  pos = pos.map((x, i) => lerp(x, FINAL[i]!, toFinal));
  const assemble = RINGS.map((_, i) => MOTION.draw(T, P + 0.35 + i * 0.1, P + 1.3 + i * 0.1));
  const explode = Math.max(0, interpolate([V + 0.9, V + 1.25, V + 1.9, V + 2.3], [0, 0.5, 0.5, 0], [EASE.enter, EASE.draw, EASE.pop])(T));
  let pulse = 0, burst = 0;
  for (const e of [K, NW, CX, NV, FL, V, D]) { pulse += spike(T, e, 0.5); burst += MOTION.draw(T, e, e + 0.9); }
  pulse += 0.8 * spike(T, V + 2.3, 0.5) + (v.fault ? spike(W, v.fault.at, 0.6) : 0);
  // spins run on the wall clock: the emblem stays alive while the clock waits
  const spinT = W + 1.4 * burst + 7 * MOTION.draw(T, V + 0.85, V + 2.4);
  const tilt = (1 - 0.65 * toCorner) * (1 - toTest) + toTest * 0.9 * (1 - 0.5 * toFinal);
  const alpha = MOTION.enter(T, P + 0.2, P + 0.6);
  return { T, W, glitch, stat: 1 - MOTION.draw(T, P + 0.1, P + 1.1), emb: { pos: pos as [number, number, number], assemble, explode, pulse, spinT, tilt, alpha } };
}

function GLView({ params }: { params: GLParams }) {
  const host = useRef<HTMLDivElement>(null);
  const gl = useRef<HoloGL | null>(null);
  useEffect(() => {
    // a fresh canvas per mount: a disposed renderer leaves its context lost
    const canvas = document.createElement("canvas");
    canvas.width = HW; canvas.height = HH;
    canvas.style.cssText = `position:absolute;left:0;top:0;width:${HW}px;height:${HH}px`;
    try { gl.current = new HoloGL(canvas); host.current?.appendChild(canvas); }
    catch (e) { console.warn("[neuralink] installation: WebGL unavailable, terminal only", e); }
    return () => { gl.current?.dispose(); gl.current = null; canvas.remove(); };
  }, []);
  useEffect(() => { gl.current?.draw(params, PALETTE); });
  return <div ref={host} style={{ position: "absolute", inset: 0, background: BG, pointerEvents: "none" }} />;
}

// ── terminal log ──
const BANNER = [
  " _  _  ___  _    ___     ___  ___ ",
  "| || |/ _ \\| |  / _ \\   / _ \\/ __|",
  "| __ | (_) | |_| (_) | | (_) \\__ \\",
  "|_||_|\\___/|___|\\___/   \\___/|___/",
];
type Tint = "a" | "b" | "dim" | undefined;
type LogEntry =
  | { t: number; kind: "cmd"; text: string; dur: number }
  | { t: number; kind: "out"; text: string; color?: Tint; stamp?: boolean; tag?: string }
  | { t: number; kind: "bar"; to: number; label: string; right: string }
  | { t: number; kind: "grid"; to: number }
  | { t: number; kind: "wave"; to: number }
  | { t: number; kind: "hex"; to: number; rate: number; max: number }
  | { t: number; kind: "ask"; text: string }
  | { t: number; kind: "clear" };

function buildLog(ctx: Ctx): LogEntry[] {
  const { Kernel: K, Network: NW, Cortex: CX, Nerve: NV, Flash: FL, Verify: V, Done: D } = C;
  const out: LogEntry[] = [];
  let t = 0;
  const cmd = (text: string, dur: number) => { out.push({ t, kind: "cmd", text, dur }); t += dur + 0.05; };
  const o = (text: string, gap?: number, opt?: { color?: Tint; stamp?: boolean; tag?: string }) => { out.push({ t, kind: "out", text, ...opt }); t += gap ?? 0.1; };
  const ok = (text: string, gap?: number, tag?: string) => o(text, gap ?? 0.14, { tag: tag || "OK" });
  const bar = (label: string, to: number, right: string) => { out.push({ t, kind: "bar", to, label, right }); t = to + 0.12; };
  const blank = () => o("", 0.02);
  const model = ctx.model;
  t = K + 0.05; cmd("boot holo-os-4.3.0.img --target=/dev/ocular0", 0.5);
  ([
    ["0.000000", "HOLO-OS 4.3.0 (build nc-09) #1 SMP PREEMPT"],
    ["0.000412", "npu: Kiroshi NPU-7 @ 2.4 THz, 4096 phase cells"],
    ["0.001207", "mem: 2048 PB neural lattice, ECC enabled"],
    ["0.004881", `ocular0: ${model} at cortical port C7`],
    ["0.004902", `ocular1: ${model} at cortical port C8`],
    ["0.009340", "bus: optic nerve bridge online (2.4 TB/s)"],
    ["0.012003", "crypto: QEC-4096 engine ready"],
    ["0.018754", "holo: no Neural-Link module on ocular0 -- installer required", "b"],
    ["0.020110", "init: switching to installer shell"],
  ] as [string, string, Tint?][]).forEach(([ts, txt, col]) => o(`[    ${ts}] ${txt}`, 0.1, { color: col, stamp: true }));
  t = K + 1.9; blank();
  BANNER.forEach((l) => o(l, 0.05, { color: "a" }));
  o("HOLO-OS INSTALLER 4.3.0  ·  8 stages  ·  target /dev/ocular0", 0.1, { color: "dim" }); blank();
  t = K + 2.5; cmd("holo-install neuralink.core --target=/dev/ocular0", 0.6);
  o("module  neuralink.core 2.0  ·  38.2 MB  ·  signed kiroshi", 0.1, { color: "dim" });
  t = ASK;
  if (ctx.selfInstall) {
    out.push({ t, kind: "ask", text: "install the Neural-Link on /dev/ocular0? [Y/n] " });
    t = CONFIRM + 0.08; ok("installation confirmed  ·  do not move your eyes", 0.1);
  } else {
    o("holo-install: self-install locked on this model", 0.12, { color: "b", tag: "LOCK" });
    o("visit a ripperdoc to have the Neural-Link installed", 0.1, { color: "a" });
  }
  t = NW + 0.1; cmd("netlink up --carrier=kiroshi-net", 0.5);
  o("scanning carriers", 0.35, { color: "dim" });
  o("  nc-09.watson.grid       -41 dBm    QEC-4096", 0.2, { color: "a" });
  o("  nc-12.westbrook.grid    -67 dBm    QEC-4096", 0.2);
  o("  nc-03.corpo.net         -83 dBm    open", 0.25, { color: "dim" });
  ok("joined nc-09.watson.grid    lease 7F:3A:91:C4", 0.25);
  cmd("fetch pkg://kiroshi/neuralink.core-2.0.pak", 0.45);
  bar("neuralink.core-2.0.pak", NW + 3.35, "38.2 MB    2.4 TB/s");
  ok("sha3-512  9f3a:b2c1:77e0 ... verified", 0.15);
  ok("package staged in /var/holo/stage");
  t = CX + 0.1; cmd("cortex map --region=V1 --cells=4096", 0.5);
  ok("probing occipital bus", 0.25);
  out.push({ t, kind: "grid", to: CX + 2.5 }); t = CX + 2.6;
  ok("4096/4096 phase cells mapped    delta 0.003", 0.2);
  cmd("cortex link --bus=occipital", 0.45);
  ok("synaptic interface calibrated", 0.2);
  ok("cortical link stable    2.4 TB/s");
  t = NV + 0.1; cmd("nerve bind --optic L,R --relay T1", 0.5);
  o("tracing optic nerve L -> chiasm -> V1 (right)", 0.1, { color: "dim" });
  out.push({ t, kind: "wave", to: NV + 1.7 }); t = NV + 1.75;
  ok("optic nerve L bound", 0.15); ok("optic nerve R bound", 0.15); ok("chiasm crossover", 0.25);
  o("syncing spinal relay T1", 0.6, { color: "dim" });
  ok("spinal relay T1    12 ms", 0.2);
  o("reflex gate armed:  blink x2 = accept    look away = decline", 0.1, { color: "a" });
  t = FL + 0.1; cmd("flash --module neuralink.core-2.0.pak --port C7", 0.55);
  o("erasing sectors 0x3F2A-0x4B6A", 0.35, { color: "b" });
  out.push({ t, kind: "hex", to: FL + 2.2, rate: 9, max: 10 }); t = FL + 2.25;
  bar("firmware 4.2.1 -> 4.3.0", FL + 3.2, "sector 0x4B6A");
  ok("emitter warm-up 31°C -> 44°C", 0.2);
  ok("holocall.service enabled");
  t = V + 0.1; cmd("selftest --all", 0.45);
  o("projecting emitter test pattern ...", 0.1, { color: "dim" });
  t = V + 2.3; ok("emitter test pattern", 0.12, "PASS"); ok("link latency 12 ms", 0.12, "PASS"); ok("encryption QEC-4096", 0.12, "PASS");
  o("7/7 checks passed", 0.1, { color: "a" });
  t = D + 0.02; cmd("clear", 0.25); out.push({ t, kind: "clear" });
  return out;
}
const endOf = (e: LogEntry) => (e.kind === "cmd" ? e.t + e.dur : "to" in e ? e.to : e.t);

function Prompt() {
  return <span><span style={{ color: B }}>root@kiroshi</span><span style={{ color: DIM }}>:~</span><span style={{ color: A }}># </span></span>;
}
function Cursor({ W }: { W: number }) {
  return <span style={{ display: "inline-block", width: 11, height: 20, background: A, verticalAlign: -3, opacity: Math.floor(W * 2.5) % 2 === 0 ? 1 : 0.15, boxShadow: `0 0 10px ${rgba(A, 0.7)}` }} />;
}

interface Choice { key: string; label: string; primary?: boolean; act(): void }
const ROW = 27, MAXU = 31;
interface Row { u: number; el: ReactNode }

function OutLine({ text, color, stamp, tag }: { text: string; color?: Tint; stamp?: boolean; tag?: string }) {
  const col = color === "a" ? A : color === "b" ? B : color === "dim" ? DIM : INK;
  const tagCol = tag === "OK" || tag === "PASS" ? A : B;
  return (
    <div style={{ height: ROW, whiteSpace: "pre", display: "flex", color: col }}>
      <span style={{ color: stamp ? DIM : "inherit" }}>{stamp ? text.slice(0, 15) : ""}</span>
      <span style={{ width: tag ? 700 : "auto" }}>{tag ? "  " : ""}{stamp ? text.slice(15) : text}</span>
      {tag ? <span style={{ color: DIM }}>[ <span style={{ color: tagCol, textShadow: `0 0 10px ${rgba(tagCol, 0.6)}` }}>{tag.padStart(4, " ")}</span> ]</span> : null}
    </div>
  );
}

function Terminal({ v, log, ctx, choices }: { v: View; log: LogEntry[]; ctx: Ctx; choices: Choice[] | null }) {
  const { T, W } = v;
  const rows: Row[] = [];
  let lastEnd = -1;
  for (const e of log) {
    if (e.t > T) break;
    lastEnd = Math.max(lastEnd, endOf(e));
    const key = e.kind + e.t;
    if (e.kind === "clear") { rows.length = 0; continue; }
    if (e.kind === "cmd") {
      const typing = T < e.t + e.dur;
      rows.push({ u: 1, el: <div key={key} style={{ height: ROW, whiteSpace: "pre" }}><Prompt />{typed(e.text, T, e.t, e.text.length / e.dur)}{typing ? <Cursor W={W} /> : null}</div> });
    } else if (e.kind === "out") {
      rows.push({ u: 1, el: <OutLine key={key} {...e} /> });
    } else if (e.kind === "ask") {
      const answered = v.confirmed && T >= CONFIRM;
      rows.push({ u: 1, el: <div key={key} style={{ height: ROW, whiteSpace: "pre", color: INK }}><span style={{ color: A }}>{"? "}</span>{e.text}{answered ? <span style={{ color: A }}>y</span> : <Cursor W={W} />}</div> });
    } else if (e.kind === "bar") {
      const u = MOTION.draw(T, e.t, e.to), n = Math.round(u * 40), done = u >= 1;
      rows.push({ u: 1, el: (
        <div key={key} style={{ height: ROW, display: "flex", alignItems: "center", gap: 14, whiteSpace: "pre" }}>
          <span style={{ color: DIM }}>  {e.label.padEnd(26, " ")}</span>
          <span style={{ color: DIM }}>[</span>
          <span style={{ display: "flex", gap: 2 }}>{Array.from({ length: 40 }, (_, i) => <span key={i} style={{ width: 9, height: 14, background: i < n ? (done ? INK : A) : DIM2, boxShadow: i < n && !done ? `0 0 6px ${rgba(A, 0.5)}` : "none" }} />)}</span>
          <span style={{ color: DIM }}>]</span>
          <span style={{ color: INK, width: 54, textAlign: "right" }}>{Math.round(u * 100)}%</span>
          <span style={{ color: DIM }}>{e.right}</span>
        </div>) });
    } else if (e.kind === "grid") {
      const n = Math.floor(MOTION.draw(T, e.t, e.to) * 384);
      rows.push({ u: 4, el: (
        <div key={key} style={{ height: ROW * 4, display: "grid", gridTemplateColumns: "repeat(64, 14px)", gridAutoRows: "14px", gap: 3, alignContent: "center", paddingLeft: 26 }}>
          {Array.from({ length: 384 }, (_, i) => <div key={i} style={{ background: i < n ? (hash(i) > 0.9 ? B : A) : "rgba(223,233,238,0.07)", opacity: i < n ? 0.55 + 0.45 * hash(i + 5) : 1 }} />)}
        </div>) });
    } else if (e.kind === "wave") {
      const env = T < e.to ? 1 : 0.2;
      const ph = T < e.to ? T : W; // the trace keeps breathing once bound
      rows.push({ u: 2, el: (
        <div key={key} style={{ height: ROW * 2, display: "flex", alignItems: "center", gap: 4, paddingLeft: 26 }}>
          {Array.from({ length: 110 }, (_, i) => { const h = 3 + 40 * env * Math.abs(Math.sin(i * 0.33 - ph * 9)) * (0.4 + 0.6 * hash(i)); return <div key={i} style={{ width: 6, height: h, background: i % 7 === 0 ? B : A, opacity: 0.5 + 0.5 * hash(i + 9) }} />; })}
        </div>) });
    } else if (e.kind === "hex") {
      const n = Math.min(e.max, Math.floor((T - e.t) * e.rate) + 1);
      for (let i = 0; i < n; i++) {
        const bytes = Array.from({ length: 12 }, (_, j) => Math.floor(hash(i * 31 + j * 7 + 2) * 256));
        const hexs = bytes.map((b) => b.toString(16).padStart(2, "0")).join(" ");
        const asc = bytes.map((b) => (b > 32 && b < 127 ? String.fromCharCode(b) : ".")).join("");
        rows.push({ u: 1, el: <div key={key + i} style={{ height: ROW, whiteSpace: "pre", color: DIM }}>  <span style={{ color: B }}>0x{(0x3f2a + i * 16).toString(16).toUpperCase()}</span>   {hexs}   <span style={{ color: DIM2 }}>|{asc}|</span></div> });
      }
    }
  }
  // the live tail: the registration wait, the failure, the choice
  if (v.holding) {
    const spin = "|/-\\"[Math.floor(W * 10) % 4];
    rows.push({ u: 1, el: <div key="hold" style={{ height: ROW, whiteSpace: "pre", color: DIM }}>  registering line <span style={{ color: INK }}>{ctx.number}</span> on nc-09.watson.grid  <span style={{ color: A }}>{spin}</span></div> });
  }
  if (v.fault) {
    rows.push({ u: 1, el: <OutLine key="fault" text={`flash: ${errorText(v.fault.slug).toLowerCase()}`} color="b" tag="FAIL" /> });
    rows.push({ u: 1, el: <OutLine key="fault2" text="module rolled back  ·  nothing was written to ocular0" color="dim" /> });
  }
  if (choices) {
    rows.push({ u: 2, el: (
      <div key="choice" className="holo-choice" style={{ height: ROW * 2 }}>
        {choices.map((c) => (
          <button key={c.key} type="button" className={`holo-key${c.primary ? " holo-key--primary" : ""}`} onClick={c.act}>
            <span className="holo-key__cap">{c.key}</span><span>{c.label}</span>
          </button>
        ))}
      </div>) });
  } else if (T > lastEnd + 0.08 && !v.holding && !v.fault) {
    rows.push({ u: 1, el: <div key="prompt" style={{ height: ROW, whiteSpace: "pre" }}><Prompt /><Cursor W={W} /></div> });
  }
  let used = 0, start = rows.length;
  while (start > 0 && used + rows[start - 1]!.u <= MAXU) { used += rows[start - 1]!.u; start--; }
  return (
    <div style={{ position: "absolute", left: 64, top: 128, width: 1268, height: MAXU * ROW, overflow: "hidden", fontFamily: FONT_M, fontSize: 19, lineHeight: ROW + "px", color: INK, display: "flex", flexDirection: "column", justifyContent: "flex-end" }}>
      {rows.slice(start).map((r) => r.el)}
    </div>
  );
}

// ── right-hand TUI panel ──
const STAGES = ["POST", "KERNEL", "NETWORK", "CORTEX", "NERVE", "FLASH", "SELFTEST", "DONE"];
const CUE_LIST = [C.Post, C.Kernel, C.Network, C.Cortex, C.Nerve, C.Flash, C.Verify, C.Done];
const stageIndex = (T: number) => { let i = 0; for (let k = 0; k < CUE_LIST.length; k++) if (T >= CUE_LIST[k]!) i = k; return i; };
function Box({ title, top, height, children }: { title: string; top: number; height: number; children: ReactNode }) {
  return (
    <div style={{ position: "absolute", left: 1372, top, width: 484, height, boxSizing: "border-box", border: `1px solid ${DIM2}`, padding: "22px 22px 16px" }}>
      <div style={{ position: "absolute", left: 14, top: -10, padding: "0 8px", background: BG, fontFamily: FONT_M, fontSize: 14, letterSpacing: "0.24em", color: A }}>{title}</div>
      {children}
    </div>
  );
}
function Meter({ label, u, value, warn }: { label: string; u: number; value: string; warn?: boolean }) {
  const n = Math.round(clamp(u, 0, 1) * 24);
  return (
    <div style={{ display: "flex", alignItems: "center", height: 30, fontFamily: FONT_M, fontSize: 15, whiteSpace: "pre" }}>
      <span style={{ color: DIM, width: 120 }}>{label}</span>
      <span style={{ display: "flex", gap: 2, width: 190 }}>{Array.from({ length: 24 }, (_, i) => <span key={i} style={{ width: 6, height: 12, background: i < n ? (warn ? B : A) : DIM2 }} />)}</span>
      <span style={{ color: INK, flex: 1, textAlign: "right" }}>{value}</span>
    </div>
  );
}
function Panel({ v, ctx }: { v: View; ctx: Ctx }) {
  const { T, W } = v;
  const si = stageIndex(T);
  const e = MOTION.enter(T, C.Kernel + 0.5, C.Kernel + 1.0) * (1 - MOTION.draw(T, C.Done + 0.3, C.Done + 0.7));
  const bus = T > C.Kernel + 1.2 ? 0.7 + 0.25 * hash(Math.floor(W * 5)) : 0;
  const link = T > C.Network + 0.4 ? 0.82 * MOTION.draw(T, C.Network + 0.4, C.Network + 1.2) : 0;
  const temp = lerp(31, 44, prog(T, C.Flash + 2.3, C.Flash + 3.4));
  const cells = Math.round(4096 * MOTION.draw(T, C.Cortex + 0.9, C.Cortex + 2.5));
  const blinkOn = Math.floor(W * 3) % 2 === 0;
  const flashed = T >= C.Flash + 3.2;
  return (
    <div style={{ position: "absolute", inset: 0, opacity: e, transform: `translateX(${(1 - e) * 30}px)`, pointerEvents: "none" }}>
      <Box title="STAGES" top={128} height={356}>
        {STAGES.map((s, i) => {
          const done = i < si, run = i === si, bad = run && !!v.fault;
          return (
            <div key={s} style={{ display: "flex", alignItems: "center", height: 38, fontFamily: FONT_M, fontSize: 17, whiteSpace: "pre", color: done ? INK : bad ? B : run ? A : DIM }}>
              <span style={{ color: DIM, width: 44 }}>{pad2(i + 1)}</span>
              <span style={{ width: 150, textShadow: run ? `0 0 12px ${rgba(bad ? B : A, 0.6)}` : "none" }}>{s}</span>
              <span style={{ flex: 1, textAlign: "right", color: done || run ? (bad ? B : A) : DIM2, opacity: run && !blinkOn ? 0.4 : 1 }}>{done ? "[ OK ]" : bad ? "[FAIL]" : run ? "[ >> ]" : "[ -- ]"}</span>
            </div>
          );
        })}
      </Box>
      <Box title="SYSTEM" top={516} height={204}>
        <Meter label="NEURAL BUS" u={bus} value={bus ? "2.4 TB/s" : "idle"} />
        <Meter label="UPLINK" u={link} value={link ? "-41 dBm" : "no carrier"} />
        <Meter label="EMITTER" u={(temp - 20) / 30} value={`${Math.round(temp)}°C`} warn={temp < 40 && T > C.Flash + 2.3} />
        <Meter label="V1 CELLS" u={cells / 4096} value={`${cells} / 4096`} />
      </Box>
      <Box title="TARGET" top={752} height={226}>
        {[["DEVICE", "/dev/ocular0"], ["PORT", "cortical C7"], ["MODEL", ctx.model], ["FIRMWARE", flashed ? "4.3.0" : "4.2.1"], ["LINE", ctx.number]].map(([k, val]) => (
          <div key={k} style={{ display: "flex", height: 32, alignItems: "center", fontFamily: FONT_M, fontSize: 15, whiteSpace: "pre" }}>
            <span style={{ color: DIM, width: 120 }}>{k}</span><span style={{ color: k === "FIRMWARE" && flashed ? A : INK, overflow: "hidden", textOverflow: "ellipsis" }}>{val}</span>
          </div>
        ))}
      </Box>
    </div>
  );
}

function Header({ T }: { T: number }) {
  const e = MOTION.enter(T, C.Kernel + 0.3, C.Kernel + 0.8) * (1 - MOTION.draw(T, C.Done + 0.3, C.Done + 0.7));
  const up = T >= C.Kernel ? `UP 00:${pad2(Math.floor(T - C.Kernel))}` : "UP --:--";
  return (
    <div style={{ position: "absolute", left: 64, right: 64, top: 48, height: 36, display: "flex", alignItems: "center", justifyContent: "space-between", fontFamily: FONT_M, fontSize: 15, letterSpacing: "0.16em", color: DIM, opacity: e, borderBottom: `1px solid ${DIM2}`, whiteSpace: "pre" }}>
      <span><span style={{ color: INK }}>KIROSHI OPTICS</span>  //  HOLO-OS INSTALLER 4.3.0</span>
      <span>tty1  ·  /dev/ocular0  ·  {up}</span>
      <span style={{ width: 160 }} />
    </div>
  );
}
function StatusBar({ v }: { v: View }) {
  const { T } = v;
  const si = stageIndex(T);
  const e = MOTION.enter(T, C.Kernel + 0.6, C.Kernel + 1.0) * (1 - MOTION.draw(T, C.Done + 0.3, C.Done + 0.7));
  const next = si < 7 ? CUE_LIST[si + 1]! : C.Done + 2;
  const total = (si + prog(T, CUE_LIST[si]!, next)) / 8;
  const n = Math.round(total * 30);
  const col = v.fault ? B : A;
  return (
    <div style={{ position: "absolute", left: 64, right: 64, top: 1004, height: 34, background: rgba(col, 0.88), color: BG, display: "flex", alignItems: "center", fontFamily: FONT_M, fontSize: 15, letterSpacing: "0.1em", fontWeight: 500, opacity: e, whiteSpace: "pre" }}>
      <span style={{ padding: "0 18px", background: v.fault ? A : B, color: "#1a0410", height: "100%", display: "flex", alignItems: "center" }}>HOLO-OS</span>
      <span style={{ padding: "0 18px" }}>STAGE {si + 1}/8  {STAGES[si]}{v.fault ? "  ·  FAILED" : v.waiting ? "  ·  AWAITING INPUT" : v.holding ? "  ·  REGISTERING" : ""}</span>
      <span style={{ display: "flex", gap: 2, padding: "0 10px" }}>{Array.from({ length: 30 }, (_, i) => <span key={i} style={{ width: 8, height: 12, background: i < n ? BG : "rgba(5,6,10,0.25)" }} />)}</span>
      <span style={{ padding: "0 14px" }}>{Math.round(total * 100)}%</span>
      <span style={{ flex: 1 }} />
      <span style={{ padding: "0 18px" }}>{T > C.Network + 1.6 ? "nc-09.watson.grid" : "no carrier"}</span>
      <span style={{ padding: "0 18px" }}>QEC-4096</span>
    </div>
  );
}

function Wordmark({ T, at, size, top }: { T: number; at: number; size: number; top: number }) {
  const o = MOTION.enter(T, at, at + 0.5);
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top, textAlign: "center", opacity: o, transform: `translateY(${(1 - o) * 14}px)` }}>
      <div style={{ fontFamily: FONT_B, fontWeight: 700, fontSize: size, letterSpacing: "0.34em", textIndent: "0.34em", lineHeight: 1, color: B, textShadow: `0 0 24px ${rgba(B, 0.55)}, 0 0 2px ${B}`, minHeight: size }}>{typed("KIROSHI", T, at, 18)}</div>
      <div style={{ fontFamily: FONT_JP, fontWeight: 500, fontSize: size * 0.42, letterSpacing: "0.2em", textIndent: "0.2em", color: A, marginTop: size * 0.22, textShadow: `0 0 16px ${rgba(A, 0.5)}`, opacity: MOTION.enter(T, at + 0.5, at + 0.9) }}>キロシ・オプティクス</div>
    </div>
  );
}
function Splash({ T, W }: { T: number; W: number }) {
  const P = C.Post, K = C.Kernel;
  const out = 1 - MOTION.draw(T, K - 0.05, K + 0.35);
  const lines: [string, number][] = [["KIROSHI OPTICS BIOS 4.2.1", P + 0.5], ["POST ................ OK", P + 1.0], ["MEM 2048 PB .......... OK", P + 1.4], ["OCULAR0 MK.IV ........ OK", P + 1.75], ["BOOT holo-os-4.3.0.img", P + 2.2]];
  return (
    <div style={{ position: "absolute", inset: 0, opacity: out, pointerEvents: "none" }}>
      <Wordmark T={T} at={P + 1.5} size={76} top={740} />
      <div style={{ position: "absolute", left: 64, top: 880, fontFamily: FONT_M, fontSize: 16, lineHeight: "26px", color: DIM, whiteSpace: "pre" }}>
        {lines.map(([l, s]) => <div key={l} style={{ color: l.endsWith("OK") && T > s + l.length / 50 ? INK : DIM }}>{typed(l, T, s, 50)}</div>)}
      </div>
      <div style={{ position: "absolute", right: 64, top: 1000, fontFamily: FONT_M, fontSize: 14, letterSpacing: "0.2em", color: DIM, opacity: T > P + 1.2 && Math.floor(W * 1.5) % 2 === 0 ? 1 : 0.3 }}>BLINK x2 TO ENTER SETUP</div>
    </div>
  );
}
function DoneScreen({ T, W, ctx }: { T: number; W: number; ctx: Ctx }) {
  const D = C.Done;
  const e = MOTION.enter(T, D + 0.5, D + 1.0);
  const n = clamp(3 - Math.floor(T - (D + 1.1)), 1, 3);
  return (
    <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
      <Wordmark T={T} at={D + 0.5} size={64} top={650} />
      <div style={{ position: "absolute", left: 0, right: 0, top: 800, textAlign: "center", fontFamily: FONT_M, fontSize: 18, letterSpacing: "0.3em", textIndent: "0.3em", color: INK, opacity: e, whiteSpace: "pre" }}>{typed("HOLO-OS 4.3.0  ·  NEURAL-LINK INSTALLED", T, D + 0.9, 60)}</div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 838, textAlign: "center", fontFamily: FONT_M, fontSize: 15, letterSpacing: "0.2em", color: A, opacity: MOTION.enter(T, D + 1.3, D + 1.6), whiteSpace: "pre" }}>{`${ctx.name.toUpperCase()}  ·  LINE ${ctx.number}`}</div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 874, textAlign: "center", fontFamily: FONT_M, fontSize: 15, letterSpacing: "0.2em", color: DIM, opacity: MOTION.enter(T, D + 1.5, D + 1.8) }}>rebooting ocular suite in {n}</div>
      <div style={{ position: "absolute", left: 64, top: 1000, fontFamily: FONT_M, fontSize: 19, whiteSpace: "pre", opacity: e }}><Prompt /><Cursor W={W} /></div>
    </div>
  );
}

/** Slices the HTML layers into displaced bands during glitch spikes (the copies are inert). */
function Glitched({ W, g, children }: { W: number; g: number; children: ReactNode }) {
  const k = Math.floor(W * 30);
  const slices = g < 0.03 ? [] : [0, 1, 2].map((i) => ({ y: hash(k + i * 7) * 92, h: 3 + hash(k + i * 13) * 9, dx: (hash(k + i * 3) - 0.5) * 70 * g }));
  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div style={{ position: "absolute", inset: 0, transform: g < 0.03 ? undefined : `translateX(${(hash(k) - 0.5) * 10 * g}px)` }}>{children}</div>
      {slices.map((s, i) => (
        <div key={i} aria-hidden {...{ inert: "" }} style={{ position: "absolute", inset: 0, pointerEvents: "none", clipPath: `inset(${s.y}% 0 ${Math.max(0, 100 - s.y - s.h)}% 0)`, transform: `translateX(${s.dx}px)`, filter: i === 1 ? "hue-rotate(120deg) saturate(2)" : "none" }}>{children}</div>
      ))}
    </div>
  );
}

// ── the piece ──
export interface HoloInstallProps {
  selfInstall: boolean;
  /** Opened with { install: true }: confirm by itself once the installer asks. */
  autoStart: boolean;
}

export function HoloInstall({ selfInstall, autoStart }: HoloInstallProps) {
  const implant = useStore((s) => s.state?.implant);
  const line = useStore((s) => s.state?.line);
  const ctx: Ctx = { selfInstall, model: implant?.model || "Kiroshi NL-77 Synapse", name: line?.name || "Unknown citizen", number: line?.number ?? "---" };
  const log = useMemo(() => buildLog(ctx), [ctx.selfInstall, ctx.model]); // eslint-disable-line react-hooks/exhaustive-deps
  const [, frame] = useReducer((n: number) => n + 1, 0);
  const view = useRef<View>({ T: 0, W: 0, holding: false, idle: 0, fault: null, waiting: false, confirmed: false });
  const run = useRef({ asked: false, reply: null as { implant: ImplantState | null } | null, cue: 0, idleAt: -10, nextIdle: 9, lastIdleSound: -99, done: false, alive: true });
  const auto = useRef(autoStart && selfInstall);

  const confirm = () => {
    const v = view.current;
    if (v.confirmed || !selfInstall || v.T < ASK) return;
    v.confirmed = true;
    // the gate now holds until the end, whatever nl:state says meanwhile
    getStore().setImplantFlow(true);
    v.T = Math.max(v.T, CONFIRM);
    v.waiting = false;
  };
  const retry = () => {
    const r = run.current, v = view.current;
    if (!v.fault) return;
    v.fault = null; v.holding = false; v.T = REQUEST_AT;
    r.asked = false; r.reply = null;
    r.cue = INSTALL_CUES.findIndex((c) => c.at >= REQUEST_AT);
  };
  const ask = () => {
    const r = run.current;
    r.asked = true;
    let timer = 0;
    const timeout = new Promise<never>((_, reject) => { timer = window.setTimeout(() => reject(new RequestError("timeout")), REPLY_TIMEOUT_MS); });
    Promise.race([request("implant.install", {}), timeout]).then(
      (data) => { if (r.alive) r.reply = { implant: data?.implant && typeof data.implant === "object" ? data.implant : null }; },
      (err) => {
        if (!r.alive) return;
        view.current.fault = { slug: err instanceof RequestError ? err.slug : "unknown", at: view.current.W };
        play("install_fault");
      },
    ).finally(() => window.clearTimeout(timer));
  };

  // The driver: one rAF loop for both clocks, the cues, the request, the holds.
  useEffect(() => {
    const r = run.current;
    r.alive = true;
    const speed = reducedMotion() ? 1.6 : 1;
    let last = performance.now(), raf = 0;
    const tick = (now: number) => {
      if (!r.alive) return;
      const dt = clamp((now - last) / 1000, 0, 0.1); // a rAF stamp may predate performance.now()
      last = now;
      const v = view.current;
      v.W += dt;
      if (!v.fault && !r.done) {
        let T = v.T + dt * speed;
        if (!v.confirmed) {
          if (T >= WAIT) { T = WAIT; v.waiting = true; if (auto.current) { auto.current = false; v.T = T; confirm(); T = v.T; } }
        } else {
          if (!r.asked && T >= REQUEST_AT) ask();
          v.holding = T >= HOLD && !r.reply && !v.fault;
          if (v.holding) T = HOLD;
        }
        v.T = T;
        while (r.cue < INSTALL_CUES.length && INSTALL_CUES[r.cue]!.at <= v.T) { play(INSTALL_CUES[r.cue]!.sound); r.cue++; }
        if (v.T >= END) {
          r.done = true;
          useStore.getState().implantOnline(r.reply?.implant ?? null);
          return;
        }
      }
      // glitch bursts while the installer waits, a few with a sound
      if (v.waiting && !v.fault && v.W >= r.nextIdle) {
        r.idleAt = v.W;
        r.nextIdle = v.W + 2.6 + Math.random() * 4.2;
        if (v.W - r.lastIdleSound > 9 && Math.random() < 0.45) { r.lastIdleSound = v.W; play("install_idle"); }
      }
      v.idle = v.waiting ? 0.9 * spike(v.W, r.idleAt, 0.28) : 0;
      frame();
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => { r.alive = false; cancelAnimationFrame(raf); };
  }, []);

  const v = view.current;
  const choices: Choice[] | null = v.fault
    ? [{ key: "R", label: "Retry the installation", primary: true, act: retry }, { key: "Q", label: "Close", act: userClose }]
    : v.waiting
      ? selfInstall
        ? [{ key: "Y", label: "Install the Neural-Link", primary: true, act: confirm }, { key: "N", label: "Cancel", act: userClose }]
        : [{ key: "Q", label: "Close", act: userClose }]
      : null;
  const choicesRef = useRef(choices);
  choicesRef.current = choices;
  // the keys on the caps (Enter takes the first); Escape stays the shell's close
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const list = choicesRef.current;
      if (!list || e.repeat) return;
      const k = e.key.length === 1 ? e.key.toUpperCase() : e.key;
      const hit = k === "Enter" ? list[0] : list.find((c) => c.key === k);
      if (hit) { e.preventDefault(); hit.act(); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const { T, W } = v;
  const { Post: P, Kernel: K, Verify: V, Done: D } = C;
  const gl = glParams(v);
  // the CRT: a line opens to the screen, the screen folds to a line then a dot
  const on = MOTION.enter(T, P, P + 0.4), off = MOTION.draw(T, D + 2.35, D + 2.7), off2 = MOTION.draw(T, D + 2.7, D + 2.95);
  const sy = lerp(0.004, 1, on) * (1 - off * 0.996), sx = 1 - off2;
  const bright = 1 + 0.9 * spike(T, P, 0.45) + 1.6 * off * (1 - off2);
  const termDim = 1 - 0.7 * MOTION.draw(T, V + 0.3, V + 0.9) * (1 - MOTION.draw(T, V + 2.2, V + 2.5));
  const termOut = 1 - MOTION.draw(T, D + 0.3, D + 0.7);
  const shot = (from: number, to: number) => T >= from && T < to;

  return (
    <div className="holo-os" role="dialog" aria-modal="true" aria-label="Kiroshi Neural-Link installation">
      <div className="holo-os__screen" style={{ transform: `scale(${sx}, ${sy})`, filter: bright !== 1 ? `brightness(${bright.toFixed(2)})` : undefined }}>
        <GLView params={gl} />
        <Glitched W={W} g={gl.glitch}>
          {shot(P, K + 0.5) && <Splash T={T} W={W} />}
          {shot(K - 0.2, D + 0.8) && <>
            <Header T={T} />
            <div style={{ position: "absolute", inset: 0, opacity: termDim * termOut }}><Terminal v={v} log={log} ctx={ctx} choices={choices} /></div>
            <Panel v={v} ctx={ctx} />
            <StatusBar v={v} />
          </>}
          {T >= D + 0.4 && <DoneScreen T={T} W={W} ctx={ctx} />}
        </Glitched>
        <div className="holo-os__scan" aria-hidden />
        <div className="holo-os__vignette" aria-hidden />
      </div>
    </div>
  );
}
