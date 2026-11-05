import { useEffect, useRef, useState, type FormEvent } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type RoomPlayer, type RoomView, type RoomsState, type UiAction } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Badge, Button, Icon, Input, Keycap, Toggle, cx } from "@/design/components";
import { KIND_ICON, KIND_LABEL } from "@/features/activities/model";
import "@/features/activities/activities.css";
import { ROOMS_ACTION, ROOMS_CLOSE_ACTION, UNRANKED_LINE, cleanCode, escapeAction, holdMs, hostGames, isFreshResult, isFull, mapLine, nextTeam, roomColumns, roomsScreen, sizeChoices, sizeLabel, slots, waitLine, type HostGame } from "./model";
import "./rooms.css";

/* The hosting menu: the rooms NPC at The Crossing (server/modules/activity_rooms.lua), or
   /room anywhere. Browse the public rooms or enter a code; host a game (game, map, teams,
   public or private); the room itself (teams, move, kick, start, leave). Everything comes
   from the `rooms` and `activities` state, the server decides. Same frame as the
   Activities panel. */

type RoomAction = Extract<UiAction, { type: typeof ROOMS_ACTION }>;

export function RoomsDialog() {
  const dialog = useStore((s) => s.dialog);
  const close = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "rooms";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "rooms", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "rooms") close(); });
    return () => {
      off();
      sendAction({ type: ROOMS_CLOSE_ACTION });
      emit(PAGE_EVENTS.focus, { active: false });
      emit(PAGE_EVENTS.dialogState, { kind: "rooms", open: false });
    };
  }, [visible, close]);
  return visible ? <RoomsBody onClose={close} /> : null;
}

