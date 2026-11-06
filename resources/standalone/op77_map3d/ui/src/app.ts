import * as THREE from "three";
import { DEFAULT_CONFIG, deepMerge, type MapConfig } from "./config";
import { on, emit } from "./bridge";
import { loadMapData, loadRoadData, type MapData } from "./data";
import { World } from "./world";
import { MapControls, keyName } from "./controls";
import { RoadGraph, progressOn, type Route, type Maneuver } from "./gps";
import { RouteView } from "./route";
import { MarkerLayer, escapeHtml, type Blip } from "./markers";
import { iconSvg, maneuverSvg } from "./icons";
import { formatDistance, toScene, type GamePos } from "./coords";
import { HoloGps } from "./holo";
import { InfluenceLayer, type InfluenceZone } from "./influence";
import { AreaLayer, areaUniforms } from "./areas";
import { inGame } from "./bridge";

// The display quality (the player's choice, kept by Lua in KVP): "performance" is a flat
// 2D map seen from straight above, cheap materials, the buildings' roofs only, no running
// effect and no antialiasing; "quality" the 3D city with every effect.
export type Quality = "performance" | "quality";

interface PlayerState { x: number; y: number; z: number; yaw: number; camYaw: number; speed: number; vehicle: boolean; valid: boolean }

const DISTRICT_NAMES: Record<string, string> = {
  city_center: "CITY CENTER", watson: "WATSON", westbrook: "WESTBROOK", heywood: "HEYWOOD",
  santo_domingo: "SANTO DOMINGO", pacifica: "PACIFICA", ep1_dogtown: "DOGTOWN", ep1_spaceport: "NCX SPACEPORT",
};

export class MapApp {
  cfg: MapConfig = DEFAULT_CONFIG;
  private renderer!: THREE.WebGLRenderer;
  private scene = new THREE.Scene();
  private mapCam = new THREE.PerspectiveCamera(42, 1, 1, 50000);
  private miniCam = new THREE.PerspectiveCamera(48, 1, 1, 50000);
  private controls!: MapControls;
  private world!: World;
  private routeView = new RouteView();
  private graph!: RoadGraph;
  private data!: MapData;
  private player: PlayerState = { x: -1450, y: 140, z: 20, yaw: 0, camYaw: 0, speed: 0, vehicle: false, valid: false };
  private playerBlip: Blip = { id: "__player", x: 0, y: 0, z: 0, heading: 0, label: "", category: "__self", priority: 2, color: "var(--m3-accent)" };
  private blips = new Map<string, Blip>();
  private waypoint: (GamePos & { z: number }) | null = null;
  private route: Route | null = null;
  private routeHint = 0;
  private offSince = 0;
  private lastReroute = 0;
  private arrivedFor: Route | null = null;
  private open = false;
  private closing = false; // the closing animation still plays (the full map keeps drawing)
  private animTimer = 0;
  private minimapVisible = true;
  private selected: Blip | null = null;
  private hover: Blip | null = null;
  private clock = new THREE.Clock();
  // "mini" draws only the minimap (its own small surface), "full" only the open map (a
  // surface hidden while closed), "both" is one page doing both (the browser preview).
  private role: "both" | "mini" | "full" | "holo" = "both";
  private quality: Quality = "performance";
  // false: the player never chose, the open map asks first (Lua says so in map3d:quality)
  private qualityChosen = true;
  private qualityPick: Quality = "performance";
  // performance mode: the same views from straight above, without perspective
  private mapOrtho = new THREE.OrthographicCamera(-1, 1, 1, -1, -6000, 20000);
  private miniOrtho = new THREE.OrthographicCamera(-1, 1, 1, -1, -6000, 20000);
  // quality mode draws through a multisampled target: the canvas has no antialiasing of
  // its own, so performance mode pays none
  private msaa: THREE.WebGLRenderTarget | null = null;
  private blit: { scene: THREE.Scene; cam: THREE.OrthographicCamera; mat: THREE.ShaderMaterial } | null = null;
  private bufSize = new THREE.Vector2();
  // only the player moved: the open map in performance mode moves its arrow and redraws
  // the city a few times a second
  private markersDirty = false;
  private holo: HoloGps | null = null;
  private lastHolo = 0;
  // influence zones: the server's switch and zones, a resource's switch (the player's own
  // is prefs.layers.influence), the layer and its labels on the open map
  private influence: InfluenceLayer | null = null;
  private influenceState: { enabled: boolean; zones: InfluenceZone[]; levels: { min: number; id: string; label: string }[] } = { enabled: false, zones: [], levels: [] };
  private influenceAllowed = true;
  private influenceAt = 0;
  private zoneEls = new Map<string, HTMLElement>();
  // areas (polygons of any resource): kept from the first message, drawn by the world's
  // shaders once the city is loaded
  private areaU = areaUniforms();
  private areas = new AreaLayer(this.areaU);
  // what the player switched on or off (HUD parts, layers, legend categories), kept
  private prefs: Prefs = loadPrefs();
  private canvasKey = "";
  private lastFull = 0;
  private navHtml = "";
  private navLeft = ""; // "2.7 km · 3 min" under the minimap while a route runs
  private barHtml = "";
  private results: { label: string; sub: string; icon: string; color?: string; x: number; y: number; z: number; blip?: Blip; distance?: number; score: number }[] = [];
  private resultIndex = 0;
  private lastMini = 0;
  // jamming: 0 = clear, 1 = nothing of the map is left (static and NO SIGNAL)
  private jam = 0;
  // The open map's zoom, orientation and tilt, kept from one opening to the next (and in
  // the page's storage, so a reload keeps them too).
  private savedView: { distance: number; yaw: number; pitch: number } | null = loadView();
  // The minimap's view glides between player updates (they arrive 30 times a second at best):
  // eased toward the last position pushed a little ahead along the measured velocity.
  private view = { x: 0, y: 0, z: 0, yaw: 0, radius: 0, tilt: 0, init: false, frameAt: 0, settling: false };
  private vel = { x: 0, y: 0 };
  // minimap zoom from the zoom keys: a factor on the radius, remembered by the page
  private miniZoom = loadZoom();
  private zoomDir = 0;
  private playerAt = 0;
  private lastInfo = 0;
  private dirty = true;
  private raycaster = new THREE.Raycaster();
  private ready = false;

  // DOM
  private root: HTMLElement;
  private canvas!: HTMLCanvasElement;
  private mapLayer!: MarkerLayer;
  private miniLayer!: MarkerLayer;
  private ui: Record<string, HTMLElement> = {};
  private districtEls: { el: HTMLElement; pos: THREE.Vector3; name: string }[] = [];

  constructor(root: HTMLElement) { this.root = root; }

  async start(): Promise<void> {
    this.buildDom();
    on("map3d:config", (c) => this.setConfig(c));
    on("map3d:theme", (t) => this.setConfig({ theme: t }));
    let roleKnown: () => void = () => {};
    const roleReady = new Promise<void>((resolve) => { roleKnown = resolve; });
    on("map3d:role", (p) => {
      if (p?.role === "mini" || p?.role === "full" || p?.role === "both" || p?.role === "holo") { this.role = p.role; this.applyMode(); }
      roleKnown();
    });
    on("map3d:quality", (p) => this.setQuality(p));
    on("map3d:holo", (p) => this.holo?.setRoute(p && Array.isArray(p.pts) ? p : null));
    on("map3d:jam", (p) => this.setJam(p));
    on("map3d:influence", (p) => this.setInfluence(p));
    on("map3d:influenceVisible", (p) => { this.influenceAllowed = p?.visible !== false; this.dirty = true; });
    // the open map's choices reach the minimap through Lua
    on("map3d:prefs", (p) => { if (this.role !== "full" && this.role !== "both") { this.prefs = normalizePrefs(p); this.applyPrefs(); } });
    on("map3d:open", (p) => this.setOpen(true, p));
    on("map3d:close", () => this.setOpen(false));
    on("map3d:player", (p) => this.setPlayer(p));
    on("map3d:blips", (p) => this.setBlips(p));
    on("map3d:blip", (b) => this.upsertBlip(b));
    on("map3d:blipRemove", (p) => { this.blips.delete(String(p?.id)); this.syncBlips(); });
    on("map3d:area", (p) => { if (this.areas.upsert(p)) this.dirty = true; });
    on("map3d:areas", (p) => {
      if (p?.clear) this.areas.clear();
      if (Array.isArray(p?.remove)) this.areas.remove(p.remove);
      this.dirty = true;
    });
    on("map3d:waypoint", (p) => this.setWaypoint(p && typeof p.x === "number" ? p : null, false));
    on("map3d:route", (p) => this.setWaypoint(p && typeof p.x === "number" ? p : null, false));
    on("map3d:minimap", (p) => { this.minimapVisible = p?.visible !== false; this.applyMode(); });
    on("map3d:focus", (p) => { if (p && typeof p.x === "number") this.focusOn(p, p.distance); });
    on("map3d:miniZoom", (p) => {
      const dir = p?.dir === 1 ? 1 : p?.dir === -1 ? -1 : 0;
      if (p?.down) { this.zoomDir = dir; this.miniZoom = clampZoom(this.miniZoom * (dir > 0 ? 0.88 : 1.14)); }
      else if (this.zoomDir === dir) { this.zoomDir = 0; saveZoom(this.miniZoom); }
      this.dirty = true;
    });
    emit("map3d:hello", {});
    // the holographic GPS surface needs no city data: wait for the role before loading
    if (inGame) await Promise.race([roleReady, new Promise((r) => setTimeout(r, 2500))]);
    if (this.role === "holo") {
      this.root.classList.add("is-holo-role");
      this.ui.loading.classList.add("is-done");
      this.holo = new HoloGps(this.root);
      this.holo.setAccent(this.cfg.theme.accent);
      loadRoadData().then((roads) => this.holo?.setRoads(roads)).catch((e) => emit("map3d:error", { message: String(e) }));
      return;
    }
    try {
      this.data = await loadMapData((label, f) => this.loading(label, f));
    } catch (e) {
      this.ui.loading.innerHTML = `<b>MAP DATA</b><span>${escapeHtml(String(e))}</span>`;
      emit("map3d:error", { message: String(e) });
      return;
    }
    this.initScene();
    this.ready = true;
    this.ui.loading.classList.add("is-done");
    this.applyMode();
    emit("map3d:ready", { lanes: this.graph.lanes, buildings: this.data.manifest.buildings.count, vw: window.innerWidth, vh: window.innerHeight });
    this.applyPrefs();
    if (this.role === "full" || this.role === "both") emit("map3d:prefs", this.prefs);
    this.loop();
  }

