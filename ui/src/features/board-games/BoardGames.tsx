import { useEffect, useRef, useState } from "react";
import type { PointerEvent as ReactPointerEvent } from "react";
import { emit, on } from "@/bridge/open77";
import { Button, Keycap, Panel } from "@/design/components";
import { useStore } from "@/state/store";
import "./board-games.css";

type CameraView = "top" | "white" | "black" | "orbit";
interface View {
  active?: boolean; placing?: boolean; kind?: string; turn?: string; status?: string;
  winner?: string; side?: string; selected?: { row: number; col: number }; axis?: string; text?: string;
  mode?: "solo" | "duel" | "teams"; owned?: boolean; ready?: boolean; actor?: number;
  isActor?: boolean; playerCount?: number; ply?: number; canConfigure?: boolean;
  cameraView?: CameraView; cameraViews?: CameraView[];
}
const CAMERAS: [CameraView, string][] = [["top", "Overhead"], ["white", "White side"], ["black", "Black side"], ["orbit", "Orbit"]];
export function BoardGames() {
  const [view, setView] = useState<View>({});
  const lastMove = useRef(0);
  useEffect(() => {
    const off = on<View>("lightrp:boardGames:view", next => {
      setView(next ?? {});
      useStore.getState().setBoardGamesActive(!!(next?.active || next?.placing));
    });
    return () => { off(); useStore.getState().setBoardGamesActive(false); };
  }, []);
  if (!view.active && !view.placing) return null;
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
  const status = view.placing ? "Board placement" : waiting ? "Waiting for players" : result;
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
      <h2>{view.kind === "connect4" ? "Connect Four" : view.kind === "checkers" ? "Checkers" : "Chess"}</h2>
      <Panel title={view.placing ? "PLACEMENT" : "MATCH STATUS"} meta={view.placing ? "01 / SETUP" : view.mode === "teams" ? "TEAM PLAY" : "TABLE SESSION"} chamfer="sm">
        <p className={`board-games__status${view.isActor ? " board-games__status--turn" : ""}`}>{status}</p>
        {!view.placing && <>
          {view.side && <p>You play {sideName(view.side)}{view.mode === "teams" ? " team" : ""}.</p>}
          <p className="board-games__meta">{view.mode === "solo" ? "Solo vs AI" : view.mode === "teams" ? "2v2 teams" : "1v1"} · {view.playerCount ?? 0}/{slots} players</p>
          {view.ready && view.status === "playing" && <p className="board-games__turn" role="status">{view.actor === 0 ? "AI is thinking…" : view.isActor ? "Your turn" : view.mode === "teams" && view.side === view.turn ? "Your teammate’s turn" : "Opponent’s turn"}</p>}
        </>}
        {view.placing && <p className="board-games__description">Place your board on a clear, level surface. Drag with the left mouse button to position it.</p>}
      </Panel>
      {!view.placing && view.owned && <Panel title="GAME SETUP" chamfer="sm">
        {(view.canConfigure ?? view.ply === 0) ? <div className="board-games__modes" role="group" aria-label="Game mode">
          {([['solo', 'Solo vs AI'], ['duel', '1v1'], ['teams', '2v2']] as const).map(([mode, label]) => <Button key={mode} size="sm" variant={(view.mode ?? "duel") === mode ? "primary" : "secondary"} aria-pressed={(view.mode ?? "duel") === mode}
            onClick={() => emit("lightrp:boardGames:mode", { mode })}>{label}</Button>)}
        </div> : <p className="board-games__description">Start a new game to change the game mode.</p>}
        {(view.ply ?? 0) > 0 && <Button size="sm" block variant="secondary" onClick={() => emit("lightrp:boardGames:reset", {})}>New game</Button>}
      </Panel>}
      <div className="board-games__instructions">
        {view.placing ? <>
          <p><Keycap size="sm">X/Y/Z</Keycap><span>Movement axis · {view.axis?.toUpperCase() ?? "XY"}</span></p>
          <p><Keycap size="sm">Q / D</Keycap><span>Rotate board</span></p>
          <p><Keycap size="sm">PG↑ / PG↓</Keycap><span>Adjust height</span></p>
        </> : <>
          <p><Keycap tone="accent" size="sm">LMB</Keycap><span>{view.kind === "connect4" ? "Drop a disc in a column" : "Drag a piece or click its destination"}</span></p>
          <p><Keycap size="sm">RMB</Keycap><span>Rotate in orbit view</span></p>
          <p><Keycap size="sm">SCROLL</Keycap><span>Zoom in orbit view</span></p>
        </>}
      </div>
      <Button variant="ghost" size="sm" onClick={() => emit("lightrp:boardGames:leave", {})}>{view.placing ? "Cancel placement" : "Leave table"}<Keycap size="sm">ESC</Keycap></Button>
    </aside>
    <footer className="board-games__toolbar" onPointerDown={blockPointer} onPointerUp={blockPointer} onPointerMove={blockPointer} onWheel={event => event.stopPropagation()}>
      {view.placing ? <>
        <span>POSITION THE BOARD</span>
        <Button size="sm" onClick={() => emit("lightrp:boardGames:confirm", {})}>Place board <Keycap size="sm">E</Keycap></Button>
      </> : <>
        <span>CAMERA</span>
        <div role="group" aria-label="Camera view">{CAMERAS.map(([camera, label]) => <Button key={camera} size="sm" variant={(view.cameraView ?? "top") === camera ? "primary" : "secondary"} aria-pressed={(view.cameraView ?? "top") === camera}
          onClick={() => emit("lightrp:boardGames:camera", { view: camera })}>{label}</Button>)}</div>
      </>}
    </footer>
  </div>;
}
