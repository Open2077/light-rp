import { useState } from "react";
import type { InventoryItem } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { Crosshair } from "lucide-react";

// Templates supply resource-local art. Never load arbitrary metadata URLs or
// remote images inside the game's browser. Legacy/custom items keep their icon.
export function ItemArt({ item, size = "slot" }: { item: InventoryItem; size?: "slot" | "detail" | "drag" }) {
  const [failed, setFailed] = useState<string>();
  const image = typeof item.image === "string" && /^img\/items\/[a-z0-9][a-z0-9_-]*\.(png|webp)$/.test(item.image) ? item.image : undefined;
  return <span className={`inventory-art inventory-art--${size}`} aria-hidden="true">
    {image && failed !== image
      ? <img src={image} alt="" draggable={false} decoding="async" onError={() => setFailed(image)} />
      : item.category === "weapon" ? <Crosshair aria-hidden="true" size={size === "detail" ? 58 : size === "drag" ? 25 : 32} />
      : <Icon name={item.icon} size={size === "detail" ? 58 : size === "drag" ? 25 : 32} />}
  </span>;
}

export function ItemEffects({ item }: { item: InventoryItem }) {
  const entries = (["food", "drink", "health"] as const).filter(key => Number.isFinite(item.effects?.[key]) && item.effects![key]! > 0);
  if (!entries.length) return null;
  const labels = { food: "Food", drink: "Hydration", health: "Health" };
  const icons = { food: "sandwich", drink: "droplet", health: "heart-pulse" };
  return <div className="inventory-effects" aria-label="Effects per item">
    {entries.map(key => <span key={key} title={`${labels[key]} restored per item, up to the maximum`}><Icon name={icons[key]} size={13} /><span>{labels[key]}</span><b>+{item.effects![key]}</b></span>)}
  </div>;
}
