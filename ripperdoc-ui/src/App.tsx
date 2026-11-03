import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { CATALOGUE, DEMO, SECTION, SECTIONS, demoLocks, roman, type Body, type Cyberware, type OpenPayload, type Reputation } from "./data";
import { emit, inGame, onClose, onOpen, onResult, onState, ready } from "./bridge";
import { loadManifest, type Manifest } from "./media";
import { play, preload } from "./sfx";
import { Stage } from "./Stage";
import { Overview } from "./Overview";
import { SectionView } from "./SectionView";
import { TopBar, BottomBar } from "./Hud";
import { Procedure } from "./Procedure";

export type Phase = "closed" | "boot" | "overview" | "diving" | "section" | "surfacing" | "leaving";

export interface Session {
  live: boolean;
  body: Body;
  clinic: NonNullable<OpenPayload["clinic"]>;
  wallet: number;
  removalFee: number;
  installed: Record<string, string[]>;
  patient: NonNullable<OpenPayload["patient"]>;
  reputation?: Reputation;               // street cred (absent: no gate shown)
  stock: Cyberware[];                    // the clinic's catalogue
  items: Record<string, Cyberware>;      // the same, by id
}

const fromPayload = (p: OpenPayload): Session => {
  const live = p.live === true;
  const reputation = p.reputation ?? (live ? undefined : DEMO.reputation);
  const given = p.catalogue && p.catalogue.length > 0 ? p.catalogue : CATALOGUE;
  // live: the server says what is locked; the preview derives it from the rank
  const stock = live || !reputation ? given : demoLocks(given, reputation);
  return {
    reputation,
    live: p.live === true,
    body: p.body === "female" ? "female" : "male",
    clinic: p.clinic ?? DEMO.clinic,
    wallet: typeof p.wallet === "number" ? p.wallet : DEMO.wallet,
    removalFee: p.removalFee ?? DEMO.removalFee,
    installed: p.installed ?? (p.live ? {} : structuredClone(DEMO.installed)),
    patient: p.patient ?? DEMO.patient,
    stock,
    items: Object.fromEntries(stock.map((x) => [x.id, x])),
  };
};

/** Implants fitted on the body (no limit: only shown). */
export const installedCount = (s: Session) => Object.values(s.installed).flat().length;

/** The installed implant of the same family (it is replaced by a better model). */
export const familyMate = (s: Session, item: Cyberware): Cyberware | undefined => {
  if (!item.family) return undefined;
  for (const id of Object.values(s.installed).flat()) {
    const other = s.items[id];
    if (other && other.id !== item.id && other.family === item.family) return other;
  }
  return undefined;
};

/** "III (Operator)": the street cred tier an implant needs. */
export const repLabel = (item: Cyberware): string =>
  `${roman(item.repTier ?? 0)}${item.repName ? ` (${item.repName})` : ""}`;

/** Why the clinic would refuse this installation, or null. Same rules as the server: no limit,
    the street cred tier of the rank, eurodollars only (a model of the same family simply
    replaces the installed one). */
export function refusal(s: Session, item: Cyberware): string | null {
  if (Object.values(s.installed).flat().includes(item.id)) return "Already installed.";
  if (item.locked) return `Street cred too low: needs reputation tier ${repLabel(item)}. PvE missions, raids, gigs and PvE activities earn it.`;
  if (item.price > s.wallet) return "Not enough eurodollars in your bank account.";
  return null;
}

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

export interface ProcedureState {
  item: Cyberware;
  mode: "install" | "remove";
  startedAt: number;
  minMs: number;
  result?: { ok: boolean; message?: string };
}

export function App() {
  const scale = useCanvasScale();
  const [phase, setPhase] = useState<Phase>("closed");
  const [session, setSession] = useState<Session>(() => fromPayload(DEMO));
  const [manifest, setManifest] = useState<Manifest>({});
  const [hovered, setHovered] = useState<string | null>(null);
  const [section, setSection] = useState<string>(SECTIONS[0]!.id);
  const [procedure, setProcedure] = useState<ProcedureState | null>(null);
  const timers = useRef<number[]>([]);
  const later = (ms: number, fn: () => void) => { timers.current.push(window.setTimeout(fn, ms)); };
  const procedureRef = useRef<ProcedureState | null>(null);
  procedureRef.current = procedure;

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
    onClose(() => { timers.current.forEach(clearTimeout); setProcedure(null); setPhase("closed"); });
    // The server's answer to the running operation, then the fresh state.
    onResult((r) => {
      const p = procedureRef.current;
      if (!p || (r.item && r.item !== p.item.id)) return;
      setProcedure({ ...p, result: { ok: r.ok === true, message: r.message } });
    });
    onState((payload) => setSession((s) => ({ ...fromPayload(payload), body: payload.body ?? s.body })));
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

  // An operation ends when the server answered AND the surgery has played long enough.
  useEffect(() => {
    if (!procedure?.result) return;
    const wait = Math.max(0, procedure.startedAt + procedure.minMs - performance.now());
    const id = window.setTimeout(() => {
      play(procedure.result!.ok ? (procedure.mode === "install" ? "granted" : "equip") : "denied");
      window.setTimeout(() => setProcedure((p) => (p === procedure ? null : p)), procedure.result!.ok ? 1100 : 2600);
    }, wait);
    return () => window.clearTimeout(id);
  }, [procedure]);

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

  const used = useMemo(() => installedCount(session), [session]);

  const startProcedure = (item: Cyberware, mode: "install" | "remove"): string | null => {
    if (procedure) return "An operation is already in progress.";
    if (mode === "install") {
      const why = refusal(session, item);
      if (why) { play("denied"); return why; }
    } else if (session.wallet < session.removalFee) {
      play("denied");
      return "Not enough eurodollars for the removal.";
    }
    const state: ProcedureState = { item, mode, startedAt: performance.now(), minMs: mode === "install" ? 4600 : 2200 };
    setProcedure(state);
    play(mode === "install" ? "install" : "unequip");
    emit("rd:action", { op: mode, item: item.id });
    if (!session.live) {
      // Browser preview: the clinic is simulated here.
      later(state.minMs - 400, () => {
        setSession((s) => {
          const mate = mode === "install" ? familyMate(s, item) : undefined;
          const list = (s.installed[item.section] ?? []).filter((id) => id !== item.id && id !== mate?.id);
          const installed = { ...s.installed };
          if (mate && mate.section !== item.section) installed[mate.section] = (installed[mate.section] ?? []).filter((id) => id !== mate.id);
          installed[item.section] = mode === "install" ? [...list, item.id] : list;
          return mode === "install"
            ? { ...s, installed, wallet: s.wallet - item.price }
            : { ...s, installed, wallet: s.wallet - s.removalFee };
        });
        setProcedure((p) => (p && p.item.id === item.id ? { ...p, result: { ok: true } } : p));
      });
    }
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
            <Overview body={session.body} manifest={manifest} phase={phase} hovered={hovered} session={session}
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
        {procedure && <Procedure state={procedure} body={session.body} />}
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
