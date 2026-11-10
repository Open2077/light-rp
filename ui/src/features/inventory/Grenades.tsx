import { useEffect } from "react";
import { Bomb, RotateCw, X } from "lucide-react";
import { emit, on } from "@/bridge/open77";
import type { GrenadeState } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import "./grenades.css";
const PAGE="lightrp:ui:grenades";
let sequence=0;
export function useGrenadeEvents() {
  useEffect(()=>on<{kind:string;request?:string;ok?:boolean;state?:GrenadeState;error?:string}>(PAGE,p=>{
    const store=useStore.getState();
    if(p.state)store.setGrenades(p.state);
    if(p.kind==="response"&&store.grenadePending===p.request){
      store.setGrenadePending(undefined);
      if(!p.ok&&store.grenades)store.setGrenades({...store.grenades,error:p.error??"Grenade synchronization failed."});
    }
  }),[]);
}
function request(operation:"sync"|"unequip") {
  const store=useStore.getState();if(store.grenadePending||store.grenades?.busy)return;
  const id=`grenade:${Date.now().toString(36)}:${++sequence}`;
  store.setGrenadePending(id);emit(PAGE,{operation,request:id,mutation:id});
  window.setTimeout(()=>{
    const current=useStore.getState();
    if(current.grenadePending!==id)return;
    current.setGrenadePending(undefined);
    if(current.grenades)current.setGrenades({...current.grenades,error:"No confirmation yet. Synchronize before using or moving grenade stock."});
  },15000);
}
export function GrenadeEquipment({inventoryBusy}:{inventoryBusy:boolean}) {
  const state=useStore(s=>s.grenades),pending=useStore(s=>s.grenadePending);
  const disabled=inventoryBusy||state?.busy||!!pending;
  return <section className="inventory-grenade" aria-label="Grenade equipment">
    <div className="inventory-grenade__main"><Bomb size={19}/><div><span>GRENADE</span><strong>{state?.label??"None selected"}</strong><small>{state?.selected?`${state.count} in your inventory`:"Select a grenade from your pockets"}</small></div>
      {state?.selected&&<button aria-label="Unequip grenade" disabled={disabled} onClick={()=>request("unequip")}><X size={14}/></button>}
      <button aria-label="Synchronize grenades" disabled={disabled} onClick={()=>request("sync")}><RotateCw size={14}/></button>
    </div>
    {(state?.busy||pending)&&<p role="status">Synchronizing grenade stock…</p>}
    {state?.error&&<p className="is-error" role="status">{state.error}</p>}
  </section>;
}
