import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { CATALOGUE, DEMO, DEMO_CAPACITY, SECTION, SECTIONS, demoLocks, type Body, type Cyberware, type Guide, type OpenPayload, type Reputation } from "./data";
import { project, refusal, simulate, usedPoints, type Capacity, type ClinicState } from "./model";
import { diag, emit, inGame, onClose, onOpen, onResult, onState, ready } from "./bridge";
import { loadManifest, type Manifest } from "./media";
import { play, preload } from "./sfx";
import { Stage } from "./Stage";
import { Overview } from "./Overview";
import { SectionView } from "./SectionView";
import { TopBar, BottomBar } from "./Hud";
import { Procedure } from "./Procedure";
import { GuideLayer } from "./Guide";

export type Phase = "closed" | "boot" | "overview" | "diving" | "section" | "surfacing" | "leaving";

export interface Session extends ClinicState {
  live: boolean;
  body: Body;
  clinic: NonNullable<OpenPayload["clinic"]>;
  wallet: number;
  fittingFee: number;                    // fit from storage, take out
  installed: Record<string, string[]>;
  storage: string[];                     // the patient's implant storage (payload `stock`)
  capacity?: Capacity;                   // points used / total (absent: no limit shown)
  patient: NonNullable<OpenPayload["patient"]>;
  reputation?: Reputation;               // street cred (absent: no gate shown)
  guide?: Guide;                         // the clinic guide (absent: no GUIDE button)
  stock: Cyberware[];                    // the clinic's catalogue
  items: Record<string, Cyberware>;      // the same, by id
}

/* Lua sends an empty list as {} (an object): every list the server sends is read through `list`, or
   one empty list (a first visit's guide, an implant without stats) threw in a render and the whole
   page went blank, the cursor alone on screen (LightRP Testing, 2026-11-05). */
const list = <T,>(v: unknown): T[] =>
  Array.isArray(v) ? (v as T[]) : v && typeof v === "object" ? (Object.values(v) as T[]) : [];
const normalise = (raw: OpenPayload): OpenPayload => {
  const p: OpenPayload = raw && typeof raw === "object" && !Array.isArray(raw) ? { ...raw } : {};
  if (p.catalogue !== undefined) p.catalogue = list<Cyberware>(p.catalogue).map((x) => ({ ...x, stats: list(x.stats) }));
  if (p.stock !== undefined) p.stock = list<string>(p.stock);
  if (p.installed !== undefined) {
    const installed: Record<string, string[]> = {};
    if (p.installed && typeof p.installed === "object")
      for (const [k, v] of Object.entries(p.installed)) installed[k] = list<string>(v);
    p.installed = installed;
  }
  if (p.guide && typeof p.guide === "object") {
    const g = p.guide;
    p.guide = { ...g, tiers: list(g.tiers), gains: list(g.gains), drops: list(g.drops), keys: list(g.keys) };
  } else if (p.guide !== undefined) delete p.guide;
  return p;
};

const fromPayload = (raw: OpenPayload): Session => {
  const p = normalise(raw);
  const live = p.live === true;
  const reputation = p.reputation ?? (live ? undefined : DEMO.reputation);
  const given = p.catalogue && p.catalogue.length > 0 ? p.catalogue : CATALOGUE;
  // live: the server says what is locked; the preview derives it from the rank
  const stock = live || !reputation ? given : demoLocks(given, reputation);
  const items = Object.fromEntries(stock.map((x) => [x.id, x]));
  const installed = p.installed ?? (live ? {} : structuredClone(DEMO.installed));
  // live: the server counts the points; the preview counts them against the demo tier's total
  let capacity: Capacity | undefined = p.capacity;
  if (!capacity && !live && reputation) {
    const used = usedPoints({ installed, items }), total = DEMO_CAPACITY[reputation.tier] ?? 26;
    capacity = { used, total, over: used > total };
  }
  return {
    reputation,
    guide: p.guide ?? (live ? undefined : DEMO.guide),
    live,
    body: p.body === "female" ? "female" : "male",
    clinic: p.clinic ?? DEMO.clinic,
    wallet: typeof p.wallet === "number" ? p.wallet : DEMO.wallet,
    fittingFee: p.fittingFee ?? p.removalFee ?? DEMO.fittingFee,
    installed,
    storage: p.stock ?? (live ? stock.filter((x) => x.stored).map((x) => x.id) : [...DEMO.stock]),
    capacity,
    patient: p.patient ?? DEMO.patient,
    stock,
    items,
  };
};

