import { useEffect, useRef, useState } from "react";
import { request, key, date, type ManekiSpot } from "./api";
import { useFormFocus } from "./SupportForms";

/* Staff management of the hidden Maneki-neko (server/modules/maneki.lua). The server
   re-checks the ACL, audits before acting and owns every rule; this only collects a
   reason and a confirmation. Placing is the in-world tool (client/core/maneki_editor.lua). */
export const manekiActionLabels:Record<string,string>={manekiTeleport:"Go to a Maneki-neko",manekiDelete:"Remove a Maneki-neko",manekiPlace:"Hide a Maneki-neko"};
export const sizeLabel=(scale:number)=>scale<=1?"Game size (16 cm)":`×${scale} (${Math.round(16*scale)} cm)`;
export function ManekiCard({spot:s}:{spot:ManekiSpot}) {
  return <div className="rp-support__record"><small>MANEKI-NEKO · {s.id}</small><h2>{s.district||"Night City"}</h2><p>Hidden by {s.placedBy||"?"} · {s.placedAt?date(s.placedAt):"—"}</p>
    <dl><dt>Position</dt><dd>{s.x.toFixed(1)}, {s.y.toFixed(1)}, {s.z.toFixed(1)}{s.distance!==undefined?` · ${s.distance.toFixed(1)} m`:""}</dd><dt>Instance</dt><dd>{s.bucket}</dd>
      <dt>Size</dt><dd>{sizeLabel(s.scale)}</dd><dt>Facing</dt><dd>{Math.round(s.yaw)}°</dd><dt>Found by</dt><dd>{s.finds} character{s.finds===1?"":"s"}</dd></dl>
    <p>Players see this cat only within 140 m, and only until their character finds it. No map marker, no hint.</p>
  </div>;
}
export function ManekiActionForm({action,spot,onCancel,onDone}:{action:"manekiTeleport"|"manekiDelete";spot:ManekiSpot;onCancel:()=>void;onDone:(message:string)=>void}) {
  const [reason,setReason]=useState(""),[confirm,setConfirm]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(""),[uncertain,setUncertain]=useState(false);
  const mutation=useRef<string>(),cancel=useRef<HTMLButtonElement>(null),ref=useFormFocus(),remove=action==="manekiDelete";
  useEffect(()=>{if(confirm)cancel.current?.focus();else ref.current?.querySelector<HTMLElement>("textarea")?.focus();},[confirm,ref]);
  const send=async()=>{
    if(busy||uncertain)return;setBusy(true);setError("");mutation.current??=key();
    try{
      const r=await request<{accepted:boolean;outcome:string;message:string}>("manekiAction",{confirmed:true,mutation:mutation.current,action,id:spot.id,reason});
      if(r.accepted&&r.outcome==="success")onDone(r.message);else{setError(r.message);setConfirm(false);setUncertain(r.outcome==="pending");}
    }catch(e){setError((e as Error).message);}finally{setBusy(false);}
  };
  return <div className="rp-support__action"><h2>{manekiActionLabels[action]}</h2><p>{spot.id} · {spot.district||"Night City"}</p>
    {confirm?<div className="rp-support__confirm" role="alertdialog" aria-label="Confirm Maneki-neko intervention"><h3>{remove?"Remove this cat?":"Go to this cat?"}</h3>
      <p>{remove?`It disappears for everyone. The ${spot.finds} find(s) already made stay counted in those players' history, not in the collection total.`:"You land a step in front of the cat, facing it."}</p>
      <blockquote>{reason}</blockquote><footer><button ref={cancel} disabled={busy} onClick={()=>setConfirm(false)}>Cancel</button><button className={remove?"is-danger":"is-primary"} disabled={busy} onClick={send}>{busy?"Applying…":remove?"Remove cat":"Teleport"}</button></footer>
    </div>:<form className="rp-support__form" ref={ref} onSubmit={e=>{e.preventDefault();mutation.current=undefined;setConfirm(true);}}>
      <label>Reason for this intervention<textarea required minLength={4} maxLength={500} rows={4} value={reason} onChange={e=>setReason(e.target.value)} placeholder="Why? This will be recorded."/></label>
      <footer><button type="button" onClick={onCancel}>Back</button><button className="is-primary" disabled={uncertain}>Review intervention</button></footer>
    </form>}{error&&<p className="rp-support__error" role="alert">{error}</p>}</div>;
}
