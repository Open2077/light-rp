import { useEffect, useRef, useState } from "react";
import { ArrowRight, Blinds, Car, Check, ChevronLeft, ChevronRight, Disc3, Gauge, Lightbulb, Lock, Palette, Pause, Play, RectangleHorizontal, RotateCcw, Sparkles, SprayCan, TriangleAlert, Wrench, X, ZoomIn, ZoomOut } from "lucide-react";
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
interface Scheme extends Option { main?:string; secondary?:string }
interface Rim extends Option { variants:Option[] }
interface BodyGroup extends Option { parts:Rim[] }
interface NeonOptions { colors:(Option&{color:string})[]; intensities:(Option&{value:number})[] }
interface PlateOptions { minLength:number; maxLength:number; charset?:string }
interface Stage { stage:number; label:string; price?:number; record?:string; available?:boolean; missing?:boolean }
interface PerformanceOptions { current:number; removal:number; stages:Stage[] }
interface Category { id:string; label:string; description:string; icon?:string; price?:number; available?:boolean; reason?:string; soon?:boolean; options?:unknown }
// The server's view of the confirmed (paid) look; phase-1 servers send paint/lightsHue/appearance only.
interface Confirmed { paint?:Paint; lightsHue?:number; appearance?:string; profile?:string; neon?:{color:string;intensity:string};
  rim?:{id:string;variant:string}; body?:Record<string,{part:string;variant:string}>; plate?:string; stage?:number }
