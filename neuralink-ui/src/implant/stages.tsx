/* The seven scenes of the installation. Each is mounted for its stage only and
   animates in CSS against `--d` (the stage length); the counters and the typed
   identity tick in JS. Captions sit under every scene. */
import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { IrisGlyph, Wordmark } from "./Kiroshi";
import { SynapseNet } from "./SynapseNet";
import { reducedMotion } from "@/shell/Stage";

function Caption({ title, sub }: { title: string; sub: string }) {
  return (
    <div className="iseq__caption">
      <div className="iseq__title label">{title}</div>
      <div className="iseq__sub mono">{sub}</div>
    </div>
  );
}

/* ------------------------------------------------------------ 1. boot */

export function BootScene() {
  return (
    <div className="iscene iscene--boot">
      <div className="iboot__iris"><IrisGlyph size={300} /></div>
      <div className="iboot__mark">
        <Wordmark reveal size={86} />
        <span className="iboot__scan" aria-hidden />
      </div>
      <div className="iboot__tag mono">KIROSHI OPTICS · NEURAL-LINK NL-77 SYNAPSE</div>
    </div>
  );
}

/* ----------------------------------------------------------- 2. flash */

const SEGMENTS = 40;

function hexLines(count: number): string[] {
  let s = 0x7f3a1c;
  const next = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s; };
  const byte = () => (next() >>> 8 & 0xff).toString(16).toUpperCase().padStart(2, "0");
  return Array.from({ length: count }, (_, i) => `0x${(0x7700 + i * 16).toString(16).toUpperCase().padStart(6, "0")}  ${Array.from({ length: 8 }, byte).join(" ")}  ${Array.from({ length: 4 }, byte).join("")}`);
}

export function FlashScene({ dur }: { dur: number }) {
  const lines = useMemo(() => hexLines(48), []);
  const pct = useRef<HTMLSpanElement>(null);
  const blocks = useRef<HTMLSpanElement>(null);
  useCounter((k) => {
    if (pct.current) pct.current.textContent = `${Math.floor(k * 100)}`.padStart(3, " ");
    if (blocks.current) blocks.current.textContent = `${Math.floor(k * 256)}`.padStart(3, "0");
  }, 0.08, 0.86, dur);
  return (
    <div className="iscene iscene--flash">
      <div className="iflash__main">
        <div className="iflash__chip" aria-hidden>
          <IrisGlyph size={92} />
          <span className="iflash__pins" />
        </div>
        <div className="iflash__file mono">
          <span>kiroshi-nl77-synapse.fw</span>
          <span className="iflash__dim">4.21 MB · signed KIROSHI-CA/77 · SHA-3 OK</span>
        </div>
        <div className="iflash__bar" aria-hidden>
          {Array.from({ length: SEGMENTS }, (_, i) => <i key={i} style={{ ["--i" as string]: i, ["--n" as string]: SEGMENTS } as CSSProperties} />)}
        </div>
        <div className="iflash__nums mono">
          <span>BLOCK <b ref={blocks}>000</b>/256</span>
          <span><b ref={pct}>  0</b> %</span>
        </div>
      </div>
      <div className="iflash__hex mono" aria-hidden>
        <div className="iflash__hexroll">
          {lines.map((l, i) => <div key={i}>{l}</div>)}
        </div>
      </div>
      <Caption title="Flashing firmware v77.2.5" sub="Writing optic microcode · do not disconnect" />
    </div>
  );
}

