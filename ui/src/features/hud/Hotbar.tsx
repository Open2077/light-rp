import { useEffect, useRef, useState } from "react";
import { on } from "@/bridge/open77";
import type { HotbarState } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { ItemArt } from "../inventory/ItemArt";
import "./hotbar.css";
interface Wire { kind:string; state?:Omit<HotbarState,"visible">; visible?:boolean; showKey?:string;slotKeys?:string[];slot?:number;request?:string;ok?:boolean;text?:string }
export function Hotbar() {
  const state=useStore(s=>s.hotbar);
  const piloting=useStore(s=>!!s.hud.titan); // the Titan's ability bar takes the bar's place (hotbar.lua stops asking for the peek too)
  const [flash,setFlash]=useState<{slot:number;request?:string;error?:boolean;text?:string}>();
  const flashRef=useRef(flash);flashRef.current=flash;
  useEffect(()=>on<Wire>("lightrp:ui:hotbar",p=>{
    if(p.kind==="state"&&p.state)useStore.getState().setHotbar({...p.state,visible:p.visible===true,showKey:p.showKey,slotKeys:p.slotKeys});
    if(p.kind==="activate"&&p.slot){const next={slot:p.slot,request:p.request};flashRef.current=next;setFlash(next);}
    if(p.kind==="response"&&p.slot&&p.request===flashRef.current?.request){const next={slot:p.slot,request:p.request,error:!p.ok,text:p.ok?undefined:p.text};flashRef.current=next;setFlash(next);}
  }),[]);
  useEffect(()=>{if(!flash)return;const t=window.setTimeout(()=>setFlash(undefined),1800);return()=>clearTimeout(t)},[flash]);
  if(!state?.ready||!state.visible||piloting)return null;
  return <div className="hotbar" data-testid="hotbar">
    <div className="hotbar__slots">{Array.from({length:5},(_,i)=>{
      const slot=i+1,item=state.items.find(x=>x.slot===slot),active=flash?.slot===slot;
      return <div key={slot} className={`hotbar__slot${item?" is-filled":""}${active?" is-active":""}${active&&flash.error?" is-error":""}`}>
        <kbd>{state.slotKeys?.[i]??slot}</kbd>{item?<><span className="hotbar__count">×{item.count}</span><div className="hotbar__art"><ItemArt item={item}/></div><span className="hotbar__name">{item.label}</span></>:<span className="hotbar__empty">—</span>}
      </div>;
    })}</div>
    <span className={`hotbar__hint${flash?.error?" is-error":""}`}>{flash?.error?flash.text:`QUICK USE · HOLD ${state.showKey??"TAB"}`}</span>
  </div>;
}