function RoomsBody({ onClose }: { onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const rooms = useStore((s) => s.state.rooms);
  const activities = useStore((s) => s.state.activities);
  const result = useStore((s) => s.lastResult);
  const [creating, setCreating] = useState(false);
  const [waiting, setWaiting] = useState(false);
  const [feedback, setFeedback] = useState<{ text: string; error: boolean }>();
  const asked = useRef(Date.now()); // not 0: the last session's result is still in the store
  const room = rooms?.room || undefined;
  const games = hostGames(rooms, activities);
  const screen = roomsScreen(rooms, creating);

  // A screen change removes what held the focus and a wait disables it: without this the
  // focus falls to the body and Esc never reaches the root.
  useEffect(() => {
    const held = document.activeElement;
    if (!root.current?.contains(held) || held?.matches(":disabled")) root.current?.focus();
  }, [screen, waiting]);
  useEffect(() => {
    if (!result || !isFreshResult(result, asked.current)) return;
    setWaiting(false);
    setFeedback({ text: result.text, error: !result.ok });
  }, [result]);
  useEffect(() => {
    if (!waiting) return;
    const t = window.setTimeout(() => setWaiting(false), 4000);
    return () => window.clearTimeout(t);
  }, [waiting]);
  // the room answers by its push; a stale form never sits over it
  useEffect(() => { if (room) { setCreating(false); setWaiting(false); } }, [room?.id]); // eslint-disable-line react-hooks/exhaustive-deps
  // the match takes the player away: the menu closes on the way in
  const leaving = !!activities?.current || (!!activities?.queued && activities.queued.match === true);
  const wasLeaving = useRef(leaving);
  useEffect(() => {
    if (leaving && !wasLeaving.current) onClose();
    wasLeaving.current = leaving;
  }, [leaving]); // eslint-disable-line react-hooks/exhaustive-deps

  // one action of a type per 250 ms on the server: a quick second click waits its turn
  const last = useRef<number>();
  const timer = useRef<number>();
  const queue = useRef<RoomAction[]>([]);
  useEffect(() => () => window.clearTimeout(timer.current), []);
  const pump = () => {
    const next = queue.current.shift();
    if (!next) return;
    last.current = Date.now();
    sendAction(next);
    if (queue.current.length > 0) timer.current = window.setTimeout(pump, holdMs(last.current, Date.now()));
  };
  const send = (action: RoomAction) => {
    queue.current.push(action);
    if (queue.current.length > 1) return;
    timer.current = window.setTimeout(pump, holdMs(last.current, Date.now()));
  };
  // a move and the settings answer with the next push, not with a text
  const ask = (action: RoomAction) => {
    if (action.operation !== "move" && action.operation !== "settings") { asked.current = Date.now(); setWaiting(true); }
    setFeedback(undefined);
    send(action);
  };

  return <div className="activities rooms o77-interactive" role="dialog" aria-modal="true" aria-labelledby="rooms-title" ref={root} tabIndex={-1}
    onKeyDown={(e) => {
      if (e.key !== "Escape") return;
      if (!e.repeat) { if (escapeAction(screen) === "back") setCreating(false); else onClose(); }
      e.preventDefault(); e.stopPropagation();
    }}>
    <header className="activities__bar">
      <span className="activities__bar-title" id="rooms-title"><Icon name="users" size={15} />GAME ROOMS</span>
      <span className="activities__bar-route">HOST · JOIN · PLAY<button aria-label="Close" onClick={onClose}><Icon name="x" size={15} /></button></span>
    </header>
    {rooms && !rooms.eligible && !room && <div className="activities__strip is-blocked">
      <Icon name="lock" size={15} /><span><b>NOT AVAILABLE</b><small>{rooms.reason}</small></span>
    </div>}

    {!rooms ? <p className="activities__empty rooms__pad"><Icon name="loader" size={14} />Waiting for the rooms…</p>
      : !rooms.enabled ? <p className="activities__empty rooms__pad">Game rooms are closed.</p>
      : room ? <Room room={room} games={games} waiting={waiting} onAsk={ask} />
      : screen === "create" ? <Create games={games} rooms={rooms} waiting={waiting} onAsk={ask} onBack={() => setCreating(false)} />
      : <Browse rooms={rooms} games={games} waiting={waiting} onAsk={ask} onCreate={() => setCreating(true)} />}

    <footer className="activities__foot">
      <span className={cx("activities__feedback", feedback?.error && "is-error")} role="status">
        {waiting ? <><Icon name="loader" size={13} />Asking…</> : feedback?.text ?? (room ? "" : UNRANKED_LINE)}
      </span>
      <span className="activities__keys"><span><Keycap size="sm">ESC</Keycap>{escapeAction(screen) === "back" ? "BACK" : "CLOSE"}</span></span>
    </footer>
  </div>;
}

/* The public rooms, a code, or host your own. */
function Browse({ rooms, games, waiting, onAsk, onCreate }: {
  rooms: RoomsState; games: HostGame[]; waiting: boolean; onAsk(action: RoomAction): void; onCreate(): void;
}) {
  const [code, setCode] = useState("");
  const blocked = !rooms.eligible;
  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (code) onAsk({ type: ROOMS_ACTION, operation: "join", code });
  };
  return <div className="activities__split">
    <div className="activities__list" aria-label="Public rooms">
      {rooms.list.length === 0 && <p className="activities__empty">No public room right now. Host one, or ask a friend for their code.</p>}
      {rooms.list.map((r) => {
        const game = games.find((g) => g.id === r.activity);
        const kind = game?.activity.kind ?? "event";
        return <button key={r.id} type="button" className={cx("activity-row", isFull(r) && "is-closed")} disabled={waiting || blocked || isFull(r)}
          onClick={() => onAsk({ type: ROOMS_ACTION, operation: "join", id: r.id })}>
          <span className="activity-row__icon"><Icon name={KIND_ICON[kind]} size={16} /></span>
          <span className="activity-row__text"><strong>{r.label}</strong>
            <small>{mapLine(r, (game?.activity.modes.length ?? 0) > 0)} · {r.host}</small></span>
          <span className="activity-row__meta">{slots(r)}{isFull(r) && <i>FULL</i>}</span>
        </button>;
      })}
    </div>
    <section className="activity-detail">
      <div className="activity-detail__head"><h1>Host a game</h1></div>
      <p className="activity-detail__brief">Pick the game and the map, open it to everyone or keep it private with a code. You start it when your players are in.</p>
      <div className="activity-detail__actions">
        <Button icon="plus" disabled={waiting || blocked || rooms.full || games.length === 0} onClick={onCreate}>HOST A GAME</Button>
      </div>
      {rooms.full && <span className="activity-detail__why is-info"><Icon name="users" size={13} />Every room is taken. Join one, or come back in a moment.</span>}
      {games.length === 0 && <span className="activity-detail__why is-info"><Icon name="clock" size={13} />No game can be hosted right now.</span>}
      <h2 className="activity-detail__step">PRIVATE ROOM</h2>
      <form className="rooms__code" onSubmit={submit}>
        <Input label="ROOM CODE" icon="key-round" value={code} autoComplete="off" spellCheck={false} maxLength={8} placeholder="ABC12"
          onChange={(e) => setCode(cleanCode(e.target.value))} />
        <Button type="submit" variant="secondary" icon="user-plus" disabled={waiting || blocked || !code}>JOIN</Button>
      </form>
    </section>
  </div>;
}