  // ---------------------------------------------------------------- config
  setConfig(patch: unknown): void {
    this.cfg = deepMerge(this.cfg, patch);
    const t = this.cfg.theme;
    const s = this.root.style;
    s.setProperty("--m3-accent", t.accent);
    s.setProperty("--m3-accent-soft", t.accentSoft);
    s.setProperty("--m3-bg", t.background);
    s.setProperty("--m3-panel", t.panel);
    s.setProperty("--m3-text", t.text);
    s.setProperty("--m3-dim", t.textDim);
    s.setProperty("--m3-danger", t.danger);
    s.setProperty("--m3-mini-size", `${this.cfg.minimap.size}px`);
    this.root.dataset.anchor = this.cfg.minimap.anchor;
    this.root.dataset.shape = this.cfg.minimap.shape;
    this.ui.title && (this.ui.title.textContent = this.cfg.map.title);
    this.ui.subtitle && (this.ui.subtitle.textContent = this.cfg.map.subtitle);
    if (this.world) {
      this.world.applyTheme(t);
      this.world.setLayerVisible("buildings", this.cfg.map.buildings && this.prefs.layers.buildings !== false);
      this.world.setLayerVisible("roadBorders", this.cfg.map.roadBorders && this.prefs.layers.roadBorders !== false);
      this.world.setLayerVisible("metro", this.prefs.layers.metro !== false);
      this.renderer.setClearColor(t.background, 1);
      this.controls.minDistance = this.cfg.map.minDistance;
      this.controls.maxDistance = this.cfg.map.maxDistance;
      this.controls.maxPitch = this.perf ? 0 : THREE.MathUtils.degToRad(this.cfg.map.maxPitch);
    }
    this.renderChooser();
    this.routeView.setColors(t.accent);
    this.influence?.setLook(this.cfg.influence);
    this.holo?.setAccent(t.accent);
    this.routeView.setWidth(this.cfg.gps.routeWidth);
    this.routeView.setSpeed(this.cfg.gps.animationSpeed);
    this.buildLegend();
    this.applyMode();
    this.dirty = true;
  }

  // ---------------------------------------------------------------- DOM
  private el(tag: string, cls: string, parent: HTMLElement, html = ""): HTMLElement {
    const e = document.createElement(tag);
    e.className = cls;
    if (html) e.innerHTML = html;
    parent.appendChild(e);
    return e;
  }

  private buildDom(): void {
    const r = this.root;
    r.classList.add("m3");
    this.canvas = document.createElement("canvas");
    this.canvas.className = "m3-canvas";
    r.appendChild(this.canvas);
    const ui = this.ui;
    ui.full = this.el("div", "m3-full", r);
    this.mapLayer = new MarkerLayer(ui.full, "map");
    // area labels sit under the blips (the markers' layer comes after them)
    ui.areas = document.createElement("div");
    ui.areas.className = "m3-areas";
    ui.full.insertBefore(ui.areas, this.mapLayer.root);
    this.areas.labelRoot = ui.areas;
    ui.districts = this.el("div", "m3-districts", ui.full);
    ui.zones = this.el("div", "m3-zones", ui.full);
    // the jam overlay sits over the map and its blips, under the panels
    ui.jamFull = this.el("div", "m3-jam", ui.full, JAM_HTML);
    ui.header = this.el("header", "m3-header", ui.full,
      `<span class="m3-tag">MAP</span><div><b class="m3-title"></b><small class="m3-subtitle"></small></div>`);
    ui.title = ui.header.querySelector(".m3-title")!;
    ui.subtitle = ui.header.querySelector(".m3-subtitle")!;
    ui.readout = this.el("div", "m3-readout", ui.full);
    ui.legend = this.el("aside", "m3-legend", ui.full);
    ui.card = this.el("section", "m3-card", ui.full);
    ui.routeBar = this.el("div", "m3-routebar", ui.full, `<div class="m3-routebar__info"></div><button class="m3-routebar__clear" data-clear></button>`);
    ui.routeInfo = ui.routeBar.querySelector(".m3-routebar__info")!;
    ui.routeClear = ui.routeBar.querySelector("[data-clear]")!;
    ui.routeClear.addEventListener("click", () => this.setWaypoint(null, true));
    ui.search = this.el("div", "m3-search", ui.full,
      `<label>${iconSvg("search", 17)}<input type="text" spellcheck="false" autocomplete="off" maxlength="48"><kbd>/</kbd></label><ol class="m3-results"></ol>`);
    ui.searchInput = ui.search.querySelector("input")!;
    ui.searchList = ui.search.querySelector("ol")!;
    this.initSearch();
    ui.tools = this.el("nav", "m3-tools", ui.full, `
      <button data-act="zoomin" title="Zoom in">+</button>
      <button data-act="zoomout" title="Zoom out">&minus;</button>
      <button data-act="north" class="m3-compass" title="North up"><i>N</i></button>
      <button data-act="pitch" title="2D / 3D" class="m3-pitch">3D</button>
      <button data-act="recenter" title="Recenter">${iconSvg("crosshair", 18)}</button>`);
    ui.tools.addEventListener("click", (e) => this.tool((e.target as HTMLElement).closest("button")?.dataset.act));
    ui.help = this.el("footer", "m3-help", ui.full);
    ui.close = this.el("button", "m3-close", ui.full, `<kbd>ESC</kbd> CLOSE`);
    ui.close.addEventListener("click", () => emit("map3d:close", {}));
    // the first opening asks how the map is drawn
    ui.chooser = this.el("div", "m3-quality", ui.full);
    ui.chooser.addEventListener("click", (e) => {
      const b = (e.target as HTMLElement).closest<HTMLElement>("[data-pick]");
      if (b) this.chooseQuality(b.dataset.pick as Quality);
    });
    ui.chooser.addEventListener("pointerover", (e) => {
      const b = (e.target as HTMLElement).closest<HTMLElement>("[data-pick]");
      if (b) this.highlightPick(b.dataset.pick as Quality);
    });
    // minimap
    ui.mini = this.el("div", "m3-mini", r);
    ui.miniFrame = this.el("div", "m3-mini__frame", ui.mini);
    this.miniLayer = new MarkerLayer(ui.mini, "minimap");
    this.miniLayer.showLabels = "never";
    ui.miniNorth = this.el("i", "m3-mini__north", ui.mini, `<svg viewBox="0 0 10 10" width="10" height="10"><path d="M5 0 10 9 5 7 0 9z" fill="currentColor"/></svg>`);
    ui.miniInfo = this.el("div", "m3-mini__info", ui.mini);
    ui.jamMini = this.el("div", "m3-jam", ui.mini, JAM_HTML);
    r.style.setProperty("--m3-noise", `url(${noiseTexture()})`);
    ui.nav = this.el("div", "m3-nav", ui.mini);
    ui.toast = this.el("div", "m3-toast", r);
    ui.loading = this.el("div", "m3-loading", r, `<b>LOADING CITY</b><span>MAP DATA</span><i><em></em></i>`);
    this.mapLayer.onClick = (b) => this.select(b);
    this.mapLayer.onHover = (b) => { this.hover = b; };
    this.mapLayer.onChange = () => { this.dirty = true; };
    this.mapLayer.wheelTarget = this.canvas;
    window.addEventListener("keydown", (e) => {
      if (!this.open || e.repeat) return;
      const k = keyName(e);
      emit("map3d:log", { message: `key ${k} (code "${e.code}", key "${e.key}", keyCode ${e.keyCode})` });
      if (this.asking()) {
        if (k === "Escape" || k === "KeyM") { e.preventDefault(); emit("map3d:close", {}); }
        else if (e.key === "1") this.chooseQuality("performance");
        else if (e.key === "2") this.chooseQuality("quality");
        else if (k === "ArrowLeft" || k === "ArrowRight" || e.key === "Tab") { e.preventDefault(); this.highlightPick(this.qualityPick === "performance" ? "quality" : "performance"); }
        else if (e.key === "Enter" || e.keyCode === 13) { e.preventDefault(); this.chooseQuality(this.qualityPick); }
        return;
      }
      if (e.target === this.ui.searchInput) return; // typing: the search box handles its own keys
      if ((e.key === "/" || (e.ctrlKey && k === "KeyF")) && this.cfg.map.search) { e.preventDefault(); (this.ui.searchInput as HTMLInputElement).focus(); }
      else if (k === "Escape" || k === "KeyM") { e.preventDefault(); emit("map3d:close", {}); }
      else if (k === "Space") { e.preventDefault(); this.tool("recenter"); }
      else if (k === "KeyN") this.tool("north");
      else if (k === "KeyG" && this.selected) this.setWaypoint(this.selected, true);
      else if (k === "Delete" || k === "Backspace") this.setWaypoint(null, true);
    });
    this.setConfig({});
  }

  private loading(label: string, f: number): void {
    (this.ui.loading.querySelector("span") as HTMLElement).textContent = label;
    (this.ui.loading.querySelector("em") as HTMLElement).style.width = `${Math.round(f * 100)}%`;
  }

