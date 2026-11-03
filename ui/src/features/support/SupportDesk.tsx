import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { useStore } from "@/state/store";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { RageMenu, isPickable, type RageMenuItem } from "@/design/components";
import { request, key, list, date, label, type Scope, type TicketList, type Detail, type Overview, type Wire, type Person, type Profile, type Audit, type TableList, type PlacedTable } from "./api";
import { ActionForm, ProfileCard, AuditEntry, actionLabels, auditLabels } from "./StaffTools";
import { TableCard, TableActionForm, moneyLine } from "./TableTools";
import { NewReport, MessageForm, SearchForm } from "./SupportForms";
import "./support.css";

type Page = { kind:"root"|"tickets"|"ticket"|"assign"|"players"|"player"|"history"|"tools"|"tables"|"table"; selected?:string; caseId?:number; person?:Person; history?:Audit[]; table?:PlacedTable };
type Form = { kind:"new"; body:string } | { kind:"message"; action:string } | { kind:"search"; target:"tickets"|"players"|"tables" } | { kind:"action"; action:string } | { kind:"tableAction"; action:"tableTeleport"|"tableDelete" };
type Entry = RageMenuItem & { run?:()=>void; change?:(patch:Partial<RageMenuItem>)=>void };
const filters=["active","open","in_progress","waiting_player","finished","all"];
const filterNames=["Active","Waiting","In progress","Need reply","Finished","All"];
const finished=(s:string)=>s==="resolved"||s==="closed";

export function SupportDesk() {
  const dialog=useStore(s=>s.dialog),close=useStore(s=>s.closeDialog),visible=dialog?.kind==="support";
  useEffect(()=>{
    if(!visible)return;
    emit(PAGE_EVENTS.dialogState,{kind:"support",open:true});
    const off=on<{kind?:string}>(PAGE_EVENTS.dialogClose,p=>{if(!p.kind||p.kind==="support")close();});
    return()=>{off();emit(PAGE_EVENTS.dialogState,{kind:"support",open:false});emit(PAGE_EVENTS.support,{operation:"input",mode:"closed"});};
  },[visible,close]);
  if(dialog?.kind!=="support")return null;
  return <Desk key={dialog.scope} scope={dialog.scope} initialDraft={dialog.body} close={close}/>;
}

