import { useEffect, useRef, useState } from "react";
import { request, key, list, date, type Overview, type Profile, type Audit } from "./api";
import { useFormFocus } from "./SupportForms";
import { tableActionLabels } from "./TableTools";
import { manekiActionLabels } from "./ManekiTools";
import { eventAuditLabels } from "./EventsTools";

export const actionLabels:Record<string,string>={gotoPlayer:"Go to player",bring:"Bring player",returnPlayer:"Return player",heal:"Heal / revive",rename:"Rename character",job:"Change job",gang:"Change affiliation",credit:"Credit money",debit:"Remove money",warn:"Formal warning",kick:"Kick player",ban:"Ban player",announce:"Server announcement"};
/** Every action the audit log can hold (citizen interventions + placed tables). */
export const auditLabels:Record<string,string>={...actionLabels,...tableActionLabels,...manekiActionLabels,...eventAuditLabels};
const money=(v:number|undefined)=>`€$ ${(v||0).toLocaleString()}`;
export function ProfileCard({profile:p}:{profile:Profile}) {
  return <div className="rp-support__record"><small>CITIZEN #{p.id} · {p.character}</small><h2>{p.name}</h2><p>{p.accountName} · {p.status}</p>
    <dl><dt>Born</dt><dd>{p.birthDate||"—"}</dd><dt>Origin</dt><dd>{p.origin||"—"}</dd><dt>Job</dt><dd>{p.job.label} · {p.job.gradeLabel}</dd><dt>Affiliation</dt><dd>{p.gang.label} · {p.gang.gradeLabel}</dd><dt>Cash</dt><dd>{money(p.money?.cash)}</dd><dt>Bank · {p.money?.number||"—"}</dt><dd>{money(p.money?.bank)}</dd></dl>
    {p.position&&<p>Position {p.position.x.toFixed(1)}, {p.position.y.toFixed(1)}, {p.position.z.toFixed(1)} · instance {p.position.bucket||0}</p>}<p>{p.story||"No backstory provided."}</p><small className="rp-support__account">Open77: {p.account}</small>
  </div>;
}
export function ActionForm({action,person,overview,onCancel,onDone}:{action:string;person:Profile;overview:Overview;onCancel:()=>void;onDone:(message:string)=>void}) {
  const [reason,setReason]=useState(""),[first,setFirst]=useState(person.firstName||""),[last,setLast]=useState(person.lastName||"");
  const [name,setName]=useState(""),[grade,setGrade]=useState("0"),[wallet,setWallet]=useState("bank"),[amount,setAmount]=useState(""),[duration,setDuration]=useState("3600");
  const [confirm,setConfirm]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(""),[uncertain,setUncertain]=useState(false);
  const mutation=useRef<string>(),cancel=useRef<HTMLButtonElement>(null),ref=useFormFocus();
  useEffect(()=>{if(confirm)cancel.current?.focus();else ref.current?.querySelector<HTMLElement>("input,textarea,select")?.focus();},[confirm,ref]);
  const catalog=action==="gang"?overview.gangs:overview.jobs,role=list(catalog).find(r=>r.name===name);
  const send=async()=>{
    if(busy||uncertain)return;setBusy(true);setError("");mutation.current??=key();
    try{
      const r=await request<{accepted:boolean;outcome:string;message:string}>("adminAction",{confirmed:true,mutation:mutation.current,target:person.id,account:person.account,character:person.character,action,reason,firstName:first,lastName:last,name,grade:Number(grade),wallet,amount:Number(amount),duration:duration==="permanent"?duration:Number(duration)});
      if(r.accepted&&r.outcome==="success")onDone(r.message);else{setError(r.message);setConfirm(false);setUncertain(r.outcome==="pending");}
    }catch(e){setError((e as Error).message);}finally{setBusy(false);}
  };
  return <div className="rp-support__action"><h2>{actionLabels[action]}</h2><p>{person.name} · #{person.id} · {person.character}</p>
    {confirm?<div className="rp-support__confirm" role="alertdialog" aria-label="Confirm staff intervention"><h3>Confirm this intervention?</h3>
      {action==="rename"&&<p>New name: {first} {last}</p>}{(action==="job"||action==="gang")&&<p>{name} · grade {grade}</p>}{(action==="credit"||action==="debit")&&<p>{money(Number(amount))} · {wallet}</p>}{action==="ban"&&<p>{duration==="permanent"?"PERMANENT":Number(duration)/3600+" hours"}</p>}
      <blockquote>{reason}</blockquote><footer><button ref={cancel} disabled={busy} onClick={()=>setConfirm(false)}>Cancel</button><button className={["ban","kick","debit"].includes(action)?"is-danger":"is-primary"} disabled={busy} onClick={send}>{busy?"Applying…":"Confirm intervention"}</button></footer>
    </div>:<form className="rp-support__form" ref={ref} onSubmit={e=>{e.preventDefault();mutation.current=undefined;void send();}}>
      {action==="rename"&&<><label>First name<input required value={first} onChange={e=>setFirst(e.target.value)} maxLength={24}/></label><label>Last name<input required value={last} onChange={e=>setLast(e.target.value)} maxLength={24}/></label></>}
      {(action==="job"||action==="gang")&&<><label>{action==="job"?"Job":"Affiliation"}<select required value={name} onChange={e=>{setName(e.target.value);setGrade("0");}}><option value="">Choose…</option>{list(catalog).map(r=><option key={r.name} value={r.name}>{r.label}</option>)}</select></label><label>Grade<select value={grade} onChange={e=>setGrade(e.target.value)}>{list(role?.grades).map(g=><option key={g.value} value={g.value}>{g.value} · {g.label}</option>)}</select></label></>}
      {(action==="credit"||action==="debit")&&<><label>Wallet<select value={wallet} onChange={e=>setWallet(e.target.value)}><option value="bank">Bank</option><option value="cash">Cash</option></select></label><label>Amount<input type="number" min={1} max={10000000} step={1} required value={amount} onChange={e=>setAmount(e.target.value)}/></label></>}
      {action==="ban"&&<label>Duration<select value={duration} onChange={e=>setDuration(e.target.value)}><option value="3600">1 hour</option><option value="86400">1 day</option><option value="604800">7 days</option><option value="2592000">30 days</option><option value="permanent">Permanent</option></select></label>}
      {action==="announce"&&<label>Announcement<textarea required minLength={4} maxLength={500} rows={4} value={reason} onChange={e=>setReason(e.target.value)}/></label>}
      <footer><button type="button" onClick={onCancel}>Back</button><button className={["ban","debit"].includes(action)?"is-danger":"is-primary"} disabled={uncertain||busy}>{busy?"Applying…":"Apply"}</button></footer>
    </form>}{error&&<p className="rp-support__error" role="alert">{error}</p>}</div>;
}
export function AuditEntry({entry:a}:{entry:Audit}) {
  return <article className="rp-support__record"><small>{date(Number(a.at))} · {a.outcome.toUpperCase()}</small><h2>{auditLabels[a.action]||a.action}</h2><dl><dt>Staff member</dt><dd>{a.actor_name}</dd><dt>{tableActionLabels[a.action]?"Table owner":manekiActionLabels[a.action]?"Collectible":eventAuditLabels[a.action]?"Event":"Citizen"}</dt><dd>{a.target_name||"Server"}</dd></dl><h3>Reason</h3><p>{a.reason}</p><p>{a.detail}</p>{a.outcome==="pending"&&<p className="rp-support__error">Check the player before repeating this action.</p>}</article>;
}