  private buildLegend(): void {
    if (!this.ui.legend) return;
    const cats = this.cfg.categories;
    const hidden = this.mapLayer?.hiddenCategories ?? new Set<string>();
    const L = this.cfg.locale;
    const toggle = (group: "hud" | "layers", id: string, label: string) => {
      const on = this.prefs[group][id] !== false;
      return `<button data-toggle="${group}:${id}" class="m3-toggle${on ? " is-on" : ""}"><span>${escapeHtml(label)}</span><i>${on ? "ON" : "OFF"}</i></button>`;
    };
    const mode = (id: Quality, label: string) => `<button data-quality="${id}" class="${this.quality === id ? "is-on" : ""}">${escapeHtml(label)}</button>`;
    this.ui.legend.innerHTML = `<h3>${escapeHtml(L.display ?? "DISPLAY")}</h3><div class="m3-qswitch">` +
      mode("performance", L.performance ?? "2D · Performance") + mode("quality", L.quality ?? "3D · Quality") + `</div>` +
      `<h3>${escapeHtml(L.legend ?? "Legend")}</h3>` + cats.map((c) =>
      `<button data-cat="${escapeHtml(c.id)}" class="${hidden.has(c.id) ? "is-off" : ""}" style="--chip:${escapeHtml(c.color ?? "var(--m3-accent)")}">${iconSvg(c.icon, 16)}<span>${escapeHtml(c.label)}</span><em data-count="${escapeHtml(c.id)}">0</em></button>`).join("") +
      `<h3>HUD</h3>` + toggle("hud", "minimap", L.minimap ?? "Minimap") + toggle("hud", "holo", L.holo ?? "Holo GPS") +
      `<h3>LAYERS</h3>` + toggle("layers", "buildings", "Buildings") + toggle("layers", "roadBorders", "Road lines") +
      toggle("layers", "metro", "Metro") + toggle("layers", "labels", "Districts") + this.influenceLegend(toggle);
    this.ui.legend.onclick = (e) => {
      const b = (e.target as HTMLElement).closest("button");
      if (!b) return;
      const p = this.prefs;
      if (b.dataset.quality) { this.chooseQuality(b.dataset.quality as Quality); return; }
      if (b.dataset.cat) {
        const id = b.dataset.cat;
        p.hiddenCats = p.hiddenCats.includes(id) ? p.hiddenCats.filter((c) => c !== id) : [...p.hiddenCats, id];
        b.classList.toggle("is-off", p.hiddenCats.includes(id));
      } else if (b.dataset.toggle) {
        const [group, id] = b.dataset.toggle.split(":") as ["hud" | "layers", string];
        const on = p[group][id] === false;
        p[group][id] = on;
        b.classList.toggle("is-on", on);
        b.querySelector("i")!.textContent = on ? "ON" : "OFF";
      } else return;
      savePrefs(p);
      this.applyPrefs();
      emit("map3d:prefs", p);
    };
  }

  /** The switch and the density scale (levels from the server, colours from the page). */
  private influenceLegend(toggle: (group: "hud" | "layers", id: string, label: string) => string): string {
    const s = this.influenceState;
    if (!s.enabled) return "";
    const L = this.cfg.locale;
    const colors = this.cfg.influence.colors;
    const levels = s.levels.length ? s.levels : colors.map((_, i) => ({ min: i + 1, id: String(i + 1), label: String(i + 1) }));
    const scale = levels.map((l, i) => `<li style="--zc:${escapeHtml(colors[Math.min(i, colors.length - 1)] ?? "#FFCC00")}"><i></i><span>${escapeHtml(l.label)}</span><em>${l.min}+</em></li>`).join("");
    // a row under the switch: one chip per level, its name and from how many players
    return toggle("layers", "influence", L.influence ?? "Activity zones") + `<ul class="m3-density" title="${escapeHtml(L.density ?? "DENSITY")}">${scale}</ul>`;
  }

  private setInfluence(p: any): void {
    const zones: InfluenceZone[] = Array.isArray(p?.zones) ? p.zones.filter((z: any) => z && [z.x, z.y, z.radius].every((n) => typeof n === "number" && isFinite(n)))
      .map((z: any) => ({ id: String(z.id), x: z.x, y: z.y, z: typeof z.z === "number" ? z.z : 0, radius: z.radius, count: Math.max(1, Number(z.count) || 1), level: Math.max(1, Number(z.level) || 1) })) : [];
    const wasEnabled = this.influenceState.enabled;
    this.influenceState = { enabled: p?.enabled === true, zones, levels: Array.isArray(p?.levels) ? p.levels : [] };
    this.influence?.set(this.influenceState.enabled ? zones : []);
    if (wasEnabled !== this.influenceState.enabled || this.ui.legend?.querySelector(".m3-density") === null) this.buildLegend();
    this.dirty = true;
  }

  /** Whether the zones are drawn in this view: the open map only (server, resource and player switches). */
  private influenceVisible(mini: boolean): boolean {
    const s = this.influenceState;
    return !mini && s.enabled && this.influenceAllowed && this.prefs.layers.influence !== false;
  }

  private tickInfluence(t: number, mini: boolean): void {
    if (!this.influence) return;
    const dt = this.influenceAt ? Math.min(0.25, t - this.influenceAt) : 0;
    this.influenceAt = t;
    this.influence.setView(!mini, this.influenceVisible(mini));
    this.influence.tick(t, dt);
  }

  /** Level and players over each zone, on the open map. */
  private placeZoneLabels(W: number, H: number, cam: THREE.Camera): void {
    const show = this.influence && this.influenceVisible(false) && this.cfg.influence.labels;
    const seen = new Set<string>();
    if (show) {
      const L = this.cfg.locale;
      for (const z of this.influence!.zonesForLabels()) {
        const id = z.zone.id;
        seen.add(id);
        let el = this.zoneEls.get(id);
        if (!el) { el = this.el("div", "m3-zone", this.ui.zones); this.zoneEls.set(id, el); }
        const level = this.influenceState.levels[z.zone.level - 1];
        const count = z.zone.count;
        const html = `<b>${escapeHtml(level?.label ?? "")}</b>` + (this.cfg.influence.showCount ? `<span>${count} ${escapeHtml(count === 1 ? L.player ?? "player" : L.players ?? "players")}</span>` : "");
        if (el.dataset.html !== html) { el.dataset.html = html; el.innerHTML = html; }
        el.style.setProperty("--zc", z.color);
        const v = z.top.project(cam);
        const vis = v.z < 1 && Math.abs(v.x) < 1.05 && Math.abs(v.y) < 1.05 && z.alpha > 0.05;
        el.style.display = vis ? "" : "none";
        if (vis) { el.style.opacity = z.alpha.toFixed(2); el.style.transform = `translate(${((v.x * 0.5 + 0.5) * W).toFixed(0)}px, ${((-v.y * 0.5 + 0.5) * H).toFixed(0)}px)`; }
      }
    }
    for (const [id, el] of this.zoneEls) if (!seen.has(id)) { el.remove(); this.zoneEls.delete(id); }
  }

  /** Static over the map and minimap: partial lets the map show through, full hides it. */
  private setJam(p: any): void {
    const s = Math.max(0, Math.min(1, Number(p?.strength) || 0));
    this.jam = s;
    const r = this.root;
    r.classList.toggle("is-jamming", s > 0);
    r.classList.toggle("is-jammed", s >= 0.99);
    r.classList.toggle("has-jam-label", s >= 0.5);
    r.style.setProperty("--m3-jam", s.toFixed(2));
    const label = typeof p?.label === "string" && p.label ? p.label : this.cfg.locale.noSignal ?? "NO SIGNAL";
    for (const el of [this.ui.jamFull, this.ui.jamMini]) el.querySelector("b")!.textContent = label;
    this.dirty = true;
  }

  /** Layers, legend categories and the holo switch, as the player left them. */
  private applyPrefs(): void {
    const p = this.prefs;
    if (this.world) {
      this.world.setLayerVisible("buildings", this.cfg.map.buildings && p.layers.buildings !== false);
      this.world.setLayerVisible("roadBorders", this.cfg.map.roadBorders && p.layers.roadBorders !== false);
      this.world.setLayerVisible("metro", p.layers.metro !== false);
    }
    if (this.ui.districts) this.ui.districts.style.display = p.layers.labels === false ? "none" : "";
    for (const layer of [this.mapLayer, this.miniLayer]) {
      if (!layer) continue;
      layer.hiddenCategories.clear();
      for (const c of p.hiddenCats) layer.hiddenCategories.add(c);
    }
    this.dirty = true;
  }

  private updateLegendCounts(): void {
    const counts = new Map<string, number>();
    for (const b of this.blips.values()) counts.set(b.category ?? "default", (counts.get(b.category ?? "default") ?? 0) + 1);
    this.ui.legend.querySelectorAll<HTMLElement>("em[data-count]").forEach((e) => { e.textContent = String(counts.get(e.dataset.count!) ?? 0); });
  }

  // ---------------------------------------------------------------- scene
  private initScene(): void {
    // no antialiasing on the canvas: quality mode draws through a multisampled target (drawScene)
    this.renderer = new THREE.WebGLRenderer({ canvas: this.canvas, antialias: false, alpha: true, powerPreference: "high-performance" });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
    this.renderer.autoClear = false;
    this.world = new World(this.data, this.cfg.theme, this.areaU);
    // a label without a height sits on the ground (or the road) under it
    this.areas.heightAt = (x, y) => {
      const ray = new THREE.Raycaster(new THREE.Vector3(x, 5000, -y), new THREE.Vector3(0, -1, 0));
      const hit = ray.intersectObjects(this.world.pickables, false)[0];
      return hit ? hit.point.y : null;
    };
    this.scene.add(this.world.root, this.routeView.group);
    this.influence = new InfluenceLayer(this.world.uniforms);
    this.influence.setLook(this.cfg.influence);
    this.influence.set(this.influenceState.zones);
    this.scene.add(this.influence.group);
    this.graph = new RoadGraph(this.data.roads);
    const start = toScene(this.player);
    this.controls = new MapControls(this.mapCam, this.canvas, {
      target: start, distance: this.cfg.map.initialDistance, yaw: 0, pitch: THREE.MathUtils.degToRad(this.cfg.map.initialPitch),
    });
    this.controls.onChange = () => { this.dirty = true; };
    this.controls.onPick = (ndc) => this.pick(ndc);
    // Double click by hand: the game's browser is sent every click with a count of 1, so
    // `dblclick` never fires in game, and each release arrives twice (2 ms apart). A click
    // is a press then its release, short and still; two of them close in time and place
    // set the waypoint. A drag, or the duplicate release, never counts.
    let press: { t: number; x: number; y: number } | null = null, last = { t: -1e9, x: 0, y: 0 };
    this.canvas.addEventListener("pointerdown", (e) => {
      press = e.button === 0 ? { t: performance.now(), x: e.clientX, y: e.clientY } : null;
    });
    this.canvas.addEventListener("pointermove", (e) => {
      if (press && Math.hypot(e.clientX - press.x, e.clientY - press.y) > 5) { press = null; last.t = -1e9; }
    });
    this.canvas.addEventListener("pointerup", (e) => {
      const p0 = press;
      press = null;
      if (!p0 || e.button !== 0 || !this.open || !this.cfg.map.doubleClickWaypoint) return;
      const now = performance.now();
      if (now - p0.t > 350 || Math.hypot(e.clientX - p0.x, e.clientY - p0.y) > 5) { last.t = -1e9; return; }
      const twice = now - last.t < 400 && Math.hypot(e.clientX - last.x, e.clientY - last.y) < 8;
      last = twice ? { t: -1e9, x: 0, y: 0 } : { t: now, x: e.clientX, y: e.clientY };
      if (!twice) return;
      const p = this.pick(this.ndc(e));
      if (p) this.setWaypoint({ x: p.x, y: -p.z, z: p.y }, true);
    });
    this.canvas.addEventListener("contextmenu", (e) => {
      if (!this.open || !this.cfg.map.rightClickWaypoint) return;
      const p = this.pick(this.ndc(e));
      if (p) this.setWaypoint({ x: p.x, y: -p.z, z: p.y }, true);
    });
    this.canvas.addEventListener("pointermove", (e) => {
      if (!this.open) return;
      const p = this.controls.isBusy() ? null : this.groundHover(this.ndc(e));
      if (p && this.cfg.map.showCoordinates) this.ui.readout.innerHTML = `<span>X ${p.x.toFixed(0)}</span><span>Y ${(-p.z).toFixed(0)}</span><b>${this.districtAt(p.x, -p.z)}</b>`;
    });
    this.canvas.addEventListener("click", () => { if (this.open && !this.hover) this.select(null); });
    for (const [key, d] of Object.entries(this.data.manifest.districts)) {
      const el = this.el("div", "m3-district", this.ui.districts, `<span>${DISTRICT_NAMES[key] ?? key.toUpperCase()}</span>`);
      this.districtEls.push({ el, pos: new THREE.Vector3(d.center[0], d.center[2] + 80, -d.center[1]), name: DISTRICT_NAMES[key] ?? key });
    }
    this.setConfig({});
    this.applyQuality(this.quality, true);
    window.addEventListener("resize", () => { this.dirty = true; });
  }

