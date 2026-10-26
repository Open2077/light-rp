import { Fragment, useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { useStore } from "@/state/store";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { RageMenu, isPickable, type RageMenuItem } from "@/design/components";
import { request, key, list } from "@/features/support/api";
import { coordinates, credits, expiry, type Home, type HousingResult, type HousingState } from "./model";
import { HousingForm, interiorForm, propertyForm, type FormSpec } from "./HousingForms";
import "@/features/support/support.css";
import "./housing.css";

type Page={kind:"root"|"nearby"|"mine"|"available"|"properties"|"property"|"templates"|"template"|"recovery"|"keys"|"people"|"assign"|"chooseTemplate";id?:string|number;selected?:string;page?:number;query?:string};
type Entry=RageMenuItem & {run?:()=>void};
const entry=(id:string,text:string,run:()=>void,extra:Partial<Entry>={}):Entry=>({id,text,run,...extra});

export function HousingDialog() {
  const dialog=useStore(s=>s.dialog),visible=dialog?.kind==="housing";
  const close=useCallback(()=>{if(useStore.getState().dialog?.kind==="housing")useStore.getState().closeDialog();},[]);
  useEffect(()=>{
    if(!visible)return;
    emit(PAGE_EVENTS.dialogState,{kind:"housing",open:true});
    const off=on<{kind?:string}>(PAGE_EVENTS.dialogClose,p=>{if(!p.kind||p.kind==="housing")close();});
    return()=>{off();emit(PAGE_EVENTS.dialogState,{kind:"housing",open:false});emit(PAGE_EVENTS.support,{operation:"input",mode:"closed"});};
  },[visible,close]);
  if(dialog?.kind!=="housing")return null;
  return <HousingMenu key={String(dialog.admin)} admin={dialog.admin} close={close}/>;
}

function HousingMenu({admin,close}:{admin:boolean;close:()=>void}) {
  const [state,setState]=useState<HousingState>(),[stack,setStack]=useState<Page[]>([{kind:"root"}]);
  const [form,setForm]=useState<(FormSpec&{mutation:string})|null>(null),[busy,setBusy]=useState(false);
  const [error,setError]=useState(""),[feedback,setFeedback]=useState("");
  const menu=useRef<HTMLDivElement>(null),panel=useRef<HTMLElement>(null),working=useRef(false),live=useRef(true),reading=useRef<string>();
  const top=stack[stack.length-1]!;
  const querySignature=JSON.stringify([admin,top.kind,top.id,top.page,top.query]);
  const expectedQuery=useRef(querySignature);expectedQuery.current=querySignature;
  const [loadedQuery,setLoadedQuery]=useState("");
  const refresh=useCallback(async()=>{
    if(reading.current===querySignature)return;
    reading.current=querySignature;
    try{const v=await request<HousingState>("housing",{action:"browse",admin,view:top.kind,id:top.id,page:top.page??1,search:top.query??""});if(live.current&&expectedQuery.current===querySignature){setState(v);setLoadedQuery(querySignature);}}
    catch(e){if(live.current&&expectedQuery.current===querySignature)setError((e as Error).message);}
    finally{if(reading.current===querySignature)reading.current=undefined;}
  },[admin,top.kind,top.id,top.page,top.query,querySignature]);
  useEffect(()=>{live.current=true;void refresh();const timer=setInterval(()=>{if(!working.current&&document.visibilityState!=="hidden")void refresh();},10000);return()=>{live.current=false;clearInterval(timer);};},[refresh]);
  useEffect(()=>{emit(PAGE_EVENTS.support,{operation:"input",mode:form?"form":"menu"});if(!form)menu.current?.focus();},[!!form]);
  const push=(page:Page)=>{setError("");setFeedback("");setStack(s=>[...s,page]);};
  const back=()=>{if(busy)return;if(form){setForm(null);return;}setError("");if(stack.length>1)setStack(s=>s.slice(0,-1));else close();};
  useEffect(()=>{
    const handler=(e:KeyboardEvent)=>{
      if(form&&e.key==="Escape"){e.preventDefault();if(!working.current)setForm(null);}
      else if(form&&e.key==="Tab"){
        const nodes=[...(panel.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled)')||[])];
        if(e.shiftKey&&document.activeElement===nodes[0]){e.preventDefault();nodes.at(-1)?.focus();}
        else if(!e.shiftKey&&document.activeElement===nodes.at(-1)){e.preventDefault();nodes[0]?.focus();}
      }else if(!form&&(e.key==="PageUp"||e.key==="PageDown")){e.preventDefault();panel.current?.scrollBy(0,(e.key==="PageDown"?1:-1)*250);}
    };
    window.addEventListener("keydown",handler);return()=>window.removeEventListener("keydown",handler);
  },[form]);
  const edit=(spec:FormSpec)=>{setError("");setForm({...spec,mutation:key()});};
  const confirm=(title:string,description:string,action:string,payload:Record<string,unknown>,danger=false)=>edit({title,description,action,payload,danger,submit:"Confirm",fields:[]});
  const run=async(action:string,payload:Record<string,unknown>={})=>{
    if(working.current)return;
    working.current=true;setBusy(true);setError("");setFeedback("");
    try{
      const result=await request<HousingResult>("housing",{...payload,action});
      if(!live.current)return;
      setForm(null);setFeedback(result.message);
      if(result.close){close();return;}
      if(action==="admin.template.create"&&result.id)setStack([{kind:"root"},{kind:"templates"},{kind:"template",id:result.id}]);
      if(action==="admin.property.create"&&result.id)setStack([{kind:"root"},{kind:"properties"},{kind:"property",id:result.id}]);
      if(action.endsWith(".delete"))setStack(s=>s.slice(0,-1));
      if(action==="key.add"||action==="admin.assign")setStack(s=>s.slice(0,-1));
    }catch(e){if(live.current)setError((e as Error).message);}
    finally{if(live.current)await refresh();working.current=false;if(live.current)setBusy(false);}
  };
  const homes=list(state?.properties),templates=list(state?.templates),home=homes.find(h=>h.id===top.id),interior=templates.find(t=>t.id===top.id);
  let title=admin?"HOUSING ADMIN":"MY HOMES",subtitle="NIGHT CITY HOUSING",entries:Entry[]=[],details:ReactNode=null;
  const empty=(text:string):Entry=>({id:"empty",text,disabled:true});
  const homeItem=(h:Home)=>entry(`home:${h.id}`,h.label,()=>push({kind:"property",id:h.id}),{type:"submenu",meta:h.owned?"YOURS":h.hasKey?"KEY":h.available?"AVAILABLE":"OCCUPIED",description:`${h.kind} · ${h.templateLabel} · ${h.near?"You are at the entrance":"Visit the entrance to enter or sign"}`});
  if(!state||loadedQuery!==querySignature)entries=[empty("Loading housing…")];
  else if(top.kind==="root"){
    if(state.inside)entries.push(entry("leave",`Leave ${state.inside.label}`,()=>{void run("leave");},{description:"Use the interior exit. After a failed transfer, this also returns you outside.",disabled:["entering","leaving"].includes(state.inside.phase)}));
    if(admin)entries.push(entry("templates","Interior templates",()=>push({kind:"templates"}),{type:"submenu",meta:String(state.counts?.templates??templates.length)}),entry("properties","Dwellings",()=>push({kind:"properties"}),{type:"submenu",meta:String(state.counts?.properties??homes.length)}));
    else entries.push(entry("nearby","At this entrance",()=>push({kind:"nearby"}),{type:"submenu",meta:String(state.counts?.nearby??homes.filter(h=>h.near).length)}),entry("mine","My homes & shared keys",()=>push({kind:"mine"}),{type:"submenu",meta:String(state.counts?.mine??homes.filter(h=>h.owned||h.hasKey).length)}),entry("available","Homes for sale or rent",()=>push({kind:"available"}),{type:"submenu"}),entry("recovery","Recover stored belongings",()=>push({kind:"recovery"}),{type:"submenu",meta:String(state.counts?.recovery??list(state.recovery).length),description:"After a tenancy ends, collect its remaining belongings at the former exterior entrance."}));
  }else if(["nearby","mine","available","properties"].includes(top.kind)){
    title=({nearby:"AT THIS ENTRANCE",mine:"MY HOMES",available:"AVAILABLE HOMES",properties:"DWELLINGS"} as Record<string,string>)[top.kind]!;
    const found=homes.filter(h=>top.kind==="properties"||(top.kind==="nearby"&&h.near)||(top.kind==="mine"&&(h.owned||h.hasKey))||(top.kind==="available"&&h.available));
    entries=found.map(homeItem);
    if(!entries.length)entries.push(empty("No matching dwellings"));
    if(top.kind==="properties")entries.unshift(entry("create","Create dwelling here",()=>push({kind:"chooseTemplate"}),{description:"Capture this exterior entrance and choose a completed interior template."}));
  }else if(top.kind==="property"&&home){
    title=home.label;subtitle=`${home.kind.toUpperCase()} #${home.id}`;
    const payload={id:home.id,revision:home.revision};
    details=<HomeDetails home={home}/>;
    if(admin){
      entries=[entry("edit","Edit dwelling",()=>push({kind:"chooseTemplate",id:home.id})),entry("capture","Move exterior entrance here",()=>confirm("Move entrance",`Capture your current position as the exterior entrance of ${home.label}. The dwelling must be vacant.`,"admin.property.capture",payload),{disabled:!!home.tenant}),
        entry("assign","Assign a resident",()=>push({kind:"assign",id:home.id}),{disabled:!!home.tenant||!home.enabled,type:"submenu"}),
        entry("revoke","Revoke current tenancy",()=>edit({title:"Revoke tenancy",description:"The resident is returned outside. Their belongings remain recoverable. This does not issue a refund.",submit:"Revoke tenancy",danger:true,action:"admin.revoke",payload,fields:[{name:"reason",label:"Reason",type:"textarea",maxLength:160}]}),{danger:true,disabled:!home.tenant}),
        entry("delete","Delete dwelling",()=>confirm("Delete dwelling",`Remove ${home.label} and its entrance. Archived belongings remain recoverable. The dwelling must be vacant and empty.`,"admin.property.delete",payload,true),{danger:true,disabled:!!home.tenant})];
    }else{
      if(state?.inside?.propertyId===home.id)entries.push(entry("stash","Open home storage",()=>{void run("stash",payload);},{description:"Stand near the storage point inside your home."}),entry("leave","Leave home",()=>{void run("leave");}));
      else{
        entries.push(entry("enter","Enter home",()=>{void run("enter",payload);},{disabled:!home.near||!home.enabled||home.available||(home.locked&&!home.hasKey),description:home.locked?"The door is locked. You need a key.":"The resident has unlocked the door for visitors."}));
        entries.push(entry("gps","Set GPS to the entrance",()=>{emit(PAGE_EVENTS.action,{type:"homes.track",id:home.id,entrance:home.entrance,label:home.label});setError("");setFeedback("GPS set: follow the route to the entrance.");},{icon:"map-pin",disabled:home.near,description:home.near?"You are at the entrance.":"Draws the route to this home's street door on your map and minimap."}));
      }
      if(home.available){
        if(home.price>0)entries.push(entry("buy","Buy this home",()=>confirm("Buy home",`${credits(home.price)} will be debited from your bank for ${home.label}. Its resale value is ${Math.round((state?.resaleFraction??.5)*100)}% of the price paid.`,"buy",payload),{meta:credits(home.price),disabled:!home.near}));
        if(home.rent>0)entries.push(entry("rent",`Rent for ${home.rentDays} days`,()=>confirm("Rent home",`Pay ${credits(home.rent)} from your bank for ${home.rentDays} real days. Renew manually before expiry; there is no automatic debit.`,"rent",payload),{meta:credits(home.rent),disabled:!home.near}));
      }
      if(home.owned){
        entries.push(entry("lock",home.locked?"Unlock for visitors":"Lock the entrance",()=>{void run("lock",{...payload,locked:!home.locked});},{description:"Residents and key holders can still enter a locked home. Visitors cannot access storage."}),entry("keys","Manage spare keys",()=>push({kind:"keys",id:home.id}),{type:"submenu",meta:String(list(home.keys).length)}));
        if(home.mode==="rent")entries.push(entry("renew",`Renew ${home.rentDays} days`,()=>confirm("Renew lease",`Pay ${credits(home.rent)} from your bank to add ${home.rentDays} days to the current expiry (${expiry(home.expires)}).`,"renew",payload),{meta:credits(home.rent),disabled:home.rent<=0}));
        if(home.mode==="purchase")entries.push(entry("sell","Sell home back",()=>confirm("Sell home",`Receive ${credits(home.resale)} in your bank. Everyone leaves and all keys are revoked. Stored belongings remain recoverable at the former entrance.`,"sell",payload,true),{danger:true,meta:credits(home.resale)}));
        else entries.push(entry("release","Give up this home",()=>confirm("End tenancy","No refund is issued. Everyone leaves and all spare keys are revoked. You can recover remaining belongings at the exterior entrance.","release",payload,true),{danger:true}));
      }
    }
  }else if(top.kind==="chooseTemplate"){
    title="CHOOSE INTERIOR";subtitle=home?`EDIT ${home.label}`:"NEW DWELLING";
    entries=templates.filter(t=>t.ready).map(t=>entry(t.id,t.label,()=>edit(propertyForm([t],home?{...home,templateId:t.id}:undefined,state?.defaults?.rentDays)),{description:`${t.slots} slots · ${t.weight} kg`,type:"submenu"}));
    if(!entries.length)entries=[empty("No completed interior templates")];
  }else if(top.kind==="templates"){
    title="INTERIOR TEMPLATES";
    entries=[entry("new","Create interior template",()=>edit(interiorForm(undefined,state?.defaults))),...templates.map(t=>entry(t.id,t.label,()=>push({kind:"template",id:t.id}),{type:"submenu",meta:t.ready?"READY":"INCOMPLETE"}))];
  }else if(top.kind==="template"&&interior){
    title=interior.label;subtitle="INTERIOR TEMPLATE";
    const payload={id:interior.id,revision:interior.revision};
    entries=[entry("edit","Name & storage capacity",()=>edit(interiorForm(interior)))];
    for(const point of ["spawn","exit","stash","wardrobe"] as const)entries.push(entry(point,`Capture ${point==="stash"?"storage":point} here`,()=>{void run("admin.template.capture",{...payload,point});},{meta:interior.points[point]?"SET":"MISSING",description:`${point==="wardrobe"?"Optional":"Required"} · ${coordinates(interior.points[point])}. Captures your actual position and heading.`}));
    if(interior.points.wardrobe)entries.push(entry("clear-wardrobe","Remove wardrobe point",()=>{void run("admin.template.capture",{...payload,point:"wardrobe",clear:true});}));
    entries.push(entry("preview","Preview private instance",()=>{void run("admin.template.preview",payload);},{disabled:!interior.points.spawn,description:"Starts a private preview. Leave it from the root of this menu to return to your original position."}),entry("delete","Delete template",()=>confirm("Delete template",`Remove ${interior.label}. First remove or reassign any dwellings using this interior.`,"admin.template.delete",payload,true),{danger:true}));
    details=<div className="rp-support__record"><small>INTERIOR AUTHORING</small><h2>{interior.label}</h2><p>Walk to each point and capture it. You keep movement and camera controls while this menu is open.</p><dl>{Object.entries(interior.points).map(([name,p])=><Fragment key={name}><dt>{name}</dt><dd>{coordinates(p)}</dd></Fragment>)}<dt>Storage</dt><dd>{interior.slots} slots · {interior.weight} kg</dd></dl><p>Spawn, exit and storage are required. Points must be within {state.maxInteriorRadius??200} metres of the spawn. Every dwelling using this template has a separate instance.</p></div>;
  }else if(top.kind==="keys"&&home){
    title="SPARE KEYS";subtitle=home.label;
    entries=[entry("give","Give a key to a player",()=>push({kind:"people",id:home.id}),{type:"submenu"}),...list(home.keys).map(k=>entry(`${k.identifier}:${k.key}`,`Revoke: ${k.name}`,()=>confirm("Revoke key",`Remove ${k.name}'s access to the locked entrance and storage.`,"key.remove",{id:home.id,revision:home.revision,identifier:k.identifier,character:k.key},true),{danger:true}))];
  }else if((top.kind==="people"||top.kind==="assign")&&home){
    title=top.kind==="assign"?"ASSIGN RESIDENT":"GIVE A KEY";subtitle=home.label;
    const assigning=top.kind==="assign";
    entries=list(state?.players).map(p=>entry(`${p.identifier}:${p.key}`,p.name,()=>confirm(assigning?"Assign home":"Give spare key",assigning?`Assign ${home.label} to ${p.name} for free, without an expiry date.`:`Give ${p.name} access to ${home.label}, its storage and wardrobe.`,assigning?"admin.assign":"key.add",{id:home.id,revision:home.revision,player:p.id,identifier:p.identifier,character:p.key}),{meta:`#${p.id}`}));
    if(assigning)entries.push(entry("offline","Assign an offline character",()=>edit({title:"Assign offline resident",description:"Enter the Open77 player identifier and the saved character key. The server verifies the character exists and is active.",submit:"Assign for free",action:"admin.assign",payload:{id:home.id,revision:home.revision},fields:[{name:"identifier",label:"Player identifier",maxLength:128},{name:"character",label:"Character key",maxLength:64}]})));
    if(!entries.length)entries.push(empty("No connected characters"));
  }else if(top.kind==="recovery"){
    title="STORED BELONGINGS";entries=list(state?.recovery).map(r=>entry(r.id,r.label,()=>{void run("recover",{contract:r.id});},{disabled:!r.near,meta:r.near?"COLLECT":"AT ENTRANCE",description:`${coordinates(r.entrance)}. Withdrawal only. Ended ${expiry(r.endedAt)}.`}));
    if(!entries.length)entries=[empty("No former tenancy storage")];
  }else entries=[empty("This record is no longer available")];
  const collection=["nearby","mine","available","properties"].includes(top.kind)?"properties":["templates","chooseTemplate"].includes(top.kind)?"templates":top.kind==="recovery"?"recovery":["people","assign"].includes(top.kind)?"players":undefined;
  if(collection){
    const info=state?.pages?.[collection];
    const changePage=(page:number)=>{setStack(s=>s.map((p,n)=>n===s.length-1?{...p,page,selected:undefined}:p));};
    entries.push({separator:true});
    if(collection!=="recovery")entries.push(entry("search","Search by name",()=>edit({title:"Find a record",description:"Filter this list by name. Leave empty to show all records.",action:"local.search",payload:{},submit:"Search",fields:[{name:"query",label:"Name",value:top.query??"",optional:true}]}),{meta:top.query||"ALL"}));
    if(info&&(info.page>1))entries.push(entry("previous",`Previous page (${info.page}/${info.pages})`,()=>changePage(info.page-1)));
    if(info&&info.page<info.pages)entries.push(entry("next",`Next page (${info.page}/${info.pages})`,()=>changePage(info.page+1)));
  }
  entries.push({separator:true},entry("refresh","Refresh",()=>{setError("");void refresh();}),entry("back",stack.length>1?"Back":"Close menu",back,{icon:"chevron-left"}));
  const chosen=entries.findIndex(e=>e.id===top.selected&&isPickable(e)),index=chosen>=0?chosen:Math.max(0,entries.findIndex(isPickable));
  return <section className="rp-support rp-housing" aria-label={admin?"Housing administration":"My homes"}>
    <div className="rp-support__menu" ref={menu} tabIndex={-1}>
      <RageMenu title={title} subtitle={subtitle} tag={admin?"STAFF":"HOUSING"} items={entries} index={index} width={350} visibleRows={9} path={stack.map(p=>p.kind.toUpperCase())} active={!form&&!busy}
        onIndexChange={i=>setStack(s=>s.map((p,n)=>n===s.length-1?{...p,selected:entries[i]?.id}:p))} onSelect={(_,i)=>{if(!busy)entries[i]?.run?.();}} onBack={back}/>
      {busy&&<p className="rp-support__success" role="status">Saving…</p>}{error&&<p className="rp-support__error" role="alert">{error}</p>}{feedback&&!error&&!busy&&<p className="rp-support__success" role="status">{feedback}</p>}
    </div>
    {(form||details)&&<aside className="rp-support__panel o77-interactive" ref={panel} aria-label={form?"Housing form":"Dwelling details"}>
      <header className="rp-support__panel-header"><span>{form?"CONFIRM YOUR CHANGES":"DETAILS · PGUP / PGDN"}</span></header>
      {form?<HousingForm key={form.mutation} spec={form} busy={busy} onCancel={()=>{if(!busy)setForm(null);}} onSave={async values=>{if(form.action==="local.search"){setStack(s=>s.map((p,n)=>n===s.length-1?{...p,page:1,query:String(values.query??""),selected:undefined}:p));setForm(null);return;}if("enabled" in values)values.enabled=values.enabled==="true";await run(form.action,{...form.payload,...values,mutation:form.mutation});}}/>:details}
    </aside>}
  </section>;
}
function HomeDetails({home:h}:{home:Home}) {
  return <div className="rp-support__record"><small>{h.kind.toUpperCase()} #{h.id}</small><h2>{h.label}</h2><p className="rp-support__badge">{h.owned?"YOUR HOME":h.available?"AVAILABLE":h.enabled?"OCCUPIED":"DISABLED"}</p>
    <dl><dt>Interior</dt><dd>{h.templateLabel}</dd><dt>Exterior entrance</dt><dd>{coordinates(h.entrance)}</dd><dt>Purchase</dt><dd>{h.price?credits(h.price):"Not for sale"}</dd><dt>Rent</dt><dd>{h.rent?`${credits(h.rent)} / ${h.rentDays} days`:"Not for rent"}</dd><dt>Door</dt><dd>{h.locked?"Locked":"Open to visitors"}</dd>
      {(h.owned||h.tenant)&&<><dt>Tenancy</dt><dd>{h.tenant?.name??"You"} · {h.mode??h.tenant?.mode}</dd><dt>Expiry</dt><dd>{expiry(h.expires??h.tenant?.expires)}</dd><dt>Inside</dt><dd>{h.occupants??0} player(s)</dd></>}
    </dl><p>Payments use your bank account. Each dwelling has its own private instance. Storage is reserved for the resident and their key holders.</p>
  </div>;
}
