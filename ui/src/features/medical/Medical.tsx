import { useEffect, useState } from "react";
import { HeartPulse, ShieldPlus, Clock3, ArrowRight } from "lucide-react";
import { emit, on } from "@/bridge/open77";
import "./medical.css";
const PAGE="lightrp:ui:medical";
interface MedicalState {
  downed:boolean;persisted?:boolean;phase?:string;remainingMs?:number;canGiveUp?:boolean;
  receiving?:boolean;error?:string;treatment?:{phase:string;patient?:string;remainingMs:number;durationMs:number};
}
export function Medical() {
  const [state,setState]=useState<MedicalState>({downed:false});
  const [receivedAt,setReceivedAt]=useState(0),[clock,setClock]=useState(0),[confirm,setConfirm]=useState(false);
  useEffect(()=>on<{kind:string;state?:MedicalState}>(PAGE,p=>{
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
  return <div className="medical-overlay">
    <section className="medical-down" role="dialog" aria-modal="false" aria-label="Unconscious status">
      <div className="medical-down__symbol"><HeartPulse size={24}/></div>
      <div className="medical-down__body"><span className="medical-down__eyebrow">LIGHT RP / EMERGENCY CARE</span><h1>{title}</h1>
        <p>{transferring?"Your hospital transfer is being synchronized.":recovering?"Your treatment is being confirmed. Stay connected.":state.receiving?"Someone is stabilizing you. Stay connected until treatment finishes.":"Stay with us. Another person can revive you with a Trauma Stabilization Kit."}</p>
        {state.error&&<p className="medical-down__error" role="status">{state.error}</p>}
        {!state.persisted?<div className="medical-down__waiting"><Clock3 size={13}/>Saving medical state…</div>:
          !state.canGiveUp?<div className="medical-down__waiting"><Clock3 size={13}/>{state.receiving||recovering?"Receiving medical assistance":transferring?"Transferring to hospital":<>Hospital transfer unlocks in <b>{minutes}:{String(seconds%60).padStart(2,"0")}</b></>}</div>:
          confirm?<div className="medical-down__confirm"><span>Leave the scene and wake up at the hospital?</span><div><button onClick={()=>{setConfirm(false);emit(PAGE,{operation:"giveup"})}}>Confirm hospital transfer<ArrowRight size={13}/></button><button className="is-secondary" onClick={()=>setConfirm(false)}>Keep waiting</button></div></div>:
          <button className="medical-down__giveup" onClick={()=>setConfirm(true)}>Give up and go to hospital<ArrowRight size={13}/></button>}
        <div className="medical-down__hint"><ShieldPlus size={13}/>You can still speak to nearby players while waiting for help.</div>
      </div>
    </section>
  </div>;
}