/* Host: the game, its map, the teams' size, public or private. */
function Create({ games, rooms, waiting, onAsk, onBack }: {
  games: HostGame[]; rooms: RoomsState; waiting: boolean; onAsk(action: RoomAction): void; onBack(): void;
}) {
  const [picked, setPicked] = useState<string>();
  const [map, setMap] = useState<string>();
  const [size, setSize] = useState<number>();
  const [secret, setSecret] = useState(false);
  const game = games.find((g) => g.id === picked) ?? games[0];
  const choose = (id: string) => { setPicked(id); setMap(undefined); setSize(undefined); };
  const sizes = game ? sizeChoices(game) : [];
  const chosenSize = size !== undefined && sizes.includes(size) ? size : game?.most;
  return <div className="activities__split">
    <div className="activities__list" role="listbox" aria-label="Games">
      {games.length === 0 && <p className="activities__empty">No game can be hosted right now.</p>}
      {games.map((g) => <button key={g.id} type="button" role="option" aria-selected={g.id === game?.id} className={cx("activity-row", g.id === game?.id && "is-selected", !g.activity.joinable && "is-closed")}
        onClick={() => choose(g.id)}>
        <span className="activity-row__icon"><Icon name={KIND_ICON[g.activity.kind]} size={16} /></span>
        <span className="activity-row__text"><strong>{g.activity.label}</strong><small>{KIND_LABEL[g.activity.kind]}{g.teams ? ` · ${g.teams} TEAMS` : ""}</small></span>
      </button>)}
    </div>
    {game ? <section className="activity-detail">
      <div className="activity-detail__head"><Badge tone="outline">UNRANKED</Badge><h1>{game.activity.label}</h1></div>
      <p className="activity-detail__brief">{game.activity.description}</p>
      {game.activity.modes.length > 0 && <>
        <h2 className="activity-detail__step">MAP</h2>
        <div className="activity-detail__modes" role="radiogroup" aria-label="Map">
          <button type="button" role="radio" aria-checked={map === undefined} className={cx("activity-mode", map === undefined && "is-on")} onClick={() => setMap(undefined)}>ANY</button>
          {game.activity.modes.map((m) => <button key={m.id} type="button" role="radio" aria-checked={map === m.id} className={cx("activity-mode", map === m.id && "is-on")}
            onClick={() => setMap(m.id)}>{m.label.toUpperCase()}</button>)}
        </div>
      </>}
      {game.activity.modes.length === 0 && <p className="activity-detail__ranked">{mapLine({}, false)}</p>}
      <h2 className="activity-detail__step">{game.teams ? "TEAMS" : "PLAYERS"}</h2>
      <div className="activity-detail__modes" role="radiogroup" aria-label={game.teams ? "Teams" : "Players"}>
        {sizes.map((n) => <button key={n} type="button" role="radio" aria-checked={n === chosenSize} className={cx("activity-mode", n === chosenSize && "is-on")}
          onClick={() => setSize(n)}>{sizeLabel(n, game.teams)}</button>)}
      </div>
      <div className="activity-detail__lobby rooms__private">
        <Toggle checked={secret} onChange={setSecret} label="PRIVATE ROOM" description={secret ? "Not listed: players join with its code" : "Listed for everyone at The Crossing"} />
      </div>
      <div className="activity-detail__actions">
        <Button icon="plus" disabled={waiting || !rooms.eligible || !game.activity.joinable}
          onClick={() => onAsk({ type: ROOMS_ACTION, operation: "create", id: game.id, mode: map, size: chosenSize, private: secret })}>OPEN THE ROOM</Button>
        <Button variant="ghost" icon="undo-2" onClick={onBack}>BACK</Button>
      </div>
      {!game.activity.joinable && <span className="activity-detail__why"><Icon name="triangle-alert" size={13} />{game.activity.label} is not taking players right now.</span>}
    </section> : <div />}
  </div>;
}