  private ndc(e: MouseEvent): THREE.Vector2 {
    return new THREE.Vector2((e.clientX / window.innerWidth) * 2 - 1, -(e.clientY / window.innerHeight) * 2 + 1);
  }
  private pick(ndc: THREE.Vector2): THREE.Vector3 | null {
    this.raycaster.setFromCamera(ndc, this.mapView());
    const hits = this.raycaster.intersectObjects(this.world.pickables, false);
    return hits.length ? hits[0].point : null;
  }
  private groundHover(ndc: THREE.Vector2): THREE.Vector3 | null {
    this.raycaster.setFromCamera(ndc, this.mapView());
    const p = new THREE.Vector3();
    return this.raycaster.ray.intersectPlane(new THREE.Plane(new THREE.Vector3(0, 1, 0), -this.controls.current.target.y), p) ? p : null;
  }
  private districtAt(x: number, y: number): string {
    let best = "", bd = Infinity;
    for (const [k, d] of Object.entries(this.data.manifest.districts)) {
      const dd = Math.hypot(d.center[0] - x, d.center[1] - y);
      if (dd < bd) { bd = dd; best = DISTRICT_NAMES[k] ?? k; }
    }
    return bd < 2600 ? best : "BADLANDS";
  }

  // ---------------------------------------------------------------- state from Lua
  private setPlayer(p: any): void {
    if (!p || typeof p.x !== "number") return;
    const pl = this.player;
    const now = performance.now();
    const gap = (now - this.playerAt) / 1000;
    if (pl.valid && gap > 0.005 && gap < 0.5) {
      this.vel.x = this.vel.x * 0.5 + ((p.x - pl.x) / gap) * 0.5;
      this.vel.y = this.vel.y * 0.5 + ((p.y - pl.y) / gap) * 0.5;
    } else { this.vel.x = 0; this.vel.y = 0; }
    this.playerAt = now;
    pl.x = p.x; pl.y = p.y; pl.z = p.z ?? pl.z;
    pl.yaw = p.yaw ?? pl.yaw; pl.camYaw = p.camYaw ?? pl.yaw;
    pl.speed = p.speed ?? 0; pl.vehicle = !!p.vehicle;
    if (!pl.valid && this.controls) this.controls.flyTo(toScene(pl), undefined);
    pl.valid = true;
    // ease the arrow toward the body's facing (shortest way round): a heading read from the
    // motion wobbles from one update to the next
    const prev = this.playerBlip.heading ?? pl.yaw;
    const delta = ((pl.yaw - prev + 540) % 360) - 180;
    this.playerBlip.x = pl.x; this.playerBlip.y = pl.y; this.playerBlip.z = pl.z;
    if (this.holo) { this.holo.setPose(pl.x, pl.y, pl.vehicle ? pl.yaw : pl.camYaw, pl.z); return; }
    this.playerBlip.heading = Math.abs(delta) > 120 ? pl.yaw : prev + delta * 0.55;
    this.markersDirty = true;
    this.updateNavigation();
  }

  private setBlips(p: any): void {
    if (!p) return;
    if (Array.isArray(p.set)) { this.blips.clear(); for (const b of p.set) this.normalize(b) && this.blips.set(String(b.id), this.normalize(b)!); }
    if (Array.isArray(p.upsert)) for (const b of p.upsert) { const n = this.normalize(b); if (n) this.blips.set(n.id, n); }
    if (Array.isArray(p.remove)) for (const id of p.remove) this.blips.delete(String(id));
    this.syncBlips();
  }
  private upsertBlip(b: any): void { const n = this.normalize(b); if (n) { this.blips.set(n.id, n); this.syncBlips(); } }
  private normalize(b: any): Blip | null {
    if (!b || b.id === undefined || typeof b.x !== "number" || typeof b.y !== "number") return null;
    return { ...b, id: String(b.id) } as Blip;
  }
  private syncBlips(): void {
    const all = [...this.blips.values()];
    if (this.waypoint) all.push({ id: "__waypoint", ...this.waypoint, icon: "waypoint", label: this.cfg.locale.waypoint, edge: true, priority: 2, category: "__waypoint", routable: false });
    this.mapLayer.sync([...all, this.playerBlip]);
    this.miniLayer.sync([...all, this.playerBlip]);
    if (this.selected && !this.blips.has(this.selected.id) && this.selected.id !== "__waypoint") this.select(null);
    this.updateLegendCounts();
    this.dirty = true;
  }

  // ---------------------------------------------------------------- open / close
  private setOpen(open: boolean, p?: any): void {
    if (this.role === "mini") open = false;
    if (open === this.open) return;
    this.open = open;
    this.animate(open);
    if (!open && this.ready && this.controls) {
      const d = this.controls.desired;
      // the flat map keeps the tilt the 3D one had
      this.savedView = { distance: d.distance, yaw: d.yaw, pitch: this.perf ? this.savedView?.pitch ?? THREE.MathUtils.degToRad(this.cfg.map.initialPitch) : d.pitch };
      saveView(this.savedView);
    }
    if (open && this.ready) {
      const focus = p && typeof p.x === "number" ? p : this.player.valid ? this.player : null;
      const yaw = THREE.MathUtils.degToRad(this.player.camYaw);
      const v = this.savedView;
      if (focus && v) {
        // reopen as it was left, centred on the player (or the asked place)
        const t = toScene(focus);
        const c = this.controls.current;
        c.target.copy(t); c.distance = v.distance; c.yaw = v.yaw; c.pitch = this.perf ? 0 : v.pitch;
        this.controls.flyTo(t, v.distance, v.yaw, v.pitch);
      } else if (focus) {
        const t = toScene(focus);
        this.controls.current.target.copy(t).add(new THREE.Vector3(Math.sin(yaw), 0, Math.cos(yaw)).multiplyScalar(400));
        this.controls.current.distance = 260;
        this.controls.current.yaw = yaw;
        this.controls.flyTo(t, this.cfg.map.initialDistance * 0.45, yaw, THREE.MathUtils.degToRad(this.cfg.map.initialPitch));
      }
    }
    this.applyMode();
    this.dirty = true;
  }

  // Opening: the map comes in from a bright blur while the camera flies in, its interface
  // a beat later. Closing: it fades out (still drawn in full) before the page goes back.
  private animate(open: boolean): void {
    const r = this.root;
    clearTimeout(this.animTimer);
    r.classList.remove("is-opening", "is-closing");
    if (open) {
      this.closing = false;
      void r.offsetWidth; // restart the animation when reopened halfway through
      r.classList.add("is-opening");
      this.animTimer = window.setTimeout(() => r.classList.remove("is-opening"), OPEN_MS);
    } else if (this.ready && r.classList.contains("is-open")) {
      this.closing = true;
      r.classList.add("is-closing");
      this.animTimer = window.setTimeout(() => {
        this.closing = false;
        r.classList.remove("is-closing");
        this.applyMode();
        this.dirty = true;
      }, CLOSE_MS);
    }
  }

  private applyMode(): void {
    const r = this.root;
    const shown = this.open || this.closing;
    r.classList.toggle("is-open", shown);
    if (shown) this.canvas.style.clipPath = "none";
    r.classList.toggle("has-mini", this.role !== "full" && !shown && this.cfg.minimap.enabled && this.minimapVisible && this.ready);
    r.classList.toggle("has-route", !!this.route);
    r.classList.toggle("is-mini-role", this.role === "mini");
    r.classList.toggle("is-perf", this.perf);
    const asking = this.asking();
    if (asking && !r.classList.contains("is-asking")) this.highlightPick(this.quality);
    r.classList.toggle("is-asking", asking);
    r.classList.toggle("has-search", this.cfg.map.search);
    if (this.ui.routeClear) this.ui.routeClear.innerHTML = `&times; ${escapeHtml(this.cfg.locale.clearRoute)} <kbd>DEL</kbd>`;
    if (this.ui.searchInput) (this.ui.searchInput as HTMLInputElement).placeholder = this.cfg.locale.search ?? "Search";
    if (!this.open && this.ui.searchInput) { (this.ui.searchInput as HTMLInputElement).blur(); }
    if (this.controls) this.controls.enabled = this.open && !asking;
    this.renderHelp();
  }

  private renderHelp(): void {
    if (!this.ui.help) return;
    const k = this.cfg.keys;
    const items: [string, string][] = [["DRAG", "Pan"], ["RIGHT DRAG", this.perf ? "Rotate" : "Rotate / tilt"], ["WHEEL", "Zoom"], [k.waypoint ?? "Double click", "Waypoint"], [k.recenter ?? "SPACE", "Recenter"]];
    this.ui.help.innerHTML = items.map(([a, b]) => `<span><kbd>${escapeHtml(a)}</kbd>${escapeHtml(b)}</span>`).join("");
  }

