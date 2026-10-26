import { useState, type FormEvent } from "react";
import type { Home, Interior } from "./model";
import { list } from "@/features/support/api";

export interface Field { name:string; label:string; value?:string|number; type?:"text"|"number"|"select"|"textarea"; options?:{value:string;label:string}[]; min?:number; max?:number; maxLength?:number; optional?:boolean }
export interface FormSpec { title:string; description:string; fields:Field[]; submit:string; danger?:boolean; action:string; payload:Record<string,unknown> }
export function HousingForm({spec,busy,onSave,onCancel}:{spec:FormSpec;busy:boolean;onSave:(values:Record<string,unknown>)=>Promise<void>;onCancel:()=>void}) {
  const [values,setValues]=useState<Record<string,string>>(()=>Object.fromEntries(spec.fields.map(f=>[f.name,String(f.value??f.options?.[0]?.value??"")])));
  const submit=(e:FormEvent)=>{e.preventDefault();if(busy)return;void onSave(Object.fromEntries(spec.fields.map(f=>[f.name,f.type==="number"?Number(values[f.name]):values[f.name]])));};
  return <form className="rp-support__form" onSubmit={submit}>
    <h2>{spec.title}</h2><p>{spec.description}</p>
    {spec.fields.map((f,i)=><label key={f.name}>{f.label}
      {f.type==="select"?<select autoFocus={i===0} disabled={busy} required value={values[f.name]} onChange={e=>setValues(v=>({...v,[f.name]:e.target.value}))}>{list(f.options).map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select>
      :f.type==="textarea"?<textarea autoFocus={i===0} disabled={busy} required maxLength={f.maxLength??160} value={values[f.name]} onChange={e=>setValues(v=>({...v,[f.name]:e.target.value}))}/>
      :<input autoFocus={i===0} disabled={busy} required={!f.optional} type={f.type??"text"} min={f.min} max={f.max} step={f.type==="number"?1:undefined} maxLength={f.maxLength??80} value={values[f.name]} onChange={e=>setValues(v=>({...v,[f.name]:e.target.value}))}/>}
    </label>)}
    <div className="rp-support__form-actions"><button type="button" disabled={busy} onClick={onCancel}>Cancel</button><button type="submit" disabled={busy} className={spec.danger?"is-danger":""}>{busy?"Saving…":spec.submit}</button></div>
  </form>;
}
export function interiorForm(t?:Interior,defaults?:{slots:number;weight:number}):FormSpec {
  return {title:t?"Edit interior":"New interior template",description:"Stand inside your chosen interior. Save its name, then capture spawn, exit and storage points from the menu. Capacity changes apply to new tenancies.",submit:"Save template",action:t?"admin.template.update":"admin.template.create",payload:t?{id:t.id,revision:t.revision}:{},fields:[
    {name:"label",label:"Template name",value:t?.label},
    {name:"slots",label:"Storage slots",type:"number",value:t?.slots??defaults?.slots??40,min:1,max:200},
    {name:"weight",label:"Storage capacity (kg)",type:"number",value:t?.weight??defaults?.weight??150,min:1,max:10000},
  ]};
}
export function propertyForm(templates:Interior[],home?:Home,defaultRentDays=7):FormSpec {
  return {title:home?"Edit dwelling":"New dwelling",description:home?"Prices apply to future purchases and renewals. Existing prepaid rent is preserved.":"Stand at the exterior door in the shared city. Several apartments may share the same entrance; each gets its own instance.",submit:"Save dwelling",action:home?"admin.property.update":"admin.property.create",payload:home?{id:home.id,revision:home.revision}:{},fields:[
    {name:"label",label:"Dwelling name",value:home?.label},
    {name:"kind",label:"Type",type:"select",value:home?.kind??"apartment",options:[{value:"apartment",label:"Apartment"},{value:"house",label:"House"}]},
    {name:"templateId",label:"Interior template",type:"select",value:home?.templateId,options:templates.filter(t=>t.ready).map(t=>({value:t.id,label:t.label}))},
    {name:"price",label:"Purchase price (€$, 0 disables buying)",type:"number",value:home?.price??50000,min:0,max:1000000000},
    {name:"rent",label:"Rent per period (€$, 0 disables renting)",type:"number",value:home?.rent??2500,min:0,max:1000000000},
    {name:"rentDays",label:"Rental period (real days)",type:"number",value:home?.rentDays??defaultRentDays,min:1,max:90},
    {name:"enabled",label:"Availability",type:"select",value:home?.enabled===false?"false":"true",options:[{value:"true",label:"Enabled"},{value:"false",label:"Disabled"}]},
  ]};
}
