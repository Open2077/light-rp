import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { CYBERWARE, DEMO, SECTION, SECTIONS, type Body, type Cyberware, type OpenPayload } from "./data";
import { emit, inGame, onClose, onOpen, ready } from "./bridge";
import { loadManifest, type Manifest } from "./media";
import { play, preload } from "./sfx";
import { Stage } from "./Stage";
import { Overview } from "./Overview";
import { SectionView } from "./SectionView";
import { TopBar, BottomBar } from "./Hud";
import { Procedure } from "./Procedure";

export type Phase = "closed" | "boot" | "overview" | "diving" | "section" | "surfacing" | "leaving";

export interface Session {
  body: Body;
  clinic: NonNullable<OpenPayload["clinic"]>;
  wallet: number;
  capacityMax: number;
  installed: Record<string, string[]>;
  patient: NonNullable<OpenPayload["patient"]>;
}

const fromPayload = (p: OpenPayload): Session => ({
  body: p.body === "female" ? "female" : "male",
  clinic: p.clinic ?? DEMO.clinic,
  wallet: typeof p.wallet === "number" ? p.wallet : DEMO.wallet,
  capacityMax: p.capacity?.max ?? DEMO.capacity.max,
  installed: p.installed ?? structuredClone(DEMO.installed),
  patient: p.patient ?? DEMO.patient,
});

export const capacityUsed = (installed: Record<string, string[]>) =>
  Object.values(installed).flat().reduce((sum, id) => sum + (CYBERWARE[id]?.capacity ?? 0), 0);

/* 1920x1080 design canvas scaled to the viewport: every coordinate below is canvas pixels. */
function useCanvasScale() {
  const [scale, setScale] = useState(1);
  useEffect(() => {
    const fit = () => setScale(Math.min(window.innerWidth / 1920, window.innerHeight / 1080));
    fit();
    window.addEventListener("resize", fit);
    return () => window.removeEventListener("resize", fit);
  }, []);
  return scale;
}