  private tool(act?: string): void {
    if (!act || !this.controls) return;
    const d = this.controls.desired;
    if (act === "zoomin") d.distance = Math.max(this.controls.minDistance, d.distance * 0.6);
    else if (act === "zoomout") d.distance = Math.min(this.controls.maxDistance, d.distance * 1.6);
    else if (act === "north") d.yaw = Math.round(d.yaw / (Math.PI * 2)) * Math.PI * 2;
    else if (act === "pitch" && !this.perf) d.pitch = d.pitch > 0.15 ? 0 : THREE.MathUtils.degToRad(this.cfg.map.initialPitch);
    else if (act === "recenter" && this.player.valid) this.controls.flyTo(toScene(this.player), Math.min(d.distance, 900));
    this.dirty = true;
  }

  private focusOn(p: GamePos, distance?: number): void {
    if (!this.controls) return;
    this.controls.flyTo(toScene(p), distance ?? Math.min(this.controls.desired.distance, 700));
    this.dirty = true;
  }

  // ---------------------------------------------------------------- search
  private initSearch(): void {
    const input = this.ui.searchInput as HTMLInputElement;
    input.addEventListener("input", () => this.runSearch());
    input.addEventListener("focus", () => { this.ui.search.classList.add("is-active"); emit("map3d:typing", { active: true }); this.runSearch(); });
    input.addEventListener("blur", () => { this.ui.search.classList.remove("is-active"); emit("map3d:typing", { active: false }); });
    input.addEventListener("keydown", (e) => {
      const k = keyName(e);
      if (k === "Escape") { e.preventDefault(); if (input.value) { input.value = ""; this.runSearch(); } else input.blur(); }
      else if (k === "ArrowDown") { e.preventDefault(); this.moveResult(1); }
      else if (k === "ArrowUp") { e.preventDefault(); this.moveResult(-1); }
      else if (e.key === "Enter" || e.keyCode === 13) { e.preventDefault(); this.pickResult(this.resultIndex); }
    });
    // pointerdown, not click: the input's blur would hide the list before a click lands
    this.ui.searchList.addEventListener("pointerdown", (e) => {
      const li = (e.target as HTMLElement).closest("li[data-i]") as HTMLElement | null;
      if (li) { e.preventDefault(); this.pickResult(Number(li.dataset.i)); }
    });
  }

  /** Blips (label, description, category, district) and district names; nearest first on ties. */
  private runSearch(): void {
    if (!this.data) return;
    const q = (this.ui.searchInput as HTMLInputElement).value.trim().toLowerCase();
    const words = q.split(/\s+/).filter(Boolean);
    const score = (text: string): number => {
      if (!words.length) return 1;
      let s = 0;
      for (const w of words) {
        const i = text.indexOf(w);
        if (i < 0) return 0;
        s += i === 0 || text[i - 1] === " " ? 2 : 1;
      }
      return s;
    };
    const cats = new Map(this.cfg.categories.map((c) => [c.id, c.label]));
    const dist = (x: number, y: number) => (this.player.valid ? Math.hypot(x - this.player.x, y - this.player.y) : undefined);
    const out: typeof this.results = [];
    for (const b of this.blips.values()) {
      const cat = cats.get(b.category ?? "default") ?? b.category ?? "";
      const label = (b.label ?? "").toLowerCase();
      const district = this.districtAt(b.x, b.y);
      const s = score(label) * 3 + score(`${label} ${(b.description ?? "").toLowerCase()} ${cat.toLowerCase()} ${district.toLowerCase()}`);
      if (s > 0) out.push({ label: b.label ?? cat, sub: `${cat} · ${district}`, icon: b.icon ?? "pin", color: b.color, x: b.x, y: b.y, z: b.z ?? 0, blip: b, distance: dist(b.x, b.y), score: s });
    }
    if (words.length) {
      for (const [key, d] of Object.entries(this.data.manifest.districts)) {
        const name = DISTRICT_NAMES[key] ?? key.toUpperCase();
        const s = score(name.toLowerCase()) * 3;
        if (s > 0) out.push({ label: name, sub: this.cfg.locale.district ?? "District", icon: "district", x: d.center[0], y: d.center[1], z: d.center[2], score: s + 1 });
      }
    }
    out.sort((a, b) => b.score - a.score || (a.distance ?? 1e9) - (b.distance ?? 1e9));
    this.results = out.slice(0, 8);
    this.resultIndex = 0;
    const units = this.cfg.gps.units;
    this.ui.searchList.innerHTML = this.results.length
      ? this.results.map((r, i) => `<li data-i="${i}" class="${i === 0 ? "is-on" : ""}" style="--chip:${escapeHtml(r.color ?? "var(--m3-accent)")}">${iconSvg(r.icon, 18)}<div><b>${escapeHtml(r.label)}</b><small>${escapeHtml(r.sub.toUpperCase())}</small></div><em>${r.distance !== undefined ? formatDistance(r.distance, units) : ""}</em></li>`).join("")
      : `<li class="is-empty">${escapeHtml(this.cfg.locale.noResults ?? "Nothing found")}</li>`;
  }

  private moveResult(step: number): void {
    if (!this.results.length) return;
    this.resultIndex = (this.resultIndex + step + this.results.length) % this.results.length;
    this.ui.searchList.querySelectorAll("li[data-i]").forEach((li, i) => li.classList.toggle("is-on", i === this.resultIndex));
  }

  private pickResult(i: number): void {
    const r = this.results[i];
    if (!r) return;
    (this.ui.searchInput as HTMLInputElement).blur();
    if (r.blip) this.select(r.blip);
    this.focusOn(r, r.blip ? 650 : 1800);
  }

  // ---------------------------------------------------------------- selection card
  private select(b: Blip | null): void {
    this.selected = b && b.id !== "__player" ? b : null;
    const card = this.ui.card;
    if (!this.selected) { card.classList.remove("is-on"); return; }
    const s = this.selected;
    const d = this.player.valid ? Math.hypot(s.x - this.player.x, s.y - this.player.y) : null;
    const routable = s.routable !== false && this.cfg.gps.enabled;
    const isDest = !!this.waypoint && Math.hypot(this.waypoint.x - s.x, this.waypoint.y - s.y) < 1;
    card.innerHTML = `<header style="--chip:${escapeHtml(s.color ?? "var(--m3-accent)")}">${iconSvg(s.icon ?? "waypoint", 22)}<div><small>${escapeHtml((s.category ?? "place").toUpperCase())}</small><b>${escapeHtml(s.label ?? "Location")}</b></div></header>` +
      (s.description ? `<p>${escapeHtml(s.description)}</p>` : "") +
      `<dl><div><dt>DISTANCE</dt><dd>${d === null ? "--" : formatDistance(d, this.cfg.gps.units)}</dd></div><div><dt>DISTRICT</dt><dd>${this.districtAt(s.x, s.y)}</dd></div></dl>` +
      (routable ? `<button class="m3-btn ${isDest ? "is-danger" : ""}" data-route>${isDest ? escapeHtml(this.cfg.locale.clearRoute) : escapeHtml(this.cfg.locale.setRoute)}<kbd>G</kbd></button>` : "");
    card.querySelector("[data-route]")?.addEventListener("click", () => {
      if (isDest) this.setWaypoint(null, true); else this.setWaypoint(s, true);
      this.select(this.selected);
    });
    card.classList.add("is-on");
    emit("map3d:blipClick", { id: s.id });
  }

  // ---------------------------------------------------------------- GPS
  setWaypoint(p: (GamePos & { z?: number }) | null, fromUser: boolean): void {
    if (!p) {
      this.waypoint = null;
      this.route = null;
      this.routeView.set(null);
      emit("map3d:holo", { clear: true, pts: [] });
      if (fromUser) emit("map3d:waypoint", { clear: true });
      emit("map3d:routeInfo", { active: false });
    } else {
      this.waypoint = { x: p.x, y: p.y, z: p.z ?? 0 };
      if (fromUser) emit("map3d:waypoint", { x: p.x, y: p.y, z: p.z ?? 0 });
      this.computeRoute(false);
    }
    this.arrivedFor = null;
    this.syncBlips();
    this.applyMode();
  }

  private computeRoute(reroute: boolean): void {
    if (!this.waypoint || !this.graph || !this.cfg.gps.enabled) return;
    if (!this.player.valid) { this.route = null; this.routeView.set(null); return; }
    const t0 = performance.now();
    const r = this.graph.route(this.player, this.waypoint, {
      heading: this.player.vehicle ? this.player.yaw : undefined,
      mainOnly: this.cfg.gps.snapMainNetwork,
      avoidHighways: this.cfg.gps.avoidHighways,
    });
    this.route = r;
    this.routeHint = 0;
    this.offSince = 0;
    this.lastReroute = performance.now();
    this.routeView.set(r);
    if (!r) this.toast(this.cfg.locale.noRoute, true);
    else if (reroute) this.toast(this.cfg.locale.rerouting, false);
    emit("map3d:routeInfo", r ? { active: true, length: Math.round(r.length), seconds: Math.round(r.seconds), computeMs: Math.round(performance.now() - t0) } : { active: false });
    this.applyMode();
  }

  /** The stretch of route the holographic GPS draws: a little behind, 450 m ahead. */
  private holoPayload(r: Route, along: number, next: Maneuver | undefined, remaining: number): unknown {
    const pts: number[] = [];
    const n = r.cumulative.length;
    // start at the last vertex behind the player: on a long straight the next vertex can
    // be far ahead, and the stretch under the arrow would be missing
    let first = 0;
    while (first + 1 < n && r.cumulative[first + 1] < along - 10) first++;
    for (let i = first; i < n; i++) {
      const d = r.cumulative[i];
      if (pts.length >= 240) break;
      pts.push(Math.round(r.points[i * 3] * 10) / 10, Math.round(r.points[i * 3 + 1] * 10) / 10, Math.round(r.points[i * 3 + 2] * 10) / 10);
      if (d > along + 450) break;
    }
    const label = next ? this.cfg.locale["m." + next.kind] ?? next.kind.toUpperCase() : "";
    return {
      pts, s0: r.cumulative[first], dest: this.waypoint ? { x: this.waypoint.x, y: this.waypoint.y, z: this.waypoint.z } : undefined,
      next: next ? { kind: next.kind, distance: formatDistance(next.at - along, this.cfg.gps.units), label } : undefined,
      left: `${formatDistance(remaining, this.cfg.gps.units)} · ${eta(remaining, r)}`,
    };
  }

