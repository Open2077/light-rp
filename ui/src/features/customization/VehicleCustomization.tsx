import { useEffect, useRef, useState } from "react";
import { ArrowRight, Car, Check, ChevronLeft, ChevronRight, Lightbulb, Palette, Pause, Play, RotateCcw, X, ZoomIn, ZoomOut } from "lucide-react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Button } from "@/design/components";
import "./customization.css";
const PAGE = PAGE_EVENTS.customization;
interface RGB { r:number; g:number; b:number }
interface Paint { applied:boolean; primary?:RGB; secondary?:RGB; lightsHue?:number }
interface Wallet { cash:number; bank:number; currency:string }
interface Option { id:string; label:string }
interface Category { id:string; label:string; description:string; icon?:string; price?:number; available?:boolean; reason?:string; options?:Option[] }
interface Confirmed { paint?:Paint; lightsHue?:number; appearance?:string }
interface Vehicle { id:string; vehicleId:number; label:string; model?:string; paint:Paint; lightsHue?:number; appearance?:string }
interface Session { kind:"open"; session:string; nextRequest:number; price:number; prices?:Record<string,number>; money:Wallet; vehicle:Vehicle; categories:Category[] }
interface Response { kind:"response"|"closed"|"unavailable"|"presentation";session:string;request?:number;nextRequest?:number;operation?:string;category?:string;ok?:boolean;text?:string;money?:Wallet;paint?:Paint;confirmed?:Confirmed }
// Editors this page knows. Any other id the server lists stays disabled.
type CategoryId = "paint"|"lights"|"trim";
const KNOWN:CategoryId[] = ["paint","lights","trim"];
interface PaintDraft { primary:string; secondary:string; stock:boolean }
interface LightsDraft { color:string; stock:boolean }
interface TrimDraft { trim:string } // "" = the record's own (factory) variant
interface Drafts { paint:PaintDraft; lights:LightsDraft; trim:TrimDraft }
type Keys = Record<CategoryId,string>;
const swatches = ["#FFCC00","#F2F3F5","#111114","#656A76","#AA172C","#F06624","#233F80","#38B8CB","#28705A","#71609C","#E0A4BB","#BAA281"];
const lightSwatches = ["#FF1E3C","#FF7A00","#FFCC00","#C8FF00","#3CFF6E","#00FFC8","#00D8FF","#2F6BFF","#7A3CFF","#C23CFF","#FF2BD6","#FF6E9C"];
const MIN_SATURATION = 0.25; // shared/vehicle_customization.lua lightsMinSaturation: a grey has no hue
const HEX = /^#[0-9a-f]{6}$/i;
const list = <T,>(value:unknown):T[] => Array.isArray(value) ? value as T[] : []; // Lua sends an empty list as {}
function hex(rgb?:RGB) { return rgb ? `#${[rgb.r,rgb.g,rgb.b].map(v=>v.toString(16).padStart(2,"0")).join("").toUpperCase()}` : "#FFCC00"; }
function channels(value:string):[number,number,number] { const c=(i:number)=>parseInt(value.slice(i,i+2),16)/255; return [c(1),c(3),c(5)]; }
function saturation(value:string) { if(!HEX.test(value))return 0; const c=channels(value),high=Math.max(...c); return high===0?0:(high-Math.min(...c))/high; }
function hue(value:string) {
  const [r,g,b]=channels(value),high=Math.max(r,g,b),d=high-Math.min(r,g,b);
  if(d===0)return 0;
  const h=high===r?((g-b)/d+6)%6:high===g?(b-r)/d+2:(r-g)/d+4;
  return h/6;
}
function hueHex(h:number) { // the full-brightness colour of a stored hue
  const f=(n:number)=>{const k=(n+h*6)%6;return Math.round(255*(1-Math.max(0,Math.min(k,4-k,1))));};
  return `#${[f(5),f(3),f(1)].map(v=>v.toString(16).padStart(2,"0")).join("").toUpperCase()}`;
}
function paintDraft(p?:Paint):PaintDraft {return {primary:hex(p?.primary),secondary:hex(p?.secondary),stock:!p?.applied};}
function lightsDraft(h?:number):LightsDraft {return typeof h==="number"?{color:hueHex(h),stock:false}:{color:"#00D8FF",stock:true};}
function trimDraft(appearance?:string):TrimDraft {return {trim:appearance??""};}
const keyOf = {
  paint:(d:PaintDraft)=>d.stock?"factory":`${d.primary.toUpperCase()}/${d.secondary.toUpperCase()}`,
  lights:(d:LightsDraft)=>d.stock?"factory":`hue:${Math.round(hue(d.color)*1000)%1000}`, // the engine keeps only the hue
  trim:(d:TrimDraft)=>d.trim||"factory",
};
const validOf = {
  paint:(d:PaintDraft)=>d.stock||(HEX.test(d.primary)&&HEX.test(d.secondary)),
  lights:(d:LightsDraft)=>d.stock||(HEX.test(d.color)&&saturation(d.color)>=MIN_SATURATION),
  trim:(_:TrimDraft)=>true,
};
const key=(c:CategoryId,d:Drafts)=>c==="paint"?keyOf.paint(d.paint):c==="lights"?keyOf.lights(d.lights):keyOf.trim(d.trim);
const valid=(c:CategoryId,d:Drafts)=>c==="paint"?validOf.paint(d.paint):c==="lights"?validOf.lights(d.lights):validOf.trim(d.trim);
function payload(c:CategoryId,d:Drafts) {
  if(c==="paint")return {category:"paint",...d.paint};
  if(c==="lights")return {category:"lights",color:d.lights.color,stock:d.lights.stock};
  return d.trim.trim?{category:"trim",trim:d.trim.trim}:{category:"trim",stock:true};
}
function draftsOf(v:{paint?:Paint;lightsHue?:number;appearance?:string}):Drafts {
  return {paint:paintDraft(v.paint),lights:lightsDraft(v.lightsHue),trim:trimDraft(v.appearance)};
}
function keysOf(d:Drafts):Keys {return {paint:keyOf.paint(d.paint),lights:keyOf.lights(d.lights),trim:keyOf.trim(d.trim)};}
const isKnown=(id:string):id is CategoryId=>(KNOWN as string[]).includes(id);
const TEXT:Record<CategoryId,{title:string;item:string;note:string;apply:string;eyebrow:string}> = {
  paint:{title:"Choose your finish",item:"Body paint",note:"Both color channels included.",apply:"Apply paint",eyebrow:"YOUR PAINT JOB"},
  lights:{title:"Choose your light tint",item:"Light tint",note:"Headlights and lamps share one hue.",apply:"Apply lights",eyebrow:"YOUR LIGHTS"},
  trim:{title:"Choose a factory trim",item:"Trim",note:"A factory variant of this model.",apply:"Apply trim",eyebrow:"YOUR TRIM"},
};
const ICONS:Record<CategoryId,typeof Palette> = {paint:Palette,lights:Lightbulb,trim:Car};
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
  const categories=list<Category>(session.categories);
  const offered=(id:string)=>categories.find(c=>c.id===id);
  const usable=(id:string)=>isKnown(id)&&offered(id)?.available!==false;
  const [active,setActive]=useState<CategoryId>(()=>(categories.map(c=>c.id).find(usable) as CategoryId|undefined)??"paint");
  const [drafts,setDrafts]=useState(()=>draftsOf(session.vehicle));
  const [savedKeys,setSavedKeys]=useState(()=>keysOf(draftsOf(session.vehicle)));
  const [money,setMoney]=useState(session.money);
  const [pay,setPay]=useState<"cash"|"bank">("bank");
  const [channel,setChannel]=useState<"primary"|"secondary">("primary");
  const [rotating,setRotating]=useState(true);
  const [pending,setPending]=useState<"preview"|"save">();
  const [queued,setQueued]=useState(false);
  const [feedback,setFeedback]=useState<{text:string;ok?:boolean}>();
  const request=useRef(session.nextRequest);
  const waiting=useRef<{request:number;operation:"preview"|"save";category:CategoryId;key:string}>();
  const queue=useRef(new Set<CategoryId>()); // categories whose latest draft still needs a preview
  const timer=useRef<number>();
  const lastSent=useRef(-1000);
  const shown=useRef<Keys>(savedKeys);  // what the car shows, per category
  const saved=useRef<Keys>(savedKeys);  // what is confirmed (paid), per category
  const latest=useRef(drafts);
  const root=useRef<HTMLDivElement>(null);
  const draft=drafts.paint;
  const selected=draft[channel];
  const amount=(value:number)=>`${money.currency} ${value.toLocaleString("en-US")}`;
  const priceOf=(c:CategoryId)=>session.prices?.[c]??offered(c)?.price??(c==="paint"?session.price:undefined);
  const price=priceOf(active);
  const changed=key(active,drafts)!==savedKeys[active];
  const purchasing=pending==="save";
  const affordable=price!==undefined&&money[pay]>=price;
  const issue=(operation:"preview"|"save",category:CategoryId,d:Drafts)=>{
    const seq=request.current;
    waiting.current={request:seq,operation,category,key:key(category,d)};lastSent.current=performance.now();setPending(operation);
    emit(PAGE,{session:session.session,operation,request:seq,...payload(category,d),...(operation==="save"?{pay}:{})});
  };
  const flush=()=>{
    if(waiting.current)return;
    for(const c of Array.from(queue.current))if(!valid(c,latest.current)||key(c,latest.current)===shown.current[c])queue.current.delete(c);
    const next=queue.current.values().next().value as CategoryId|undefined;
    if(!next){setQueued(false);return;}
    const delay=Math.max(0,230-(performance.now()-lastSent.current));
    if(delay>0){timer.current=window.setTimeout(flush,delay);return;}
    queue.current.delete(next);setQueued(queue.current.size>0);issue("preview",next,latest.current);
  };
  const update=<C extends CategoryId>(category:C,value:Drafts[C],immediate=false)=>{
    if(purchasing)return;
    latest.current={...latest.current,[category]:value};setDrafts(latest.current);setFeedback(undefined);
    window.clearTimeout(timer.current);
    if(valid(category,latest.current))queue.current.add(category);else queue.current.delete(category);
    setQueued(queue.current.size>0);
    timer.current=window.setTimeout(flush,immediate?0:180);
  };
  useEffect(()=>on<Response>(PAGE,p=>{
    const inflight=waiting.current;
    if(p.kind!=="response"||p.session!==session.session||!inflight||p.request!==inflight.request)return;
    request.current=p.nextRequest??inflight.request+1;waiting.current=undefined;setPending(undefined);
    if(p.money)setMoney(p.money);
    let next:Keys={...saved.current};
    if(p.confirmed)next=keysOf(draftsOf({paint:p.confirmed.paint??p.paint,lightsHue:p.confirmed.lightsHue,appearance:p.confirmed.appearance}));
    else if(p.paint)next.paint=keyOf.paint(paintDraft(p.paint));
    if(!p.confirmed&&!(p.paint&&inflight.category==="paint")&&p.ok&&inflight.operation==="save")next[inflight.category]=inflight.key;
    saved.current=next;setSavedKeys(next);
    // a refused preview or purchase puts that category back to its confirmed look
    shown.current={...shown.current,[inflight.category]:p.ok?inflight.key:next[inflight.category]};
    if(!p.ok||inflight.operation==="save")setFeedback({text:p.text??"Applied.",ok:p.ok});
    if(queue.current.size){window.clearTimeout(timer.current);timer.current=window.setTimeout(flush,0);}
  }),[session.session]);
  useEffect(()=>{root.current?.focus();return()=>window.clearTimeout(timer.current);},[]);
  // A control disabled while a request is pending drops the keyboard focus to <body>:
  // take it back, or Escape and the Tab trap stop working.
  useEffect(()=>{if(!pending&&!root.current?.contains(document.activeElement))root.current?.focus();},[pending]);
  useEffect(()=>{if(!pending)return;const t=window.setTimeout(()=>setFeedback({text:"Still waiting for confirmation. Close and reopen to check the outcome. Your purchase will not be sent twice."}),12000);return()=>clearTimeout(t);},[pending]);
  const camera=(command:string,enabled?:boolean)=>emit(PAGE,{session:session.session,operation:"camera",command,enabled});
  const choose=(value:string)=>update("paint",{...latest.current.paint,[channel]:value,stock:false},true);
  const tint=(value:string,immediate=true)=>update("lights",{color:value,stock:false},immediate);
  const purchase=()=>{
    const d=latest.current;
    if(waiting.current||queue.current.size||!usable(active)||!valid(active,d)||key(active,d)===saved.current[active]||price===undefined||money[pay]<price)return;
    setFeedback(undefined);issue("save",active,d);
  };
  const text=TEXT[active];
  const lights=drafts.lights;
  const lightHint=!lights.stock&&HEX.test(lights.color)&&saturation(lights.color)<MIN_SATURATION;
  const trims=list<Option>(offered("trim")?.options);
  return <div className="workshop o77-interactive" ref={root} tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="workshop-title" onKeyDown={e=>{
    if(e.key==="Escape"){e.preventDefault();e.stopPropagation();close();}
    if(e.key==="Tab"){
      const nodes=Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),[tabindex="0"]')??[]);
      if(e.shiftKey&&(document.activeElement===nodes[0]||document.activeElement===root.current)){e.preventDefault();nodes.at(-1)?.focus();}
      else if(!e.shiftKey&&(document.activeElement===nodes.at(-1)||document.activeElement===root.current)){e.preventDefault();nodes[0]?.focus();}
    }
  }}>
    <section className="workshop__panel" aria-label="Vehicle customization">
    <header className="workshop__header"><div><span className="workshop__eyebrow">OPEN // 77 <i>VEHICLE CUSTOMIZATION</i></span><h1 id="workshop-title">AUTO STUDIO<span>_</span></h1><p>{session.vehicle.label}<span>#{session.vehicle.id.slice(0,8).toUpperCase()}</span></p></div><button className="workshop__exit" aria-label="Close customization" onClick={close}><X size={17}/></button></header>
      <nav className="workshop__categories" aria-label="Customization categories">{categories.map((c,i)=>{
        const enabled=usable(c.id);const Icon=isKnown(c.id)?ICONS[c.id]:Palette;
        return <button key={c.id} aria-current={active===c.id?"page":undefined} disabled={!enabled||purchasing} onClick={()=>{if(isKnown(c.id)){setActive(c.id);setFeedback(undefined);}}}>
          <span className="workshop__category-icon"><Icon size={17}/></span>
          <strong>{c.label}<small className={enabled?undefined:"is-unavailable"}>{enabled?c.description:(c.reason??"Not available for this vehicle.")}</small></strong>
          <span>{String(i+1).padStart(2,"0")}</span></button>;})}</nav>
      <div className="workshop__editor">
        <div className="workshop__editor-title"><h2>{text.title}</h2><span>{pending==="preview"||queued?"UPDATING…":"LIVE PREVIEW"}</span></div>
        {active==="paint"&&<>
        <div className="workshop__channels" role="group" aria-label="Paint channel">{(["primary","secondary"] as const).map(c=><button key={c} aria-pressed={channel===c} onClick={()=>setChannel(c)}><i style={{background:draft[c]}}/>{c==="primary"?"Primary":"Secondary"}</button>)}</div>
        <div className="workshop__swatches" role="group" aria-label="Paint presets">{swatches.map(value=><button key={value} disabled={purchasing} aria-label={`Paint ${value}`} aria-pressed={!draft.stock&&selected.toUpperCase()===value} onClick={()=>choose(value)}><i style={{background:value}}/>{!draft.stock&&selected.toUpperCase()===value&&<Check size={17} style={{color:["#111114","#233F80","#AA172C","#28705A","#71609C"].includes(value)?"#fff":"#050506"}}/>}</button>)}</div>
        <label className="workshop__hex"><span>Custom color</span><div><input type="color" aria-label="Color picker" disabled={purchasing} value={HEX.test(selected)?selected:"#000000"} onChange={e=>choose(e.target.value.toUpperCase())}/><input aria-label="Hex color" maxLength={7} spellCheck={false} disabled={purchasing} value={selected} onChange={e=>update("paint",{...latest.current.paint,[channel]:e.target.value.toUpperCase(),stock:false})}/></div></label>
        <button className="workshop__factory" aria-pressed={draft.stock} disabled={purchasing} onClick={()=>update("paint",{...latest.current.paint,stock:true},true)}><RotateCcw size={14}/>Factory finish</button>
        </>}
        {active==="lights"&&<>
        <div className="workshop__swatches workshop__swatches--lights" role="group" aria-label="Light presets">{lightSwatches.map(value=>{
          const on=!lights.stock&&keyOf.lights({color:value,stock:false})===keyOf.lights(lights);
          return <button key={value} disabled={purchasing} aria-label={`Light ${value}`} aria-pressed={on} onClick={()=>tint(value)}><i style={{background:value,boxShadow:`0 0 12px ${value}80`}}/>{on&&<Check size={17} style={{color:"#050506"}}/>}</button>;})}</div>
        <label className="workshop__hex"><span>Custom tint</span><div><input type="color" aria-label="Light color picker" disabled={purchasing} value={HEX.test(lights.color)?lights.color:"#00D8FF"} onChange={e=>tint(e.target.value.toUpperCase())}/><input aria-label="Light hex color" maxLength={7} spellCheck={false} disabled={purchasing} value={lights.color} onChange={e=>tint(e.target.value.toUpperCase(),false)}/></div></label>
        <p className={`workshop__hint${lightHint?" is-error":""}`}>{lightHint?"Pick a more saturated color: a grey has no hue.":"Only the hue is kept: the car sets the brightness."}</p>
        <button className="workshop__factory" aria-pressed={lights.stock} disabled={purchasing} onClick={()=>update("lights",{...latest.current.lights,stock:true},true)}><RotateCcw size={14}/>Factory lights</button>
        </>}
        {active==="trim"&&<div className="workshop__trims" role="group" aria-label="Factory trims">
          <button aria-pressed={drafts.trim.trim===""} disabled={purchasing} onClick={()=>update("trim",{trim:""},true)}><RotateCcw size={14}/><span>Factory trim</span></button>
          {trims.map(t=><button key={t.id} aria-pressed={drafts.trim.trim===t.id} disabled={purchasing} onClick={()=>update("trim",{trim:t.id},true)}><Car size={14}/><span>{t.label}</span>{drafts.trim.trim===t.id&&<Check size={15}/>}</button>)}
        </div>}
      </div>
    <aside className="workshop__checkout" aria-label="Purchase" aria-busy={purchasing}>
      <span className="workshop__eyebrow">{text.eyebrow}</span><div className="workshop__price"><span>{text.item}</span><strong>{price===undefined?"—":amount(price)}</strong></div>
      <p>{text.note}</p>
      <div className="workshop__payment" role="group" aria-label="Payment method">{(["cash","bank"] as const).map(method=><button key={method} aria-pressed={pay===method} disabled={purchasing} onClick={()=>setPay(method)}><span>{method==="cash"?"Cash":"Bank"}</span><strong>{amount(money[method])}</strong></button>)}</div>
      {feedback&&<p className={`workshop__feedback${feedback.ok===false?" is-error":""}`} role="status">{feedback.text}</p>}
      {price!==undefined&&!affordable&&<p className="workshop__feedback is-error" role="status">Not enough {pay==="cash"?"cash":"money in your bank account"}.</p>}
      <Button className="workshop__apply" variant="primary" block disabled={!!pending||queued||!usable(active)||!valid(active,drafts)||!changed||!affordable} onClick={purchase}>{purchasing?"Processing payment…":`${text.apply} · ${price===undefined?"—":amount(price)}`}<ArrowRight size={16}/></Button>
      <small>{feedback?.ok?"Saved to this vehicle.":"Free preview. Pay only when you apply."}</small>
      <button className="workshop__leave" onClick={close}>Leave studio<kbd>ESC</kbd></button>
    </aside>
    </section>
    <div className="workshop__camera" aria-label="Vehicle camera controls"><button aria-label="Rotate left" onClick={()=>camera("left")}><ChevronLeft size={18}/></button><button aria-label={rotating?"Pause rotation":"Resume rotation"} aria-pressed={rotating} onClick={()=>{setRotating(!rotating);camera("rotate",!rotating);}}>{rotating?<Pause size={15}/>:<Play size={15}/>}<span>{rotating?"Auto orbit":"Orbit paused"}</span></button><button aria-label="Rotate right" onClick={()=>camera("right")}><ChevronRight size={18}/></button><i/><button aria-label="Zoom in" onClick={()=>camera("zoomIn")}><ZoomIn size={18}/></button><button aria-label="Zoom out" onClick={()=>camera("zoomOut")}><ZoomOut size={18}/></button></div>
  </div>;
}
