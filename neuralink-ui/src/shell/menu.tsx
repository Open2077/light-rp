/* The SAO menu model: column items and each item's sub-panel rows. Shared by
   the mouse UI and the keyboard navigation. */
import type { ReactNode } from "react";
import {
  Activity, Bell, BookUser, CircleUser, Contact as ContactIcon, Cpu, Flame, History, Info, Megaphone, MessageSquare, MessageSquarePlus,
  Palette, PenLine, Phone, PhoneCall, Radio, Settings as SettingsIcon, Star, UserPlus, UserRound, Users, Volume2, Grid3x3,
} from "lucide-react";
import type { State } from "@/bridge/protocol";
import type { MenuId, View } from "@/store/store";
import { AppIcon } from "@/components/Icon";

export interface ColumnItem {
  id: MenuId | "call";
  label: string;
  icon: ReactNode;
  badge?: number;
  color?: string;
  appId?: string;
}

export interface PanelRow {
  id: string;
  label: string;
  hint?: string;
  icon: ReactNode;
  badge?: number;
  view: View;
}

const I = 30; // column icon size
const R = 18; // row icon size

export function unreadTotal(state: State | null): number {
  return (state?.threads ?? []).reduce((n, t) => n + (t.unread > 0 ? t.unread : 0), 0);
}

/** Missed calls since the last time Recents was looked at. */
export function missedSince(state: State | null, seenAt: number): number {
  return (state?.recents ?? []).filter((r) => r.direction === "in" && r.status === "missed" && r.at > seenAt).length;
}

export function columnItems(state: State | null, missed: number, hasCall: boolean): ColumnItem[] {
  const items: ColumnItem[] = [];
  if (hasCall) items.push({ id: "call", label: "Call", icon: <PhoneCall size={I} strokeWidth={1.9} /> });
  items.push(
    { id: "status", label: "Status", icon: <UserRound size={I} strokeWidth={1.9} /> },
    { id: "phone", label: "Phone", icon: <Phone size={I} strokeWidth={1.9} />, badge: missed },
    { id: "messages", label: "Messages", icon: <MessageSquare size={I} strokeWidth={1.9} />, badge: unreadTotal(state) },
    { id: "contacts", label: "Contacts", icon: <BookUser size={I} strokeWidth={1.9} /> },
    { id: "social", label: "Screamsheet", icon: <Megaphone size={I} strokeWidth={1.9} />, badge: state?.social?.unread ?? 0 },
    { id: "settings", label: "Settings", icon: <SettingsIcon size={I} strokeWidth={1.9} /> },
  );
  for (const app of state?.apps ?? []) {
    items.push({ id: `app:${app.id}`, label: app.label, icon: <AppIcon name={app.icon} size={I} />, color: app.color, appId: app.id });
  }
  return items;
}

