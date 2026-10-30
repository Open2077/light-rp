// Everything a server can change without touching the page: shared/config.lua sends
// it on start (map3d:config) and the page deep-merges it over these defaults.

export interface Theme {
  background: string; // behind the city (the void)
  terrain: string;
  terrainGrid: string; // faint metric grid on the ground
  water: string;
  waterLine: string;
  road: string;
  roadEdge: string;
  metro: string;
  building: string; // building faces
  buildingTop: string; // roofs
  buildingEdge: string; // outline glow
  landmark: string;
  accent: string; // UI accent, route, selection
  accentSoft: string;
  text: string;
  textDim: string;
  panel: string; // HUD panel background
  danger: string;
  fog: number; // 0 = none, 1 = thick
}

export interface MinimapConfig {
  enabled: boolean;
  anchor: "top-right" | "top-left" | "bottom-right" | "bottom-left";
  size: number; // px (square)
  margin: [number, number]; // px from the anchored corners
  shape: "chamfer" | "circle" | "square";
  tilt: number; // degrees from straight down, on foot
  vehicleTilt: number; // degrees from straight down, in a vehicle
  vehicleFollow: "camera" | "vehicle"; // in a vehicle the minimap turns with the camera or the car
  rotate: boolean; // heading-up (true) or north-up
  radius: number; // metres shown from the centre on foot
  vehicleRadius: number; // metres shown at speed
  fps: number; // redraws per second at most (the route's animation needs them)
  supersample: number; // drawn at this many times the screen resolution: steadier lines
  xray: number; // metres: buildings between the camera and you are cut away (0 = off)
  showRoute: boolean;
  showLabels: boolean;
}

export interface MapViewConfig {
  initialDistance: number;
  minDistance: number;
  maxDistance: number;
  initialPitch: number; // degrees from straight down
  maxPitch: number;
  buildings: boolean;
  roadBorders: boolean;
  districtLabels: boolean;
  showCoordinates: boolean;
  doubleClickWaypoint: boolean;
  rightClickWaypoint: boolean;
  title: string;
  subtitle: string;
  resolution: number; // render scale of the open map (1 = screen pixels)
  idleFps: number; // redraws per second while nothing moves but the route animates
  search: boolean; // the search box over the legend
}

export interface GpsConfig {
  enabled: boolean;
  rerouteDistance: number; // metres off the route before a new one
  rerouteDelay: number; // seconds off the route before a new one
  arriveDistance: number;
  snapMainNetwork: boolean;
  avoidHighways: boolean;
  units: "metric" | "imperial";
  routeWidth: number; // pixels-ish at mid zoom
  animationSpeed: number; // chevrons per second
}

export interface CategoryConfig {
  id: string;
  label: string;
  icon: string;
  color?: string;
  visible?: boolean;
}

export interface InfluenceConfig {
  colors: string[]; // one per density level, lowest first
  labels: boolean; // level and count over each zone on the open map
  showCount: boolean;
  buildings: boolean; // the buildings inside a zone light up
  beaconLevel: number; // from this level on, a column of light
}

export interface MapConfig {
  theme: Theme;
  minimap: MinimapConfig;
  map: MapViewConfig;
  gps: GpsConfig;
  influence: InfluenceConfig;
  categories: CategoryConfig[];
  keys: Record<string, string>; // labels shown in the help bar
  locale: Record<string, string>;
}

