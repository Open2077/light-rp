import * as THREE from "three";
import { iconSvg } from "./icons";

// Blips drawn as DOM over the canvas: crisp icons and labels at any zoom, hit-testable,
// themed by CSS. One overlay per view (full map, minimap); each frame the overlay
// projects its blips with that view's camera.

export interface Blip {
  id: string;
  x: number; y: number; z?: number;
  icon?: string;
  color?: string;
  label?: string;
  description?: string;
  category?: string;
  scale?: number;
  map?: boolean; // shown on the full map (default true)
  minimap?: boolean; // shown on the minimap (default true)
  edge?: boolean; // pinned to the minimap's edge when out of range
  pulse?: boolean;
  heading?: number; // game yaw: an arrow instead of an icon (players, vehicles)
  routable?: boolean; // the card offers "Set route" (default true)
  priority?: number;
  owner?: string;
}

interface Slot { el: HTMLElement; blip: Blip; key: string; x: number; y: number; clamped: boolean }

const tmp = new THREE.Vector3();
const tmp2 = new THREE.Vector3();

export class MarkerLayer {
  readonly root: HTMLElement;
  private slots = new Map<string, Slot>();
  hiddenCategories = new Set<string>();
  showLabels: "always" | "zoom" | "never" = "zoom";
  onClick: (b: Blip) => void = () => {};
  onHover: (b: Blip | null) => void = () => {};
  /** The layout changed without the camera moving (a group opened or closed). */
  onChange: () => void = () => {};
  // Blips closer than this on screen are one marker with a count; hovering it on the full
  // map fans them out around it, each with its label, hoverable and clickable.
  private expanded: string | null = null;
  private collapseTimer = 0;
  // a group closing: its members fold back for a moment before they hide
  private closing: { key: string; until: number } | null = null;
  /** Where the wheel goes when it turns over a blip (the map's canvas): blips must not eat the zoom. */
  wheelTarget: HTMLElement | null = null;

  constructor(parent: HTMLElement, readonly mode: "map" | "minimap") {
    this.root = document.createElement("div");
    this.root.className = `m3-markers m3-markers--${mode}`;
    parent.appendChild(this.root);
    this.root.addEventListener("wheel", (e) => {
      if (!this.wheelTarget) return;
      e.preventDefault();
      this.wheelTarget.dispatchEvent(new WheelEvent("wheel", {
        deltaX: e.deltaX, deltaY: e.deltaY, deltaZ: e.deltaZ, deltaMode: e.deltaMode,
        clientX: e.clientX, clientY: e.clientY, ctrlKey: e.ctrlKey, shiftKey: e.shiftKey, altKey: e.altKey, bubbles: true, cancelable: true,
      }));
    }, { passive: false });
  }

  sync(blips: Iterable<Blip>): void {
    const seen = new Set<string>();
    for (const b of blips) {
      if (this.mode === "map" && b.map === false) continue;
      if (this.mode === "minimap" && b.minimap === false) continue;
      seen.add(b.id);
      const key = `${b.icon}|${b.color}|${b.label}|${b.pulse}|${b.heading !== undefined}|${b.scale}`;
      let s = this.slots.get(b.id);
      if (!s) {
        const el = document.createElement("div");
        el.className = "m3-blip";
        el.addEventListener("click", (e) => { e.stopPropagation(); this.onClick(this.slots.get(b.id)!.blip); });
        el.addEventListener("pointerenter", () => {
          this.onHover(this.slots.get(b.id)!.blip);
          window.clearTimeout(this.collapseTimer);
          if (el.dataset.group && this.mode === "map" && this.expanded !== el.dataset.group) { this.expanded = el.dataset.group; this.onChange(); }
        });
        el.addEventListener("pointerleave", () => {
          this.onHover(null);
          if (!this.expanded) return;
          window.clearTimeout(this.collapseTimer);
          this.collapseTimer = window.setTimeout(() => {
            if (this.expanded) this.closing = { key: this.expanded, until: performance.now() + 200 };
            this.expanded = null;
            this.onChange();
            window.setTimeout(() => this.onChange(), 220); // hide them once folded
          }, 300);
        });
        this.root.appendChild(el);
        s = { el, blip: b, key: "", x: 0, y: 0, clamped: false };
        this.slots.set(b.id, s);
      }
      s.blip = b;
      if (s.key !== key) {
        s.key = key;
        const arrow = b.heading !== undefined;
        s.el.innerHTML = `<i class="m3-blip__pin${arrow ? " is-arrow" : ""}">${arrow ? '<svg viewBox="0 0 24 24" width="20" height="20"><path d="M12 3 19 20 12 16 5 20z" fill="currentColor"/></svg>' : iconSvg(b.icon, 18)}</i>${b.label ? `<b class="m3-blip__label">${escapeHtml(b.label)}</b>` : ""}<em class="m3-blip__count"></em>`;
        s.el.style.setProperty("--blip-color", b.color ?? "var(--m3-accent)");
        s.el.style.setProperty("--blip-scale", String(b.scale ?? 1));
        s.el.classList.toggle("is-pulse", !!b.pulse);
      }
    }
    for (const [id, s] of this.slots) if (!seen.has(id)) { s.el.remove(); this.slots.delete(id); }
  }