  private updateNavigation(): void {
    const r = this.route;
    if (!r) { if (this.waypoint && this.player.valid && this.graph && performance.now() - this.lastReroute > 2000) this.computeRoute(false); return; }
    const pr = progressOn(r, this.player, this.routeHint);
    this.routeHint = pr.index;
    this.routeView.setProgress(pr.along);
    const now = performance.now();
    const remaining = Math.max(0, r.length - pr.along);
    const toDest = this.waypoint ? Math.hypot(this.waypoint.x - this.player.x, this.waypoint.y - this.player.y) : remaining;
    // arrived: close to the place itself, or at the road's end when the place is off the
    // road (never on progress alone: a route passing near its own end could fake it)
    const n = r.cumulative.length;
    const endGap = this.waypoint ? Math.hypot(r.points[(n - 1) * 3] - this.waypoint.x, r.points[(n - 1) * 3 + 1] - this.waypoint.y) : 0;
    const arrived = toDest < this.cfg.gps.arriveDistance ||
      (remaining < this.cfg.gps.arriveDistance && toDest < this.cfg.gps.arriveDistance + endGap + 10);
    if (arrived && this.arrivedFor !== r) {
      this.arrivedFor = r;
      this.toast(this.cfg.locale.arrived, false);
      emit("map3d:arrived", { x: this.waypoint?.x, y: this.waypoint?.y, distance: Math.round(toDest) });
      this.setWaypoint(null, true);
      return;
    }
    if (pr.off > this.cfg.gps.rerouteDistance) {
      if (!this.offSince) this.offSince = now;
      else if (now - this.offSince > this.cfg.gps.rerouteDelay * 1000 && now - this.lastReroute > 2500) this.computeRoute(true);
    } else this.offSince = 0;
    // the next maneuver ahead of the player
    let next: Maneuver | undefined;
    for (const m of r.maneuvers) if (m.at > pr.along + 4 && m.kind !== "start") { next = m; break; }
    const ui = this.ui;
    if (next) {
      const d = next.at - pr.along;
      const label = this.cfg.locale["m." + next.kind] ?? next.kind.toUpperCase();
      // only rewritten when the text changes: rebuilding it 15 times a second ate the clicks
      const nav = `<i>${maneuverSvg(next.kind, 15)}</i><b>${formatDistance(d, this.cfg.gps.units)}</b><span>${escapeHtml(label)}</span>`;
      if (nav !== this.navHtml) { this.navHtml = nav; ui.nav.innerHTML = nav; }
      this.navLeft = `${formatDistance(remaining, this.cfg.gps.units)} · ${eta(remaining, r)}`;
      const bar = `${maneuverSvg(next.kind, 22)}<b>${formatDistance(d, this.cfg.gps.units)}</b><span>${escapeHtml(label)}</span><i></i><span>${formatDistance(remaining, this.cfg.gps.units)}</span><span>${eta(remaining, r)}</span>`;
      if (bar !== this.barHtml) { this.barHtml = bar; ui.routeInfo.innerHTML = bar; }
    }
    if (now - this.lastHolo > 100) {
      this.lastHolo = now;
      emit("map3d:holo", this.holoPayload(r, pr.along, next, remaining));
    }
    if (now - this.lastInfo > 500) {
      this.lastInfo = now;
      emit("map3d:routeInfo", { active: true, remaining: Math.round(remaining), next: next ? { kind: next.kind, distance: Math.round(next.at - pr.along) } : null, off: Math.round(pr.off) });
    }
  }

  private toast(text: string, danger: boolean): void {
    const t = this.ui.toast;
    t.textContent = text;
    t.classList.toggle("is-danger", danger);
    t.classList.remove("is-on");
    void t.offsetWidth;
    t.classList.add("is-on");
  }

  // ---------------------------------------------------------------- render
  private miniRect(): { x: number; y: number; w: number; h: number } {
    const m = this.cfg.minimap, W = window.innerWidth, H = window.innerHeight, s = m.size;
    const x = m.anchor.endsWith("right") ? W - m.margin[0] - s : m.margin[0];
    const y = m.anchor.startsWith("bottom") ? H - m.margin[1] - s : m.margin[1];
    return { x, y, w: s, h: s };
  }

  /**
   * The canvas covers only what is drawn: the whole screen while the map is open, the
   * minimap's square otherwise (a full-screen canvas cleared 30 times a second made the
   * game recompose the whole overlay just to show a corner).
   */
  private placeCanvas(mode: "full" | "mini" | "none"): { w: number; h: number } {
    const W = window.innerWidth, H = window.innerHeight, dpr = window.devicePixelRatio || 1;
    const rect = mode === "mini" ? this.miniRect() : { x: 0, y: 0, w: mode === "full" ? W : 1, h: mode === "full" ? H : 1 };
    // performance: the open map at screen pixels at most, the minimap barely supersampled
    const pr = mode === "mini"
      ? this.perf ? Math.min(2, dpr * 1.25) : Math.min(3, dpr * Math.max(1, this.cfg.minimap.supersample))
      : Math.min(this.perf ? 1 : 2, dpr * Math.max(0.5, this.cfg.map.resolution));
    const key = `${mode}:${rect.x}:${rect.y}:${rect.w}:${rect.h}:${pr}:${this.cfg.minimap.shape}`;
    if (key !== this.canvasKey) {
      this.canvasKey = key;
      const s = this.canvas.style;
      s.left = `${rect.x}px`; s.top = `${rect.y}px`; s.width = `${rect.w}px`; s.height = `${rect.h}px`;
      s.display = mode === "none" ? "none" : "block";
      s.clipPath = mode === "mini" ? clipFor(this.cfg.minimap.shape, { x: 0, y: 0, w: rect.w, h: rect.h }) : "none";
      this.renderer.setPixelRatio(pr);
      this.renderer.setSize(rect.w, rect.h, false);
      this.dirty = true;
    }
    return rect;
  }

  private loop = (): void => {
    requestAnimationFrame(this.loop);
    const dt = Math.min(0.1, this.clock.getDelta());
    const t = this.clock.elapsedTime;
    const mode = this.open || this.closing ? "full" : this.root.classList.contains("has-mini") ? "mini" : "none";
    const rect = this.placeCanvas(mode);
    if (this.jam >= 0.99) return; // fully jammed: the static covers everything, draw nothing
    if (mode === "full") {
      // every frame while the camera moves; otherwise only for changes and the route's animation
      const moving = this.controls.update(dt);
      // performance: nothing on the map runs by itself (still route, zones and areas)
      const animate = !this.perf && (!!this.route || !!(this.influence?.active && this.influenceVisible(false)) || this.areas.pulsing("map")) && t - this.lastFull >= 1 / Math.max(1, this.cfg.map.idleFps);
      if (moving || this.dirty || animate) { this.lastFull = t; this.renderFull(t, rect.w, rect.h); }
      else if (this.markersDirty) {
        // only the player moved: the arrow follows every update, the city (the route's
        // travelled part) is redrawn 4 times a second in performance mode
        if (!this.perf || t - this.lastFull >= 0.25) { this.lastFull = t; this.renderFull(t, rect.w, rect.h); }
        else this.projectFull(rect.w, rect.h);
      }
    } else if (mode === "mini") {
      const fps = this.perf ? Math.min(30, this.cfg.minimap.fps) : this.cfg.minimap.fps;
      const due = t - this.lastMini >= 1 / Math.max(1, fps) - 0.002;
      const runs = !this.perf && (!!this.route || this.areas.pulsing("minimap"));
      if (due && (this.dirty || this.markersDirty || runs || this.view.settling)) { this.lastMini = t; this.renderMini(t, rect.w, rect.h); }
    }
  };

  private renderFull(t: number, W: number, H: number): void {
    this.world.uniforms.uTime.value = t;
    this.routeView.tick(t);
    this.tickInfluence(t, false);
    this.mapCam.aspect = W / H;
    this.mapCam.updateProjectionMatrix();
    const cam = this.mapView();
    const dist = this.controls.current.distance;
    this.world.updateFog(dist);
    // performance: small boxes leave a little sooner
    this.world.uniforms.uLod.value = this.perf ? 0.0032 : 0.0022;
    this.world.uniforms.uCut.value = 0;
    this.routeView.scaleMarkers(dist, t);
    // hatching `areas.hatch` pixels apart: metres per pixel at the camera's target (the
    // flat view has the same scale there)
    const mpp = (2 * dist * Math.tan(THREE.MathUtils.degToRad(this.mapCam.fov / 2))) / Math.max(1, H);
    this.areas.prepare("map", this.perf ? STILL_T : t, this.cfg.areas.hatch * mpp, 1, cam);
    const r = this.renderer;
    r.setScissorTest(false);
    r.setViewport(0, 0, W, H);
    this.drawScene(cam);
    this.projectFull(W, H);
    this.dirty = false;
  }

  /** The open map's overlay (blips, labels, districts, compass) placed with its camera. */
  private projectFull(W: number, H: number): void {
    const cam = this.mapView();
    const dist = this.controls.current.distance;
    this.mapLayer.project(cam, { x: 0, y: 0, w: W, h: H }, { distance: dist });
    this.areas.placeLabels(cam, W, H, this.cfg.areas.labels);
    this.placeZoneLabels(W, H, cam);
    // district names and the compass
    const showDistricts = dist > 1400;
    for (const d of this.districtEls) {
      const v = d.pos.clone().project(cam);
      const vis = showDistricts && v.z < 1 && Math.abs(v.x) < 1.1 && Math.abs(v.y) < 1.1;
      d.el.style.display = vis ? "" : "none";
      if (vis) d.el.style.transform = `translate(${((v.x * 0.5 + 0.5) * W).toFixed(0)}px, ${((-v.y * 0.5 + 0.5) * H).toFixed(0)}px)`;
    }
    (this.ui.tools.querySelector(".m3-compass i") as HTMLElement).style.transform = `rotate(${this.controls.current.yaw}rad)`;
    (this.ui.tools.querySelector(".m3-pitch") as HTMLElement).textContent = this.controls.current.pitch > 0.15 ? this.cfg.locale.view2d : this.cfg.locale.view3d;
    this.markersDirty = false;
  }