interface Vehicle { id:string; vehicleId:number; label:string; model?:string; paint:Paint; lightsHue?:number; appearance?:string }
interface Session { kind:"open"; session:string; nextRequest:number; price:number; prices?:Record<string,number>; money:Wallet; vehicle:Vehicle; categories:Category[]; confirmed?:Confirmed }
interface Response { kind:"response"|"closed"|"unavailable"|"presentation"|"warning"|"camera";session:string;request?:number;nextRequest?:number;operation?:string;category?:string;ok?:boolean;text?:string;money?:Wallet;paint?:Paint;confirmed?:Confirmed;rotating?:boolean }
// Editors this page knows. Any other id the server lists stays greyed.
type CategoryId = "paint"|"livery"|"rims"|"body"|"neon"|"lights"|"trim"|"plate"|"performance";
const KNOWN:CategoryId[] = ["paint","livery","rims","body","neon","lights","trim","plate","performance"];
interface PaintDraft { primary:string; secondary:string; stock:boolean }
interface LightsDraft { color:string; stock:boolean }
interface TrimDraft { trim:string } // "" = the record's own (factory) variant
interface LiveryDraft { profile:string } // "" = plain paint
interface RimsDraft { rim:string; variant:string } // "" = factory rims
interface BodyDraft { parts:Partial<Record<string,{part:string;variant:string}>> } // a group left out = factory
interface NeonDraft { color:string; intensity:string; stock:boolean }
interface PlateDraft { plate:string }
interface PerformanceDraft { stage:number }
interface Drafts { paint:PaintDraft; livery:LiveryDraft; rims:RimsDraft; body:BodyDraft; neon:NeonDraft; lights:LightsDraft; trim:TrimDraft; plate:PlateDraft; performance:PerformanceDraft }
type Keys = Record<CategoryId,string>;
// What the drafts are checked against: the options the server offered.
interface Context { plate?:PlateOptions; performance?:PerformanceOptions }
const swatches = ["#FFCC00","#F2F3F5","#111114","#656A76","#AA172C","#F06624","#233F80","#38B8CB","#28705A","#71609C","#E0A4BB","#BAA281"];
const lightSwatches = ["#FF1E3C","#FF7A00","#FFCC00","#C8FF00","#3CFF6E","#00FFC8","#00D8FF","#2F6BFF","#7A3CFF","#C23CFF","#FF2BD6","#FF6E9C"];
const MIN_SATURATION = 0.25; // shared/vehicle_customization.lua lightsMinSaturation: a grey has no hue
const MIN_NEON = 0.2;        // shared/vehicle_customization.lua neon.minBrightness: too dark lights nothing
const HEX = /^#[0-9a-f]{6}$/i;
const list = <T,>(value:unknown):T[] => Array.isArray(value) ? value as T[] : []; // Lua sends an empty list as {}
const map = <T,>(value:unknown):Record<string,T> => value&&typeof value==="object"&&!Array.isArray(value) ? value as Record<string,T> : {};
function hex(rgb?:RGB) { return rgb ? `#${[rgb.r,rgb.g,rgb.b].map(v=>v.toString(16).padStart(2,"0")).join("").toUpperCase()}` : "#FFCC00"; }
function channels(value:string):[number,number,number] { const c=(i:number)=>parseInt(value.slice(i,i+2),16)/255; return [c(1),c(3),c(5)]; }
function saturation(value:string) { if(!HEX.test(value))return 0; const c=channels(value),high=Math.max(...c); return high===0?0:(high-Math.min(...c))/high; }
function brightness(value:string) { return HEX.test(value)?Math.max(...channels(value)):0; }
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
const plateText=(value:string)=>value.toUpperCase().replace(/\s+/g,"");
function paintDraft(p?:Paint):PaintDraft {return {primary:hex(p?.primary),secondary:hex(p?.secondary),stock:!p?.applied};}
function lightsDraft(h?:number):LightsDraft {return typeof h==="number"?{color:hueHex(h),stock:false}:{color:"#00D8FF",stock:true};}
function trimDraft(appearance?:string):TrimDraft {return {trim:appearance??""};}
const keyOf = {
  paint:(d:PaintDraft)=>d.stock?"factory":`${d.primary.toUpperCase()}/${d.secondary.toUpperCase()}`,
  livery:(d:LiveryDraft)=>d.profile||"plain",
  rims:(d:RimsDraft)=>d.rim?`${d.rim}/${d.variant}`:"factory",
  body:(d:BodyDraft)=>Object.entries(d.parts).flatMap(([g,v])=>v?.part?[`${g}=${v.part}/${v.variant}`]:[]).sort().join(",")||"factory",
  neon:(d:NeonDraft)=>d.stock?"off":`${d.color.toUpperCase()}@${d.intensity}`,
  lights:(d:LightsDraft)=>d.stock?"factory":`hue:${Math.round(hue(d.color)*1000)%1000}`, // the engine keeps only the hue
  trim:(d:TrimDraft)=>d.trim||"factory",
  plate:(d:PlateDraft)=>plateText(d.plate),
  performance:(d:PerformanceDraft)=>`stage:${d.stage}`,
};
const validOf = {
  paint:(d:PaintDraft)=>d.stock||(HEX.test(d.primary)&&HEX.test(d.secondary)),
  livery:(_:LiveryDraft)=>true,
  rims:(d:RimsDraft)=>!d.rim||!!d.variant,
  body:(d:BodyDraft)=>Object.values(d.parts).every(x=>!x||(!!x.part&&!!x.variant)),
  neon:(d:NeonDraft)=>d.stock||(HEX.test(d.color)&&brightness(d.color)>=MIN_NEON&&!!d.intensity),
  lights:(d:LightsDraft)=>d.stock||(HEX.test(d.color)&&saturation(d.color)>=MIN_SATURATION),
  trim:(_:TrimDraft)=>true,
  plate:(d:PlateDraft,x:Context)=>{const t=plateText(d.plate),o=x.plate;return !!o&&t.length>=o.minLength&&t.length<=o.maxLength&&/^[A-Z0-9]+$/.test(t);},
  performance:(d:PerformanceDraft,x:Context)=>{const s=list<Stage>(x.performance?.stages).find(s=>s.stage===d.stage);return !!s&&s.available!==false&&(s.stage===0||!!s.record);},
};
const key=(c:CategoryId,d:Drafts)=>(keyOf[c] as (v:unknown)=>string)(d[c]);
const valid=(c:CategoryId,d:Drafts,x:Context)=>(validOf[c] as (v:unknown,x:Context)=>boolean)(d[c],x);
// Performance is fitted on purchase only: the car is rebuilt, there is nothing to preview.
const previewable=(c:CategoryId)=>c!=="performance";
function payload(c:CategoryId,d:Drafts) {
  switch(c){
  case "paint":return {category:"paint",...d.paint};
  case "lights":return {category:"lights",color:d.lights.color,stock:d.lights.stock};
  case "trim":return d.trim.trim?{category:"trim",trim:d.trim.trim}:{category:"trim",stock:true};
  case "livery":return d.livery.profile?{category:"livery",profile:d.livery.profile}:{category:"livery",stock:true};
  case "rims":return d.rims.rim?{category:"rims",rim:d.rims.rim,variant:d.rims.variant}:{category:"rims",stock:true};
  case "body":return {category:"body",parts:Object.fromEntries(Object.entries(d.body.parts).filter(([,v])=>v?.part))};
  case "neon":return d.neon.stock?{category:"neon",stock:true}:{category:"neon",color:d.neon.color.toUpperCase(),intensity:d.neon.intensity};
  case "plate":return {category:"plate",plate:plateText(d.plate.plate)};
  case "performance":return {category:"performance",stage:d.performance.stage};
  }
}
function draftsOf(v:Confirmed):Drafts {
  const neon=v.neon&&HEX.test(v.neon.color)?{color:v.neon.color.toUpperCase(),intensity:v.neon.intensity||"medium",stock:false}:{color:"#00E5FF",intensity:"medium",stock:true};
  return {paint:paintDraft(v.paint),lights:lightsDraft(v.lightsHue),trim:trimDraft(v.appearance),livery:{profile:v.profile??""},
    rims:v.rim?.id?{rim:v.rim.id,variant:v.rim.variant??""}:{rim:"",variant:""},body:{parts:{...map<{part:string;variant:string}>(v.body)}},
    neon,plate:{plate:v.plate??""},performance:{stage:typeof v.stage==="number"?v.stage:0}};
}
function keysOf(d:Drafts):Keys {return Object.fromEntries(KNOWN.map(c=>[c,key(c,d)])) as Keys;}
const isKnown=(id:string):id is CategoryId=>(KNOWN as string[]).includes(id);
// Generic paint replaces a factory scheme and a scheme goes on the factory paint layer.
const LINKED:Partial<Record<CategoryId,CategoryId>> = {paint:"livery",livery:"paint"};
const TEXT:Record<CategoryId,{title:string;item:string;note:string;apply:string;eyebrow:string}> = {
  paint:{title:"Choose your finish",item:"Body paint",note:"Both color channels included.",apply:"Apply paint",eyebrow:"YOUR PAINT JOB"},
  livery:{title:"Choose a factory scheme",item:"Livery",note:"A two-tone scheme of this model. It replaces custom paint.",apply:"Apply livery",eyebrow:"YOUR LIVERY"},
  rims:{title:"Choose your rims",item:"Rims",note:"Every wheel, one finish.",apply:"Apply rims",eyebrow:"YOUR RIMS"},
  body:{title:"Build your body kit",item:"Body kit",note:"One part per group. Priced per group changed.",apply:"Apply body kit",eyebrow:"YOUR BODY KIT"},
  neon:{title:"Choose your neon",item:"Neon",note:"Under-chassis light: color and brightness.",apply:"Apply neon",eyebrow:"YOUR NEON"},
  lights:{title:"Choose your light tint",item:"Light tint",note:"Headlights and lamps share one hue.",apply:"Apply lights",eyebrow:"YOUR LIGHTS"},
  trim:{title:"Choose a factory trim",item:"Trim",note:"A factory variant of this model.",apply:"Apply trim",eyebrow:"YOUR TRIM"},
  plate:{title:"Register a plate",item:"Plate",note:"Unique in the city. Shown in your garage and the vehicle menu.",apply:"Register plate",eyebrow:"YOUR PLATE"},
  performance:{title:"Tune the engine",item:"Performance",note:"Fitted on purchase, no preview: the car is rebuilt with everyone out.",apply:"Fit stage",eyebrow:"YOUR TUNE"},
};
const ICONS:Record<string,typeof Palette> = {paint:Palette,livery:SprayCan,rims:Disc3,body:Wrench,neon:Sparkles,lights:Lightbulb,trim:Car,plate:RectangleHorizontal,windows:Blinds,performance:Gauge};
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
  const usable=(id:string):id is CategoryId=>isKnown(id)&&offered(id)?.available!==false;
  const context:Context={plate:offered("plate")?.options as PlateOptions|undefined,performance:offered("performance")?.options as PerformanceOptions|undefined};
  const initial=session.confirmed??{paint:session.vehicle.paint,lightsHue:session.vehicle.lightsHue,appearance:session.vehicle.appearance};
  const [active,setActive]=useState<string>(()=>categories.map(c=>c.id).find(usable)??"paint");
  const [drafts,setDrafts]=useState(()=>draftsOf(initial));
  const [savedKeys,setSavedKeys]=useState(()=>keysOf(draftsOf(initial)));
  const [confirmed,setConfirmed]=useState<Confirmed>(initial);
  const [money,setMoney]=useState(session.money);
  const [pay,setPay]=useState<"cash"|"bank">("bank");
  const [channel,setChannel]=useState<"primary"|"secondary">("primary");
  const [rotating,setRotating]=useState(true);
  const [pending,setPending]=useState<"preview"|"save">();
  const [queued,setQueued]=useState(false);
  const [feedback,setFeedback]=useState<{text:string;ok?:boolean;saved?:boolean}>();
  const [warning,setWarning]=useState<{category:string;text:string}>();
  const request=useRef(session.nextRequest);
  const waiting=useRef<{request:number;operation:"preview"|"save";category:CategoryId;key:string}>();
  const queue=useRef(new Set<CategoryId>()); // categories whose latest draft still needs a preview
  const timer=useRef<number>();
  const lastSent=useRef(-1000);
  const shown=useRef<Keys>(savedKeys);  // what the car shows, per category
  const saved=useRef<Keys>(savedKeys);  // what is confirmed (paid), per category
  const latest=useRef(drafts);
  const root=useRef<HTMLDivElement>(null);
  const editable=usable(active);
  const category=(editable?active:"paint") as CategoryId;
  const draft=drafts.paint;
  const selected=draft[channel];
  const amount=(value:number)=>`${money.currency} ${value.toLocaleString("en-US")}`;
  // Display only: the server quotes every purchase itself.
  const priceOf=(c:CategoryId):number|undefined=>{
    const flat=session.prices?.[c]??offered(c)?.price??(c==="paint"?session.price:undefined);
    if(c==="body"&&flat!==undefined){
      const want=drafts.body.parts,have=map<{part:string;variant:string}>(confirmed.body);
      const groups=list<BodyGroup>(offered("body")?.options).filter(g=>keyOf.body({parts:{[g.id]:want[g.id]}})!==keyOf.body({parts:{[g.id]:have[g.id]}})).length;
      return flat*Math.max(1,groups);
    }
    if(c==="performance"){
      const o=context.performance;if(!o)return undefined;
      const current=typeof confirmed.stage==="number"?confirmed.stage:o.current,target=drafts.performance.stage;
      if(target<=current)return o.removal;
      return list<Stage>(o.stages).filter(s=>s.stage>current&&s.stage<=target).reduce((sum,s)=>sum+(s.price??0),0);
    }
    return flat;
  };
  const price=editable?priceOf(category):undefined;
  const changed=editable&&key(category,drafts)!==savedKeys[category];
  const purchasing=pending==="save";
  const affordable=price!==undefined&&money[pay]>=price;
  const issue=(operation:"preview"|"save",c:CategoryId,d:Drafts)=>{
    const seq=request.current;
    waiting.current={request:seq,operation,category:c,key:key(c,d)};lastSent.current=performance.now();setPending(operation);
    emit(PAGE,{session:session.session,operation,request:seq,...payload(c,d),...(operation==="save"?{pay}:{})});
  };
  const flush=()=>{
    if(waiting.current)return;
    for(const c of Array.from(queue.current))if(!valid(c,latest.current,context)||key(c,latest.current)===shown.current[c])queue.current.delete(c);
    const next=queue.current.values().next().value as CategoryId|undefined;
    if(!next){setQueued(false);return;}
    const delay=Math.max(0,230-(performance.now()-lastSent.current));
    if(delay>0){timer.current=window.setTimeout(flush,delay);return;}
    queue.current.delete(next);setQueued(queue.current.size>0);issue("preview",next,latest.current);
  };
  const update=<C extends CategoryId>(c:C,value:Drafts[C],immediate=false)=>{
    if(purchasing)return;
    latest.current={...latest.current,[c]:value};setDrafts(latest.current);setFeedback(undefined);
    if(!previewable(c))return;
    window.clearTimeout(timer.current);
    if(valid(c,latest.current,context))queue.current.add(c);else queue.current.delete(c);
    setQueued(queue.current.size>0);
    timer.current=window.setTimeout(flush,immediate?0:180);
  };
  useEffect(()=>on<Response>(PAGE,p=>{
    if(p.session!==session.session)return;
    if(p.kind==="warning"){setWarning({category:p.category??"",text:p.text??""});return;}
    if(p.kind==="camera"){if(typeof p.rotating==="boolean")setRotating(p.rotating);return;}
    const inflight=waiting.current;
    if(p.kind!=="response"||!inflight||p.request!==inflight.request)return;
    request.current=p.nextRequest??inflight.request+1;waiting.current=undefined;setPending(undefined);
    if(p.money)setMoney(p.money);
    let next:Keys={...saved.current};
    if(p.confirmed){const view={...p.confirmed,paint:p.confirmed.paint??p.paint};next=keysOf(draftsOf(view));setConfirmed(view);}
    else if(p.paint)next.paint=keyOf.paint(paintDraft(p.paint));
    if(!p.confirmed&&!(p.paint&&inflight.category==="paint")&&p.ok&&inflight.operation==="save")next[inflight.category]=inflight.key;
    saved.current=next;setSavedKeys(next);
    // a refused preview or purchase puts that category (and its linked one) back to its confirmed look
    const linked=LINKED[inflight.category];
    shown.current={...shown.current,[inflight.category]:p.ok?inflight.key:next[inflight.category]};
    if(linked&&!p.ok)shown.current[linked]=next[linked];
    if(linked&&p.ok){
      // the server replaced the other one on the car: keep its draft in step with the car
      const d=latest.current;
      if(inflight.category==="paint"){shown.current.livery="plain";if(d.livery.profile){latest.current={...d,livery:{profile:""}};setDrafts(latest.current);}}
      else if(inflight.key!=="plain"){shown.current.paint="factory";if(!d.paint.stock){latest.current={...d,paint:{...d.paint,stock:true}};setDrafts(latest.current);}}
    }
    if(!p.ok||inflight.operation==="save"||inflight.category==="plate")setFeedback({text:p.text??"Applied.",ok:p.ok,saved:p.ok&&inflight.operation==="save"});
    if(inflight.category==="rims"||inflight.category==="body")setWarning(w=>w?.category===inflight.category?undefined:w);
    if(queue.current.size){window.clearTimeout(timer.current);timer.current=window.setTimeout(flush,0);}
  }),[session.session]);
  useEffect(()=>{root.current?.focus();return()=>window.clearTimeout(timer.current);},[]);
  // Each category frames the car its own way (client presets); others use the default shot.
  useEffect(()=>{emit(PAGE,{session:session.session,operation:"camera",command:"preset",category:active});},[active]);
  // A control disabled while a request is pending drops the keyboard focus to <body>:
  // take it back, or Escape and the Tab trap stop working.
  useEffect(()=>{if(!pending&&!root.current?.contains(document.activeElement))root.current?.focus();},[pending]);
  useEffect(()=>{if(!pending)return;const t=window.setTimeout(()=>setFeedback({text:"Still waiting for confirmation. Close and reopen to check the outcome. Your purchase will not be sent twice."}),12000);return()=>clearTimeout(t);},[pending]);
  const camera=(command:string,enabled?:boolean)=>emit(PAGE,{session:session.session,operation:"camera",command,enabled});
  const choose=(value:string)=>update("paint",{...latest.current.paint,[channel]:value,stock:false},true);
  const tint=(value:string,immediate=true)=>update("lights",{color:value,stock:false},immediate);
  const purchase=()=>{
    const d=latest.current;
    if(!editable||waiting.current||queue.current.size||!valid(category,d,context)||key(category,d)===saved.current[category]||price===undefined||money[pay]<price)return;
    setFeedback(undefined);issue("save",category,d);
  };
  const info=offered(active);
  const text=editable?TEXT[category]:{title:info?.label??"Unavailable",item:info?.label??"",note:info?.description??"",apply:info?.soon?"Coming soon":"Unavailable",eyebrow:""};
  const lights=drafts.lights;
  const lightHint=!lights.stock&&HEX.test(lights.color)&&saturation(lights.color)<MIN_SATURATION;
  const trims=list<Option>(offered("trim")?.options);
  const schemes=list<Scheme>(offered("livery")?.options);
  const rims=list<Rim>(offered("rims")?.options);
  const groups=list<BodyGroup>(offered("body")?.options);
  const neonOptions=(offered("neon")?.options??{}) as Partial<NeonOptions>;
  const neon=drafts.neon,neonHint=!neon.stock&&HEX.test(neon.color)&&brightness(neon.color)<MIN_NEON;
  const plate=drafts.plate,plateOptions=context.plate;
  const plateHint=plateOptions?`${plateOptions.minLength===plateOptions.maxLength?plateOptions.minLength:`${plateOptions.minLength} to ${plateOptions.maxLength}`} characters: capital letters A-Z and digits 0-9.`:"";
  const stages=list<Stage>(context.performance?.stages);
  const fittedStage=typeof confirmed.stage==="number"?confirmed.stage:context.performance?.current??0;
  const selectedRim=rims.find(r=>r.id===drafts.rims.rim);
  const compact=categories.length>4;
  const badge=(c:Category)=>c.soon?"Coming soon":"Unavailable";
  return <div className="workshop o77-interactive" ref={root} tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="workshop-title" onKeyDown={e=>{
    if(e.key==="Escape"){e.preventDefault();e.stopPropagation();close();}
    if(e.key==="Tab"){
      const nodes=Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),[tabindex="0"]')??[]);
      if(e.shiftKey&&(document.activeElement===nodes[0]||document.activeElement===root.current)){e.preventDefault();nodes.at(-1)?.focus();}
      else if(!e.shiftKey&&(document.activeElement===nodes.at(-1)||document.activeElement===root.current)){e.preventDefault();nodes[0]?.focus();}
    }
  }}>
    <section className="workshop__panel" aria-label="Vehicle customization">
    <header className="workshop__header"><div><span className="workshop__eyebrow">OPEN // 77 <i>VEHICLE CUSTOMIZATION</i></span><h1 id="workshop-title">AUTO STUDIO<span>_</span></h1><p>{session.vehicle.label}<span>{confirmed.plate?confirmed.plate:`#${session.vehicle.id.slice(0,8).toUpperCase()}`}{fittedStage>0?` · STAGE ${fittedStage}`:""}</span></p></div><button className="workshop__exit" aria-label="Close customization" onClick={close}><X size={17}/></button></header>
      <nav className={`workshop__categories${compact?" workshop__categories--grid":""}`} aria-label="Customization categories">{categories.map((c,i)=>{
        const enabled=usable(c.id);const Icon=ICONS[c.id]??Palette;
        // A greyed category stays selectable: its editor says why it is not sold here.
        return <button key={c.id} aria-current={active===c.id?"page":undefined} aria-disabled={enabled?undefined:true} className={enabled?undefined:"is-unavailable"} title={enabled?c.description:c.reason} disabled={purchasing} onClick={()=>{setActive(c.id);setFeedback(undefined);}}>
          <span className="workshop__category-icon">{enabled?<Icon size={compact?15:17}/>:<Lock size={compact?13:15}/>}</span>
          <strong>{c.label}<small className={enabled?undefined:"is-unavailable"}>{enabled?c.description:compact?badge(c):(c.reason??"Not available for this vehicle.")}</small></strong>
          {!compact&&<span>{String(i+1).padStart(2,"0")}</span>}</button>;})}</nav>
      <div className="workshop__editor">
        <div className="workshop__editor-title"><h2>{text.title}</h2><span>{!editable?"LOCKED":category==="performance"?"NO PREVIEW":pending==="preview"||queued?"UPDATING…":"LIVE PREVIEW"}</span></div>
        {warning&&warning.category===active&&<p className="workshop__warning" role="alert"><TriangleAlert size={14}/>{warning.text}</p>}
        {!editable&&<div className="workshop__locked"><Lock size={18}/><p>{info?.reason??"Not available for this vehicle."}</p></div>}
        {editable&&category==="paint"&&<>
        <div className="workshop__channels" role="group" aria-label="Paint channel">{(["primary","secondary"] as const).map(c=><button key={c} aria-pressed={channel===c} onClick={()=>setChannel(c)}><i style={{background:draft[c]}}/>{c==="primary"?"Primary":"Secondary"}</button>)}</div>
        <div className="workshop__swatches" role="group" aria-label="Paint presets">{swatches.map(value=><button key={value} disabled={purchasing} aria-label={`Paint ${value}`} aria-pressed={!draft.stock&&selected.toUpperCase()===value} onClick={()=>choose(value)}><i style={{background:value}}/>{!draft.stock&&selected.toUpperCase()===value&&<Check size={17} style={{color:["#111114","#233F80","#AA172C","#28705A","#71609C"].includes(value)?"#fff":"#050506"}}/>}</button>)}</div>
        <label className="workshop__hex"><span>Custom color</span><div><input type="color" aria-label="Color picker" disabled={purchasing} value={HEX.test(selected)?selected:"#000000"} onChange={e=>choose(e.target.value.toUpperCase())}/><input aria-label="Hex color" maxLength={7} spellCheck={false} disabled={purchasing} value={selected} onChange={e=>update("paint",{...latest.current.paint,[channel]:e.target.value.toUpperCase(),stock:false})}/></div></label>
        <button className="workshop__factory" aria-pressed={draft.stock} disabled={purchasing} onClick={()=>update("paint",{...latest.current.paint,stock:true},true)}><RotateCcw size={14}/>Factory finish</button>
        </>}
        {editable&&category==="livery"&&<div className="workshop__trims" role="group" aria-label="Factory schemes">
          <button aria-pressed={drafts.livery.profile===""} disabled={purchasing} onClick={()=>update("livery",{profile:""},true)}><RotateCcw size={14}/><span>Plain paint</span></button>
          {schemes.map(s=><button key={s.id} aria-pressed={drafts.livery.profile===s.id} disabled={purchasing} onClick={()=>update("livery",{profile:s.id},true)}>
            <i className="workshop__scheme" aria-hidden="true" style={{background:`linear-gradient(135deg,${s.main??"#656A76"} 50%,${s.secondary??s.main??"#111114"} 50%)`}}/><span>{s.label}</span>{drafts.livery.profile===s.id&&<Check size={15}/>}</button>)}
        </div>}
        {editable&&category==="rims"&&<>
          <div className="workshop__tiles" role="group" aria-label="Rims">
            <button aria-pressed={drafts.rims.rim===""} disabled={purchasing} onClick={()=>update("rims",{rim:"",variant:""},true)}><RotateCcw size={14}/><span>Factory rims</span></button>
            {rims.map(r=><button key={r.id} aria-pressed={drafts.rims.rim===r.id} disabled={purchasing} onClick={()=>update("rims",{rim:r.id,variant:r.variants.some(v=>v.id===drafts.rims.variant)?drafts.rims.variant:list<Option>(r.variants)[0]?.id??""},true)}><Disc3 size={14}/><span>{r.label}</span></button>)}
          </div>
          {selectedRim&&<div className="workshop__finishes" role="group" aria-label="Rim finish">{list<Option>(selectedRim.variants).map(v=><button key={v.id} aria-pressed={drafts.rims.variant===v.id} disabled={purchasing} onClick={()=>update("rims",{rim:selectedRim.id,variant:v.id},true)}>{v.label}</button>)}</div>}
        </>}
        {editable&&category==="body"&&<div className="workshop__groups">{groups.map(g=>{
          const held=drafts.body.parts[g.id],part=list<Rim>(g.parts).find(x=>x.id===held?.part);
          const set=(value?:{part:string;variant:string})=>{const parts={...latest.current.body.parts};if(value)parts[g.id]=value;else delete parts[g.id];update("body",{parts},true);};
          return <div key={g.id} className="workshop__group"><h3>{g.label}</h3>
            <div className="workshop__tiles" role="group" aria-label={g.label}>
              <button aria-pressed={!part} disabled={purchasing} onClick={()=>set()}><RotateCcw size={14}/><span>None</span></button>
              {list<Rim>(g.parts).map(x=><button key={x.id} aria-pressed={part?.id===x.id} disabled={purchasing} onClick={()=>set({part:x.id,variant:list<Option>(x.variants).some(v=>v.id===held?.variant)?held!.variant:list<Option>(x.variants)[0]?.id??""})}><span>{x.label}</span></button>)}
            </div>
            {part&&<div className="workshop__finishes" role="group" aria-label={`${g.label} finish`}>{list<Option>(part.variants).map(v=><button key={v.id} aria-pressed={held?.variant===v.id} disabled={purchasing} onClick={()=>set({part:part.id,variant:v.id})}>{v.label}</button>)}</div>}
          </div>;})}</div>}
        {editable&&category==="neon"&&<>
          <div className="workshop__swatches workshop__swatches--lights" role="group" aria-label="Neon presets">{list<Option&{color:string}>(neonOptions.colors).map(c=>{
            const on=!neon.stock&&neon.color.toUpperCase()===c.color.toUpperCase();
            return <button key={c.id} disabled={purchasing} aria-label={`Neon ${c.label}`} aria-pressed={on} onClick={()=>update("neon",{...latest.current.neon,color:c.color.toUpperCase(),stock:false},true)}><i style={{background:c.color,boxShadow:`0 0 12px ${c.color}80`}}/>{on&&<Check size={17} style={{color:"#050506"}}/>}</button>;})}</div>
          <label className="workshop__hex"><span>Custom neon</span><div><input type="color" aria-label="Neon color picker" disabled={purchasing} value={HEX.test(neon.color)?neon.color:"#00E5FF"} onChange={e=>update("neon",{...latest.current.neon,color:e.target.value.toUpperCase(),stock:false},true)}/><input aria-label="Neon hex color" maxLength={7} spellCheck={false} disabled={purchasing} value={neon.color} onChange={e=>update("neon",{...latest.current.neon,color:e.target.value.toUpperCase(),stock:false})}/></div></label>
          <div className="workshop__finishes" role="group" aria-label="Neon brightness">{list<Option&{value:number}>(neonOptions.intensities).map(s=><button key={s.id} aria-pressed={!neon.stock&&neon.intensity===s.id} disabled={purchasing} onClick={()=>update("neon",{...latest.current.neon,intensity:s.id,stock:false},true)}>{s.label}</button>)}</div>
          <p className={`workshop__hint${neonHint?" is-error":""}`}>{neonHint?"This color is too dark to light anything.":"Lit around the car for every player."}</p>
          <button className="workshop__factory" aria-pressed={neon.stock} disabled={purchasing} onClick={()=>update("neon",{...latest.current.neon,stock:true},true)}><RotateCcw size={14}/>No neon</button>
        </>}
        {editable&&category==="lights"&&<>
        <div className="workshop__swatches workshop__swatches--lights" role="group" aria-label="Light presets">{lightSwatches.map(value=>{
          const on=!lights.stock&&keyOf.lights({color:value,stock:false})===keyOf.lights(lights);
          return <button key={value} disabled={purchasing} aria-label={`Light ${value}`} aria-pressed={on} onClick={()=>tint(value)}><i style={{background:value,boxShadow:`0 0 12px ${value}80`}}/>{on&&<Check size={17} style={{color:"#050506"}}/>}</button>;})}</div>
        <label className="workshop__hex"><span>Custom tint</span><div><input type="color" aria-label="Light color picker" disabled={purchasing} value={HEX.test(lights.color)?lights.color:"#00D8FF"} onChange={e=>tint(e.target.value.toUpperCase())}/><input aria-label="Light hex color" maxLength={7} spellCheck={false} disabled={purchasing} value={lights.color} onChange={e=>tint(e.target.value.toUpperCase(),false)}/></div></label>
        <p className={`workshop__hint${lightHint?" is-error":""}`}>{lightHint?"Pick a more saturated color: a grey has no hue.":"Only the hue is kept: the car sets the brightness."}</p>
        <button className="workshop__factory" aria-pressed={lights.stock} disabled={purchasing} onClick={()=>update("lights",{...latest.current.lights,stock:true},true)}><RotateCcw size={14}/>Factory lights</button>
        </>}
        {editable&&category==="trim"&&<div className="workshop__trims" role="group" aria-label="Factory trims">
          <button aria-pressed={drafts.trim.trim===""} disabled={purchasing} onClick={()=>update("trim",{trim:""},true)}><RotateCcw size={14}/><span>Factory trim</span></button>
          {trims.map(t=><button key={t.id} aria-pressed={drafts.trim.trim===t.id} disabled={purchasing} onClick={()=>update("trim",{trim:t.id},true)}><Car size={14}/><span>{t.label}</span>{drafts.trim.trim===t.id&&<Check size={15}/>}</button>)}
        </div>}
        {editable&&category==="plate"&&<>
          <div className="workshop__plate" aria-hidden="true"><span>NIGHT CITY</span><strong>{plateText(plate.plate)||"·······"}</strong></div>
          <label className="workshop__hex"><span>Plate number</span><div><input aria-label="Plate number" maxLength={(plateOptions?.maxLength??8)+4} spellCheck={false} autoComplete="off" disabled={purchasing} value={plate.plate} onChange={e=>update("plate",{plate:e.target.value.toUpperCase()})}/></div></label>
          <p className={`workshop__hint${plate.plate&&!valid("plate",drafts,context)?" is-error":""}`}>{plateHint}</p>
        </>}
        {editable&&category==="performance"&&<div className="workshop__trims" role="group" aria-label="Performance stages">
          {stages.map(s=><button key={s.stage} aria-pressed={drafts.performance.stage===s.stage} disabled={purchasing||s.available===false} onClick={()=>update("performance",{stage:s.stage})}>
            <Gauge size={14}/><span>{s.label}{s.stage===fittedStage&&<small> · fitted</small>}{s.missing&&<small> · not in your game</small>}</span>{s.stage>0&&s.price!==undefined&&<em>{amount(s.price)}</em>}{drafts.performance.stage===s.stage&&<Check size={15}/>}</button>)}
        </div>}
      </div>
    <aside className="workshop__checkout" aria-label="Purchase" aria-busy={purchasing}>
      <span className="workshop__eyebrow">{text.eyebrow}</span><div className="workshop__price"><span>{text.item}</span><strong>{price===undefined?"—":amount(price)}</strong></div>
      <p>{text.note}</p>
      <div className="workshop__payment" role="group" aria-label="Payment method">{(["cash","bank"] as const).map(method=><button key={method} aria-pressed={pay===method} disabled={purchasing} onClick={()=>setPay(method)}><span>{method==="cash"?"Cash":"Bank"}</span><strong>{amount(money[method])}</strong></button>)}</div>
      {feedback&&<p className={`workshop__feedback${feedback.ok===false?" is-error":""}`} role="status">{feedback.text}</p>}
      {editable&&price!==undefined&&!affordable&&<p className="workshop__feedback is-error" role="status">Not enough {pay==="cash"?"cash":"money in your bank account"}.</p>}
      <Button className="workshop__apply" variant="primary" block disabled={!editable||!!pending||queued||!valid(category,drafts,context)||!changed||!affordable} onClick={purchase}>{purchasing?"Processing payment…":`${text.apply} · ${price===undefined?"—":amount(price)}`}<ArrowRight size={16}/></Button>
      <small>{feedback?.saved?"Saved to this vehicle.":editable&&category==="performance"?"Paid on fitting. Keep everyone out of the car.":"Free preview. Pay only when you apply."}</small>
      <button className="workshop__leave" onClick={close}>Leave studio<kbd>ESC</kbd></button>
    </aside>
    </section>
    <div className="workshop__camera" aria-label="Vehicle camera controls"><button aria-label="Rotate left" onClick={()=>camera("left")}><ChevronLeft size={18}/></button><button aria-label={rotating?"Pause rotation":"Resume rotation"} aria-pressed={rotating} onClick={()=>{setRotating(!rotating);camera("rotate",!rotating);}}>{rotating?<Pause size={15}/>:<Play size={15}/>}<span>{rotating?"Auto orbit":"Orbit paused"}</span></button><button aria-label="Rotate right" onClick={()=>camera("right")}><ChevronRight size={18}/></button><i/><button aria-label="Zoom in" onClick={()=>camera("zoomIn")}><ZoomIn size={18}/></button><button aria-label="Zoom out" onClick={()=>camera("zoomOut")}><ZoomOut size={18}/></button></div>
  </div>;
}
