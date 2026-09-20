import { useState } from "react";
import { Icon } from "@/design/components";
import bank from "./vehicle-images.json";

const images: Record<string, { file: string }> = bank.vehicles;
export function vehicleImage(key: string, override?: string) {
  if (override && /^img\/vehicles\/[a-z0-9][a-z0-9_-]*\.(?:jpg|jpeg|png|webp)$/.test(override)) return override;
  const asset = Object.hasOwn(images, key) ? images[key] : undefined;
  return asset ? `img/vehicles/${asset.file}` : undefined;
}
export function VehicleArt({ vehicle }: { vehicle: { key: string; label: string; image?: string } }) {
  const src = vehicleImage(vehicle.key, vehicle.image);
  const [failed, setFailed] = useState<string>();
  return src && failed !== src
    ? <img className="rental-art" src={src} alt={vehicle.label} draggable={false} decoding="async" loading="lazy" onError={() => setFailed(src)} />
    : <span className="rental-art-fallback"><Icon name="car" size={38} /><span>Preview unavailable</span></span>;
}