/** Calls `fn(k)` every frame, k going 0..1 between fractions `from` and `to` of a `dur` ms stage. */
function useCounter(fn: (k: number) => void, from: number, to: number, dur: number) {
  const cb = useRef(fn);
  cb.current = fn;
  useEffect(() => {
    let raf = 0;
    const t0 = performance.now();
    const tick = (now: number) => {
      const k = Math.max(0, Math.min(1, ((now - t0) / dur - from) / (to - from)));
      cb.current(k);
      if (k < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [from, to, dur]);
}

/* ---------------------------------------------------------- 3. insert */

const HEAD = "M232 562 C230 522 214 490 196 458 C160 402 150 322 176 252 C206 170 290 122 370 130 C452 138 506 198 512 272 C514 298 510 314 518 328 L548 382 C552 392 546 398 532 400 L530 420 C538 426 538 434 528 438 L530 452 C528 472 512 486 486 490 C460 492 440 490 424 502 L410 562";
const BRAIN = "M206 300 C206 226 262 176 338 172 C420 168 482 214 486 282 C488 318 474 344 444 356 C410 370 372 362 340 372 C300 384 262 382 236 364 C214 348 206 326 206 300 Z";
const GYRI = [
  "M240 250 C262 228 288 236 300 220 C316 200 344 206 352 192",
  "M226 306 C252 296 262 272 290 274 C318 276 322 250 350 252",
  "M372 214 C392 236 420 222 440 240 C458 256 462 240 476 262",
  "M300 330 C320 312 348 322 362 304 C378 284 404 296 420 282",
  "M250 350 C270 336 292 346 306 336",
  "M380 340 C400 326 428 336 452 318",
];

export function InsertScene({ model, dur }: { model: string; dur: number }) {
  const depth = useRef<HTMLElement>(null);
  const anchors = useRef<HTMLElement>(null);
  useCounter((k) => {
    if (depth.current) depth.current.textContent = (k * 4.2).toFixed(2);
    if (anchors.current) anchors.current.textContent = String(Math.floor(k * 6));
  }, 0.1, 0.62, dur);
  return (
    <div className="iscene iscene--insert">
      <svg className="iins__svg" viewBox="80 100 560 480" width={620} height={530} aria-hidden>
        <defs>
          <radialGradient id="iins-dock" r="0.5">
            <stop offset="0" className="iins__stop0" />
            <stop offset="0.4" className="iins__stop1" />
            <stop offset="1" className="iins__stop2" />
          </radialGradient>
        </defs>
        <g className="iins__grid">
          {Array.from({ length: 12 }, (_, i) => <line key={`h${i}`} x1="80" x2="640" y1={110 + i * 40} y2={110 + i * 40} />)}
          {Array.from({ length: 14 }, (_, i) => <line key={`v${i}`} y1="100" y2="580" x1={100 + i * 40} x2={100 + i * 40} />)}
        </g>
        <path className="iins__head" d={HEAD} pathLength={1} />
        <path className="iins__brain" d={BRAIN} pathLength={1} />
        {GYRI.map((d, i) => <path key={i} className="iins__gyrus" d={d} pathLength={1} style={{ ["--i" as string]: i } as CSSProperties} />)}
        <path className="iins__cerebellum" d="M214 372 C204 392 214 414 238 418 C262 420 276 404 270 386" pathLength={1} />
        <path className="iins__stem" d="M262 382 C262 410 256 432 252 470" pathLength={1} />
        {Array.from({ length: 5 }, (_, i) => <rect key={i} className="iins__vert" x={236 - i * 2} y={446 + i * 24} width="34" height="16" rx="5" />)}
        {/* the cortical port and the implant docking into it */}
        <circle className="iins__port" cx="232" cy="432" r="12" />
        <g className="iins__dockglow"><circle cx="232" cy="432" r="46" fill="url(#iins-dock)" /></g>
        <g className="iins__ripple"><circle cx="232" cy="432" r="18" /></g>
        <g className="iins__sparks">
          {Array.from({ length: 10 }, (_, i) => {
            const a = (i / 10) * Math.PI * 2 + 0.3;
            return <line key={i} x1={232 + Math.cos(a) * 16} y1={432 + Math.sin(a) * 16} x2={232 + Math.cos(a) * (34 + (i % 3) * 10)} y2={432 + Math.sin(a) * (34 + (i % 3) * 10)} style={{ ["--i" as string]: i } as CSSProperties} />;
          })}
        </g>
        <g className="iins__node">
          <path d="M-14 -8 L0 -16 L14 -8 L14 8 L0 16 L-14 8 Z" />
          <circle r="5" />
        </g>
        <path className="iins__trace" d="M232 432 C236 400 250 386 262 382 C282 370 300 352 340 340" pathLength={1} />
        <g className="iins__callout">
          <line x1="240" y1="438" x2="128" y2="520" />
          <line x1="128" y1="520" x2="96" y2="520" />
          <text x="96" y="540">PORT C7</text>
        </g>
      </svg>
      <div className="iins__read mono">
        <div><span>DEPTH</span><b ref={depth}>0.00</b> mm</div>
        <div><span>ANCHORS</span><b ref={anchors}>0</b>/6</div>
        <div><span>MODEL</span><b>{model}</b></div>
      </div>
      <Caption title="Inserting implant · cortical port C7" sub="Seating micro-anchors · sealing the dura" />
    </div>
  );
}

/* --------------------------------------------------------- 4. synapse */

const SYNAPSES = 86_400_000_000;

function abbreviate(n: number): string {
  if (n >= 1e9) return `${(n / 1e9).toFixed(1)} B`;
  if (n >= 1e6) return `${(n / 1e6).toFixed(1)} M`;
  if (n >= 1e3) return `${(n / 1e3).toFixed(1)} K`;
  return String(Math.floor(n));
}
const spaced = (n: number) => Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");

export function SynapseScene({ dur, scanAt }: { dur: number; scanAt: number }) {
  const big = useRef<HTMLSpanElement>(null);
  const full = useRef<HTMLSpanElement>(null);
  const cover = useRef<HTMLSpanElement>(null);
  const from = scanAt / dur, to = 0.9;
  useCounter((k) => {
    // exponential feel: slow first links, then billions at once
    const n = k >= 1 ? SYNAPSES : SYNAPSES * (Math.pow(10, k * 4) - 1) / 9999;
    if (big.current) big.current.textContent = abbreviate(n);
    if (full.current) full.current.textContent = spaced(n);
    if (cover.current) cover.current.textContent = String(Math.round(k * 100));
  }, from, to, dur);
  return (
    <div className="iscene iscene--synapse">
      <div className="isyn__net"><SynapseNet startAt={scanAt} spreadMs={dur * (to - from)} /></div>
      <div className="isyn__count">
        <span className="isyn__label label">Synapses linked</span>
        <span className="isyn__big mono" ref={big}>0</span>
        <span className="isyn__full mono"><span ref={full}>0</span> / 86{" "}400{" "}000{" "}000</span>
        <span className="isyn__cover mono">CORTEX COVERAGE <b ref={cover}>0</b> %</span>
      </div>
      <Caption title="Connecting to synapse" sub="Mapping the neural mesh outward from the implant" />
    </div>
  );
}

/* ------------------------------------------------------- 5. calibrate */

function irisFibres(): string {
  const parts: string[] = [];
  for (let i = 0; i < 90; i++) {
    const a = (i / 90) * Math.PI * 2;
    const wob = Math.sin(i * 1.7) * 0.06;
    const r0 = 34 + (i % 3) * 3, r1 = 104 - (i % 4) * 6;
    parts.push(`M${(Math.cos(a) * r0).toFixed(1)} ${(Math.sin(a) * r0).toFixed(1)} Q${(Math.cos(a + wob) * (r0 + r1) / 2).toFixed(1)} ${(Math.sin(a + wob) * (r0 + r1) / 2).toFixed(1)} ${(Math.cos(a + wob * 2) * r1).toFixed(1)} ${(Math.sin(a + wob * 2) * r1).toFixed(1)}`);
  }
  return parts.join(" ");
}

export function CalibrateScene({ dur }: { dur: number }) {
  const fibres = useMemo(irisFibres, []);
  const dio = useRef<HTMLElement>(null);
  const ang = useRef<HTMLElement>(null);
  useCounter((k) => {
    const e = 1 - k;
    if (dio.current) dio.current.textContent = (e * 2.75 * Math.cos(k * 9)).toFixed(2);
    if (ang.current) ang.current.textContent = (0.02 + e * 1.8).toFixed(2);
  }, 0.05, 0.66, dur);
  return (
    <div className="iscene iscene--calibrate">
      <svg className="ical__svg" viewBox="-200 -200 400 400" width={460} height={460} aria-hidden>
        <g className="ical__eye">
          <circle className="ical__sclera" r="118" />
          <path className="ical__fibres" d={fibres} />
          <circle className="ical__limbal" r="108" />
          <circle className="ical__pupil" r="32" />
          <circle className="ical__glint" cx="-12" cy="-14" r="7" />
        </g>
        <g className="ical__ring ical__ring--a">
          <circle r="150" strokeDasharray="4 8" />
          {Array.from({ length: 4 }, (_, i) => <line key={i} x1="0" y1="-170" x2="0" y2="-138" transform={`rotate(${i * 90})`} />)}
        </g>
        <g className="ical__ring ical__ring--b">
          <circle r="132" strokeDasharray="160 47.3" />
        </g>
        <g className="ical__ring ical__ring--c">
          <circle r="60" strokeDasharray="30 17.1" />
          <line x1="-190" y1="0" x2="-70" y2="0" /><line x1="70" y1="0" x2="190" y2="0" />
          <line x1="0" y1="-190" x2="0" y2="-70" /><line x1="0" y1="70" x2="0" y2="190" />
        </g>
        <g className="ical__lock">
          {[0, 90, 180, 270].map((r) => <path key={r} d="M-176 -150 L-176 -176 L-150 -176" transform={`rotate(${r})`} />)}
        </g>
      </svg>
      <div className="ical__read mono">
        <div><span>DIOPTRE</span><b ref={dio}>2.75</b> D</div>
        <div><span>ALIGN</span>±<b ref={ang}>1.82</b>°</div>
        <div className="ical__ok"><span>IRIS</span><b>LOCK</b></div>
      </div>
      <Caption title="Optic calibration" sub="Kiroshi optic interface · aligning the focal plane" />
    </div>
  );
}

/* -------------------------------------------------------- 6. identity */

function useTyped(text: string, delay: number, cps: number): string {
  const [n, setN] = useState(reducedMotion() ? text.length : 0);
  useEffect(() => {
    if (reducedMotion()) { setN(text.length); return; }
    setN(0);
    let iv = 0;
    const t = window.setTimeout(() => {
      iv = window.setInterval(() => setN((x) => { if (x >= text.length) { window.clearInterval(iv); return x; } return x + 1; }), 1000 / cps);
    }, delay);
    return () => { window.clearTimeout(t); window.clearInterval(iv); };
  }, [text, delay, cps]);
  return text.slice(0, n);
}

export function IdentityScene({ name, number, grantAt, holding }: { name: string; number: string; grantAt: number; holding: boolean }) {
  const typedName = useTyped(name.toUpperCase(), 120, 40);
  const typedNum = useTyped(number, 120 + name.length * 25 + 60, 40);
  const [granted, setGranted] = useState(false);
  useEffect(() => {
    const t = window.setTimeout(() => setGranted(true), grantAt);
    return () => window.clearTimeout(t);
  }, [grantAt]);
  return (
    <div className="iscene iscene--identity">
      <div className={`iid__card ${granted ? "is-granted" : ""}`}>
        <div className="iid__top mono"><span>NEURAL-LINK · CITIZEN BINDING</span><span>NC-ID</span></div>
        <div className="iid__body">
          <div className="iid__iris"><IrisGlyph size={104} /></div>
          <div className="iid__fields">
            <span className="iid__k mono">NAME</span>
            <span className="iid__name">{typedName}<i className="iid__caret" /></span>
            <span className="iid__k mono">NEURAL LINE</span>
            <span className="iid__num mono">{typedNum || " "}</span>
          </div>
        </div>
        <div className="iid__bar" aria-hidden><span /></div>
        {granted && <div className="iid__stamp label">Access granted</div>}
      </div>
      <Caption title="Binding identity" sub={holding ? "Awaiting cortex handshake…" : "Biometric signature → neural line"} />
    </div>
  );
}

/* ---------------------------------------------------------- 7. online */

export function OnlineScene({ model, name }: { model: string; name: string }) {
  return (
    <div className="iscene iscene--online">
      <span className="ion__ring ion__ring--a" aria-hidden />
      <span className="ion__ring ion__ring--b" aria-hidden />
      <div className="ion__text">
        <span className="ion__word label">Neural-Link online</span>
        <span className="ion__sub mono">{model} · bound to {name}</span>
      </div>
    </div>
  );
}
