import { useEffect, useRef, useState } from "react";
import { ArrowLeft, ArrowRight, Check, ChevronLeft, ChevronRight, Palette, Pause, Play, RotateCcw, Save, X, ZoomIn, ZoomOut } from "lucide-react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Button, SectionHeader } from "@/design/components";
import "./customization.css";
const PAGE = PAGE_EVENTS.customization;
interface RGB { r:number; g:number; b:number }
interface Paint { applied:boolean; primary?:RGB; secondary?:RGB }
interface Session { kind:"open"; session:string; nextRequest:number; vehicle:{id:string;vehicleId:number;label:string;paint:Paint};categories:Array<{id:string;label:string;description:string}> }
interface Response { kind:"response"|"closed"|"unavailable";session:string;request?:number;nextRequest?:number;operation?:string;ok?:boolean;text?:string }
const swatches = ["#FFCC00","#F2F3F5","#111114","#656A76","#AA172C","#F06624","#233F80","#38B8CB","#28705A","#71609C","#E0A4BB","#BAA281"];
function hex(rgb?:RGB) { return rgb ? `#${[rgb.r,rgb.g,rgb.b].map(v=>v.toString(16).padStart(2,"0")).join("").toUpperCase()}` : "#FFCC00"; }
export function VehicleCustomization() {
  const [session,setSession] = useState<Session>();
  useEffect(()=>on<Session|Response>(PAGE,p=>{
    if(p.kind==="open") {useStore.getState().closeDialog();setSession(p);}
    else if(p.kind==="unavailable") {
      const store=useStore.getState();store.closeDialog();store.pushNotice({kind:"error",title:"Auto Studio",body:p.text??"Vehicle preview is unavailable.",source:"LIGHT RP",durationMs:6000});
    }
    else if(p.kind==="closed") setSession(s=>s?.session===p.session?undefined:s);
  }),[]);
  if(!session)return null;
  return <Workshop key={session.session} session={session} close={()=>{emit(PAGE,{operation:"close",session:session.session});setSession(undefined);}}/>;
}
function Workshop({session,close}:{session:Session;close():void}) {
  const [primary,setPrimary]=useState(hex(session.vehicle.paint.primary));
  const [secondary,setSecondary]=useState(hex(session.vehicle.paint.secondary));
  const [channel,setChannel]=useState<"primary"|"secondary">("primary");
  const [stock,setStock]=useState(!session.vehicle.paint.applied);
  const [rotating,setRotating]=useState(true);
  const [pending,setPending]=useState(false);
  const [feedback,setFeedback]=useState<{text:string;ok?:boolean}>();
  const request=useRef(session.nextRequest), waiting=useRef<number>();
  const root=useRef<HTMLDivElement>(null);
  const selected=channel==="primary"?primary:secondary;
  const valid=/^#[0-9a-f]{6}$/i.test(primary)&&/^#[0-9a-f]{6}$/i.test(secondary);
  useEffect(()=>on<Response>(PAGE,p=>{
    if(p.kind!=="response"||p.session!==session.session||p.request!==waiting.current)return;
    request.current=p.nextRequest??request.current+1;waiting.current=undefined;setPending(false);
    setFeedback({text:p.text??"Vehicle updated.",ok:p.ok});
  }),[session.session]);
  useEffect(()=>{root.current?.focus();},[]);
  useEffect(()=>{if(!pending)return;const t=window.setTimeout(()=>setFeedback({text:"Still waiting for confirmation. Close and reopen to check the saved finish."}),12000);return()=>clearTimeout(t);},[pending]);
  const camera=(command:string,enabled?:boolean)=>emit(PAGE,{session:session.session,operation:"camera",command,enabled});
  const issue=(operation:"preview"|"save",paint?:{primary:string;secondary:string;stock:boolean})=>{
    if(waiting.current!=null||(!paint&&!valid&&!stock))return;
    waiting.current=request.current;setPending(true);setFeedback(undefined);
    emit(PAGE,{session:session.session,operation,request:request.current,category:"paint",...(paint??{primary,secondary,stock})});
  };
  const choose=(value:string)=>{
    if(pending)return;
    const paint={primary:channel==="primary"?value:primary,secondary:channel==="secondary"?value:secondary,stock:false};
    setPrimary(paint.primary);setSecondary(paint.secondary);setStock(false);issue("preview",paint);
  };
  return <div className="workshop o77-interactive" ref={root} tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="workshop-title" onKeyDown={e=>{
    if(e.key==="Escape"){e.preventDefault();e.stopPropagation();close();}
    if(e.key==="Tab"){
      const nodes=Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),[tabindex="0"]')??[]);
      if(e.shiftKey&&(document.activeElement===nodes[0]||document.activeElement===root.current)){e.preventDefault();nodes.at(-1)?.focus();}
      else if(!e.shiftKey&&(document.activeElement===nodes.at(-1)||document.activeElement===root.current)){e.preventDefault();nodes[0]?.focus();}
    }
  }}>
    <aside className="workshop__panel">
      <header><span className="workshop__eyebrow">LIGHT RP <i>//</i> AUTO STUDIO</span><button className="workshop__close" aria-label="Close customization" onClick={close}><X size={18}/></button><h1 id="workshop-title">Make it yours<span>.</span></h1><p>{session.vehicle.label}</p><code>REGISTRATION #{session.vehicle.id.slice(0,8).toUpperCase()}</code></header>
      <nav className="workshop__categories" aria-label="Customization categories">{session.categories.map((c,i)=><button key={c.id} aria-current={c.id==="paint"?"page":undefined} disabled={c.id!=="paint"}><span>{String(i+1).padStart(2,"0")}</span><Palette size={18}/><div><strong>{c.label}</strong><small>{c.description}</small></div><ChevronRight size={17}/></button>)}</nav>
      <div className="workshop__editor">
        <SectionHeader index="01" title="BODY PAINT" subtitle="Two tones. Your signature."/>
        <div className="workshop__channels" role="group" aria-label="Paint channel">{(["primary","secondary"] as const).map(c=><button key={c} aria-pressed={channel===c} onClick={()=>setChannel(c)}><i style={{background:c==="primary"?primary:secondary}}/>{c==="primary"?"Primary":"Secondary"}</button>)}</div>
        <div className="workshop__swatches" role="group" aria-label="Paint presets">{swatches.map(value=><button key={value} disabled={pending} aria-label={`Paint ${value}`} aria-pressed={!stock&&selected.toUpperCase()===value} style={{background:value}} onClick={()=>choose(value)}>{!stock&&selected.toUpperCase()===value&&<Check size={18} style={{color:["#111114","#233F80","#AA172C","#28705A","#71609C"].includes(value)?"#fff":"#050506"}}/>}</button>)}</div>
        <label className="workshop__hex"><span>CUSTOM COLOR</span><div><input type="color" aria-label="Color picker" disabled={pending} value={/^#[0-9a-f]{6}$/i.test(selected)?selected:"#000000"} onChange={e=>{(channel==="primary"?setPrimary:setSecondary)(e.target.value.toUpperCase());setStock(false);}}/><input aria-label="Hex color" maxLength={7} spellCheck={false} disabled={pending} value={selected} onChange={e=>{(channel==="primary"?setPrimary:setSecondary)(e.target.value.toUpperCase());setStock(false);}}/></div></label>
        <div className="workshop__preview-actions"><Button variant="secondary" size="sm" disabled={pending||(!valid&&!stock)} onClick={()=>issue("preview")}>Preview color<ArrowRight size={14}/></Button><button disabled={pending} onClick={()=>{setStock(true);issue("preview",{primary,secondary,stock:true});}}><RotateCcw size={13}/>Factory finish</button></div>
        <p className="workshop__note">Preview your finish on the vehicle. Save changes to keep it when you return to the garage. Color coverage varies by model.</p>
      </div>
      <footer aria-busy={pending}>
        {feedback&&<p className={`workshop__feedback${feedback.ok===false?" is-error":""}`} role="status">{feedback.text}</p>}
        <Button variant="primary" block disabled={pending||(!valid&&!stock)} onClick={()=>issue("save")}><Save size={16}/>{pending?"Synchronizing…":"Save changes"}</Button>
        <button className="workshop__leave" onClick={close}><ArrowLeft size={14}/>Back to the street<kbd>ESC</kbd></button>
        <span className="workshop__saved-note">Unsaved previews are discarded when you leave.</span>
      </footer>
    </aside>
    <div className="workshop__view-label"><span>LIVE PREVIEW</span><strong>{session.vehicle.label}</strong></div>
    <div className="workshop__camera" aria-label="Vehicle camera controls"><button aria-label="Rotate left" onClick={()=>camera("left")}><ChevronLeft size={18}/></button><button aria-label={rotating?"Pause rotation":"Resume rotation"} aria-pressed={rotating} onClick={()=>{setRotating(!rotating);camera("rotate",!rotating);}}>{rotating?<Pause size={15}/>:<Play size={15}/>}<span>{rotating?"Auto orbit":"Orbit paused"}</span></button><button aria-label="Rotate right" onClick={()=>camera("right")}><ChevronRight size={18}/></button><i/><button aria-label="Zoom in" onClick={()=>camera("zoomIn")}><ZoomIn size={18}/></button><button aria-label="Zoom out" onClick={()=>camera("zoomOut")}><ZoomOut size={18}/></button></div>
  </div>;
}
