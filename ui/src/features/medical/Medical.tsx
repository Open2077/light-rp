import { useEffect, useState } from "react";
import { ShieldPlus, ArrowRight } from "lucide-react";
import { emit, on } from "@/bridge/open77";
import { formatMoney } from "@/bridge/money";
import "./medical.css";
const PAGE="lightrp:ui:medical";
interface MedicalState {
  downed:boolean;persisted?:boolean;phase?:string;remainingMs?:number;canGiveUp?:boolean;
  receiving?:boolean;error?:string;bill?:number;treatment?:{phase:string;patient?:string;remainingMs:number;durationMs:number};
}
export function Medical() {
  const [state,setState]=useState<MedicalState>({downed:false});
  const [receivedAt,setReceivedAt]=useState(0),[clock,setClock]=useState(0),[confirm,setConfirm]=useState(false);
  const [covered,setCovered]=useState(false);
  useEffect(()=>on<{kind:string;state?:MedicalState;down?:boolean}>(PAGE,p=>{
    if(p?.kind==="cover"){setCovered(p.down===true);return;} // DeathCover draws the opaque backdrop
    if(p.kind!=="state"||!p.state)return;
    setState(p.state);setReceivedAt(performance.now());
    if(!p.state.downed)setConfirm(false);
  }),[]);
  useEffect(()=>{if(!state.downed)return;const timer=window.setInterval(()=>setClock(performance.now()),250);return()=>clearInterval(timer)},[state.downed]);
  if(!state.downed)return null;
  const remaining=Math.max(0,(state.remainingMs??0)-Math.max(0,clock-receivedAt));
  const seconds=Math.ceil(remaining/1000),minutes=Math.floor(seconds/60);
  const transferring=state.phase==="hospital",recovering=state.phase==="reviving";
  const title=transferring?"Medical transfer":recovering?"Recovery in progress":"You are unconscious";
  return <div className={`medical-overlay${covered?" is-covered":""}`}>
    <svg className="medical-lifeline" viewBox="0 0 1600 400" preserveAspectRatio="none" aria-hidden="true">
      <defs><path id="medical-pulse" pathLength="1000" d="M0 220 H220 L250 200 L280 240 L310 220 H460 L500 180 L535 260 L580 25 L635 375 L685 145 L730 220 H970 L1000 195 L1030 245 L1060 220 H1600"/></defs>
      <use href="#medical-pulse" className="medical-lifeline__track"/>
      <use href="#medical-pulse" className="medical-lifeline__pulse"/>
    </svg>
    <div className="medical-brand" aria-hidden="true">OPEN<span>//</span>77 <span>EMERGENCY PROTOCOL</span></div>
    <section className="medical-down" role="dialog" aria-modal="false" aria-label="Unconscious status">
      <img className="medical-down__skull" src="img/medical/cyberpunk-skull.png" alt="" aria-hidden="true"/>
      <span className="medical-down__eyebrow">YOU ARE</span>
      <h1 aria-label={title}>{transferring?"TRANSFER":recovering?"RECOVERING":"DEAD"}</h1>
      <div className="medical-down__timer" aria-label="Hospital transfer countdown">{minutes}:{String(seconds%60).padStart(2,"0")}</div>
      <span className="medical-down__status" role="status">{!state.persisted?"Saving medical state…":transferring?"Transferring to hospital":recovering||state.receiving?"Receiving medical assistance":state.canGiveUp?"Hospital transfer available":"Hospital transfer unlocks in"}</span>
      <p>{transferring?"Your hospital transfer is being synchronized.":recovering?"Your treatment is being confirmed. Stay connected.":state.receiving?"Someone is stabilizing you. Stay connected until treatment finishes.":"Another person can revive you with a Trauma Stabilization Kit."}</p>
      {state.error&&<p className="medical-down__error" role="alert">{state.error}</p>}
      <div className="medical-down__actions">
        {state.persisted&&state.canGiveUp&&(confirm?<>
          <span className="medical-down__question">Leave the scene and wake up at the hospital?{state.bill===undefined?"":state.bill>0?` The clinic bills ${formatMoney(state.bill)}.`:" The city covers this visit."}</span>
          <div className="medical-down__buttons"><button onClick={()=>{setConfirm(false);emit(PAGE,{operation:"giveup"})}}>Confirm hospital transfer<ArrowRight size={16}/></button><button className="is-secondary" onClick={()=>setConfirm(false)}>Keep waiting</button></div>
        </>:<button onClick={()=>setConfirm(true)}>Give up and go to hospital<ArrowRight size={16}/></button>)}
      </div>
      <div className="medical-down__hint"><ShieldPlus size={14}/>You can still speak to nearby players while waiting for help.</div>
    </section>
    <div className="medical-footer" aria-hidden="true"><span>VITAL SIGNAL // LOST</span><span>TRAUMA RESPONSE SYSTEM</span></div>
  </div>;
}
