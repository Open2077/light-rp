import { Crosshair } from "lucide-react";
import { Icon } from "@/design/components";
import { useStore } from "@/state/store";
import type { ArmamentHand, ArmamentWeapon, InventoryItem } from "@/bridge/protocol";
import { performArmament, refreshArmament, retryArmament, weaponInstance } from "./armament";
import "./armament.css";

const knownCount = (value?: number) => Number.isInteger(value) && value! >= 0 ? String(value) : "?";

export function ArmamentPanel({ inventoryBusy }: { inventoryBusy: boolean }) {
  const state = useStore(s => s.armament), pending = useStore(s => s.armamentPending), feedback = useStore(s => s.armamentFeedback);
  const disabled = inventoryBusy || !state || state.busy || !!pending;
  const syncDisabled = inventoryBusy || state?.busy || !!pending;
  const card = (hand: ArmamentHand, weapon?: ArmamentWeapon) => <section className={`inventory-armament__hand${weapon ? " is-equipped" : ""}`} aria-label={hand === "right" ? "Main droite" : "Main gauche"}>
    <header><span>{hand === "right" ? "Main droite" : "Main gauche"}</span></header>
    <div><Crosshair size={23} strokeWidth={1.4} aria-hidden="true" /><span><strong>{weapon?.label ?? "Aucune arme"}</strong><small>{weapon ? `N° ${weapon.instanceId.slice(0, 8)}` : "Sélectionnez un pistolet dans vos poches"}</small></span>
      {weapon && <button className="inventory-armament__remove" aria-label={`Retirer l'arme de la main ${hand === "right" ? "droite" : "gauche"}`} disabled={disabled} onClick={() => performArmament("unequip", { hand })}><Icon name="x" size={13} /></button>}</div>
    {weapon && <footer><span>Chargeur observé</span><b>{knownCount(weapon.magazine)} <i>/ {knownCount(weapon.capacity)}</i></b></footer>}
  </section>;
  return <section className="inventory-armament" aria-label="Équipement et munitions">
    <div className="inventory-armament__head"><span className="inventory__eyebrow">Équipement</span><span className={state?.busy || pending ? "is-busy" : ""}><i />{pending?.uncertain ? "À vérifier" : state?.busy || pending ? "Synchronisation…" : state?.ready ? "État serveur" : "Indisponible"}</span></div>
    <div className="inventory-armament__layout">
      {card("right", state?.right)}{card("left", state?.left)}
      <div className="inventory-armament__stock"><span>Stock pistolet commun</span><strong>{state?.ready ? knownCount(state.ammo?.pistol?.remaining) : "—"}<small>balles</small></strong><p>Chargeurs inclus · une seule réserve pour les deux mains.</p></div>
      <div className="inventory-armament__tools"><button disabled={disabled || !state?.ready || !state?.right && !state?.left} onClick={() => performArmament("holster")}><Icon name="hand" size={13} />Ranger les armes</button><button disabled={syncDisabled} onClick={() => performArmament("sync")}><Icon name="activity" size={13} />Synchroniser</button>{!state?.ready && <button disabled={!!pending} onClick={() => { void refreshArmament(); }}>Actualiser l'état</button>}</div>
    </div>
    {(pending?.uncertain || state?.error || feedback) && <div className={`inventory-armament__feedback${pending?.uncertain || state?.error || feedback?.error ? " is-error" : ""}`} role="status"><Icon name={pending?.uncertain || state?.error || feedback?.error ? "triangle-alert" : "check"} size={13} /><span>{state?.error || feedback?.text}</span>{pending?.uncertain && <button onClick={retryArmament}>Vérifier l'action</button>}</div>}
  </section>;
}

export function ArmamentItemActions({ item, mine, inventoryBusy }: { item: InventoryItem; mine: boolean; inventoryBusy: boolean }) {
  const state = useStore(s => s.armament), pending = useStore(s => s.armamentPending);
  const instanceId = weaponInstance(item);
  const disabled = inventoryBusy || !state || state.busy || !!pending;
  if (!mine) return <p className="inventory-armament-item__hint">Placez cet objet dans vos poches pour l'utiliser.</p>;
  if (item.category === "ammo") return <div className="inventory-armament-item">
    <button className="inventory-button inventory-button--primary" disabled={disabled || item.count < 1} onClick={() => performArmament("ammo", { slot: item.slot })}><Icon name="package-open" size={16} />Ouvrir une boîte</button>
    <p>Consomme une seule boîte. Le serveur crédite son contenu au stock commun.</p>
  </div>;
  if (!instanceId) return <p className="inventory-armament-item__hint">Cette arme n'a pas d'identifiant d'instance. Actualisez l'inventaire ; elle ne peut pas être équipée.</p>;
  const equipped = state?.right?.instanceId === instanceId ? "right" : state?.left?.instanceId === instanceId ? "left" : undefined;
  return <div className="inventory-armament-item">
    <small>N° {instanceId.slice(0, 8)}{equipped ? ` · Main ${equipped === "right" ? "droite" : "gauche"}` : " · Dans vos poches"}</small>
    {!equipped ? <>
      <button className="inventory-button inventory-button--primary" disabled={disabled || !state?.ready} onClick={() => performArmament("equip", { hand: "right", slot: item.slot, instanceId })}><Crosshair size={16} aria-hidden="true" />Équiper à droite</button>
      <button className="inventory-button" disabled={disabled || !state?.ready} onClick={() => performArmament("equip", { hand: "left", slot: item.slot, instanceId })}><Crosshair size={16} aria-hidden="true" />Équiper à gauche</button>
    </> : <button className="inventory-button" disabled={disabled} onClick={() => performArmament("unequip", { hand: equipped })}><Icon name="hand" size={16} />Retirer de cette main</button>}
    <p>Deux pistolets utilisent la même réserve. Le serveur vérifie la compatibilité de la paire.</p>
  </div>;
}
