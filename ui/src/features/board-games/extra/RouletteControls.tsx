import { useState } from "react";
import { Button, Panel } from "@/design/components";
import { emit } from "@/bridge/open77";
import { useStore } from "@/state/store";
import type { ExtraControlsProps } from "./registry";
interface RouletteState {
  kind?: string;phase?: string;round?: number;yourStake?: number;status?: string;
  result?: {outcome:number;color:string;payouts?:Array<{gross:number}>};
}
export function RouletteControls({game:state,ready}:ExtraControlsProps) {
 const game=state as RouletteState;
 const [amount,setAmount]=useState(10),[bet,setBet]=useState('red');
 const cash=useStore(s=>s.state.money.cash);
 const action=(operation:string,data:Record<string,unknown>={})=>emit('lightrp:tabletop:action',{operation,data});
 return <Panel title="ROULETTE · CASH BETS" chamfer="sm">
  <p className="board-games__meta">Round {game.round??1} · Cash €$ {cash.toLocaleString('en-US')}</p>
  {game.phase==='result'&&game.result&&<p className="board-games__status">{game.result.outcome} · {game.result.color.toUpperCase()}</p>}
  {game.phase==='spinning'?<p role="status">Wheel spinning… bets are closed.</p>:game.phase==='result'?<Button block size="sm" onClick={()=>action('nextRound')}>Next round</Button>:<>
   <label className="board-games__field">Bet<select aria-label="Roulette bet" value={bet} onChange={e=>setBet(e.target.value)}>
    <optgroup label="Even chance">{['red','black','even','odd','low','high'].map(x=><option key={x} value={x}>{({red:'Red · 1:1',black:'Black · 1:1',even:'Even · 1:1',odd:'Odd · 1:1',low:'1–18 · 1:1',high:'19–36 · 1:1'} as Record<string,string>)[x]}</option>)}</optgroup>
    <optgroup label="Dozens">{[1,2,3].map(n=><option key={n} value={`dozen${n}`}>{(n-1)*12+1}–{n*12} · 2:1</option>)}</optgroup>
    <optgroup label="Straight number">{Array.from({length:37},(_,n)=><option key={n} value={`number:${n}`}>{n} · 35:1</option>)}</optgroup>
   </select></label>
   <label className="board-games__field">Cash amount<input aria-label="Bet amount" type="number" min={1} max={1000000} step={1} value={amount} onChange={e=>setAmount(Number(e.target.value))}/></label>
   <div className="board-games__modes"><Button size="sm" disabled={!ready||!Number.isInteger(amount)||amount<1||amount>cash||amount>1000000} onClick={()=>action('bet',{bet,amount})}>Place bet</Button><Button variant="secondary" size="sm" disabled={!ready} onClick={()=>action('spin')}>Spin wheel</Button></div>
  </>}
  <p className="board-games__meta">Your stakes: €$ {(game.yourStake??0).toLocaleString('en-US')}</p>
  <p className="board-games__description">Stakes and winnings use your RP cash. Winning returns include the original stake; 0 loses all even-chance bets.</p>
 </Panel>;
}