  /** The camera the open map draws with: the orbit's, or straight above it in performance mode. */
  private mapView(): THREE.Camera {
    if (!this.perf || !this.controls) return this.mapCam;
    const c = this.controls.current;
    const halfH = c.distance * Math.tan(THREE.MathUtils.degToRad(this.mapCam.fov / 2));
    return topDown(this.mapOrtho, c.target, c.distance, halfH * this.mapCam.aspect, halfH, c.yaw);
  }

  /** The scene into the canvas: straight in performance mode, through 4x MSAA in quality mode. */
  private drawScene(cam: THREE.Camera): void {
    const r = this.renderer;
    r.setClearColor(this.cfg.theme.background, 1);
    if (this.perf) {
      r.setRenderTarget(null);
      r.clear();
      r.render(this.scene, cam);
      return;
    }
    const size = r.getDrawingBufferSize(this.bufSize);
    if (!this.msaa) this.msaa = new THREE.WebGLRenderTarget(size.x, size.y, { samples: 4 });
    else if (this.msaa.width !== size.x || this.msaa.height !== size.y) this.msaa.setSize(size.x, size.y);
    if (!this.blit) {
      const mat = new THREE.ShaderMaterial({
        uniforms: { uTex: { value: null } },
        vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`,
        fragmentShader: `uniform sampler2D uTex; varying vec2 vUv; void main(){ gl_FragColor = texture2D(uTex, vUv); }`,
        depthTest: false, depthWrite: false,
      });
      const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), mat);
      quad.frustumCulled = false;
      const scene = new THREE.Scene();
      scene.add(quad);
      this.blit = { scene, cam: new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1), mat };
    }
    r.setRenderTarget(this.msaa);
    r.clear();
    r.render(this.scene, cam);
    r.setRenderTarget(null);
    this.blit.mat.uniforms.uTex.value = this.msaa.texture;
    r.render(this.blit.scene, this.blit.cam);
  }

  // ---------------------------------------------------------------- display quality
  get perf(): boolean { return this.quality === "performance"; }

  /** The open map waits for the player's choice (never chosen yet). */
  private asking(): boolean {
    return this.open && this.ready && !this.qualityChosen && (this.role === "full" || this.role === "both");
  }

  /** From Lua: the stored mode, and whether the player ever chose. */
  private setQuality(p: any): void {
    if (p?.mode !== "performance" && p?.mode !== "quality") return;
    this.qualityChosen = p.chosen !== false;
    this.applyQuality(p.mode);
  }

  private applyQuality(mode: Quality, force = false): void {
    const changed = mode !== this.quality;
    this.quality = mode;
    if (this.world && (changed || force)) {
      const perf = this.perf;
      this.world.setPerformance(perf);
      this.influence?.setPerformance(perf);
      this.routeView.setPerformance(perf);
      if (perf) { this.msaa?.dispose(); this.msaa = null; }
      const c = this.controls;
      c.maxPitch = perf ? 0 : THREE.MathUtils.degToRad(this.cfg.map.maxPitch);
      if (perf) { c.desired.pitch = 0; c.current.pitch = 0; }
      // back to the tilted city the player left
      else if (changed) c.desired.pitch = this.savedView?.pitch ?? THREE.MathUtils.degToRad(this.cfg.map.initialPitch);
      this.canvasKey = ""; // the resolution follows the mode
    } else this.routeView.setPerformance(this.perf);
    this.buildLegend();
    this.applyMode();
    this.dirty = true;
  }

  /** The player's choice (the first opening's question, or the legend's switch): Lua keeps it. */
  private chooseQuality(mode: Quality): void {
    if (mode !== "performance" && mode !== "quality") return;
    const wasAsking = this.asking();
    if (mode === this.quality && this.qualityChosen) return;
    this.qualityChosen = true;
    this.applyQuality(mode);
    emit("map3d:quality", { mode });
    const L = this.cfg.locale;
    if (!wasAsking) this.toast(mode === "performance" ? L.performanceOn ?? "PERFORMANCE MODE · 2D" : L.qualityOn ?? "QUALITY MODE · 3D", false);
  }

  private highlightPick(mode: Quality): void {
    this.qualityPick = mode;
    this.ui.chooser?.querySelectorAll<HTMLElement>("[data-pick]").forEach((b) => b.classList.toggle("is-on", b.dataset.pick === mode));
  }

  /** The first opening's question, in the map's look. */
  private renderChooser(): void {
    if (!this.ui.chooser) return;
    const L = this.cfg.locale;
    const card = (id: Quality, key: string, art: string, tag: string, title: string, text: string) =>
      `<button data-pick="${id}" class="${this.qualityPick === id ? "is-on" : ""}"><i class="m3-quality__art">${art}</i>` +
      `<div><em>${escapeHtml(tag)}</em><b>${escapeHtml(title)}</b><span>${escapeHtml(text)}</span></div><kbd>${key}</kbd></button>`;
    this.ui.chooser.innerHTML = `<div class="m3-quality__panel">` +
      `<header><span class="m3-tag">${escapeHtml(L.displayTag ?? "MAP")}</span><div><b>${escapeHtml(L.displayTitle ?? "DISPLAY MODE")}</b><small>${escapeHtml(L.displayQuestion ?? "HOW SHOULD THE CITY BE DRAWN?")}</small></div></header>` +
      `<div class="m3-quality__cards">` +
      card("performance", "1", ART_2D, L.performanceTag ?? "LIGHT · ANY PC", L.performanceTitle ?? "PERFORMANCE", L.performanceText ?? "A flat 2D map without the heavy effects, on the map and the minimap. Smooth on small configurations.") +
      card("quality", "2", ART_3D, L.qualityTag ?? "RECENT GRAPHICS CARD", L.qualityTitle ?? "QUALITY", L.qualityText ?? "The 3D city: lit buildings, x-ray minimap, animated route and activity zones.") +
      `</div><footer><span><kbd>ENTER</kbd>${escapeHtml(L.confirm ?? "Confirm")}</span><span>${escapeHtml(L.displayHint ?? "Switch at any time under DISPLAY in the legend.")}</span></footer></div>`;
  }

  private renderMini(t: number, w: number, h: number): void {
    this.world.uniforms.uTime.value = t;
    this.routeView.tick(t);
    this.tickInfluence(t, true);
    const m = this.cfg.minimap;
    const p = this.player;
    const v = this.view;
    const now = performance.now();
    const dt = v.frameAt ? Math.min(0.1, (now - v.frameAt) / 1000) : 0;
    v.frameAt = now;
    const ahead = Math.min(0.1, (now - this.playerAt) / 1000);
    const tx = p.x + this.vel.x * ahead, ty = p.y + this.vel.y * ahead;
    // flat and close on foot; in a vehicle tilted toward the road ahead (GTA-like), a bit
    // wider with speed
    const speedK = THREE.MathUtils.clamp((p.speed - 8) / 32, 0, 1);
    if (this.zoomDir) this.miniZoom = clampZoom(this.miniZoom * Math.exp(-this.zoomDir * dt * 1.4));
    const tRadius = (p.vehicle ? THREE.MathUtils.lerp(m.vehicleRadius * 0.8, m.vehicleRadius, speedK) : m.radius) * this.miniZoom;
    const tTilt = p.vehicle ? m.vehicleTilt : m.tilt;
    const tYaw = m.rotate ? (p.vehicle && m.vehicleFollow === "vehicle" ? p.yaw : p.camYaw) : 0;
    if (!v.init) { v.x = tx; v.y = ty; v.z = p.z; v.yaw = tYaw; v.radius = tRadius; v.tilt = tTilt; v.init = true; }
    const ease = (rate: number) => 1 - Math.exp(-dt * rate);
    v.x += (tx - v.x) * ease(16); v.y += (ty - v.y) * ease(16); v.z += (p.z - v.z) * ease(8);
    const turn = ((tYaw - v.yaw + 540) % 360) - 180;
    v.yaw += turn * ease(12);
    v.radius += (tRadius - v.radius) * ease(2.5);
    v.tilt += (tTilt - v.tilt) * ease(2.5);
    v.settling = Math.abs(tx - v.x) + Math.abs(ty - v.y) > 0.03 || Math.abs(turn) > 0.2 || Math.abs(tRadius - v.radius) > 0.5 || Math.abs(tTilt - v.tilt) > 0.2 || p.speed > 0.2 || this.zoomDir !== 0;
    // the arrow sits where the view is centred
    this.playerBlip.x = v.x; this.playerBlip.y = v.y;
    const radius = v.radius;
    const yaw = THREE.MathUtils.degToRad(v.yaw);
    // performance: always straight down (the tilt still pushes the view ahead in a car)
    const pitch = this.perf ? 0 : THREE.MathUtils.degToRad(v.tilt);
    const dist = radius / Math.tan(THREE.MathUtils.degToRad(this.miniCam.fov / 2));
    const target = toScene({ x: v.x, y: v.y, z: v.z });
    // look a little ahead of the player so more of the road in front is visible
    target.add(new THREE.Vector3(-Math.sin(yaw), 0, -Math.cos(yaw)).multiplyScalar(radius * THREE.MathUtils.mapLinear(v.tilt, m.tilt, Math.max(m.tilt + 1, m.vehicleTilt), 0.1, 0.32)));
    let c: THREE.Camera;
    if (this.perf) c = topDown(this.miniOrtho, target, dist, radius, radius, yaw);
    else {
      const pc = this.miniCam;
      pc.aspect = 1;
      const off = new THREE.Vector3(Math.sin(yaw) * Math.sin(pitch), Math.cos(pitch), Math.cos(yaw) * Math.sin(pitch)).multiplyScalar(dist);
      pc.position.copy(target).add(off);
      pc.up.set(-Math.sin(yaw), 0, -Math.cos(yaw)).lerp(new THREE.Vector3(0, 1, 0), Math.min(1, pitch / 0.35));
      pc.lookAt(target);
      pc.near = Math.max(1, dist * 0.05);
      pc.far = dist * 6;
      pc.updateProjectionMatrix();
      pc.updateMatrixWorld();
      c = pc;
    }
    this.world.updateFog(dist * 0.9);
    this.world.uniforms.uLod.value = this.perf ? 0.005 : 0.004;
    this.world.uniforms.uFocus.value.copy(toScene({ x: v.x, y: v.y, z: v.z })).y += 1.5;
    this.world.uniforms.uCut.value = this.perf ? 0 : Math.max(0, m.xray);
    this.routeView.scaleMarkers(dist * 0.6, t);
    // the minimap shows 2 x radius metres across its height
    this.areas.prepare("minimap", this.perf ? STILL_T : t, this.cfg.areas.minimapHatch * (2 * radius) / Math.max(1, h), THREE.MathUtils.clamp(this.cfg.areas.minimapStrength, 0, 1), c);
    const r = this.renderer;
    r.setScissorTest(false);
    r.setViewport(0, 0, w, h);
    this.routeView.group.visible = !!this.route && m.showRoute;
    this.drawScene(c);
    this.routeView.group.visible = !!this.route;
    // the minimap overlay is positioned on the minimap: project in its own frame
    this.miniLayer.project(c, { x: 0, y: 0, w, h }, { distance: dist, edgeInset: 16 });
    // north: a small arrow on the square's edge, where north lies from the centre
    const o = target.clone().project(c), nth = target.clone().add(new THREE.Vector3(0, 0, -radius)).project(c);
    let ndx = (nth.x - o.x) * w, ndy = -(nth.y - o.y) * h;
    const nl = Math.hypot(ndx, ndy) || 1; ndx /= nl; ndy /= nl;
    const inset = 7, k = Math.min((w / 2 - inset) / Math.max(1e-6, Math.abs(ndx)), (h / 2 - inset) / Math.max(1e-6, Math.abs(ndy)));
    this.ui.miniNorth.style.transform = `translate(${(w / 2 + ndx * k).toFixed(1)}px, ${(h / 2 + ndy * k).toFixed(1)}px) rotate(${Math.atan2(ndx, -ndy).toFixed(3)}rad)`;
    const wpd = this.waypoint ? Math.hypot(this.waypoint.x - p.x, this.waypoint.y - p.y) : null;
    const left = this.route ? this.navLeft : wpd !== null ? formatDistance(wpd, this.cfg.gps.units) : "";
    // inside a labelled area (a danger zone), its name in its colour replaces the district's
    const area = this.cfg.areas.minimapLabel ? this.areas.at(p.x, p.y, "minimap") : null;
    const place = area ? `<b class="m3-mini__area" style="--ac:${escapeHtml(area.stroke)}">${escapeHtml(area.label ?? "")}</b>` : `<b>${this.districtAt(p.x, p.y)}</b>`;
    const info = `${place}${left ? `<span>${iconSvg("waypoint", 13)}${left}</span>` : ""}`;
    if (info !== this.ui.miniInfo.dataset.html) { this.ui.miniInfo.dataset.html = info; this.ui.miniInfo.innerHTML = info; }
    this.dirty = false;
    this.markersDirty = false;
  }
}

// A still frame time for the areas' pulse in performance mode (sin(2.6 t) near its top).
const STILL_T = 0.6;

/** An orthographic camera straight above `target`, `halfW` x `halfH` metres, heading `yaw` up. */
function topDown(o: THREE.OrthographicCamera, target: THREE.Vector3, height: number, halfW: number, halfH: number, yaw: number): THREE.OrthographicCamera {
  o.left = -halfW; o.right = halfW; o.top = halfH; o.bottom = -halfH;
  // the near plane far above: the camera keeps its height (the buildings' level of detail
  // reads it) and the tallest towers are never cut
  o.near = -6000; o.far = height + 6000;
  o.position.set(target.x, target.y + height, target.z);
  o.up.set(-Math.sin(yaw), 0, -Math.cos(yaw));
  o.lookAt(target);
  o.updateProjectionMatrix();
  o.updateMatrixWorld();
  return o;
}

/** The chooser's pictures: the flat map and the 3D city, in the map's colours. */
const ART_2D = `<svg viewBox="0 0 120 72" width="120" height="72"><rect width="120" height="72" fill="#1f2128"/>` +
  `<path d="M0 44H120M58 0V72" stroke="#41444f" stroke-width="7"/>` +
  `<g fill="#3a3d4a" stroke="currentColor" stroke-width="1"><rect x="6" y="6" width="22" height="16"/><rect x="32" y="8" width="18" height="28"/><rect x="66" y="5" width="30" height="14"/>` +
  `<rect x="100" y="6" width="14" height="30"/><rect x="66" y="23" width="14" height="13"/><rect x="84" y="23" width="12" height="13"/><rect x="6" y="26" width="22" height="10"/>` +
  `<rect x="6" y="52" width="40" height="14"/><rect x="66" y="52" width="20" height="16"/><rect x="92" y="54" width="22" height="12"/></g>` +
  `<path d="M2 44H58V70" fill="none" stroke="currentColor" stroke-width="2.4" stroke-dasharray="5 3"/></svg>`;
function isoBox(x: number, y: number, w: number, d: number, h: number): string {
  const p = (...pts: number[][]) => pts.map(([a, b]) => `${a.toFixed(1)},${b.toFixed(1)}`).join(" ");
  const b1 = [x + w * 0.87, y - w * 0.5], b3 = [x - d * 0.87, y - d * 0.5];
  const t0 = [x, y - h], t1 = [b1[0], b1[1] - h], t3 = [b3[0], b3[1] - h], t2 = [t1[0] - d * 0.87, t1[1] - d * 0.5];
  return `<polygon points="${p([x, y], b1, t1, t0)}" fill="#2c2f3a"/><polygon points="${p([x, y], b3, t3, t0)}" fill="#3a3d4a"/><polygon points="${p(t0, t1, t2, t3)}" fill="#666a7d"/>`;
}
const ART_3D = `<svg viewBox="0 0 120 72" width="120" height="72"><rect width="120" height="72" fill="#1f2128"/>` +
  `<path d="M0 62 60 28 120 62" fill="none" stroke="#41444f" stroke-width="6"/>` +
  `<g stroke="currentColor" stroke-width="1" stroke-linejoin="round">${isoBox(30, 60, 14, 12, 30)}${isoBox(62, 66, 18, 14, 46)}${isoBox(94, 58, 12, 12, 22)}${isoBox(78, 40, 10, 8, 16)}</g>` +
  `<path d="M14 70 60 44 104 70" fill="none" stroke="currentColor" stroke-width="2.4" stroke-dasharray="5 3"/></svg>`;

const JAM_HTML = `<i class="m3-jam__noise"></i><i class="m3-jam__band"></i><div class="m3-jam__label"><svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M2 8.5a15 15 0 0 1 20 0"/><path d="M5.5 12a10 10 0 0 1 13 0"/><path d="M9 15.5a5 5 0 0 1 6 0"/><path d="M3 3l18 18"/></svg><b></b></div>`;

/** A tile of grey static (generated once; the CSS jumps it around to animate it). */
function noiseTexture(): string {
  const c = document.createElement("canvas");
  c.width = c.height = 128;
  const g = c.getContext("2d")!, img = g.createImageData(128, 128);
  for (let i = 0; i < img.data.length; i += 4) {
    const v = Math.random() < 0.5 ? Math.random() * 90 : 90 + Math.random() * 165;
    img.data[i] = img.data[i + 1] = img.data[i + 2] = v; img.data[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  return c.toDataURL("image/png");
}

// The player's display choices, kept by the page (and sent to Lua for the other surfaces).
interface Prefs { hud: Record<string, boolean>; layers: Record<string, boolean>; hiddenCats: string[] }
const PREFS_KEY = "op77_map3d.prefs";
function normalizePrefs(v: any): Prefs {
  const bools = (o: any) => Object.fromEntries(Object.entries(o && typeof o === "object" ? o : {}).filter(([, b]) => typeof b === "boolean")) as Record<string, boolean>;
  return { hud: bools(v?.hud), layers: bools(v?.layers), hiddenCats: Array.isArray(v?.hiddenCats) ? v.hiddenCats.filter((c: unknown) => typeof c === "string") : [] };
}
function loadPrefs(): Prefs {
  try {
    const p = normalizePrefs(JSON.parse(localStorage.getItem(PREFS_KEY) ?? "null"));
    if (localStorage.getItem("op77_map3d.holo") === "0" && p.hud.holo === undefined) p.hud.holo = false; // the earlier switch
    return p;
  } catch { return normalizePrefs(null); }
}
function savePrefs(p: Prefs): void { try { localStorage.setItem(PREFS_KEY, JSON.stringify(p)); } catch { /* memory only */ } }

const ZOOM_KEY = "op77_map3d.miniZoom";
function clampZoom(z: number): number { return Math.min(3, Math.max(0.35, z)); }
function loadZoom(): number {
  try { const z = Number(localStorage.getItem(ZOOM_KEY)); return z > 0 ? clampZoom(z) : 1; } catch { return 1; }
}
function saveZoom(z: number): void { try { localStorage.setItem(ZOOM_KEY, String(z)); } catch { /* memory only */ } }

const VIEW_KEY = "op77_map3d.view";
// Open / close animation lengths (styles.css: m3-map-in, m3-map-out)
const OPEN_MS = 560;
const CLOSE_MS = 240;
function loadView(): { distance: number; yaw: number; pitch: number } | null {
  try {
    const v = JSON.parse(localStorage.getItem(VIEW_KEY) ?? "null");
    return v && [v.distance, v.yaw, v.pitch].every((n) => typeof n === "number" && isFinite(n)) ? v : null;
  } catch { return null; }
}
function saveView(v: { distance: number; yaw: number; pitch: number }): void {
  try { localStorage.setItem(VIEW_KEY, JSON.stringify(v)); } catch { /* storage refused: memory only */ }
}

function clipFor(shape: string, r: { x: number; y: number; w: number; h: number }): string {
  if (shape === "circle") return `circle(${r.w / 2}px at ${r.x + r.w / 2}px ${r.y + r.h / 2}px)`;
  if (shape === "square") return `inset(${r.y}px calc(100% - ${r.x + r.w}px) calc(100% - ${r.y + r.h}px) ${r.x}px)`;
  const c = 14, x0 = r.x, y0 = r.y, x1 = r.x + r.w, y1 = r.y + r.h;
  return `polygon(${x0 + c}px ${y0}px, ${x1}px ${y0}px, ${x1}px ${y1 - c}px, ${x1 - c}px ${y1}px, ${x0}px ${y1}px, ${x0}px ${y0 + c}px)`;
}

function eta(remaining: number, r: Route): string {
  const avg = r.length > 0 ? r.length / Math.max(1, r.seconds) : 12;
  const s = remaining / Math.max(4, avg);
  return s < 60 ? `${Math.max(1, Math.round(s))} s` : `${Math.round(s / 60)} min`;
}
