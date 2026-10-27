import { useState } from "react";
import { Button, Panel } from "@/design/components";
import { emit } from "@/bridge/open77";
import { useStore } from "@/state/store";
export interface ExtraState {
  kind?: string;phase?: string;round?: number;yourStake?: number;remaining?: number;height?: number;status?: string;
  result?: {outcome:number;color:string;payouts?:Array<{gross:number}>};
  hand?:Array<{id:string;a:number;b:number}>;handCounts?:Record<string,number>;drawCount?:number;left?:number;right?:number;
}
export function TabletopExtraControls({kind,game,selectedTile,ready,isActor}:{kind:string;game:ExtraState;selectedTile?:string;ready?:boolean;isActor?:boolean}) {
 const [amount,setAmount]=useState(10),[bet,setBet]=useState('red');
 const [level,setLevel]=useState(0),[yaw,setYaw]=useState(0),[orientation,setOrientation]=useState<'frame'|'flat'>('frame');
 const cash=useStore(s=>s.state.money.cash);
 const action=(operation:string,data:Record<string,unknown>={})=>emit('lightrp:tabletop:action',{operation,data});
 const configure=(next:{level?:number;yaw?:number;orientation?:'frame'|'flat'})=>{
  const p={level:next.level??level,yaw:next.yaw??yaw,orientation:next.orientation??orientation};
  setLevel(p.level);setYaw(p.yaw);setOrientation(p.orientation);action('configure',p);
 };
 if(kind==='roulette') return <Panel title="ROULETTE · CASH BETS" chamfer="sm">
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
 if(kind==='dominoes') return <Panel title="DOMINOES · YOUR HAND" chamfer="sm">
  <p className="board-games__meta">Draw pile: {game.drawCount??0} · Ends {game.left??'—'} / {game.right??'—'}</p>
  <div className="board-games__tiles" role="group" aria-label="Domino hand">{game.hand?.map(tile=><Button key={tile.id} size="sm" variant={selectedTile===tile.id?'primary':'secondary'} aria-pressed={selectedTile===tile.id} onClick={()=>action('configure',{selectedTile:tile.id})}>{tile.a} | {tile.b}</Button>)}</div>
  <div className="board-games__modes"><Button size="sm" disabled={!isActor||!selectedTile} onClick={()=>action('play',{tileId:selectedTile,end:'left'})}>Play left</Button><Button size="sm" disabled={!isActor||!selectedTile} onClick={()=>action('play',{tileId:selectedTile,end:'right'})}>Play right</Button></div>
  <div className="board-games__modes"><Button size="sm" variant="secondary" disabled={!isActor||(game.drawCount??0)===0} onClick={()=>action('draw')}>Draw</Button><Button size="sm" variant="ghost" disabled={!isActor} onClick={()=>action('pass')}>Pass</Button></div>
 </Panel>;
 return <Panel title="CARD TOWER · BUILD" chamfer="sm">
  <p className="board-games__meta">Cards remaining: {game.remaining??52}</p>
  {game.status==='collapsed'?<p role="status" className="board-games__status">The tower collapsed. Start a new game.</p>:<>
   <div className="board-games__modes"><Button size="sm" variant={orientation==='frame'?'primary':'secondary'} onClick={()=>configure({orientation:'frame'})}>A-frame · 2 cards</Button><Button size="sm" variant={orientation==='flat'?'primary':'secondary'} onClick={()=>configure({orientation:'flat'})}>Roof · 1 card</Button></div>
   <label className="board-games__field">Level<input aria-label="Card level" type="number" min={0} max={5} value={level} onChange={e=>configure({level:Math.max(0,Math.min(5,Math.floor(Number(e.target.value))))})}/></label>
   <label className="board-games__field">Rotation<select aria-label="Card rotation" value={yaw} onChange={e=>configure({yaw:Number(e.target.value)})}>{[0,45,90,135,180,225,270,315].map(n=><option key={n} value={n}>{n}°</option>)}</select></label>
   <p className="board-games__description">Click the table to place. Leaning pairs support roofs; unsupported weight or a bad overlap collapses the tower.</p>
  </>}
 </Panel>;
}