function Desk({scope,initialDraft,close}:{scope:Scope;initialDraft?:string;close:()=>void}) {
  const staff=scope==="staff";
  const [stack,setStack]=useState<Page[]>([{kind:"root"}]),[form,setForm]=useState<Form|null>(initialDraft===undefined?null:{kind:"new",body:initialDraft});
  const [overview,setOverview]=useState<Overview>(),[cases,setCases]=useState<TicketList>(),[detail,setDetail]=useState<Detail>(),[profile,setProfile]=useState<Profile>();
  const [history,setHistory]=useState<{entries:Audit[];hasMore:boolean}>(),[historyPage,setHistoryPage]=useState(1);
  const [filter,setFilter]=useState(0),[mine,setMine]=useState(false),[query,setQuery]=useState(""),[citizenQuery,setCitizenQuery]=useState(""),[page,setPage]=useState(1);
  const [tables,setTables]=useState<TableList>(),[tablePage,setTablePage]=useState(1),[tableSort,setTableSort]=useState(0),[tableQuery,setTableQuery]=useState(""),[tableDetail,setTableDetail]=useState<TableList>();
  const [epoch,setEpoch]=useState(0),[error,setError]=useState(""),[feedback,setFeedback]=useState(""),[busy,setBusy]=useState(false),[showConversation,setShowConversation]=useState(true);
  const top=stack[stack.length-1]!,panel=useRef<HTMLElement>(null),menu=useRef<HTMLDivElement>(null),working=useRef(false);
  const mutation=useRef<{signature:string;key:string}>();
  const refresh=useCallback(()=>setEpoch(n=>n+1),[]);
  const push=(next:Page)=>{setError("");setFeedback("");setStack(s=>[...s,next]);};
  const back=()=>{setError("");setFeedback("");if(form){setForm(null);return;}if(stack.length>1)setStack(s=>s.slice(0,-1));else close();};
  useEffect(()=>{if(initialDraft!==undefined)setForm({kind:"new",body:initialDraft});},[initialDraft]);
  useEffect(()=>on<Wire>(PAGE_EVENTS.support,p=>{if(p.kind==="changed")refresh();if(p.kind==="draft")setForm({kind:"new",body:p.body||""});}),[refresh]);
  useEffect(()=>{const timer=setInterval(()=>{if(document.visibilityState!=="hidden")refresh();},12000);return()=>clearInterval(timer);},[refresh]);
  useEffect(()=>{
    let live=true;
    if(staff)request<Overview>("overview").then(v=>{if(live)setOverview(v);},e=>{if(live){setOverview(undefined);setError(e.message);}});
    return()=>{live=false;};
  },[staff,epoch]);
  useEffect(()=>{
    let live=true;if(top.kind==="tickets")request<TicketList>("list",{scope,filter:filters[filter],mine,search:query,page}).then(v=>{if(live){setCases(v);setError("");}},e=>{if(live){setCases(undefined);setError(e.message);}});
    return()=>{live=false;};
  },[top.kind,scope,filter,mine,query,page,epoch]);
  useEffect(()=>{
    let live=true;if(top.kind==="tables")request<TableList>("tables",{page:tablePage,sort:tableSort?"near":"newest",search:tableQuery}).then(v=>{if(live){setTables(v);setError("");}},e=>{if(live){setTables(undefined);setError(e.message);}});
    return()=>{live=false;};
  },[top.kind,tablePage,tableSort,tableQuery,epoch]);
  const tableId=top.kind==="table"?top.table?.id:undefined;
  useEffect(()=>{
    let live=true;if(tableId)request<TableList>("tables",{search:tableId}).then(v=>{if(live)setTableDetail(v);},e=>{if(live){setTableDetail(undefined);setError(e.message);}});
    return()=>{live=false;};
  },[tableId,epoch]);
  const caseId=top.caseId;
  useEffect(()=>{
    let live=true;if(caseId)request<Detail>("detail",{scope,ticket:caseId}).then(v=>{
      if(!live)return;
      setDetail(old=>{
        const earlier=old?.ticket.id===v.ticket.id?list(old.messages).filter(m=>m.id<(list(v.messages)[0]?.id||0)):[];
        return {...v,messages:[...earlier,...list(v.messages)],hasOlder:earlier.length?old!.hasOlder:v.hasOlder};
      });
      request("read",{scope,ticket:caseId,revision:v.ticket.revision}).catch(()=>{});
    },e=>{if(live){setDetail(undefined);setError(e.message);}});
    return()=>{live=false;};
  },[caseId,scope,epoch]);
  const target=top.person;
  useEffect(()=>{
    let live=true;if(target)request<Profile>("player",{target:target.id,account:target.account,character:target.character}).then(v=>{if(live)setProfile(v);},e=>{if(live){setProfile(undefined);setError(e.message);}});
    return()=>{live=false;};
  },[target,epoch]);
  useEffect(()=>{
    let live=true;if(top.kind==="history"&&!top.history)request<{entries:Audit[];hasMore:boolean}>("audit",{page:historyPage}).then(v=>{if(live)setHistory(v);},e=>{if(live){setHistory(undefined);setError(e.message);}});
    return()=>{live=false;};
  },[top.kind,top.history,historyPage,epoch]);
  useEffect(()=>{
    emit(PAGE_EVENTS.support,{operation:"input",mode:form?"form":"menu"});
    if(!form)menu.current?.focus();
  },[!!form]);
  useEffect(()=>{
    const handler=(e:KeyboardEvent)=>{
      if(form){
        if(e.key==="Escape"){e.preventDefault();setForm(null);return;}
        if(e.key!=="Tab")return;
        const nodes=[...(panel.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled)')||[])];
        const first=nodes[0],last=nodes.at(-1);
        if(e.shiftKey&&document.activeElement===first){e.preventDefault();last?.focus();}
        else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first?.focus();}
      }else if(e.key==="PageDown"||e.key==="PageUp"){
        e.preventDefault();const el=panel.current;if(el)el.scrollTop+=(e.key==="PageDown"?1:-1)*el.clientHeight*.8;
      }else if(e.key==="Tab"){e.preventDefault();menu.current?.focus();}
    };
    window.addEventListener("keydown",handler);return()=>window.removeEventListener("keydown",handler);
  },[form]);
  const currentDetail=detail?.ticket.id===caseId?detail:undefined;
  const currentProfile=profile&&target&&profile.id===target.id&&profile.account===target.account&&profile.character===target.character?profile:undefined;
  const mutate=async(action:string,body="",extra:Record<string,unknown>={})=>{
    if(!currentDetail||working.current)return false;
    working.current=true;setBusy(true);setError("");
    const signature=JSON.stringify([caseId,action,body,extra]);
    if(mutation.current?.signature!==signature)mutation.current={signature,key:key()};
    try{
      await request("mutate",{scope,ticket:caseId,revision:currentDetail.ticket.revision,mutation:mutation.current.key,action,body,...extra});
      mutation.current=undefined;setFeedback("Case updated.");refresh();return true;
    }catch(e){setError((e as Error).message);refresh();return false;}finally{working.current=false;setBusy(false);}
  };
  const editMessage=(action:string)=>{setError("");setForm({kind:"message",action});};
  const openCase=(id:number)=>{setDetail(undefined);setShowConversation(true);push({kind:"ticket",caseId:id});};
  const openCitizen=(person:Person)=>{setProfile(undefined);push({kind:"player",person});};
  const item=(id:string,text:string,run:()=>void,options:Partial<Entry>={}):Entry=>({id,text,run,...options});
  const submenu=(id:string,text:string,run:()=>void,options:Partial<Entry>={}):Entry=>item(id,text,run,{type:"submenu",...options});
  let title="LIGHT/RP",subtitle=staff?"STAFF MENU":"PLAYER SUPPORT",entries:Entry[]=[],content:ReactNode=null;
  const loading:Entry={id:"loading",text:"Loading…",disabled:true};
  if(top.kind==="root"){
    entries=staff?[
      submenu("reports","Reports",()=>push({kind:"tickets"}),{icon:"message-square",disabled:!overview?.permissions.reports,description:"Take a case, answer the player and track its progress."}),
      submenu("citizens","Citizens",()=>push({kind:"players"}),{icon:"users",meta:String(list(overview?.players).length),disabled:!overview,description:"RP records, moderation and character interventions."}),
      ...(overview?.permissions.audit?[submenu("history","Staff history",()=>{setHistoryPage(1);push({kind:"history"});},{icon:"file-text",description:"Who acted, why and whether the intervention completed."})]:[]),
      submenu("tools","Personal tools",()=>push({kind:"tools"}),{icon:"shield",disabled:!overview,description:"Noclip, god mode and the advanced console."}),
      ...(overview?.permissions.tables?[submenu("tables","Placed tables",()=>{setTablePage(1);push({kind:"tables"});},{icon:"box",description:"Every placed board and casino table: owner, seats, open stakes. Go to one or remove it."})]:[]),
      ...(overview?.permissions.housing?[submenu("housing","Housing",()=>{close();emit(PAGE_EVENTS.action,{type:"housing.open",admin:true});},{icon:"map-pin",description:"Interior templates, dwellings and resident assignments."})]:[]),
      ...(overview?.permissions.safezones?[submenu("safezones","Safe zones",()=>{close();emit(PAGE_EVENTS.safezones,{operation:"open"});},{icon:"shield",description:"Create and edit world-space PvP protection zones."})]:[]),
    ]:[submenu("reports","My reports",()=>push({kind:"tickets"}),{icon:"message-square",description:"Private conversations with staff, including closed cases."}),item("new","New report",()=>setForm({kind:"new",body:""}),{icon:"message-square",description:"Describe a problem and follow its handling here."})];
    entries.push({separator:true},item("refresh","Refresh",refresh,{icon:"activity"}),item("close","Close menu",close,{icon:"x"}));
  }else if(top.kind==="tools"){
    title="PERSONAL TOOLS";
    entries=([["noclip","Noclip"],["god","God mode"],["advanced","Advanced console"]] as const).filter(([a])=>overview?.permissions[a]).map(([action,text])=>item(action,text,()=>emit(PAGE_EVENTS.support,{operation:"native",action}),{description:"Uses your server permissions. The menu closes when this tool starts."}));
  }else if(top.kind==="tickets"){
    title=staff?"REPORTS":"MY REPORTS";subtitle=`${cases?.total??"—"} CASES · PAGE ${page}`;
    entries=[{id:"filter",text:"Status",type:"list",options:filterNames,index:filter,change:p=>{setCases(undefined);setFilter(p.index||0);setPage(1);},description:"Use left / right to include finished cases."},
      ...(staff?[{id:"mine",text:"Assigned to me",type:"checkbox" as const,checked:mine,change:()=>{setCases(undefined);setMine(!mine);setPage(1);},run:()=>{setCases(undefined);setMine(!mine);setPage(1);}}]:[item("new","New report",()=>setForm({kind:"new",body:""}),{icon:"message-square"})]),
      item("search","Search reports",()=>setForm({kind:"search",target:"tickets"}),{icon:"search",meta:query||"ALL",description:"Search by case number, subject or reporter."}),{separator:true},
      ...(!cases?[loading]:list(cases.tickets).length?list(cases.tickets).map(t=>submenu(`case:${t.id}`,`#${t.id} ${t.subject}`,()=>openCase(t.id),{meta:t.unread?"NEW":undefined,description:`${label(t.status)} · ${t.assignee||"Unassigned"} · ${t.reporter}`})):[{id:"empty",text:"No reports match",disabled:true}]),
      ...(page>1?[item("previous","Previous page",()=>{setCases(undefined);setPage(n=>n-1);})]:[]),
      ...(cases&&page*cases.pageSize<cases.total?[item("next","Next page",()=>{setCases(undefined);setPage(n=>n+1);})]:[]),item("refresh","Refresh",refresh)];
  }else if(top.kind==="ticket"){
    title=`CASE #${caseId}`;const d=currentDetail,t=d?.ticket;subtitle=t?`${label(t.status)} · ${t.assignee||"UNASSIGNED"}`:"Loading case";
    if(!d||!t)entries=[loading];else{
      const done=finished(t.status);
      entries=[{id:"conversation",text:"Conversation",type:"checkbox",checked:showConversation,run:()=>setShowConversation(v=>!v),change:()=>setShowConversation(v=>!v),description:"Read the conversation beside this menu. Page Up / Down scrolls it."},
        ...(!done&&!t.assignee&&staff?[item("claim","Take this case",()=>{void mutate("claim");},{disabled:busy})]:[]),
        ...(!done?[item("reply",staff?"Reply to player":"Reply to staff",()=>editMessage("reply"),{icon:"message-square"})]:[]),
        ...(!done&&staff?[item("note","Internal staff note",()=>editMessage("note"),{description:"Private: only support staff can read this note."})]:[]),
        ...(!done&&staff&&d.canManage?[item("waiting","Ask for information",()=>editMessage("waiting")),item("resolve","Resolve case",()=>editMessage("resolve"))]:[]),
        ...(!done&&(!staff||d.canManage)?[item("close-case","Close case",()=>editMessage("close"),{danger:true})]:[]),
        ...(done&&d.canReopen?[item("reopen","Reopen case",()=>editMessage("reopen"),{description:"Explain why you still need help. Returns the case to the staff queue."})]:[]),
        ...(!done&&staff&&d.canManage&&t.assignee?[item("release","Return to queue",()=>{void mutate("release");},{disabled:busy})]:[]),
        ...(!done&&staff&&d.canAssign?[submenu("assign","Assign to admin",()=>push({kind:"assign",caseId}))]:[]),
        ...(staff?[{id:"urgent",text:"Urgent",type:"checkbox" as const,checked:t.priority==="urgent",disabled:busy,run:()=>{void mutate("priority","",{priority:t.priority==="urgent"?"normal":"urgent"});},change:()=>{void mutate("priority","",{priority:t.priority==="urgent"?"normal":"urgent"});}}]:[]),
        ...(staff&&t.reporterPlayer&&overview?.players.some(p=>p.id===t.reporterPlayer&&p.account===t.owner)?[submenu("reporter","Reporter profile",()=>{const p=overview.players.find(p=>p.id===t.reporterPlayer&&p.account===t.owner);if(p)openCitizen(p);})]:[]),
        ...(d.hasOlder?[item("older","Load earlier messages",()=>{void request<Detail>("detail",{scope,ticket:caseId,before:list(d.messages)[0]?.id}).then(v=>setDetail(old=>old&&old.ticket.id===caseId?{...old,messages:[...list(v.messages),...list(old.messages)],hasOlder:v.hasOlder}:old),e=>setError(e.message));})]:[]),
        item("refresh","Refresh case",refresh)];
      if(showConversation)content=<Conversation data={d}/>;
    }
  }else if(top.kind==="assign"){
    title="ASSIGN CASE";subtitle=`CASE #${caseId}`;
    entries=list(overview?.staff).map(p=>item(`assign:${p.id}`,p.name,()=>{void mutate("assign","",{assignee:p.id}).then(ok=>{if(ok)back();});},{disabled:busy,description:"Transfer this case to this connected admin."}));
  }else if(top.kind==="players"){
    title="CITIZENS";subtitle=`${list(overview?.players).length} CONNECTED`;
    const people=list(overview?.players).filter(p=>`${p.id} ${p.name} ${p.accountName} ${p.job.label}`.toLowerCase().includes(citizenQuery.toLowerCase()));
    entries=[item("search","Search citizens",()=>setForm({kind:"search",target:"players"}),{icon:"search",meta:citizenQuery||"ALL"}),{separator:true},...people.map(p=>submenu(`citizen:${p.account}:${p.character}`,`#${p.id} ${p.name}`,()=>openCitizen(p),{meta:p.life,description:`${p.accountName} · ${p.job.label} · ${p.gang.label}`})),...(!people.length?[{id:"empty",text:"No matching citizens",disabled:true}]:[]),item("refresh","Refresh",refresh)];
  }else if(top.kind==="player"){
    title="CITIZEN";subtitle=currentProfile?`#${currentProfile.id} · ${currentProfile.name}`:"Loading RP record";
    if(!currentProfile)entries=[loading];else{
      entries=Object.entries(actionLabels).filter(([a])=>overview?.permissions[a]&&(a!=="returnPlayer"||currentProfile.canReturn)).map(([a,text])=>submenu(a,text,()=>setForm({kind:"action",action:a}),{danger:["kick","ban","debit"].includes(a),description:`${currentProfile.name} · A reason and confirmation are required.`}));
      if(overview?.permissions.audit)entries.push(submenu("history","Recent interventions",()=>push({kind:"history",history:currentProfile.history})));
      content=<ProfileCard profile={currentProfile}/>;
    }
  }else if(top.kind==="tables"){
    title="PLACED TABLES";subtitle=`${tables?.total??"—"} TABLES · PAGE ${tablePage}`;
    const rows=list(tables?.tables);
    entries=[{id:"sort",text:"Sort",type:"list",options:["Newest","Nearest"],index:tableSort,change:p=>{setTables(undefined);setTableSort(p.index||0);setTablePage(1);},description:"Nearest: tables in your instance first, by distance."},
      item("search","Search tables",()=>setForm({kind:"search",target:"tables"}),{icon:"search",meta:tableQuery||"ALL",description:"Table ID, kind, owner name or inventory."}),{separator:true},
      ...(!tables?[loading]:rows.length?rows.map(t=>submenu(`table:${t.id}`,`${t.title} · ${t.owner}`,()=>{setTableDetail(undefined);push({kind:"table",table:t});},{meta:t.distance!==undefined?`${t.distance.toFixed(0)} m`:t.seatedCount?`${t.seatedCount} seated`:undefined,description:`${t.id} · instance ${t.bucket} · ${moneyLine(t)}`})):[{id:"empty",text:"No placed tables match",disabled:true}]),
      ...(tablePage>1?[item("previous","Previous page",()=>{setTables(undefined);setTablePage(n=>n-1);})]:[]),
      ...(tables&&tablePage*tables.pageSize<tables.total?[item("next","Next page",()=>{setTables(undefined);setTablePage(n=>n+1);})]:[]),
      ...(tables?.pendingReturns?[{id:"pending",text:`Items awaiting return: ${tables.pendingReturns}`,disabled:true,description:"Removed tables whose item goes back when the owner's character is next loaded."}]:[]),
      item("refresh","Refresh",refresh)];
    const chosen=rows.find(t=>`table:${t.id}`===top.selected);if(chosen)content=<TableCard table={chosen}/>;
  }else if(top.kind==="table"){
    const live=list(tableDetail?.tables).find(t=>t.id===top.table?.id),t=live||top.table!;
    title="PLACED TABLE";subtitle=`${t.title} · ${t.id}`;
    if(!tableDetail)entries=[loading];
    else if(!live)entries=[{id:"gone",text:"This table no longer exists",disabled:true}];
    else entries=[
      ...(tableDetail?.canTeleport?[submenu("tableTeleport","Go to table",()=>setForm({kind:"tableAction",action:"tableTeleport"}),{icon:"navigation",description:"Teleport beside the table, facing it. A reason is recorded."})]:[]),
      ...(tableDetail?.canDelete?[submenu("tableDelete","Remove table",()=>setForm({kind:"tableAction",action:"tableDelete"}),{icon:"trash-2",danger:true,description:"Refunds open stakes, unseats players, optionally gives the item back. A reason is recorded."})]:[]),
      item("refresh","Refresh table",refresh)];
    content=<TableCard table={t}/>;
  }else if(top.kind==="history"){
    title="STAFF HISTORY";subtitle=top.history?"SELECTED CITIZEN":`PAGE ${historyPage}`;
    const rows=top.history||list(history?.entries);
    entries=rows.map(a=>({id:`audit:${a.id}`,text:`${auditLabels[a.action]||a.action} · ${a.target_name||"Server"}`,meta:a.outcome,description:`${a.actor_name} · ${date(Number(a.at))}`}));
    const chosen=rows.find(a=>`audit:${a.id}`===top.selected)||rows[0];if(chosen)content=<AuditEntry entry={chosen}/>;
    if(!rows.length)entries.push({id:"empty",text:history||top.history?"No recorded interventions":"Loading…",disabled:true});
    if(!top.history){if(historyPage>1)entries.push(item("previous","Previous page",()=>setHistoryPage(n=>n-1)));if(history?.hasMore)entries.push(item("next","Next page",()=>setHistoryPage(n=>n+1)));entries.push(item("refresh","Refresh",refresh));}
  }
  if(top.kind!=="root")entries.push({separator:true},item("back","Back",back,{icon:"chevron-left"}));
  const selected=entries.findIndex(e=>e.id===top.selected&&isPickable(e));
  const index=selected>=0?selected:Math.max(0,entries.findIndex(isPickable));
  const cancel=()=>{setForm(null);setError("");};
  if(form?.kind==="new")content=<NewReport initial={form.body} onCancel={cancel} onCreated={id=>{setForm(null);setDetail(undefined);setStack([{kind:"root",selected:"reports"},{kind:"tickets"},{kind:"ticket",caseId:id}]);refresh();}}/>;
  else if(form?.kind==="search")content=<SearchForm initial={form.target==="tickets"?query:form.target==="tables"?tableQuery:citizenQuery} onCancel={cancel} onSave={value=>{if(form.target==="tickets"){setCases(undefined);setQuery(value);setPage(1);}else if(form.target==="tables"){setTables(undefined);setTableQuery(value);setTablePage(1);}else setCitizenQuery(value);cancel();}}/>;
  else if(form?.kind==="tableAction"&&top.table){const t=list(tableDetail?.tables).find(r=>r.id===top.table!.id)||top.table;content=<TableActionForm key={form.action} action={form.action} table={t} onCancel={cancel} onDone={message=>{setFeedback(message);setForm(null);if(form.action==="tableDelete"){setTables(undefined);setStack(s=>s.slice(0,-1));}refresh();}}/>;}
  else if(form?.kind==="message")content=<MessageForm action={form.action} busy={busy} onCancel={cancel} onSend={async body=>{if(await mutate(form.action,body))setForm(null);}}/>;
  else if(form?.kind==="action"&&currentProfile&&overview)content=<ActionForm action={form.action} person={currentProfile} overview={overview} onCancel={cancel} onDone={message=>{setFeedback(message);setForm(null);refresh();}}/>;
  return <section className="rp-support" aria-label={staff?"LightRP staff menu":"Reports and support"}>
    <div className="rp-support__menu" ref={menu} tabIndex={-1}>
      <RageMenu title={title} subtitle={subtitle} tag={staff?"STAFF":"SUPPORT"} items={entries} index={index} path={stack.map(p=>p.kind.toUpperCase())} width={350} visibleRows={9} active={!form}
        onIndexChange={i=>setStack(s=>s.map((p,n)=>n===s.length-1?{...p,selected:entries[i]?.id}:p))}
        onSelect={(_,i)=>entries[i]?.run?.()} onChange={(_,i,patch)=>entries[i]?.change?.(patch)} onBack={back}
        footer={<><span>↑↓ MOVE</span><span>←→ CHANGE</span><span>ENTER SELECT</span><span>BKSP / ESC BACK</span></>}/>
      {error&&<p className="rp-support__error" role="alert">{error}</p>}{feedback&&!error&&<p className="rp-support__success" role="status">{feedback}</p>}
    </div>
    {content&&<aside className="rp-support__panel o77-interactive" ref={panel} aria-label={form?"Support form":"Selected record"}>
      <header className="rp-support__panel-header"><span>{form?"COMPLETE THIS STEP":"DETAILS · PGUP / PGDN TO SCROLL"}</span>{form&&<button onClick={cancel} aria-label="Back to menu">Esc · Back</button>}</header>
      {content}
    </aside>}
  </section>;
}

function Conversation({data}:{data:Detail}) {
  const t=data.ticket;
  return <div className="rp-support__record"><small>CASE #{t.id} · {t.category}</small><h2>{t.subject}</h2><p className="rp-support__badge">{label(t.status)}</p>
    <dl><dt>Reporter</dt><dd>{t.reporter} · {t.reporterOnline?"online":"offline"}</dd><dt>Assigned admin</dt><dd>{t.assignee||"Waiting for staff"}{t.assignee?` · ${t.assigneeOnline?"online":"offline"}`:""}</dd>{t.reported&&<><dt>Player involved</dt><dd>{t.reported}</dd></>}{t.position&&<><dt>Location</dt><dd>{t.position.x.toFixed(1)}, {t.position.y.toFixed(1)}, {t.position.z.toFixed(1)} · instance {t.position.bucket}</dd></>}</dl>
    <div className="rp-support__conversation" aria-label="Case history">{list(data.messages).map(m=><article className={m.internal?"is-private":""} key={m.id}><header><b>{m.author}</b><small>{m.internal?"PRIVATE STAFF NOTE":m.role.toUpperCase()} · {date(m.at)}</small></header><p>{m.body}</p></article>)}</div>
  </div>;
}
