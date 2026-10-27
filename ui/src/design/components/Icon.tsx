import type { CSSProperties } from "react";
import {
  Activity, Apple, ArrowLeftRight, BadgeCheck, Bandage, Banknote, Battery, Beef, Box, BriefcaseMedical, Calendar, Candy, Car, Check, Cigarette, Clock, Coffee, CreditCard, CupSoda, Pizza, Soup, Fan, Trash2,
  Briefcase, Flame, Footprints, Hammer, Hand, Landmark, PackageOpen, Pill, Sandwich, Smartphone, Wallet, Watch, Wrench, ChevronLeft, ChevronRight, CircleHelp,
  Droplet, FileText, Fuel, HeartPulse, IdCard, Info, Keyboard, KeyRound, Loader, MapPin,
  MessageSquare, Mic, MicOff, OctagonAlert, Package, Radio, Settings, Shield, ShieldAlert,
  Siren, Terminal, TriangleAlert, User, Users, Utensils, X, Zap, CheckCheck, Search, ArrowDown, ArrowRight, Backpack, Split, Video,
  Lock, LockOpen, ShoppingCart, MessageCircle, Coins, Send, Route, Gauge, Plus, MousePointerClick,
  House, BookOpen, Building2, Navigation, Recycle, Bike, Timer, ArrowLeft, ListChecks, Scale, Shirt, Glasses, Eye, Crown, UserPlus, UserMinus, LogOut, Undo2, Swords, type LucideIcon,
} from "lucide-react";

/* Lucide, bundled (the design system loads it from a CDN; the in-game host serves
   only the resource's own files). Stroke-only, currentColor, 12–20px. Add a glyph
   here when a component needs it: the name is the Lucide kebab-case id. */
const GLYPHS: Record<string, LucideIcon> = {
  lock: Lock, "lock-open": LockOpen, "shopping-cart": ShoppingCart, "message-circle": MessageCircle, coins: Coins, send: Send, route: Route, gauge: Gauge, plus: Plus, "mouse-pointer-click": MousePointerClick,
  video: Video, fan: Fan, "trash-2": Trash2, utensils: Utensils,
  "briefcase-medical": BriefcaseMedical, coffee: Coffee, pizza: Pizza, soup: Soup,
  search: Search, "arrow-down": ArrowDown, "arrow-right": ArrowRight, backpack: Backpack, split: Split,
  activity: Activity, "arrow-left-right": ArrowLeftRight, calendar: Calendar, clock: Clock, footprints: Footprints,
  apple: Apple, bandage: Bandage, battery: Battery, box: Box, candy: Candy, cigarette: Cigarette, "cup-soda": CupSoda, flame: Flame, hammer: Hammer,
  briefcase: Briefcase, hand: Hand, "package-open": PackageOpen, pill: Pill, sandwich: Sandwich, smartphone: Smartphone, watch: Watch, wrench: Wrench, "credit-card": CreditCard, landmark: Landmark, wallet: Wallet, "badge-check": BadgeCheck, banknote: Banknote, beef: Beef, car: Car, check: Check,
  "check-check": CheckCheck, "chevron-left": ChevronLeft, "chevron-right": ChevronRight, "circle-help": CircleHelp,
  droplet: Droplet, "file-text": FileText, fuel: Fuel, "heart-pulse": HeartPulse, "id-card": IdCard, info: Info,
  keyboard: Keyboard, "key-round": KeyRound, loader: Loader, "map-pin": MapPin, "message-square": MessageSquare,
  mic: Mic, "mic-off": MicOff, "octagon-alert": OctagonAlert, package: Package, radio: Radio, settings: Settings,
  shield: Shield, "shield-alert": ShieldAlert, siren: Siren, terminal: Terminal, "triangle-alert": TriangleAlert,
  user: User, users: Users, x: X, zap: Zap,
  house: House, "book-open": BookOpen, "building-2": Building2, navigation: Navigation, recycle: Recycle, bike: Bike,
  timer: Timer, "arrow-left": ArrowLeft, "list-checks": ListChecks, scale: Scale, shirt: Shirt, glasses: Glasses, eye: Eye,
  crown: Crown, "user-plus": UserPlus, "user-minus": UserMinus, "log-out": LogOut, "undo-2": Undo2, swords: Swords,
};

export type IconName = keyof typeof GLYPHS | string;

export interface IconProps {
  name: IconName;
  size?: number;
  style?: CSSProperties;
  className?: string;
}

export function Icon({ name, size = 16, style, className }: IconProps) {
  const Glyph = GLYPHS[name] ?? GLYPHS.package!;
  if (!Glyph) {
    return (
      <span aria-hidden="true" title={"missing icon: " + name} className={className}
        style={{ display: "inline-block", width: size, height: size, boxShadow: "inset 0 0 0 1px currentColor", opacity: .6, ...style }} />
    );
  }
  return <Glyph aria-hidden="true" className={className} size={size} strokeWidth={2} style={{ display: "block", flex: "0 0 auto", ...style }} />;
}
