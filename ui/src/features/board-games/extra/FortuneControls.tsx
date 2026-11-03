import { useEffect, useState } from "react";
import { Button, Panel } from "@/design/components";
import { emit } from "@/bridge/open77";
import { useStore } from "@/state/store";
import type { ExtraControlsProps } from "./registry";
import "./fortune.css";

/* Fortune Wheel (big-six money wheel). The server owns every stake, spin and
   payout; this panel only sends `bet` / `spin` requests. */
const SPOTS = [
  { id: "1", label: "1x", pays: "1 to 1" },
  { id: "2", label: "2x", pays: "2 to 1" },
  { id: "5", label: "5x", pays: "5 to 1" },
  { id: "10", label: "10x", pays: "10 to 1" },
  { id: "20", label: "20x", pays: "20 to 1" },
  { id: "eye", label: "Neon Eye", pays: "40 to 1" },
  { id: "star", label: "Starburst", pays: "40 to 1" },
] as const;
const QUICK = [5, 25, 100, 500];
/* Mirrors LightRpCasinoFortune.layout: half a turn repeats, 0 = eye, 27 = star. */
const HALF = ["S","1","2","1","5","1","2","1","10","1","2","5","1","20","1","2","1","5","2","1","10","1","2","5","1","2","1"];
const spotOf = (segment: number) => { const s = HALF[segment % 27] ?? "1"; return s === "S" ? (segment === 0 ? "eye" : "star") : s; };
const labelOf = (spot: string) => SPOTS.find(s => s.id === spot)?.label ?? spot;

interface FortuneState {
  phase?: string; round?: number; pot?: Record<string, number>;
  yourBets?: Record<string, number>; yourStake?: number; yourWin?: number;
  minBet?: number; maxBet?: number; recent?: number[];
  result?: { segment: number; spot: string; multiplier: number };
  picked?: string; pickSerial?: number;
}

export function FortuneControls({ game: state, ready }: ExtraControlsProps) {
  const game = state as FortuneState;
  const cash = useStore(s => s.state.money.cash);
  const [spot, setSpot] = useState<string>("1");
  const [amount, setAmount] = useState(10);
  useEffect(() => { if (game.picked && SPOTS.some(s => s.id === game.picked)) setSpot(game.picked); }, [game.pickSerial, game.picked]);
  const action = (operation: string, data: Record<string, unknown> = {}) => emit("lightrp:tabletop:action", { operation, data });
  const min = game.minBet ?? 1, max = game.maxBet ?? 1000;
  const spinning = game.phase === "spinning";
  const valid = Number.isInteger(amount) && amount >= min && amount <= max && amount <= cash;
  const mine = game.yourBets ?? {};
  const recent = Array.isArray(game.recent) ? game.recent : [];
  return <Panel title="FORTUNE WHEEL · CASH BETS" chamfer="sm">
    <p className="board-games__meta">Round {game.round ?? 1} · Cash €$ {cash.toLocaleString("en-US")}</p>
    {spinning ? <p className="board-games__status" role="status">Wheel spinning… bets are closed.</p>
      : game.phase === "result" && game.result ? <p className="board-games__status" role="status">
        <span className="fortune__tag" data-spot={game.result.spot}>{labelOf(game.result.spot)}</span>
        {" "}{(game.yourWin ?? 0) > 0 ? `You won €$ ${(game.yourWin ?? 0).toLocaleString("en-US")}` : "wins this spin"}
      </p> : <p className="board-games__status">Place your bets</p>}
    <div className="fortune__spots" role="radiogroup" aria-label="Multiplier">
      {SPOTS.map(s => <button key={s.id} type="button" role="radio" aria-checked={spot === s.id} data-spot={s.id}
        className={"fortune__spot" + (spot === s.id ? " is-selected" : "")} onClick={() => setSpot(s.id)}>
        <strong>{s.label}</strong><small>{s.pays}</small>
        {(mine[s.id] ?? 0) > 0 && <em>€$ {(mine[s.id] ?? 0).toLocaleString("en-US")}</em>}
      </button>)}
    </div>
    <label className="board-games__field">Cash amount ({min}–{max.toLocaleString("en-US")})
      <input aria-label="Bet amount" type="number" min={min} max={max} step={1} value={amount} onChange={e => setAmount(Number(e.target.value))}/>
    </label>
    <div className="board-games__modes">{QUICK.map(n => <Button key={n} variant="ghost" size="sm" onClick={() => setAmount(n)}>{n}</Button>)}</div>
    <div className="board-games__modes">
      <Button size="sm" disabled={!ready || spinning || !valid} onClick={() => action("bet", { spot, amount })}>Place bet on {labelOf(spot)}</Button>
      <Button variant="secondary" size="sm" disabled={!ready || spinning} onClick={() => action("spin")}>Spin wheel</Button>
    </div>
    <p className="board-games__meta">Your stakes this spin: €$ {(game.yourStake ?? 0).toLocaleString("en-US")}</p>
    {recent.length > 0 && <div className="fortune__recent" aria-label="Last results">
      {recent.map((segment, i) => <span key={i} className="fortune__tag" data-spot={spotOf(segment)}>{labelOf(spotOf(segment))}</span>)}
    </div>}
    <p className="board-games__description">Click a spot on the felt or pick one here. Winning bets return the multiplier times the stake plus the stake, paid when the wheel stops. Any seated player may spin.</p>
  </Panel>;
}