/* The room: the host moves, kicks and starts; everyone else watches and may leave. */
function Room({ room, games, waiting, onAsk }: { room: RoomView; games: HostGame[]; waiting: boolean; onAsk(action: RoomAction): void }) {
  const game = games.find((g) => g.id === room.activity);
  const modes = game?.activity.modes ?? [];
  const cols = roomColumns(room);
  const sizes = room.least !== undefined && room.most !== undefined ? sizeChoices({ least: room.least, most: room.most }) : [];
  return <section className="friendly rooms__room" aria-label="Your room">
    <div className="activity-detail__head">
      <Badge tone="accent">{room.private ? "PRIVATE" : "PUBLIC"}</Badge><Badge tone="outline">UNRANKED</Badge>
      <h1>{room.label}</h1>
      <span className="rooms__slots">{slots(room)}</span>
    </div>
    <p className="activity-detail__brief">{mapLine(room, modes.length > 0)} · {UNRANKED_LINE}</p>
    {room.code && <p className="rooms__codeline"><Icon name="key-round" size={14} />ROOM CODE<b>{room.code}</b></p>}
    {room.mine && modes.length > 0 && <div className="activity-detail__modes" role="radiogroup" aria-label="Map">
      <button type="button" role="radio" aria-checked={room.mode === undefined} className={cx("activity-mode", room.mode === undefined && "is-on")}
        onClick={() => onAsk({ type: ROOMS_ACTION, operation: "settings", mode: "" })}>ANY</button>
      {modes.map((m) => <button key={m.id} type="button" role="radio" aria-checked={room.mode === m.id} className={cx("activity-mode", room.mode === m.id && "is-on")}
        onClick={() => onAsk({ type: ROOMS_ACTION, operation: "settings", mode: m.id })}>{m.label.toUpperCase()}</button>)}
    </div>}
    {room.mine && sizes.length > 1 && <div className="activity-detail__modes" role="radiogroup" aria-label={room.teams ? "Teams" : "Players"}>
      {sizes.map((n) => <button key={n} type="button" role="radio" aria-checked={n === room.size} className={cx("activity-mode", n === room.size && "is-on")}
        onClick={() => onAsk({ type: ROOMS_ACTION, operation: "settings", size: n })}>{sizeLabel(n, room.teams?.length)}</button>)}
    </div>}
    <div className="friendly__cols" style={{ gridTemplateColumns: `repeat(${cols.length}, minmax(0, 1fr))` }}>
      {cols.map((c) => <div key={c.key} className="friendly__col">
        <h2>{c.title}<span>{c.players.length}/{c.size}</span></h2>
        {c.players.map((p) => <Chip key={p.id} p={p} room={room} team={c.team} waiting={waiting} onAsk={onAsk} />)}
        {c.players.length === 0 && <p className="friendly__empty">Empty</p>}
      </div>)}
    </div>
    <div className="friendly__actions">
      {room.mine && <Toggle checked={room.private} onChange={(on) => onAsk({ type: ROOMS_ACTION, operation: "settings", private: on })}
        label="PRIVATE ROOM" description={room.private ? "Only the code gets in" : "Listed for everyone"} />}
      {room.mine && <Button icon="swords" disabled={waiting || !!room.issue} onClick={() => onAsk({ type: ROOMS_ACTION, operation: "start" })}>START</Button>}
      <Button variant="ghost" icon="log-out" disabled={waiting} onClick={() => onAsk({ type: ROOMS_ACTION, operation: "leave" })}>LEAVE</Button>
    </div>
    <span className={cx("activity-detail__why", !(room.mine && room.issue) && "is-info")}>
      <Icon name={room.mine && room.issue ? "triangle-alert" : "users"} size={13} />{waitLine(room)}</span>
  </section>;
}

function Chip({ p, room, team, waiting, onAsk }: { p: RoomPlayer; room: RoomView; team?: number; waiting: boolean; onAsk(action: RoomAction): void }) {
  const to = room.mine && team !== undefined ? nextTeam(room, team) : undefined;
  return <div className="rooms__member">
    <button type="button" className="friendly-chip" disabled={to === undefined} title={to !== undefined ? `Move to team ${String.fromCharCode(64 + to)}` : undefined}
      onClick={() => { if (to !== undefined) onAsk({ type: ROOMS_ACTION, operation: "move", target: p.id, team: to }); }}>
      <Icon name={p.host ? "crown" : "user"} size={13} /><span>{p.name}</span>{p.host && <small>HOST</small>}
    </button>
    {room.mine && !p.host && <button type="button" className="rooms__kick" aria-label={`Kick ${p.name}`} title="Kick" disabled={waiting}
      onClick={() => onAsk({ type: ROOMS_ACTION, operation: "kick", target: p.id })}><Icon name="user-minus" size={13} /></button>}
  </div>;
}