  /** rect = the view's rectangle in page pixels. */
  project(camera: THREE.PerspectiveCamera, rect: { x: number; y: number; w: number; h: number }, opts: { distance: number; edgeInset?: number; rotate?: number }): void {
    const inset = opts.edgeInset ?? 14;
    const labelsOn = this.showLabels === "always" || (this.showLabels === "zoom" && opts.distance < 1800);
    const dpr = window.devicePixelRatio || 1;
    const place = (s: Slot, x: number, y: number) => {
      // whole device pixels: a 1 px border sliding across pixel boundaries flickers
      s.el.style.transform = `translate(${(Math.round(x * dpr) / dpr).toFixed(3)}px, ${(Math.round(y * dpr) / dpr).toFixed(3)}px)`;
    };
    const shown: Slot[] = [];
    for (const s of this.slots.values()) {
      const b = s.blip;
      const hiddenCat = b.category && this.hiddenCategories.has(b.category);
      tmp.set(b.x, (b.z ?? 0) + 2, -b.y).project(camera);
      let x = rect.x + (tmp.x * 0.5 + 0.5) * rect.w;
      let y = rect.y + (-tmp.y * 0.5 + 0.5) * rect.h;
      const behind = tmp.z > 1;
      let out = behind || tmp.x < -1 || tmp.x > 1 || tmp.y < -1 || tmp.y > 1;
      let clamped = false;
      if (out && this.mode === "minimap" && b.edge) {
        // pin to the edge, in the direction of the blip
        const cx = rect.x + rect.w / 2, cy = rect.y + rect.h / 2;
        let dx = x - cx, dy = y - cy;
        if (behind) { dx = -dx; dy = -dy; }
        const k = Math.min((rect.w / 2 - inset) / Math.abs(dx || 1e-6), (rect.h / 2 - inset) / Math.abs(dy || 1e-6));
        x = cx + dx * k; y = cy + dy * k;
        out = false; clamped = true;
      }
      const visible = !out && !hiddenCat;
      s.el.style.display = visible ? "" : "none";
      if (!visible) continue;
      s.x = x; s.y = y; s.clamped = clamped;
      shown.push(s);
      place(s, x, y);
      s.el.classList.toggle("is-edge", clamped);
      s.el.classList.toggle("show-label", labelsOn || b.priority === 2);
      if (b.heading !== undefined) {
        // screen angle of the heading: project a point a few metres ahead
        const a = (b.heading * Math.PI) / 180;
        tmp.set(b.x, b.z ?? 0, -b.y).project(camera);
        tmp2.set(b.x - Math.sin(a) * 10, b.z ?? 0, -(b.y + Math.cos(a) * 10)).project(camera);
        // the arrow points up; CSS rotates clockwise: angle = atan2(screen dx, -screen dy)
        const ang = Math.atan2((tmp2.x - tmp.x) * rect.w, (tmp2.y - tmp.y) * rect.h);
        (s.el.firstElementChild as HTMLElement).style.transform = `rotate(${ang.toFixed(3)}rad)`;
      }
    }
    this.group(shown, place);
  }

  /**
   * Blips overlapping on screen become one marker: the most important one with a count.
   * The player's arrow, other players, the waypoint and edge-pinned blips stay apart.
   */
  private group(shown: Slot[], place: (s: Slot, x: number, y: number) => void): void {
    const radius = this.mode === "map" ? 30 : 15;
    const free = shown
      .filter((s) => !s.clamped && s.blip.heading === undefined && s.blip.priority !== 2)
      .sort((a, b) => (b.blip.priority ?? 0) - (a.blip.priority ?? 0) || (a.blip.id < b.blip.id ? -1 : 1));
    const taken = new Set<Slot>();
    let open = false;
    for (const s of free) {
      if (taken.has(s)) continue;
      const members = [s];
      taken.add(s);
      for (const t of free) if (!taken.has(t) && Math.hypot(t.x - s.x, t.y - s.y) < radius) { members.push(t); taken.add(t); }
      const count = s.el.querySelector(".m3-blip__count") as HTMLElement | null;
      if (members.length === 1) {
        delete s.el.dataset.group;
        s.el.classList.remove("has-group", "in-fan");
        continue;
      }
      const key = members.map((m) => m.blip.id).sort().join("|");
      const fanned = this.mode === "map" && this.expanded === key;
      const folding = !fanned && this.closing?.key === key && performance.now() < this.closing.until;
      open ||= fanned;
      members.forEach((m, i) => {
        // a column centred on the group's place, labels to the right: nothing overlaps
        const dy = (i - (members.length - 1) / 2) * 36;
        m.el.dataset.group = key;
        // the offset back to the group's place, for the unfold / fold animations
        m.el.style.setProperty("--fan-y", `${-dy}px`);
        if (fanned && !m.el.classList.contains("in-fan")) m.el.classList.add("fan-in");
        m.el.classList.toggle("in-fan", fanned);
        m.el.classList.toggle("fan-out", folding);
        if (!fanned) m.el.classList.remove("fan-in");
        m.el.classList.toggle("has-group", !fanned && !folding && i === 0);
        if (fanned || folding) {
          place(m, s.x, s.y + dy);
          m.el.classList.toggle("show-label", fanned);
        } else if (i === 0) {
          place(m, s.x, s.y);
          m.el.classList.toggle("show-label", false);
        } else m.el.style.display = "none";
      });
      if (count) count.textContent = String(members.length);
    }
    if (this.expanded && !open) this.expanded = null; // the group no longer exists
  }

  clear(): void { for (const s of this.slots.values()) s.el.remove(); this.slots.clear(); }
}

export function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}
