import { useEffect, useRef, useState } from "react";
import { request, key, date, type PlacedTable } from "./api";
import { useFormFocus } from "./SupportForms";

/* Staff management of placed tables (board games, casino tables). The server
   (server/modules/board_games_admin.lua) re-checks the ACL, audits before
   acting and owns every rule; this only collects a reason and a confirmation. */
export const tableActionLabels:Record<string,string>={tableTeleport:"Go to table",tableDelete:"Remove table"};
const money=(v:number)=>`€$ ${v.toLocaleString()}`;
export function moneyLine(t:PlacedTable) {
  if(t.resolving)return `Resolving: ${t.resolving}`;
  return t.stakes?`${money(t.stakes)} in open stakes`:"No open stakes";
}
export function TableCard({table:t}:{table:PlacedTable}) {
  return <div className="rp-support__record"><small>PLACED TABLE · {t.id}</small><h2>{t.title}</h2><p>{t.owner} · {t.online?`online #${t.online}`:"offline"}</p>
    <dl><dt>Kind</dt><dd>{t.kind}</dd><dt>Placed</dt><dd>{t.placedAt?date(t.placedAt):"—"} · rev {t.revision}</dd>
      <dt>Position</dt><dd>{t.x.toFixed(1)}, {t.y.toFixed(1)}, {t.z.toFixed(1)}{t.distance!==undefined?` · ${t.distance.toFixed(1)} m`:""}</dd><dt>Instance</dt><dd>{t.bucket}</dd>
      <dt>Seated</dt><dd>{t.seatedCount?t.seated:"Nobody"}</dd><dt>Phase</dt><dd>{t.phase||"—"}</dd><dt>Money</dt><dd>{moneyLine(t)}</dd></dl>
    {t.busy&&<p className="rp-support__error">A move or a payout is saving on this table.</p>}
    <small className="rp-support__account">Owner inventory: {t.inventory}</small>
  </div>;
}
export function TableActionForm({action,table,onCancel,onDone}:{action:"tableTeleport"|"tableDelete";table:PlacedTable;onCancel:()=>void;onDone:(message:string)=>void}) {
  const [reason,setReason]=useState(""),[giveBack,setGiveBack]=useState(true),[confirm,setConfirm]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(""),[uncertain,setUncertain]=useState(false);
  const mutation=useRef<string>(),cancel=useRef<HTMLButtonElement>(null),ref=useFormFocus(),remove=action==="tableDelete";
  useEffect(()=>{if(confirm)cancel.current?.focus();else ref.current?.querySelector<HTMLElement>("input,textarea")?.focus();},[confirm,ref]);
  const send=async()=>{
    if(busy||uncertain)return;setBusy(true);setError("");mutation.current??=key();
    try{
      const r=await request<{accepted:boolean;outcome:string;message:string}>("tableAction",{confirmed:true,mutation:mutation.current,action,table:table.id,kind:table.kind,reason,returnItem:remove&&giveBack});
      if(r.accepted&&r.outcome==="success")onDone(r.message);else{setError(r.message);setConfirm(false);setUncertain(r.outcome==="pending");}
    }catch(e){setError((e as Error).message);}finally{setBusy(false);}
  };
  return <div className="rp-support__action"><h2>{tableActionLabels[action]}</h2><p>{table.title} · {table.id} · {table.owner}</p>
    {confirm?<div className="rp-support__confirm" role="alertdialog" aria-label="Confirm table intervention"><h3>{remove?"Remove this table?":"Go to this table?"}</h3>
      {remove&&<p>{table.seatedCount?`${table.seatedCount} seated player(s) will be unseated. `:""}{table.stakes?`${money(table.stakes)} of open stakes will be refunded. `:""}{giveBack?"The item goes back to the owner's character.":"The item is NOT given back."}</p>}
      {!remove&&<p>You land beside the table, facing it{table.bucket?` (instance ${table.bucket})`:""}.</p>}
      <blockquote>{reason}</blockquote><footer><button ref={cancel} disabled={busy} onClick={()=>setConfirm(false)}>Cancel</button><button className={remove?"is-danger":"is-primary"} disabled={busy} onClick={send}>{busy?"Applying…":remove?"Remove table":"Teleport"}</button></footer>
    </div>:<form className="rp-support__form" ref={ref} onSubmit={e=>{e.preventDefault();mutation.current=undefined;setConfirm(true);}}>
      {remove&&<p>{table.resolving?`Resolving: ${table.resolving} The server refuses until it settles.`:"Open stakes are refunded exactly like a pickup, the dealer leaves with the table and seated players get a notice."}</p>}
      {remove&&<label className="rp-support__check"><span><input type="checkbox" checked={giveBack} onChange={e=>setGiveBack(e.target.checked)}/> Give the item back to the owner</span><small>Into the owner's character inventory now, or when that character is next loaded with a free slot.</small></label>}
      <label>Reason for this intervention<textarea required minLength={4} maxLength={500} rows={4} value={reason} onChange={e=>setReason(e.target.value)} placeholder="Explain the situation. This will be recorded."/></label>
      <footer><button type="button" onClick={onCancel}>Back</button><button className="is-primary" disabled={uncertain}>Review intervention</button></footer>
    </form>}{error&&<p className="rp-support__error" role="alert">{error}</p>}</div>;
}
