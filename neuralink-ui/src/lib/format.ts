import type { Contact } from "@/bridge/protocol";

export const pad2 = (n: number) => String(Math.max(0, Math.floor(n))).padStart(2, "0");

/** Real-world clock "HH:MM" from Unix ms. */
export function hhmm(at: number): string {
  const d = new Date(at);
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

const DAY = 86_400_000;
export function startOfDay(at: number): number { const d = new Date(at); d.setHours(0, 0, 0, 0); return d.getTime(); }

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** "Today", "Yesterday", "Mon 12 Oct". */
export function dayLabel(at: number, now = Date.now()): string {
  const diff = Math.round((startOfDay(now) - startOfDay(at)) / DAY);
  if (diff <= 0) return "Today";
  if (diff === 1) return "Yesterday";
  const d = new Date(at);
  return `${WEEKDAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

/** Thread list stamp: time today, weekday this week, else date. */
export function listStamp(at: number, now = Date.now()): string {
  const diff = Math.round((startOfDay(now) - startOfDay(at)) / DAY);
  if (diff <= 0) return hhmm(at);
  if (diff === 1) return "Yesterday";
  const d = new Date(at);
  if (diff < 7) return WEEKDAYS[d.getDay()]!;
  return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

/** "now", "4 min", "2 h", then the list stamp. */
export function relative(at: number, now = Date.now()): string {
  const s = Math.max(0, (now - at) / 1000);
  if (s < 50) return "now";
  if (s < 3600) return `${Math.round(s / 60)} min ago`;
  if (s < 6 * 3600) return `${Math.round(s / 3600)} h ago`;
  return listStamp(at, now);
}

/** Call duration "m:ss" or "h:mm:ss". */
export function duration(seconds: number): string {
  const t = Math.max(0, Math.floor(seconds));
  const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), s = t % 60;
  return h > 0 ? `${h}:${pad2(m)}:${pad2(s)}` : `${m}:${pad2(s)}`;
}

/** Keep digits, insert the dash: "5550123" -> "555-0123". */
export function formatNumberInput(raw: string): string {
  const digits = raw.replace(/\D/g, "").slice(0, 7);
  return digits.length > 3 ? `${digits.slice(0, 3)}-${digits.slice(3)}` : digits;
}

export function initials(name: string): string {
  const parts = name.replace(/[^\p{L}\p{N} ]/gu, " ").trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "#";
  if (parts.length === 1) return parts[0]!.slice(0, 2).toUpperCase();
  return (parts[0]![0]! + parts[parts.length - 1]![0]!).toUpperCase();
}

/** Stable hue per string, for avatar tints. */
export function hueOf(key: string): number {
  let h = 0;
  for (let i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) >>> 0;
  return h % 360;
}

export function contactByNumber(contacts: Contact[], number: string): Contact | undefined {
  return contacts.find((c) => c.number === number);
}

export function displayName(contacts: Contact[], number: string, fallback?: string): string {
  return contactByNumber(contacts, number)?.name ?? (fallback && fallback !== number ? fallback : number);
}

export function clamp(v: number, lo: number, hi: number): number { return Math.min(hi, Math.max(lo, v)); }

/** Copy text: async clipboard when allowed, a hidden textarea otherwise (CEF). */
export async function copyText(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard?.writeText) { await navigator.clipboard.writeText(text); return true; }
  } catch { /* fall through */ }
  try {
    const ta = document.createElement("textarea");
    ta.value = text; ta.setAttribute("readonly", ""); ta.style.position = "fixed"; ta.style.opacity = "0";
    document.body.appendChild(ta); ta.select();
    const ok = document.execCommand("copy");
    ta.remove();
    return ok;
  } catch { return false; }
}
