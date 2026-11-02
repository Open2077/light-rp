import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { emit, on } from "@/bridge/open77";
import type { ArmamentState, ArsenalWeapon } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { performArmament } from "../inventory/armament";
import "./weaponwheel.css";

/* The weapon wheel (hold TAB, client/core/weapon_wheel.lua). Every weapon in the
   pockets on a radial, "holster" at the top: whatever is in the hands goes away (a gun,
   the fists, the blades) and the loadout stays; it works with empty pockets. The mouse aims a virtual stick: its
   movement, not the pointer position, picks the slot, so the wheel works wherever
   the pointer starts. Releasing the key commits (server operation `select`). */

const PAGE = "lightrp:ui:weaponwheel";
const HALF = 340;                     // half of the drawn square, px
const R_OUT = 300, R_IN = 138, R_HUB = 124;
const MIN_SLOTS = 6, GAP = 1.4;       // degrees between two slots
const DEAD = 26, CLAMP = 120;         // virtual stick: dead zone and reach, px
const POP = 14;                       // how far the aimed slot leaves the ring
const CLASS: Record<string, string> = {
  pistol: "PISTOL", revolver: "REVOLVER", smg: "SUBMACHINE GUN", shotgun: "SHOTGUN", rifle: "ASSAULT RIFLE",
  lmg: "LIGHT MACHINE GUN", precision: "PRECISION RIFLE", sniper: "SNIPER RIFLE",
};

type Slot = { key: string; kind: "unarmed" | "weapon" | "empty"; weapon?: ArsenalWeapon };
type Phase = "closed" | "open" | "closing";
interface Toast { id: number; title: string; text?: string; error?: boolean }
interface Wire { kind: string; key?: string }

const rad = (d: number) => (d * Math.PI) / 180;
const at = (deg: number, r: number): [number, number] => [Math.cos(rad(deg)) * r, Math.sin(rad(deg)) * r];
function sector(a0: number, a1: number, r0: number, r1: number): string {
  const large = a1 - a0 > 180 ? 1 : 0;
  const [x0, y0] = at(a0, r1), [x1, y1] = at(a1, r1), [x2, y2] = at(a1, r0), [x3, y3] = at(a0, r0);
  return `M${x0} ${y0}A${r1} ${r1} 0 ${large} 1 ${x1} ${y1}L${x2} ${y2}A${r0} ${r0} 0 ${large} 0 ${x3} ${y3}Z`;
}
function arc(a0: number, a1: number, r: number): string {
  const [x0, y0] = at(a0, r), [x1, y1] = at(a1, r);
  return `M${x0} ${y0}A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1} ${y1}`;
}
const pad = (n?: number) => (Number.isInteger(n) ? String(Math.max(0, Math.min(999, n!))).padStart(3, "0") : "---");

function Fist({ size = 64 }: { size?: number }) {
  return <svg viewBox="0 0 48 48" width={size} height={size} fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinejoin="round" strokeLinecap="round" aria-hidden="true">
    <path d="M14 22v-6a3 3 0 0 1 6 0v4M20 19v-5a3 3 0 0 1 6 0v6M26 20v-4a3 3 0 0 1 6 0v6M32 22v-2a3 3 0 0 1 6 0v8c0 7-5 12-12 12h-2c-6 0-10-4-10-9v-5c0-2 1-3 3-3h4a3 3 0 0 1 0 6h-5" />
  </svg>;
}

function state(weapon: ArsenalWeapon, armament?: ArmamentState): { text: string; tone: string } {
  if (weapon.hand === "right" || weapon.hand === "left")
    return armament?.holstered ? { text: "HOLSTERED", tone: "steel" } : { text: weapon.hand === "left" ? "LEFT HAND" : "IN HAND", tone: "accent" };
  return { text: "IN POCKETS", tone: "dim" };
}

