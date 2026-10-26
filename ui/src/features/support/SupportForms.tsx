import { useEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { request, key, list } from "./api";

export function useFormFocus() {
  const ref=useRef<HTMLFormElement>(null);
  useEffect(()=>{ref.current?.querySelector<HTMLElement>('input,textarea,select')?.focus();},[]);
  return ref;
}
export function NewReport({initial,onCancel,onCreated}:{initial:string;onCancel:()=>void;onCreated:(id:number)=>void}) {
  const [subject,setSubject]=useState(""),[body,setBody]=useState(initial),[category,setCategory]=useState("help"),[reported,setReported]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState("");
  const online=useStore(s=>s.state.online),you=useStore(s=>s.state.character.playerId),mutation=useRef(key()),ref=useFormFocus();
  return <form className="rp-support__form" ref={ref} onSubmit={async e=>{e.preventDefault();if(busy)return;setBusy(true);setError("");try{const r=await request<{ticketId:number}>("create",{mutation:mutation.current,subject,body,category,reportedPlayer:reported?Number(reported):undefined});onCreated(r.ticketId);}catch(e){setError((e as Error).message);}finally{setBusy(false);}}}>
    <h2>New report</h2><p>Private conversation with staff. Replies stay available after you disconnect.</p>
    <label>Subject<input required minLength={4} maxLength={120} value={subject} onChange={e=>setSubject(e.target.value)} placeholder="A short summary"/></label>
    <label>Category<select value={category} onChange={e=>setCategory(e.target.value)}><option value="help">Help</option><option value="player">Player incident</option><option value="bug">Bug / technical issue</option><option value="other">Other</option></select></label>
    <label>Player involved<select value={reported} onChange={e=>setReported(e.target.value)}><option value="">No specific player</option>{list(online).filter(p=>p.id!==you).map(p=><option key={p.id} value={p.id}>#{p.id} · {p.name}</option>)}</select></label>
    <label>What happened?<textarea required minLength={10} maxLength={2000} rows={5} value={body} onChange={e=>setBody(e.target.value)} placeholder="What, where, when? Evidence links can be pasted here."/><small>{body.length}/2000 · Location is saved for staff.</small></label>
    {error&&<p className="rp-support__error" role="alert">{error}</p>}<footer><button type="button" onClick={onCancel} disabled={busy}>Cancel</button><button className="is-primary" disabled={busy}>{busy?"Saving…":"Send report"}</button></footer>
  </form>;
}
const names:Record<string,string>={reply:"Reply",note:"Internal staff note",waiting:"Ask for information",resolve:"Resolve case",close:"Close case",reopen:"Reopen case"};
export function MessageForm({action,busy,onCancel,onSend}:{action:string;busy:boolean;onCancel:()=>void;onSend:(body:string)=>Promise<void>}) {
  const [body,setBody]=useState(""),ref=useFormFocus();
  return <form className="rp-support__form" ref={ref} onSubmit={e=>{e.preventDefault();if(!busy)void onSend(body);}}>
    <h2>{names[action]||action}</h2><p>{action==="note"?"Private: only support staff can read this note.":action==="resolve"?"Explain the resolution to the player.":action==="reopen"?"Explain why you still need help.":"This message is saved even if the other person is offline."}</p>
    <label>Message<textarea aria-label="Message" value={body} onChange={e=>setBody(e.target.value)} required minLength={4} maxLength={2000} rows={7} disabled={busy}/><small>{body.length}/2000</small></label>
    <footer><button type="button" onClick={onCancel} disabled={busy}>Cancel</button><button className="is-primary" disabled={busy||body.trim().length<4}>{busy?"Saving…":action==="resolve"?"Confirm resolution":action==="close"?"Confirm closure":action==="reopen"?"Reopen case":"Send"}</button></footer>
  </form>;
}
export function SearchForm({initial,onCancel,onSave}:{initial:string;onCancel:()=>void;onSave:(value:string)=>void}) {
  const [value,setValue]=useState(initial),ref=useFormFocus();
  return <form className="rp-support__form" ref={ref} onSubmit={e=>{e.preventDefault();onSave(value);}}><h2>Search</h2><label>Name, ID or subject<input value={value} onChange={e=>setValue(e.target.value)} maxLength={80}/></label><p>Leave empty to show all results.</p><footer><button type="button" onClick={onCancel}>Cancel</button><button className="is-primary">Apply filter</button></footer></form>;
}
