import type { CSSProperties } from "react";
import {
  Activity, ArrowLeftRight, BadgeCheck, Banknote, Beef, Calendar, Car, Check, Clock, CreditCard, Landmark, Wallet, ChevronLeft, ChevronRight, CircleHelp,
  Droplet, FileText, Fuel, HeartPulse, IdCard, Info, Keyboard, KeyRound, Loader, MapPin,
  MessageSquare, Mic, MicOff, OctagonAlert, Package, Radio, Settings, Shield, ShieldAlert,
  Siren, Terminal, TriangleAlert, User, Users, X, Zap, CheckCheck, type LucideIcon,
} from "lucide-react";

/* Lucide, bundled (the design system loads it from a CDN; the in-game host serves
   only the resource's own files). Stroke-only, currentColor, 12–20px. Add a glyph
   here when a component needs it: the name is the Lucide kebab-case id. */
const GLYPHS: Record<string, LucideIcon> = {
  activity: Activity, "arrow-left-right": ArrowLeftRight, calendar: Calendar, clock: Clock, "credit-card": CreditCard, landmark: Landmark, wallet: Wallet, "badge-check": BadgeCheck, banknote: Banknote, beef: Beef, car: Car, check: Check,
  "check-check": CheckCheck, "chevron-left": ChevronLeft, "chevron-right": ChevronRight, "circle-help": CircleHelp,
  droplet: Droplet, "file-text": FileText, fuel: Fuel, "heart-pulse": HeartPulse, "id-card": IdCard, info: Info,
  keyboard: Keyboard, "key-round": KeyRound, loader: Loader, "map-pin": MapPin, "message-square": MessageSquare,
  mic: Mic, "mic-off": MicOff, "octagon-alert": OctagonAlert, package: Package, radio: Radio, settings: Settings,
  shield: Shield, "shield-alert": ShieldAlert, siren: Siren, terminal: Terminal, "triangle-alert": TriangleAlert,
  user: User, users: Users, x: X, zap: Zap,
};

export type IconName = keyof typeof GLYPHS | string;

export interface IconProps {
  name: IconName;
  size?: number;
  style?: CSSProperties;
  className?: string;
}

export function Icon({ name, size = 16, style, className }: IconProps) {
  const Glyph = GLYPHS[name];
  if (!Glyph) {
    return (
      <span aria-hidden="true" title={"missing icon: " + name} className={className}
        style={{ display: "inline-block", width: size, height: size, boxShadow: "inset 0 0 0 1px currentColor", opacity: .6, ...style }} />
    );
  }
  return <Glyph aria-hidden="true" className={className} size={size} strokeWidth={2} style={{ display: "block", flex: "0 0 auto", ...style }} />;
}