export function App() {
  const scale = useCanvasScale();
  const [phase, setPhase] = useState<Phase>("closed");
  const [session, setSession] = useState<Session>(() => fromPayload(DEMO));
  const [manifest, setManifest] = useState<Manifest>({});
  const [hovered, setHovered] = useState<string | null>(null);
  const [section, setSection] = useState<string>(SECTIONS[0]!.id);
  const [procedure, setProcedure] = useState<{ item: Cyberware; mode: "install" | "remove" } | null>(null);
  const timers = useRef<number[]>([]);
  const later = (ms: number, fn: () => void) => { timers.current.push(window.setTimeout(fn, ms)); };

  const open = useCallback((payload: OpenPayload) => {
    timers.current.forEach(clearTimeout);
    timers.current = [];
    setSession(fromPayload(payload));
    setHovered(null);
    setProcedure(null);
    setPhase("boot");
    play("open");
    later(380, () => play("glitch"));
    later(2300, () => setPhase("overview"));
  }, []);

  const close = useCallback(() => {
    setPhase((p) => (p === "closed" ? p : "leaving"));
    play("close");
    later(650, () => { setPhase("closed"); emit("rd:close", {}); });
  }, []);

  useEffect(() => {
    void loadManifest().then(setManifest);
    preload();
    onOpen(open);
    onClose(() => { timers.current.forEach(clearTimeout); setPhase("closed"); });
    ready();
    if (!inGame()) {
      // Browser preview: ?body=female, ?section=<id> opens straight on a section.
      const params = new URLSearchParams(location.search);
      const body = params.get("body") === "female" ? "female" : "male";
      later(250, () => open({ ...DEMO, body }));
      const deep = params.get("section");
      // A plain timer: open() clears the session's own timers.
      if (deep && SECTION[deep]) window.setTimeout(() => { setSection(deep); setPhase("section"); }, 2700);
    }
    return () => timers.current.forEach(clearTimeout);
  }, [open]);

  const dive = useCallback((id: string) => {
    if (phase !== "overview") return;
    setSection(id);
    setHovered(id);
    setPhase("diving");
    play("zoom_in");
    later(160, () => play("glitch"));
    later(820, () => { setPhase("section"); play("scan_tag"); });
  }, [phase]);

  const surface = useCallback(() => {
    if (phase !== "section") return;
    setPhase("surfacing");
    play("zoom_out");
    later(560, () => setPhase("overview"));
  }, [phase]);

  const cycle = useCallback((step: number) => {
    const index = SECTIONS.findIndex((s) => s.id === section);
    const next = SECTIONS[(index + step + SECTIONS.length) % SECTIONS.length]!;
    setSection(next.id);
    play("tick_up");
    play("glitch");
  }, [section]);

  // Keyboard: Esc backs out, A/D (or arrows) cycle the sections inside the close-up.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (procedure) return;
      if (e.key === "Escape" || e.key === "Backspace") {
        e.preventDefault();
        if (phase === "section") surface(); else if (phase === "overview") close();
      } else if (phase === "section" && (e.key === "a" || e.key === "A" || e.key === "ArrowLeft")) cycle(-1);
      else if (phase === "section" && (e.key === "d" || e.key === "D" || e.key === "ArrowRight")) cycle(1);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [phase, procedure, surface, close, cycle]);

  const used = useMemo(() => capacityUsed(session.installed), [session.installed]);

  const startProcedure = (item: Cyberware, mode: "install" | "remove", replace?: string) => {
    if (mode === "install") {
      if (item.price > session.wallet) { play("denied"); return "funds"; }
      const freed = replace ? CYBERWARE[replace]?.capacity ?? 0 : 0;
      if (used - freed + item.capacity > session.capacityMax) { play("denied"); return "capacity"; }
    }
    setProcedure({ item, mode });
    play(mode === "install" ? "install" : "unequip");
    emit("rd:action", { op: mode, section: item.section, item: item.id, replace: replace ?? null });
    const ms = mode === "install" ? 4600 : 1800;
    later(ms, () => {
      setSession((s) => {
        const list = [...(s.installed[item.section] ?? [])];
        if (mode === "remove") {
          return { ...s, installed: { ...s.installed, [item.section]: list.filter((id) => id !== item.id) } };
        }
        const at = replace ? list.indexOf(replace) : -1;
        if (at >= 0) list[at] = item.id; else list.push(item.id);
        return { ...s, wallet: s.wallet - item.price, installed: { ...s.installed, [item.section]: list } };
      });
      play(mode === "install" ? "granted" : "equip");
      later(900, () => setProcedure(null));
    });
    return null;
  };

  if (phase === "closed" && inGame()) return null;

  const focusSection = phase === "diving" || phase === "section" || phase === "surfacing" ? section : hovered;

  return (
    <div className={`rd-viewport rd-phase-${phase}`}>
      <div className="rd-canvas" style={{ transform: `translate(-50%, -50%) scale(${scale})` }}>
        <div className="rd-backdrop" />
        <Stage body={session.body} manifest={manifest} phase={phase} focus={focusSection}>
          {(phase === "overview" || phase === "boot" || phase === "diving" || phase === "surfacing") && (
            <Overview body={session.body} manifest={manifest} phase={phase} hovered={hovered} installed={session.installed}
              onHover={setHovered} onDive={dive} />
          )}
        </Stage>
        {(phase === "section" || phase === "surfacing") && (
          <SectionView key={section} body={session.body} section={section} session={session} used={used}
            leaving={phase === "surfacing"} busy={procedure !== null}
            onBack={surface} onCycle={cycle} onProcedure={startProcedure} />
        )}
        <TopBar session={session} used={used} phase={phase} section={phase === "section" ? SECTION[section] : undefined} />
        <BottomBar phase={phase} />
        {procedure && <Procedure item={procedure.item} mode={procedure.mode} body={session.body} />}
        <div className="rd-fx-scan" />
        <div className="rd-fx-vignette" />
        <div className="rd-fx-lines" />
        {phase === "diving" && <div className="rd-fx-dive" />}
        {phase === "boot" && <BootLayer patient={session.patient.name ?? "UNKNOWN"} clinic={session.clinic.name} />}
        {phase === "closed" && (
          <button className="rd-reopen" onClick={() => open({ ...DEMO, body: session.body })}>REOPEN PREVIEW</button>
        )}
      </div>
    </div>
  );
}

function BootLayer({ patient, clinic }: { patient: string; clinic: string }) {
  return (
    <div className="rd-boot">
      <div className="rd-boot-frame">
        <div className="rd-boot-kicker">NEURAL HANDSHAKE // {clinic.toUpperCase()}</div>
        <div className="rd-boot-title" data-text="PATIENT LINKED">PATIENT LINKED</div>
        <div className="rd-boot-sub">{patient.toUpperCase()} — BIOMETRIC SCAN IN PROGRESS</div>
        <div className="rd-boot-bar"><i /></div>
      </div>
    </div>
  );
}
