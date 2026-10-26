import { useEffect, useRef, useState } from "react";
import { ArrowRight, Check, ChevronLeft, ChevronRight, Palette, Pause, Play, RotateCcw, X, ZoomIn, ZoomOut } from "lucide-react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Button } from "@/design/components";
import "./customization.css";
const PAGE = PAGE_EVENTS.customization;
interface RGB { r:number; g:number; b:number }
interface Paint { applied:boolean; primary?:RGB; secondary?:RGB }
interface Draft { primary:string; secondary:string; stock:boolean }
interface Wallet { cash:number; bank:number; currency:string }
interface Session { kind:"open"; session:string; nextRequest:number; price:number;money:Wallet;vehicle:{id:string;vehicleId:number;label:string;paint:Paint};categories:Array<{id:string;label:string;description:string}> }
interface Response { kind:"response"|"closed"|"unavailable"|"presentation";session:string;request?:number;nextRequest?:number;operation?:string;ok?:boolean;text?:string;money?:Wallet;paint?:Paint }
const swatches = ["#FFCC00","#F2F3F5","#111114","#656A76","#AA172C","#F06624","#233F80","#38B8CB","#28705A","#71609C","#E0A4BB","#BAA281"];
function hex(rgb?:RGB) { return rgb ? `#${[rgb.r,rgb.g,rgb.b].map(v=>v.toString(16).padStart(2,"0")).join("").toUpperCase()}` : "#FFCC00"; }
function draftOf(p:Paint):Draft {return {primary:hex(p.primary),secondary:hex(p.secondary),stock:!p.applied};}
function signature(d:Draft) {return d.stock?"factory":`${d.primary.toUpperCase()}/${d.secondary.toUpperCase()}`;}
function valid(d:Draft) {return d.stock||(/^#[0-9a-f]{6}$/i.test(d.primary)&&/^#[0-9a-f]{6}$/i.test(d.secondary));}
export function VehicleCustomization() {
  const [session,setSession] = useState<Session>();
  const presentation = useRef<string>();
  useEffect(()=>{
    const off=on<Session|Response>(PAGE,p=>{
    if(p.kind==="presentation"){presentation.current=p.session;useStore.getState().setCustomizationActive(true);return;}
    if(p.kind==="open") {presentation.current=p.session;useStore.getState().setCustomizationActive(true);useStore.getState().closeDialog();setSession(p);}
    else if(p.kind==="unavailable") {
      if(presentation.current&&presentation.current!==p.session)return;
      presentation.current=undefined;
      const store=useStore.getState();store.setCustomizationActive(false);store.closeDialog();store.pushNotice({kind:"error",title:"Auto Studio",body:p.text??"Vehicle preview is unavailable.",source:"LIGHT RP",durationMs:6000});
    }
    else if(p.kind==="closed"&&presentation.current===p.session) {
      presentation.current=undefined;useStore.getState().setCustomizationActive(false);setSession(s=>s?.session===p.session?undefined:s);
    }
    });
    return()=>{off();useStore.getState().setCustomizationActive(false);};
  },[]);
  if(!session)return null;
  return <Workshop key={session.session} session={session} close={()=>{emit(PAGE,{operation:"close",session:session.session});presentation.current=undefined;useStore.getState().setCustomizationActive(false);setSession(undefined);}}/>;
}
function Workshop({session,close}:{session:Session;close():void}) {
  const [draft,setDraft]=useState(()=>draftOf(session.vehicle.paint));
  const [savedKey,setSavedKey]=useState(()=>signature(draftOf(session.vehicle.paint)));
  const [money,setMoney]=useState(session.money);
  const [pay,setPay]=useState<"cash"|"bank">("bank");
  const [channel,setChannel]=useState<"primary"|"secondary">("primary");
  const [rotating,setRotating]=useState(true);
  const [pending,setPending]=useState<"preview"|"save">();
  const [queued,setQueued]=useState(false);
  const [feedback,setFeedback]=useState<{text:string;ok?:boolean}>();
  const request=useRef(session.nextRequest);
  const waiting=useRef<{request:number;operation:"preview"|"save";draft:Draft}>();
  const queue=useRef<Draft>();
  const timer=useRef<number>();
  const lastSent=useRef(-1000);
  const shown=useRef(savedKey);
  const saved=useRef(savedKey);
  const latest=useRef(draft);
  const root=useRef<HTMLDivElement>(null);
  const selected=draft[channel];
  const amount=(value:number)=>`${money.currency} ${value.toLocaleString("en-US")}`;
  const changed=signature(draft)!==savedKey;
  const purchasing=pending==="save";
  const issue=(operation:"preview"|"save",paint:Draft)=>{
    const seq=request.current;
    waiting.current={request:seq,operation,draft:paint};lastSent.current=performance.now();setPending(operation);
    emit(PAGE,{session:session.session,operation,request:seq,category:"paint",...paint,...(operation==="save"?{pay}:{})});
  };
  const flush=()=>{
    if(waiting.current||!queue.current)return;
    const paint=queue.current;
    if(!valid(paint)||signature(paint)===shown.current){queue.current=undefined;setQueued(false);return;}
    const delay=Math.max(0,230-(performance.now()-lastSent.current));
    if(delay>0){timer.current=window.setTimeout(flush,delay);return;}
    queue.current=undefined;setQueued(false);issue("preview",paint);
  };
  const update=(paint:Draft,immediate=false)=>{
    if(purchasing)return;
    latest.current=paint;setDraft(paint);setFeedback(undefined);
    window.clearTimeout(timer.current);queue.current=valid(paint)?paint:undefined;setQueued(!!queue.current);
    timer.current=window.setTimeout(flush,immediate?0:180);
  };
  useEffect(()=>on<Response>(PAGE,p=>{
    const inflight=waiting.current;
    if(p.kind!=="response"||p.session!==session.session||!inflight||p.request!==inflight.request)return;
    request.current=p.nextRequest??inflight.request+1;waiting.current=undefined;setPending(undefined);
    if(p.money)setMoney(p.money);
    if(p.paint){saved.current=signature(draftOf(p.paint));setSavedKey(saved.current);}
    else if(p.ok&&inflight.operation==="save"){saved.current=signature(inflight.draft);setSavedKey(saved.current);}
    shown.current=p.ok?signature(inflight.draft):saved.current;
    if(!p.ok||inflight.operation==="save")setFeedback({text:p.text??"Paint applied.",ok:p.ok});
    if(queue.current){window.clearTimeout(timer.current);timer.current=window.setTimeout(flush,0);}
  }),[session.session]);
  useEffect(()=>{root.current?.focus();return()=>window.clearTimeout(timer.current);},[]);
  useEffect(()=>{if(!pending)return;const t=window.setTimeout(()=>setFeedback({text:"Still waiting for confirmation. Close and reopen to check the outcome. Your purchase will not be sent twice."}),12000);return()=>clearTimeout(t);},[pending]);
  const camera=(command:string,enabled?:boolean)=>emit(PAGE,{session:session.session,operation:"camera",command,enabled});
  const choose=(value:string)=>update({...latest.current,[channel]:value,stock:false},true);
  const purchase=()=>{
    if(waiting.current||queue.current||!valid(latest.current)||signature(latest.current)===saved.current||money[pay]<session.price)return;
    setFeedback(undefined);issue("save",latest.current);
  };
  return <div className="workshop o77-interactive" ref={root} tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="workshop-title" onKeyDown={e=>{
    if(e.key==="Escape"){e.preventDefault();e.stopPropagation();close();}
    if(e.key==="Tab"){
      const nodes=Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),[tabindex="0"]')??[]);
      if(e.shiftKey&&(document.activeElement===nodes[0]||document.activeElement===root.current)){e.preventDefault();nodes.at(-1)?.focus();}
      else if(!e.shiftKey&&(document.activeElement===nodes.at(-1)||document.activeElement===root.current)){e.preventDefault();nodes[0]?.focus();}
    }
  }}>
    <section className="workshop__panel" aria-label="Paint customization">
    <header className="workshop__header"><div><span className="workshop__eyebrow">OPEN // 77 <i>VEHICLE CUSTOMIZATION</i></span><h1 id="workshop-title">AUTO STUDIO<span>_</span></h1><p>{session.vehicle.label}<span>#{session.vehicle.id.slice(0,8).toUpperCase()}</span></p></div><button className="workshop__exit" aria-label="Close customization" onClick={close}><X size={17}/></button></header>
      <nav className="workshop__categories" aria-label="Customization categories">{session.categories.map(c=><button key={c.id} aria-current={c.id==="paint"?"page":undefined} disabled={c.id!=="paint"}><span className="workshop__category-icon"><Palette size={17}/></span><strong>{c.label}<small>{c.description}</small></strong><span>01</span></button>)}</nav>
      <div className="workshop__editor">
        <div className="workshop__editor-title"><h2>Choose your finish</h2><span>{pending==="preview"||queued?"UPDATING…":"LIVE PREVIEW"}</span></div>
        <div className="workshop__channels" role="group" aria-label="Paint channel">{(["primary","secondary"] as const).map(c=><button key={c} aria-pressed={channel===c} onClick={()=>setChannel(c)}><i style={{background:draft[c]}}/>{c==="primary"?"Primary":"Secondary"}</button>)}</div>
        <div className="workshop__swatches" role="group" aria-label="Paint presets">{swatches.map(value=><button key={value} disabled={purchasing} aria-label={`Paint ${value}`} aria-pressed={!draft.stock&&selected.toUpperCase()===value} onClick={()=>choose(value)}><i style={{background:value}}/>{!draft.stock&&selected.toUpperCase()===value&&<Check size={17} style={{color:["#111114","#233F80","#AA172C","#28705A","#71609C"].includes(value)?"#fff":"#050506"}}/>}</button>)}</div>
        <label className="workshop__hex"><span>Custom color</span><div><input type="color" aria-label="Color picker" disabled={purchasing} value={/^#[0-9a-f]{6}$/i.test(selected)?selected:"#000000"} onChange={e=>choose(e.target.value.toUpperCase())}/><input aria-label="Hex color" maxLength={7} spellCheck={false} disabled={purchasing} value={selected} onChange={e=>update({...latest.current,[channel]:e.target.value.toUpperCase(),stock:false})}/></div></label>
        <button className="workshop__factory" aria-pressed={draft.stock} disabled={purchasing} onClick={()=>update({...latest.current,stock:true},true)}><RotateCcw size={14}/>Factory finish</button>
      </div>
    <aside className="workshop__checkout" aria-label="Paint purchase" aria-busy={purchasing}>
      <span className="workshop__eyebrow">YOUR PAINT JOB</span><div className="workshop__price"><span>Body paint</span><strong>{amount(session.price)}</strong></div>
      <p>Both color channels included.</p>
      <div className="workshop__payment" role="group" aria-label="Payment method">{(["cash","bank"] as const).map(method=><button key={method} aria-pressed={pay===method} disabled={purchasing} onClick={()=>setPay(method)}><span>{method==="cash"?"Cash":"Bank"}</span><strong>{amount(money[method])}</strong></button>)}</div>
      {feedback&&<p className={`workshop__feedback${feedback.ok===false?" is-error":""}`} role="status">{feedback.text}</p>}
      {money[pay]<session.price&&<p className="workshop__feedback is-error" role="status">Not enough {pay==="cash"?"cash":"money in your bank account"}.</p>}
      <Button className="workshop__apply" variant="primary" block disabled={!!pending||queued||!valid(draft)||!changed||money[pay]<session.price} onClick={purchase}>{purchasing?"Processing payment…":`Apply paint · ${amount(session.price)}`}<ArrowRight size={16}/></Button>
      <small>{feedback?.ok?"Your finish is saved to this vehicle.":"Free preview. Pay only when you apply."}</small>
      <button className="workshop__leave" onClick={close}>Leave studio<kbd>ESC</kbd></button>
    </aside>
    </section>
    <div className="workshop__camera" aria-label="Vehicle camera controls"><button aria-label="Rotate left" onClick={()=>camera("left")}><ChevronLeft size={18}/></button><button aria-label={rotating?"Pause rotation":"Resume rotation"} aria-pressed={rotating} onClick={()=>{setRotating(!rotating);camera("rotate",!rotating);}}>{rotating?<Pause size={15}/>:<Play size={15}/>}<span>{rotating?"Auto orbit":"Orbit paused"}</span></button><button aria-label="Rotate right" onClick={()=>camera("right")}><ChevronRight size={18}/></button><i/><button aria-label="Zoom in" onClick={()=>camera("zoomIn")}><ZoomIn size={18}/></button><button aria-label="Zoom out" onClick={()=>camera("zoomOut")}><ZoomOut size={18}/></button></div>
  </div>;
}
