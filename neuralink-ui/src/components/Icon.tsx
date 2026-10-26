/* Third-party app icons arrive as lucide names ("car-taxi-front", "Landmark").
   A curated set renders synchronously; anything else loads the full lucide
   icon table once, from a local chunk (no network), and falls back to a
   generic glyph meanwhile or when the name is unknown. */
import { useEffect, useState, type ComponentType } from "react";
import {
  AppWindow, Banknote, Bike, Bot, Briefcase, Building2, Calendar, Camera, Car, CarFront, CarTaxiFront, Cpu, CreditCard,
  Crosshair, Gamepad2, Gavel, Globe, HeartPulse, Home, Landmark, Map, MapPin, Music, Newspaper, Package, Pill, Radio,
  Shield, ShieldAlert, ShoppingBag, ShoppingCart, Siren, Skull, Star, Stethoscope, Truck, Utensils, Wallet, Wrench, Zap,
  type LucideProps,
} from "lucide-react";

type IconCmp = ComponentType<LucideProps>;

const CURATED: Record<string, IconCmp> = {
  AppWindow, Banknote, Bike, Bot, Briefcase, Building2, Calendar, Camera, Car, CarFront, CarTaxiFront, Cpu, CreditCard,
  Crosshair, Gamepad2, Gavel, Globe, HeartPulse, Home, Landmark, Map, MapPin, Music, Newspaper, Package, Pill, Radio,
  Shield, ShieldAlert, ShoppingBag, ShoppingCart, Siren, Skull, Star, Stethoscope, Truck, Utensils, Wallet, Wrench, Zap,
};

export function pascal(name: string): string {
  return name.trim().split(/[-_\s]+/).filter(Boolean).map((p) => p[0]!.toUpperCase() + p.slice(1)).join("");
}

let fullTable: Record<string, IconCmp> | null = null;
let fullLoad: Promise<Record<string, IconCmp>> | null = null;
function loadFull(): Promise<Record<string, IconCmp>> {
  fullLoad ??= import("./lucideAll").then((m) => (fullTable = m.icons)).catch(() => (fullTable = {}));
  return fullLoad;
}

export function AppIcon({ name, size = 30, strokeWidth = 1.9 }: { name: string; size?: number; strokeWidth?: number }) {
  const key = pascal(name || "app-window");
  const [, force] = useState(0);
  const Cmp = CURATED[key] ?? fullTable?.[key];
  useEffect(() => {
    if (!CURATED[key] && !fullTable) void loadFull().then(() => force((n) => n + 1));
  }, [key]);
  const C = Cmp ?? AppWindow;
  return <C size={size} strokeWidth={strokeWidth} />;
}