export function panelRows(menu: MenuId | null, state: State | null, missed: number): PanelRow[] {
  switch (menu) {
    case "status":
      return [{ id: "identity", label: "Identity", hint: state?.line?.number ?? "No line", icon: <ContactIcon size={R} />, view: { app: "status" } }];
    case "phone":
      return [
        { id: "dial", label: "Keypad", hint: "Dial a number", icon: <Grid3x3 size={R} />, view: { app: "phone", tab: "dial" } },
        { id: "recents", label: "Recents", hint: `${state?.recents.length ?? 0} calls`, icon: <History size={R} />, badge: missed, view: { app: "phone", tab: "recents" } },
        { id: "favorites", label: "Favorites", hint: `${state?.contacts.filter((c) => c.favorite).length ?? 0} linked`, icon: <Star size={R} />, view: { app: "phone", tab: "favorites" } },
      ];
    case "messages":
      return [
        { id: "inbox", label: "Inbox", hint: `${state?.threads.length ?? 0} threads`, icon: <MessageSquare size={R} />, badge: unreadTotal(state), view: { app: "messages", screen: "list" } },
        { id: "new", label: "New message", hint: "Number or contact", icon: <MessageSquarePlus size={R} />, view: { app: "messages", screen: "new" } },
        { id: "group", label: "New group", hint: "2 to 15 members", icon: <Users size={R} />, view: { app: "messages", screen: "group-new" } },
      ];
    case "contacts":
      return [
        { id: "all", label: "All contacts", hint: `${state?.contacts.length ?? 0} saved`, icon: <BookUser size={R} />, view: { app: "contacts", screen: "list", filter: "all" } },
        { id: "fav", label: "Favorites", hint: `${state?.contacts.filter((c) => c.favorite).length ?? 0} starred`, icon: <Star size={R} />, view: { app: "contacts", screen: "list", filter: "favorites" } },
        { id: "add", label: "Add contact", hint: "Name and number", icon: <UserPlus size={R} />, view: { app: "contacts", screen: "edit" } },
      ];
    case "social": {
      const unread = state?.social?.unread ?? 0;
      const handle = state?.social?.handle ?? "";
      return [
        { id: "pulse", label: "Pulse", hint: "Everyone, live", icon: <Radio size={R} />, view: { app: "social", screen: "feed", mode: "pulse" } },
        { id: "crew", label: "Crew", hint: "People you follow", icon: <Users size={R} />, view: { app: "social", screen: "feed", mode: "crew" } },
        { id: "hot", label: "Hot", hint: "Best of the last 24 h", icon: <Flame size={R} />, view: { app: "social", screen: "feed", mode: "hot" } },
        { id: "compose", label: "Compose", hint: "Scream to the city", icon: <PenLine size={R} />, view: { app: "social", screen: "compose" } },
        { id: "pings", label: "Pings", hint: unread ? `${unread} new` : "Cred, echoes, replies", icon: <Bell size={R} />, badge: unread, view: { app: "social", screen: "pings" } },
        { id: "heat", label: "Net Heat", hint: "Trending tags and districts", icon: <Activity size={R} />, view: { app: "social", screen: "heat" } },
        { id: "me", label: "My profile", hint: handle ? `@${handle}` : "Your screams", icon: <CircleUser size={R} />, view: { app: "social", screen: "profile", handle } },
      ];
    }
    case "settings":
      return [
        { id: "sound", label: "Sound", hint: "Ringtone, volume, DND", icon: <Volume2 size={R} />, view: { app: "settings", section: "sound" } },
        { id: "display", label: "Hologram", hint: "Accent, intensity", icon: <Palette size={R} />, view: { app: "settings", section: "display" } },
        { id: "about", label: "System", hint: "Neural-Link OS", icon: <Cpu size={R} />, view: { app: "settings", section: "about" } },
      ];
    default:
      return [];
  }
}

export const MENU_TITLES: Record<string, { title: string; icon: ReactNode }> = {
  status: { title: "Status", icon: <UserRound size={22} /> },
  phone: { title: "Phone", icon: <Phone size={22} /> },
  messages: { title: "Messages", icon: <MessageSquare size={22} /> },
  contacts: { title: "Contacts", icon: <BookUser size={22} /> },
  social: { title: "Screamsheet", icon: <Megaphone size={22} /> },
  settings: { title: "Settings", icon: <SettingsIcon size={22} /> },
  about: { title: "About", icon: <Info size={22} /> },
};

export function sameView(a: View | null | undefined, b: View): boolean {
  if (!a || a.app !== b.app) return false;
  return JSON.stringify(a) === JSON.stringify(b);
}

/** Whether a sub-panel row corresponds to the window currently on screen. */
export function rowMatches(row: PanelRow, base: View | null | undefined): boolean {
  if (!base || base.app !== row.view.app) return false;
  if (base.app === "phone" && row.view.app === "phone") return base.tab === row.view.tab;
  if (base.app === "settings" && row.view.app === "settings") return base.section === row.view.section;
  if (base.app === "contacts" && row.view.app === "contacts") {
    if (row.view.screen === "edit") return base.screen === "edit" && base.id == null;
    return base.screen === "list" && base.filter === row.view.filter;
  }
  if (base.app === "messages" && row.view.app === "messages") return base.screen === row.view.screen;
  if (base.app === "social" && row.view.app === "social") {
    if (base.screen === "feed" && row.view.screen === "feed") return base.mode === row.view.mode;
    if (base.screen === "profile" && row.view.screen === "profile") return base.handle === row.view.handle;
    if (base.screen === "compose") return row.view.screen === "compose" && base.replyTo == null && base.quoteOf == null;
    return base.screen === row.view.screen;
  }
  return base.app === row.view.app;
}
