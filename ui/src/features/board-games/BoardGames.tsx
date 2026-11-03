import { useEffect, useRef, useState } from "react";
import type { PointerEvent as ReactPointerEvent } from "react";
import { emit, on } from "@/bridge/open77";
import { Button, Keycap, Panel } from "@/design/components";
import { useStore } from "@/state/store";
import { EXTRA_GAMES, type ExtraState } from "./extra/registry";
import "./board-games.css";

type CameraView = "free" | "top" | "white" | "black" | "orbit";
interface View {
  active?: boolean; placing?: boolean; kind?: string; turn?: string; status?: string;
  winner?: string; side?: string; selected?: { row: number; col: number }; axis?: string; text?: string;
  mode?: "solo" | "duel" | "teams"; owned?: boolean; ready?: boolean; actor?: number;
  isActor?: boolean; playerCount?: number; ply?: number; canConfigure?: boolean;
  extra?: ExtraState;
  cameraView?: CameraView; cameraViews?: CameraView[];
  /** Free mode: no scripted camera, the player walks and aims with the crosshair. */
  free?: boolean;
  /** The panel holds the cursor (always while placing or in a scripted view). */
  panel?: boolean;
  panelKey?: string;
  /** Milliseconds left before walking away leaves the table. */
  leaving?: number;
}
const CAMERAS: [CameraView, string][] = [["free", "Free"], ["top", "Overhead"], ["white", "White side"], ["black", "Black side"], ["orbit", "Orbit"]];
const NAMES: Record<string, string> = { chess: "Chess", checkers: "Checkers", connect4: "Connect Four" };
export function BoardGames() {
  const [view, setView] = useState<View>({});
  const lastMove = useRef(0);
  useEffect(() => {
    const off = on<View>("lightrp:boardGames:view", next => {
      setView(next ?? {});
      // Only the panel (cursor) hides the gameplay HUD; free mode keeps it.
      useStore.getState().setBoardGamesActive(!!(next?.placing || (next?.active && next?.panel)));
    });
    return () => { off(); useStore.getState().setBoardGamesActive(false); };
  }, []);
  // The game owns Escape for its pause menu, so Lua may never see it; when the
  // page has the keyboard, Escape closes the panel (cancels a placement) and
  // Backspace (outside a text field) leaves.
  const open = !!(view.active || view.placing);
  const panel = !!(view.placing || view.panel);
  useEffect(() => {
    if (!open || !panel) return;
    const onKey = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      const typing = !!target && (target.tagName === "INPUT" || target.tagName === "SELECT" || target.tagName === "TEXTAREA");
      if (event.key === "Escape" && !view.placing) {
        event.preventDefault();
        emit("lightrp:boardGames:panel", { open: false });
      } else if (event.key === "Escape" || (event.key === "Backspace" && !typing)) {
        event.preventDefault();
        emit("lightrp:boardGames:leave", {});
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, panel, view.placing]);
  if (!open) return null;
  if (!panel) return <FreeHud view={view}/>;
  const pointer = (event: ReactPointerEvent, edge?: "pressed" | "released" | "rightPressed" | "rightReleased") => {
    const now = performance.now();
    if (!edge && now - lastMove.current < 16) return;
    lastMove.current = now;
    emit("lightrp:boardGames:pointer", {
      x: Math.max(0, Math.min(1, event.clientX / window.innerWidth)),
      y: Math.max(0, Math.min(1, event.clientY / window.innerHeight)), ...(edge ? { [edge]: true } : {}),
    });
  };
  const blockPointer = (event: ReactPointerEvent) => {
    event.stopPropagation();
    emit("lightrp:boardGames:pointer", { blocked: true });
  };
  const sideName = (side?: string) => view.kind === "connect4" ? side === "white" ? "Red" : "Yellow" : side === "white" ? "White" : "Black";
  const result = view.status === "draw" ? "Draw" : view.status === "won" ? `${sideName(view.winner)} wins` : `${sideName(view.turn)} to move`;
  const slots = view.mode === "teams" ? 4 : view.mode === "solo" ? 1 : 2;
  const waiting = view.ready === false && view.status === "playing";
  const extraGame = view.kind ? EXTRA_GAMES[view.kind] : undefined;
  const openPlay = extraGame?.openPlay ?? false;
  const names = NAMES;
  const panelKey = view.panelKey ?? "H";
  const status = view.placing ? "Board placement" : waiting ? "Waiting for players" : openPlay ? "Open table" : extraGame ? "Table session" : result;
  return <div className="board-games" aria-label="Board game"
    onContextMenu={event => event.preventDefault()}
    onPointerMove={event => pointer(event)}
    onPointerDown={event => {
      if (event.button !== 0 && event.button !== 2) return;
      event.currentTarget.setPointerCapture(event.pointerId);
      pointer(event, event.button === 0 ? "pressed" : "rightPressed");
    }}
    onPointerUp={event => {
      if (event.button !== 0 && event.button !== 2) return;
      pointer(event, event.button === 0 ? "released" : "rightReleased");
    }}
    onPointerCancel={event => { pointer(event, "released"); pointer(event, "rightReleased"); }}
    onWheel={event => { if (!view.placing && view.cameraView === "orbit") emit("lightrp:boardGames:camera", { view: "orbit", zoom: Math.sign(event.deltaY) }); }}>
    <aside className="board-games__sidebar" onPointerDown={blockPointer} onPointerUp={blockPointer} onPointerMove={blockPointer} onWheel={event => event.stopPropagation()}>
      <div className="board-games__brand"><span>OPEN//77</span><span>TABLETOP_</span></div>
      <h2>{extraGame?.name ?? names[view.kind??"chess"] ?? "Tabletop"}</h2>
      <Panel title={view.placing ? "PLACEMENT" : "MATCH STATUS"} meta={view.placing ? "01 / SETUP" : view.mode === "teams" ? "TEAM PLAY" : "TABLE SESSION"} chamfer="sm">
        <p className={`board-games__status${view.isActor ? " board-games__status--turn" : ""}`}>{status}</p>
        {!view.placing && <>
          {view.side && <p>You play {sideName(view.side)}{view.mode === "teams" ? " team" : ""}.</p>}
          <p className="board-games__meta">{view.mode === "solo" ? "Solo vs AI" : view.mode === "teams" ? "2v2 teams" : "1v1"} · {view.playerCount ?? 0}/{slots} players</p>
          {view.ready && view.status === "playing" && !extraGame && <p className="board-games__turn" role="status">{view.actor === 0 ? "AI is thinking…" : view.isActor ? "Your turn" : view.mode === "teams" && view.side === view.turn ? "Your teammate’s turn" : "Opponent’s turn"}</p>}
        </>}
        {view.placing && <p className="board-games__description">Place your board on a clear, level surface. Drag with the left mouse button to position it.</p>}
      </Panel>
      {!view.placing && view.owned && <Panel title="GAME SETUP" chamfer="sm">
        {!extraGame && (view.canConfigure ?? view.ply === 0) ? <div className="board-games__modes" role="group" aria-label="Game mode">
          {([['solo', 'Solo vs AI'], ['duel', '1v1'], ['teams', '2v2']] as const).map(([mode, label]) => <Button key={mode} size="sm" variant={(view.mode ?? "duel") === mode ? "primary" : "secondary"} aria-pressed={(view.mode ?? "duel") === mode}
            onClick={() => emit("lightrp:boardGames:mode", { mode })}>{label}</Button>)}
        </div> : !extraGame && <p className="board-games__description">Start a new game to change the game mode.</p>}
        {(view.ply ?? 0) > 0 && <Button size="sm" block variant="secondary" onClick={() => emit("lightrp:boardGames:reset", {})}>New game</Button>}
      </Panel>}
      {!view.placing && extraGame && view.extra && <extraGame.Controls key={view.kind} game={view.extra} ready={view.ready} isActor={view.isActor}/> }
      <div className="board-games__instructions">
        {view.placing ? <>
          <p><Keycap size="sm">X/Y/Z</Keycap><span>Movement axis · {view.axis?.toUpperCase() ?? "XY"}</span></p>
          <p><Keycap size="sm">Q / D</Keycap><span>Rotate board</span></p>
          <p><Keycap size="sm">PG↑ / PG↓</Keycap><span>Adjust height</span></p>
        </> : <>
          <p><Keycap tone="accent" size="sm">LMB</Keycap><span>{view.kind === "connect4" ? "Drop a disc in a column" : extraGame ? extraGame.hint : "Drag a piece or click its destination"}</span></p>
          {view.cameraView === "orbit" ? <>
            <p><Keycap size="sm">RMB</Keycap><span>Rotate the orbit view</span></p>
            <p><Keycap size="sm">SCROLL</Keycap><span>Zoom the orbit view</span></p>
          </> : <p><Keycap size="sm">{panelKey}</Keycap><span>{view.free === false ? "Back to free mode" : "Close the panel, play by aiming"}</span></p>}
        </>}
      </div>
      {!view.placing && <Button variant="secondary" size="sm" onClick={() => emit("lightrp:boardGames:panel", { open: false })}>{view.free === false ? "Back to free mode" : "Close panel"}<Keycap size="sm">{panelKey}</Keycap></Button>}
      <Button variant="ghost" size="sm" onClick={() => emit("lightrp:boardGames:leave", {})}>{view.placing ? "Cancel placement" : "Leave table"}<Keycap size="sm">BACKSPACE</Keycap></Button>
    </aside>
    <footer className="board-games__toolbar" onPointerDown={blockPointer} onPointerUp={blockPointer} onPointerMove={blockPointer} onWheel={event => event.stopPropagation()}>
      {view.placing ? <>
        <span>POSITION THE BOARD</span>
        <Button size="sm" onClick={() => emit("lightrp:boardGames:confirm", {})}>Place board <Keycap size="sm">E</Keycap></Button>
      </> : <>
        <span>CAMERA</span>
        <div role="group" aria-label="Camera view">{CAMERAS.map(([camera, label]) => <Button key={camera} size="sm" variant={(view.cameraView ?? "free") === camera ? "primary" : "secondary"} aria-pressed={(view.cameraView ?? "free") === camera}
          onClick={() => emit("lightrp:boardGames:camera", { view: camera })}>{label}</Button>)}</div>
      </>}
    </footer>
  </div>;
}

/* Free mode: a heads-up strip that never takes the pointer or the keyboard.
   The crosshair aims at the table, the left mouse button acts, and the
   aimed cell and the selection are outlined on the table itself (Lua). */
function FreeHud({ view }: { view: View }) {
  const extraGame = view.kind ? EXTRA_GAMES[view.kind] : undefined;
  const side = (s?: string) => view.kind === "connect4" ? s === "white" ? "Red" : "Yellow" : s === "white" ? "White" : "Black";
  const waiting = view.ready === false && view.status === "playing";
  let status: string;
  if (extraGame) status = waiting ? "Waiting for players" : "Table session";
  else if (waiting) status = "Waiting for players";
  else if (view.status === "draw") status = "Draw";
  else if (view.status === "won") status = `${side(view.winner)} wins`;
  else if (view.actor === 0) status = "AI is thinking…";
  else if (view.isActor) status = "Your turn";
  else status = `${side(view.turn)} to move`;
  const hint = extraGame ? extraGame.freeHint ?? extraGame.hint
    : view.kind === "connect4" ? "Aim at a column and click to drop a disc"
    : view.selected ? "Click the destination square" : "Aim at a piece and click it (or hold and drag)";
  const leaving = typeof view.leaving === "number";
  return <div className="board-games board-games--free" aria-label="Board game">
    <div className="board-games__crosshair" aria-hidden="true"/>
    <section className={`board-games__hud${leaving ? " board-games__hud--leaving" : ""}`}>
      <p className="board-games__hud-head">
        <span className="board-games__hud-title">{extraGame?.name ?? NAMES[view.kind ?? ""] ?? "Tabletop"}</span>
        <span className={`board-games__hud-status${view.isActor && !extraGame ? " board-games__status--turn" : ""}`} role="status">{status}</span>
      </p>
      {leaving && <p className="board-games__hud-warning" role="alert">Too far from the table. Step back or you leave your seat.</p>}
      <p className="board-games__hud-keys">
        <span><Keycap tone="accent" size="sm">LMB</Keycap><span>{hint}</span></span>
        <span><Keycap size="sm">{view.panelKey ?? "H"}</Keycap><span>{extraGame ? "Bets and controls" : "Panel and camera views"}</span></span>
        <span><Keycap size="sm">BACKSPACE</Keycap><span>Leave</span></span>
      </p>
    </section>
  </div>;
}