/** Implants fitted on the body. */
export const installedCount = (s: Session) => Object.values(s.installed).flat().length;

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
  // The guide on screen; `auto`: it opened by itself (first visit), so closing it tells the server.
  const [guide, setGuide] = useState<{ auto: boolean } | null>(null);
  // The implant whose surgery the HUD previews (SectionView: hovered, else selected).
  const [previewId, setPreviewId] = useState<string | null>(null);
  const timers = useRef<number[]>([]);
  const later = (ms: number, fn: () => void) => { timers.current.push(window.setTimeout(fn, ms)); };
  const procedureRef = useRef<ProcedureState | null>(null);
  procedureRef.current = procedure;

  const open = useCallback((payload: OpenPayload) => {
    timers.current.forEach(clearTimeout);
    timers.current = [];
    let next: Session;
    try { next = fromPayload(payload); }
    catch (err) {
      // never a blank page holding the cursor: say why and give the game back
      diag(`open payload refused: ${String(err)}`);
      emit("rd:close", {});
      return;
    }
    setSession(next);
    setHovered(null);
    setProcedure(null);
    setGuide(null);
    setPhase("boot");
    play("open");
    later(380, () => play("glitch"));
    later(2300, () => setPhase("overview"));
    // First visit: the guide opens by itself once the body is on screen.
    if (next.guide?.auto) later(2900, () => { setGuide({ auto: true }); play("scan_tag"); });
  }, []);

  const close = useCallback(() => {
    setGuide(null);
    setPhase((p) => (p === "closed" ? p : "leaving"));
    play("close");
    later(650, () => { setPhase("closed"); emit("rd:close", {}); });
  }, []);

  useEffect(() => {
    void loadManifest().then(setManifest);
    preload();
    onOpen(open);
    onClose(() => { timers.current.forEach(clearTimeout); setProcedure(null); setGuide(null); setPhase("closed"); });
    // The server's answer to the running operation, then the fresh state.
    onResult((r) => {
      const p = procedureRef.current;
      if (!p || (r.item && r.item !== p.item.id)) return;
      setProcedure({ ...p, result: { ok: r.ok === true, message: r.message } });
    });
    onState((payload) => {
      try { const next = fromPayload(payload); setSession((s) => ({ ...next, body: payload.body ?? s.body })); }
      catch (err) { diag(`state payload refused: ${String(err)}`); }
    });
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

  // Finished, skipped or closed: a guide that opened by itself is remembered (it will not open by itself again).
  const closeGuide = useCallback(() => {
    setGuide((g) => {
      if (g?.auto) {
        emit("rd:guide", { seen: true });
        setSession((s) => (s.guide ? { ...s, guide: { ...s.guide, auto: false } } : s));
      }
      return null;
    });
    play("zoom_out");
  }, []);
  const openGuide = useCallback(() => {
    if (!session.guide || procedure || (phase !== "overview" && phase !== "section")) return;
    setGuide({ auto: false });
    play("scan_tag");
  }, [session.guide, procedure, phase]);

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
      if (procedure || guide) return;
      if (e.key === "h" || e.key === "H") { e.preventDefault(); openGuide(); return; }
      if (e.key === "Escape" || e.key === "Backspace") {
        e.preventDefault();
        if (phase === "section") surface(); else if (phase === "overview") close();
      } else if (phase === "section" && (e.key === "a" || e.key === "A" || e.key === "ArrowLeft")) cycle(-1);
      else if (phase === "section" && (e.key === "d" || e.key === "D" || e.key === "ArrowRight")) cycle(1);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [phase, procedure, guide, surface, close, cycle, openGuide]);

  const used = useMemo(() => installedCount(session), [session]);
  const previewItem = previewId ? session.items[previewId] : undefined;
  const preview = useMemo(() => (previewItem && phase === "section" && !procedure ? project(session, previewItem) : undefined),
    [previewItem, phase, procedure, session]);

  const startProcedure = (item: Cyberware, mode: "install" | "remove"): string | null => {
    if (procedure) return "An operation is already in progress.";
    const why = refusal(session, item, mode);
    if (why) { play("denied"); return why; }
    const state: ProcedureState = { item, mode, startedAt: performance.now(), minMs: mode === "install" ? 4600 : 2200 };
    setProcedure(state);
    play(mode === "install" ? "install" : "unequip");
    emit("rd:action", { op: mode, item: item.id });
    if (!session.live) {
      // Browser preview: the clinic is simulated here.
      later(state.minMs - 400, () => {
        setSession((s) => ({ ...s, ...simulate(s, item, mode) }));
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
            onBack={surface} onCycle={cycle} onProcedure={startProcedure} onPreview={setPreviewId} />
        )}
        <TopBar session={session} used={used} phase={phase} section={phase === "section" ? SECTION[section] : undefined}
          onGuide={session.guide && !procedure && (phase === "overview" || phase === "section") ? openGuide : undefined}
          preview={preview} />
        <BottomBar phase={phase} guide={session.guide !== undefined} />
        {procedure && <Procedure state={procedure} body={session.body} />}
        {guide && session.guide && <GuideLayer guide={session.guide} session={session} onClose={closeGuide} />}
        <div className="rd-fx-scan" />
        <div className="rd-fx-vignette" />
        <div className="rd-fx-lines" />
        {phase === "diving" && <div className="rd-fx-dive" />}
        {phase === "boot" && <BootLayer patient={session.patient.name ?? "UNKNOWN"} />}
        {phase === "closed" && (
          <button className="rd-reopen" onClick={() => open({ ...DEMO, body: session.body })}>REOPEN PREVIEW</button>
        )}
      </div>
    </div>
  );
}

function BootLayer({ patient }: { patient: string }) {
  return (
    <div className="rd-boot">
      <div className="rd-boot-frame">
        <div className="rd-boot-kicker">NEURAL HANDSHAKE // RIPPERDOC CLINIC</div>
        <div className="rd-boot-title" data-text="PATIENT LINKED">PATIENT LINKED</div>
        <div className="rd-boot-sub">{patient.toUpperCase()} — BIOMETRIC SCAN IN PROGRESS</div>
        <div className="rd-boot-bar"><i /></div>
      </div>
    </div>
  );
}