export function WeaponWheel() {
  const armament = useStore(s => s.armament);
  const feedback = useStore(s => s.armamentFeedback);
  const [phase, setPhase] = useState<Phase>("closed");
  const [index, setIndex] = useState(0);
  const [aim, setAim] = useState<number | null>(null);
  const [key, setKey] = useState("TAB");
  const [chosen, setChosen] = useState<string | null>(null);
  const [toast, setToast] = useState<Toast | null>(null);
  const [kick, setKick] = useState(0);
  // a tap on the key: the wheel stays open and a click (or the key again) picks
  const [latched, setLatched] = useState(false);

  const slots = useMemo<Slot[]>(() => {
    const list: Slot[] = [{ key: "unarmed", kind: "unarmed" }, ...(armament?.arsenal ?? []).map(w => ({ key: w.instanceId, kind: "weapon" as const, weapon: w }))];
    while (list.length < MIN_SLOTS) list.push({ key: `empty:${list.length}`, kind: "empty" });
    return list;
  }, [armament?.arsenal]);

  const r = useRef({ phase: "closed" as Phase, index: 0, slots, armament, vec: { x: 0, y: 0 }, last: null as null | { x: number; y: number }, committedAt: 0 });
  r.current.phase = phase; r.current.index = index; r.current.slots = slots; r.current.armament = armament;

  const say = (t: Omit<Toast, "id">) => setToast({ ...t, id: Date.now() });

  useEffect(() => {
    const select = (i: number) => {
      const s = r.current.slots;
      if (i === r.current.index || i < 0 || i >= s.length || s[i]?.kind === "empty") return;
      r.current.index = i; setIndex(i); setKick(k => k + 1);
      emit(PAGE, { kind: "hover" });
    };
    const finish = () => {
      r.current.phase = "closing"; setPhase("closing");
      window.setTimeout(() => { if (r.current.phase === "closing") { r.current.phase = "closed"; setPhase("closed"); } }, 230);
    };
    const commit = () => {
      if (r.current.phase !== "open") return;
      const slot = r.current.slots[r.current.index], a = r.current.armament, store = useStore.getState();
      if (!slot) { finish(); return; }
      const busy = !!(store.armamentPending || a?.busy);
      if (slot.kind === "unarmed") {
        // The server holsters whatever is in the hands, armament or not (B does the same).
        emit(PAGE, { kind: "holster" });
        r.current.committedAt = Date.now();
        setChosen(slot.key); emit(PAGE, { kind: "chosen", unarmed: true });
        say({ title: "HOLSTERED", text: "Hands free. Your loadout stays with you." });
        finish();
        return;
      }
      let request: { instanceId?: string } | null = null;
      if (slot.kind === "weapon" && slot.weapon && !(a?.right?.instanceId === slot.weapon.instanceId && !a?.holstered)) request = { instanceId: slot.weapon.instanceId };
      if (request && busy) say({ title: "EQUIPMENT BUSY", text: "Synchronizing — try again in a moment.", error: true });
      else if (request) {
        performArmament("select", request);
        r.current.committedAt = Date.now();
        setChosen(slot.key); emit(PAGE, { kind: "chosen", unarmed: false });
        say({ title: "IN HAND", text: slot.weapon!.label });
      }
      finish();
    };
    const cancel = () => { if (r.current.phase === "open") finish(); };
    const offWire = on<Wire>(PAGE, p => {
      if (p?.kind === "open") {
        const a = r.current.armament, s = r.current.slots;
        const held = a?.right?.instanceId ? s.findIndex(x => x.key === a.right!.instanceId) : 0;
        r.current.vec = { x: 0, y: 0 }; r.current.last = null; r.current.index = Math.max(0, held);
        setIndex(Math.max(0, held)); setAim(null); setChosen(null); setKey(p.key || "TAB"); setLatched(false);
        r.current.phase = "open"; setPhase("open");
      } else if (p?.kind === "latch") setLatched(true);
      else if (p?.kind === "commit") commit();
      else if (p?.kind === "cancel") cancel();
    });
    const move = (e: MouseEvent) => {
      if (r.current.phase !== "open") return;
      const last = r.current.last;
      r.current.last = { x: e.clientX, y: e.clientY };
      if (!last) return;
      const v = r.current.vec;
      v.x += e.clientX - last.x; v.y += e.clientY - last.y;
      const len = Math.hypot(v.x, v.y);
      if (len > CLAMP) { v.x *= CLAMP / len; v.y *= CLAMP / len; }
      if (len < DEAD) return;
      const angle = (Math.atan2(v.y, v.x) * 180) / Math.PI;
      setAim(angle);
      const n = r.current.slots.length, step = 360 / n;
      select(((Math.round((angle + 90) / step) % n) + n) % n);
    };
    const wheel = (e: WheelEvent) => {
      if (r.current.phase !== "open") return;
      const s = r.current.slots, n = s.length, dir = e.deltaY > 0 ? 1 : -1;
      for (let k = 1, i = r.current.index; k < n; k++) { i = (i + dir + n) % n; if (s[i]?.kind !== "empty") { select(i); setAim(-90 + (360 / n) * i); break; } }
    };
    const down = (e: MouseEvent) => {
      if (r.current.phase !== "open") return;
      e.preventDefault();
      if (e.button === 0) emit(PAGE, { kind: "close", commit: true });
      if (e.button === 2) emit(PAGE, { kind: "close", commit: false });
    };
    const menu = (e: MouseEvent) => { if (r.current.phase === "open") e.preventDefault(); };
    window.addEventListener("mousemove", move);
    window.addEventListener("wheel", wheel, { passive: true });
    window.addEventListener("mousedown", down);
    window.addEventListener("contextmenu", menu);
    return () => { offWire(); window.removeEventListener("mousemove", move); window.removeEventListener("wheel", wheel); window.removeEventListener("mousedown", down); window.removeEventListener("contextmenu", menu); };
  }, []);

  // a refusal from the server right after a choice replaces the confirmation
  useEffect(() => {
    if (feedback?.error && Date.now() - r.current.committedAt < 6000) say({ title: "NOT EQUIPPED", text: feedback.text, error: true });
  }, [feedback]);
  useEffect(() => { if (!toast) return; const t = window.setTimeout(() => setToast(null), toast.error ? 3600 : 2200); return () => clearTimeout(t); }, [toast]);

  const toastView = toast && <div key={toast.id} className={`ww-toast${toast.error ? " is-error" : ""}`}><b>{toast.title}</b>{toast.text && <span>{toast.text}</span>}</div>;
  if (phase === "closed") return toastView || null;

  const n = slots.length, step = 360 / n, rMid = (R_IN + R_OUT) / 2 + 6;
  const hovered = slots[Math.min(index, n - 1)] ?? slots[0]!;
  const w = hovered.weapon, st = w ? state(w, armament) : null;
  const empty = w && (w.rounds ?? 0) <= 0;
  return <>
    {toastView}
    <div className={`ww is-${phase}`} data-testid="weapon-wheel">
      <div className="ww__scrim" />
      <div className="ww__wheel" style={{ width: HALF * 2, height: HALF * 2 }}>
        <svg className="ww__svg" viewBox={`${-HALF} ${-HALF} ${HALF * 2} ${HALF * 2}`} width={HALF * 2} height={HALF * 2} aria-hidden="true">
          <defs>
            <radialGradient id="ww-seg" cx="0" cy="0" r={R_OUT} gradientUnits="userSpaceOnUse">
              <stop offset={R_IN / R_OUT} stopColor="#0A0A0C" stopOpacity=".94" />
              <stop offset="1" stopColor="#17181C" stopOpacity=".9" />
            </radialGradient>
            <radialGradient id="ww-seg-on" cx="0" cy="0" r={R_OUT} gradientUnits="userSpaceOnUse">
              <stop offset={R_IN / R_OUT} stopColor="#241B00" stopOpacity=".96" />
              <stop offset="1" stopColor="#4A3800" stopOpacity=".92" />
            </radialGradient>
          </defs>
          <circle r={R_OUT + 26} className="ww__orbit" />
          <circle r={R_OUT + 36} className="ww__orbit ww__orbit--far" />
          {Array.from({ length: n }, (_, i) => { const [x0, y0] = at(-90 + i * step + step / 2, R_OUT + 20), [x1, y1] = at(-90 + i * step + step / 2, R_OUT + 32); return <line key={i} x1={x0} y1={y0} x2={x1} y2={y1} className="ww__tick" />; })}
          {slots.map((s, i) => {
            const c = -90 + i * step, on = i === index, [dx, dy] = at(c, on ? POP : 0);
            const cls = `ww__seg ww__seg--${s.kind}${on ? " is-on" : ""}${s.weapon?.hand ? " is-held" : ""}${chosen === s.key ? " is-chosen" : ""}`;
            return <g key={s.key} className={cls} style={{ transform: `translate(${dx}px, ${dy}px)`, "--i": i } as CSSProperties}>
              <path d={sector(c - step / 2 + GAP, c + step / 2 - GAP, R_IN, R_OUT)} className="ww__seg-fill" />
              <path d={arc(c - step / 2 + GAP + .6, c + step / 2 - GAP - .6, R_OUT - 3)} className="ww__seg-rim" />
              <path d={arc(c - step / 2 + GAP + .6, c + step / 2 - GAP - .6, R_IN + 3)} className="ww__seg-inner" />
            </g>;
          })}
          <circle r={R_HUB + 8} className="ww__hub-ring" />
          <circle r={R_HUB + 8} className="ww__hub-ring ww__hub-ring--spin" />
          {aim !== null && <g className="ww__needle" style={{ transform: `rotate(${aim}deg)` }}><path d={`M${R_HUB + 12} -7 L${R_HUB + 24} 0 L${R_HUB + 12} 7 Z`} /></g>}
        </svg>
        {slots.map((s, i) => {
          const c = -90 + i * step, on = i === index, [x, y] = at(c, rMid + (on ? POP : 0));
          return <div key={s.key} className={`ww__item ww__item--${s.kind}${on ? " is-on" : ""}${chosen === s.key ? " is-chosen" : ""}`}
            style={{ left: HALF + x, top: HALF + y, "--i": i } as CSSProperties}>
            {s.kind === "weapon" && s.weapon && <>
              <span className="ww__art">{s.weapon.image ? <img src={s.weapon.image} alt="" draggable={false} /> : null}</span>
              <span className={`ww__rounds${(s.weapon.rounds ?? 0) <= 0 ? " is-empty" : ""}`}>{pad(s.weapon.rounds)}</span>
              {s.weapon.hand && <i className={`ww__held${armament?.holstered ? " is-holstered" : ""}`} />}
            </>}
            {s.kind === "unarmed" && <><Fist size={46} /><span className="ww__item-label">HOLSTER</span></>}
            {s.kind === "empty" && <span className="ww__dash" />}
          </div>;
        })}
        <div className="ww__hub">
          <div key={`${hovered.key}:${kick}`} className="ww__hub-body">
            {hovered.kind === "weapon" && w && <>
              <span className="ww__tag">{CLASS[w.class ?? ""] ?? "WEAPON"}</span>
              <b className="ww__name">{w.label}</b>
              <div className="ww__ammo"><strong className={empty ? "is-empty" : ""}>{pad(w.rounds)}</strong><small>{(w.ammoLabel ?? "rounds").toUpperCase()}</small></div>
              <span className={`ww__chip ww__chip--${empty ? "danger" : st!.tone}`}>{empty ? "NO AMMO" : st!.text}</span>
              <span className="ww__serial">SN {w.instanceId.slice(0, 8).toUpperCase()}</span>
            </>}
            {hovered.kind === "unarmed" && <>
              <span className="ww__tag">HOLSTER</span>
              <span className="ww__fist"><Fist size={54} /></span>
              <b className="ww__name">Hands down</b>
              <span className="ww__chip ww__chip--accent">PUT AWAY WHAT YOU HOLD</span>
              <span className="ww__serial">Guns, fists or blades · B does the same</span>
            </>}
            {hovered.kind === "empty" && <><span className="ww__tag">EMPTY</span><b className="ww__name">No weapon</b><span className="ww__serial">Gun stores sell them</span></>}
          </div>
          {armament?.busy && <span className="ww__sync">SYNCHRONIZING</span>}
        </div>
      </div>
      <div className="ww__hints">
        {latched
          ? <span><kbd>CLICK</kbd><kbd>{key}</kbd>EQUIP</span>
          : <span><kbd>{key}</kbd>RELEASE TO EQUIP</span>}
        <span><kbd>MOUSE</kbd>AIM</span>
        <span><kbd>WHEEL</kbd>CYCLE</span>
        <span><kbd>RMB</kbd>CANCEL</span>
      </div>
    </div>
  </>;
}
