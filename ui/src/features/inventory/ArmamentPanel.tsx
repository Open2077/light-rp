import { useState } from "react";
import { Crosshair } from "lucide-react";
import { Icon } from "@/design/components";
import { useStore } from "@/state/store";
import type { ArmamentHand, ArmamentWeapon, InventoryItem } from "@/bridge/protocol";
import { performArmament, refreshArmament, retryArmament, weaponInstance } from "./armament";
import { GrenadeEquipment } from "./Grenades";
import "./armament.css";

const knownCount = (value?: number) => Number.isInteger(value) && value! >= 0 ? String(value) : "?";

function WeaponArt({name}:{name?:string}) {
  const [failed,setFailed]=useState<string>();
  return name&&/^weapon_[a-z0-9_]+$/.test(name)&&failed!==name
    ? <img className="inventory-armament__art" src={`img/items/${name}.png`} alt="" onError={()=>setFailed(name)} />
    : <Crosshair size={23} strokeWidth={1.4} aria-hidden="true"/>;
}
export function ArmamentPanel({ inventoryBusy }: { inventoryBusy: boolean }) {
  const state = useStore(s => s.armament), pending = useStore(s => s.armamentPending), feedback = useStore(s => s.armamentFeedback);
  const disabled = inventoryBusy || !state || state.busy || !!pending;
  const syncDisabled = inventoryBusy || state?.busy || !!pending;
  // the ammunition of the weapon in hand (handgun rounds when unarmed)
  const stock = state?.ammo?.[state?.right?.ammo ?? "pistol"] ?? state?.ammo?.pistol;
  const card = (hand: ArmamentHand, weapon?: ArmamentWeapon) => <section className={`inventory-armament__hand${weapon ? " is-equipped" : ""}`} aria-label={hand === "right" ? "Right hand" : "Left hand"}>
    <header><span>{hand === "right" ? "Right hand" : "Left hand"}</span></header>
    <div><WeaponArt name={weapon?.name}/><span><strong>{weapon?.label ?? "No weapon"}</strong><small>{weapon ? `Serial ${weapon.instanceId.slice(0, 8)}` : "Select a weapon in your pockets"}</small></span>
      {weapon && <button className="inventory-armament__remove" aria-label={`Unequip the weapon in your ${hand === "right" ? "right hand" : "left hand"}`} disabled={disabled} onClick={() => performArmament("unequip", { hand })}><Icon name="x" size={13} /></button>}</div>
    {weapon && <footer><span>Magazine</span><b>{knownCount(weapon.magazine)} <i>/ {knownCount(weapon.capacity)}</i></b></footer>}
  </section>;
  return <section className="inventory-armament" aria-label="Equipment and ammunition">
    <div className="inventory-armament__head"><span className="inventory__eyebrow">Weapons</span><span className={state?.busy || pending ? "is-busy" : ""}><i />{pending?.uncertain ? "Needs verification" : state?.busy || pending ? "Synchronizing…" : state?.ready ? "Ready" : "Unavailable"}</span></div>
    <div className="inventory-armament__layout">
      {card("right", state?.right)}{card("left", state?.left)}
      <div className="inventory-armament__stock"><span>{stock?.label ?? "Handgun rounds"} in your pockets</span><strong>{state?.ready ? knownCount(stock?.remaining) : "—"}<small>rounds</small></strong><p>Loaded magazines included · every shot spends one round from your inventory.</p></div>
      <div className="inventory-armament__tools"><button disabled={disabled || !state?.ready || !state?.right && !state?.left} onClick={() => performArmament("holster")}><Icon name="hand" size={13} />Holster weapons</button><button disabled={syncDisabled} onClick={() => performArmament("sync")}><Icon name="activity" size={13} />Synchronize</button>{!state?.ready && <button disabled={!!pending} onClick={() => { void refreshArmament(); }}>Refresh status</button>}</div>
    </div>
    <GrenadeEquipment inventoryBusy={inventoryBusy} />
    {(pending?.uncertain || state?.error || feedback) && <div className={`inventory-armament__feedback${pending?.uncertain || state?.error || feedback?.error ? " is-error" : ""}`} role="status"><Icon name={pending?.uncertain || state?.error || feedback?.error ? "triangle-alert" : "check"} size={13} /><span>{state?.error || feedback?.text}</span>{pending?.uncertain && <button onClick={retryArmament}>Check request</button>}</div>}
  </section>;
}

export function ArmamentItemActions({ item, mine, inventoryBusy }: { item: InventoryItem; mine: boolean; inventoryBusy: boolean }) {
  const state = useStore(s => s.armament), pending = useStore(s => s.armamentPending);
  const instanceId = weaponInstance(item);
  const disabled = inventoryBusy || !state || state.busy || !!pending;
  if (!mine) return <p className="inventory-armament-item__hint">Move this item into your pockets to use it.</p>;
  if (item.category === "ammo" && !item.name.endsWith("_box")) return <p className="inventory-armament-item__hint">Loose rounds. An equipped pistol or revolver loads from the rounds in your pockets; every shot spends one.</p>;
  if (item.category === "ammo") return <div className="inventory-armament-item">
    <button className="inventory-button inventory-button--primary" disabled={disabled || item.count < 1} onClick={() => performArmament("ammo", { slot: item.slot })}><Icon name="package-open" size={16} />Unpack one box</button>
    <p>Puts the box's rounds in your pockets as loose ammunition.</p>
  </div>;
  if (!instanceId) return <p className="inventory-armament-item__hint">This weapon has no valid serial number. Refresh your inventory before equipping it.</p>;
  const equipped = state?.right?.instanceId === instanceId ? "right" : state?.left?.instanceId === instanceId ? "left" : undefined;
  return <div className="inventory-armament-item">
    <small>Serial {instanceId.slice(0, 8)}{equipped ? ` · ${equipped === "right" ? "right hand" : "left hand"}` : " · In your pockets"}</small>
    {!equipped ? <>
      <button className="inventory-button inventory-button--primary" disabled={disabled || !state?.ready} onClick={() => performArmament("equip", { hand: "right", slot: item.slot, instanceId })}><Crosshair size={16} aria-hidden="true" />Equip right hand</button>
      <button className="inventory-button" disabled={disabled || !state?.ready} onClick={() => performArmament("equip", { hand: "left", slot: item.slot, instanceId })}><Crosshair size={16} aria-hidden="true" />Equip left hand</button>
    </> : <>
      <button className="inventory-button inventory-button--primary" disabled={disabled} onClick={() => performArmament("unequip", { hand: equipped, instanceId })}><Crosshair size={16} aria-hidden="true" />Store weapon</button>
      <button className="inventory-button" disabled={disabled} onClick={() => performArmament("unequip", { hand: equipped })}><Icon name="hand" size={16} />Unequip this hand</button>
    </>}
    <p>Loads from the matching rounds in your pockets. Only pistols and revolvers can be paired in two hands.</p>
  </div>;
}
