import { useEffect, useState } from "react";
import { Button, Panel } from "@/design/components";
import { emit } from "@/bridge/open77";
import { useStore } from "@/state/store";
import type { ExtraControlsProps } from "./registry";

interface SlotsState {
  kind?: string; round?: number; seat?: string; spinning?: boolean; yours?: boolean;
  result?: { bet: number; gross: number; multiplier: number; label: string; symbols?: string[]; round?: number };
  paytable?: { three?: Record<string, number>; twoCherries?: number; mixedFruit?: number; oneCherry?: number; minBet?: number; maxBet?: number };
}
const NAMES: Record<string, string> = { cherry: "Cherry", lemon: "Lemon", grape: "Grape", bell: "Bell", bar: "Bar", chip: "Chip", diamond: "Diamond", seven: "Seven" };
const PRESETS = [1, 10, 50, 100, 500, 1000];
const money = (n: number) => `€$ ${n.toLocaleString("en-US")}`;

export function SlotsControls({ game: state, ready }: ExtraControlsProps) {
  const game = state as SlotsState;
  const [amount, setAmount] = useState(10);
  const cash = useStore(s => s.state.money.cash);
  const max = game.paytable?.maxBet ?? 1000, min = game.paytable?.minBet ?? 1;
  const valid = Number.isInteger(amount) && amount >= min && amount <= max;
  // The Lua side keeps the chosen bet so a click on the lever pulls with it.
  useEffect(() => { if (valid) emit("lightrp:slots:bet", { amount }); }, [amount, valid]);
  const seated = game.seat === "white";
  const result = game.result;
  const three = Object.entries(game.paytable?.three ?? {}).sort((a, b) => b[1] - a[1]);
  return <Panel title="SLOT MACHINE · CASH" chamfer="sm">
    <p className="board-games__meta">Pull {game.round ?? 0} · Cash {money(cash)}</p>
    {game.spinning ? <p className="board-games__status" role="status">Reels spinning…</p>
      : result ? <>
        <p className="board-games__status" role="status">{result.gross > 0 ? `${result.label} · ${money(result.gross)}` : "No win"}</p>
        {result.symbols && <p className="board-games__meta">{result.symbols.map(s => NAMES[s] ?? s).join(" · ")} · bet {money(result.bet)}</p>}
      </> : <p className="board-games__status">Ready</p>}
    {seated ? <>
      <label className="board-games__field">Bet (whole RP dollars, {min}–{max.toLocaleString("en-US")})
        <input aria-label="Bet amount" type="number" min={min} max={max} step={1} value={amount} onChange={e => setAmount(Number(e.target.value))}/>
      </label>
      <div className="board-games__modes" role="group" aria-label="Bet presets">
        {PRESETS.map(p => <Button key={p} size="sm" variant={amount === p ? "primary" : "secondary"} aria-pressed={amount === p} onClick={() => setAmount(p)}>{p}</Button>)}
      </div>
      <div className="board-games__modes">
        <Button block size="sm" disabled={!ready || game.spinning || !valid || amount > cash} onClick={() => emit("lightrp:tabletop:action", { operation: "pull", data: { bet: amount } })}>
          {game.spinning ? "Spinning…" : `Pull · ${money(valid ? amount : 0)}`}
        </Button>
      </div>
    </> : <p className="board-games__description">You are watching. The player in the first seat pulls the lever.</p>}
    <p className="board-games__meta">Paytable · returns per {money(1)} bet, stake included</p>
    <p className="board-games__description">
      {three.map(([symbol, pays]) => `3 ${NAMES[symbol] ?? symbol} ×${pays}`).join(" · ")}
      {` · Cherry, Cherry ×${game.paytable?.twoCherries ?? 4} · Any 3 fruit ×${game.paytable?.mixedFruit ?? 2} · Cherry on reel 1 ×${game.paytable?.oneCherry ?? 1}`}
    </p>
    <p className="board-games__description">Payline is the middle row. The server spins the reels; winnings arrive in your cash when the last reel stops. Expected return 94.4 %.</p>
  </Panel>;
}