export const DEFAULT_CONFIG: MapConfig = {
  theme: {
    background: "#17191f",
    terrain: "#1f2128",
    terrainGrid: "#ffcc00",
    water: "#0e1015",
    waterLine: "#4d5260",
    road: "#41444f",
    roadEdge: "#ffcc00",
    metro: "#8a6900",
    building: "#3a3d4a",
    buildingTop: "#666a7d",
    buildingEdge: "#ffcc00",
    landmark: "#ffcc00",
    accent: "#ffcc00",
    accentSoft: "rgba(255, 204, 0, 0.22)",
    text: "#f2f3f5",
    textDim: "#8a8f9c",
    panel: "rgba(6, 6, 8, 0.82)",
    danger: "#ff2e3c",
    fog: 0.35,
  },
  minimap: {
    enabled: true,
    anchor: "top-right",
    size: 264,
    margin: [32, 26],
    shape: "chamfer",
    tilt: 10,
    vehicleTilt: 54,
    vehicleFollow: "camera",
    rotate: true,
    radius: 150,
    vehicleRadius: 250,
    fps: 60,
    supersample: 1.75,
    xray: 70,
    showRoute: true,
    showLabels: false,
  },
  map: {
    initialDistance: 2600,
    minDistance: 60,
    maxDistance: 11000,
    initialPitch: 42,
    maxPitch: 72,
    buildings: true,
    roadBorders: true,
    districtLabels: true,
    showCoordinates: true,
    doubleClickWaypoint: true,
    rightClickWaypoint: false,
    title: "NIGHT CITY",
    subtitle: "CITY MAP",
    resolution: 1,
    idleFps: 30,
    search: true,
  },
  gps: {
    enabled: true,
    rerouteDistance: 38,
    rerouteDelay: 1.2,
    arriveDistance: 22,
    snapMainNetwork: true,
    avoidHighways: false,
    units: "metric",
    routeWidth: 1,
    animationSpeed: 1.6,
  },
  influence: {
    colors: ["#3FE0D0", "#FFCC00", "#FF8A1F", "#FF2E3C"],
    labels: true,
    showCount: true,
    buildings: true,
    beaconLevel: 2,
  },
  categories: [
    { id: "player", label: "Players", icon: "user" },
    { id: "service", label: "Services", icon: "store" },
    { id: "job", label: "Jobs", icon: "briefcase" },
    { id: "mission", label: "Missions", icon: "target" },
    { id: "vehicle", label: "Vehicles", icon: "car" },
    { id: "housing", label: "Housing", icon: "home" },
    { id: "default", label: "Other", icon: "pin" },
  ],
  keys: { open: "M", close: "ESC", waypoint: "Double click", recenter: "SPACE", rotate: "Right drag", pan: "Left drag" },
  locale: {
    setRoute: "Set route",
    clearRoute: "Clear route",
    waypoint: "Waypoint",
    arrived: "You have arrived",
    noRoute: "No road to that place",
    rerouting: "Rerouting",
    you: "You",
    legend: "Legend",
    recenter: "Recenter",
    northUp: "North up",
    view3d: "3D",
    view2d: "2D",
    search: "Search places",
    holo: "Holo GPS",
    influence: "Activity zones",
    density: "DENSITY",
    players: "players",
    player: "player",
    minimap: "Minimap",
    noSignal: "NO SIGNAL",
    noResults: "Nothing found",
    district: "District",
    "m.start": "START", "m.straight": "CONTINUE", "m.left": "TURN LEFT", "m.right": "TURN RIGHT",
    "m.slight-left": "KEEP LEFT", "m.slight-right": "KEEP RIGHT", "m.sharp-left": "SHARP LEFT", "m.sharp-right": "SHARP RIGHT",
    "m.uturn": "U-TURN", "m.arrive": "DESTINATION",
  },
};

type Json = Record<string, unknown>;
export function deepMerge<T>(base: T, patch: unknown): T {
  if (!patch || typeof patch !== "object" || Array.isArray(patch)) return base;
  const out: Json = { ...(base as Json) };
  for (const [k, v] of Object.entries(patch as Json)) {
    const cur = out[k];
    if (v && typeof v === "object" && !Array.isArray(v) && cur && typeof cur === "object" && !Array.isArray(cur)) out[k] = deepMerge(cur, v);
    else if (v !== undefined && v !== null) out[k] = v;
  }
  return out as T;
}
