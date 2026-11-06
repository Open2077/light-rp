import "./styles.css";
import { MapApp } from "./app";
import { inGame, dispatchLocal, setMockEmit, on } from "./bridge";
import { HoloGps } from "./holo";
import { loadRoadData } from "./data";
import { RoadGraph } from "./gps";

const app = new MapApp(document.getElementById("app")!);

if (!inGame) {
  // Browser preview: a player driving around City Center, a few blips, the map open
  // with ?open=1, a route with ?route=1. Nothing here runs in game.
  const q = new URLSearchParams(location.search);
  // ?holo=1: the holographic GPS, fed by this page's own route (in game it has a surface of its own)
  const holo = q.has("holo") ? new HoloGps(document.getElementById("app")!) : null;
  if (holo) on("map3d:player", (p) => { if (!q.has("fixed")) holo.setPose(p.x, p.y, p.vehicle ? p.yaw : p.camYaw, p.z); });
  (window as { __holo?: HoloGps }).__holo = holo ?? undefined;
  if (holo) void loadRoadData().then((roads) => {
    holo.setRoads(roads);
    if (!q.has("holotest")) return;
    // ?holotest=1&at=<m>&speed=<m/s>: drive along a real route (City Center -> Kabuki)
    // the way the game would feed the holo: its own pose, the route window ahead
    const r = new RoadGraph(roads).route({ x: -1450, y: 140 }, { x: -747.8, y: 914.6 }, { mainOnly: true })!;
    let along = Number(q.get("at") ?? 0);
    const speed = Number(q.get("speed") ?? 0);
    const n = r.cumulative.length;
    const tick = () => {
      along = Math.min(r.length - 1, along + speed / 30);
      let i = 0;
      while (i + 2 < n && r.cumulative[i + 1] < along) i++;
      const f = (along - r.cumulative[i]) / Math.max(1e-6, r.cumulative[i + 1] - r.cumulative[i]);
      const P = r.points, ax = P[i * 3], ay = P[i * 3 + 1], az = P[i * 3 + 2], bx = P[i * 3 + 3], by = P[i * 3 + 4];
      const yaw = (Math.atan2(-(bx - ax), by - ay) * 180) / Math.PI;
      holo.setPose(ax + (bx - ax) * f, ay + (by - ay) * f, yaw, az);
      let first = 0;
      while (first + 1 < n && r.cumulative[first + 1] < along - 10) first++;
      const pts: number[] = [];
      for (let k = first; k < n && pts.length < 240; k++) { pts.push(P[k * 3], P[k * 3 + 1], P[k * 3 + 2]); if (r.cumulative[k] > along + 450) break; }
      holo.setRoute({ pts, s0: r.cumulative[first], dest: { x: -747.8, y: 914.6, z: 30 } });
    };
    tick();
    setInterval(tick, 33);
  });
  setMockEmit((name, payload) => {
    if (name === "map3d:holo") { holo?.setRoute(payload as never); return; }
    console.log("[map3d mock] page ->", name, payload);
    if (name === "map3d:close") dispatchLocal("map3d:close", {});
  });
  const path = [[-1505, 120], [-1380, 120], [-1300, 210], [-1180, 300], [-1040, 300], [-900, 330]];
  let t = 0;
  const player = () => {
    // ?px=-1750&py=-2500: the mock player stands there (the minimap over a place)
    if (q.has("px")) {
      dispatchLocal("map3d:player", { x: Number(q.get("px")), y: Number(q.get("py") ?? 0), z: 40, yaw: Number(q.get("pyaw") ?? 30), camYaw: Number(q.get("pyaw") ?? 30), speed: 0, vehicle: false });
      return;
    }
    t += 0.0035;
    const k = (Math.sin(t) * 0.5 + 0.5) * (path.length - 1);
    const i = Math.min(path.length - 2, Math.floor(k)), f = k - i;
    const [ax, ay] = path[i], [bx, by] = path[i + 1];
    const yaw = (Math.atan2(-(bx - ax), by - ay) * 180) / Math.PI;
    dispatchLocal("map3d:player", { x: ax + (bx - ax) * f, y: ay + (by - ay) * f, z: 20, yaw, camYaw: yaw, speed: q.has("drive") ? 18 : 2, vehicle: q.has("drive") });
  };
  // ?quality=quality: the 3D city (performance by default, as in game); ?ask=1: the first
  // opening's question
  setTimeout(() => {
    dispatchLocal("map3d:quality", { mode: q.get("quality") === "quality" ? "quality" : "performance", chosen: !q.has("ask") });
    if (q.has("theme")) dispatchLocal("map3d:config", { theme: { accent: "#3fe0d0", roadEdge: "#3fe0d0", buildingEdge: "#3fe0d0", terrainGrid: "#3fe0d0" } });
    dispatchLocal("map3d:blips", { set: [
      { id: "a", x: -1188, y: 320, icon: "store", label: "24/7 Store", category: "service", description: "Snacks, water and phone credit." },
      { id: "b", x: -1600, y: -40, icon: "garage", label: "Kabuki Garage", category: "vehicle", color: "#7fb4d6" },
      { id: "c", x: -2044, y: -2406, icon: "mission", label: "Chimera Protocol", category: "mission", color: "#ff2e3c", pulse: true, edge: true, description: "RAID - Dogtown arena." },
      { id: "d", x: -747.8, y: 914.6, icon: "home", label: "Kabuki Apartment", category: "housing", color: "#8fe04a" },
      { id: "e", x: -1450, y: 600, icon: "briefcase", label: "Courier depot", category: "job" },
      { id: "f", x: -1330, y: 160, heading: 90, label: "Jack", category: "player", color: "#3fe0d0" },
      ...(q.has("cluster") ? [
        { id: "g1", x: -1186, y: 318, icon: "car", label: "Rent-a-Ride", category: "vehicle" },
        { id: "g2", x: -1190, y: 322, icon: "shirt", label: "Wardrobe", category: "service" },
        { id: "g3", x: -1184, y: 324, icon: "pin", label: "Job Center // City Center", category: "job" },
      ] : []),
    ] });
    if (q.has("jam")) dispatchLocal("map3d:jam", { strength: Number(q.get("jam")), label: q.get("label") ?? undefined });
    // ?areas=1: Light RP's Dogtown danger zone (try ?areas=1&open=1&dist=2600&fx=-1750&fy=-2450)
    if (q.has("areas")) {
      const dogtown = [-2550, -2726.6, -2410, -2846.6, -2450, -3006.6, -2410, -3146.6, -1930, -3066.6, -1910, -3006.6, -1690, -2946.6, -1510, -2866.6,
        -1510, -2806.6, -1370, -2766.6, -1250, -2586.6, -1290, -2366.6, -1050, -2246.6, -1010, -2146.6, -1050, -1886.6, -1150, -1806.6,
        -1390, -1786.6, -1550, -1906.6, -1570, -2026.6, -1830, -2086.6, -1930, -2206.6, -2030, -2206.6, -2070, -2286.6, -2150, -2286.6,
        -2230, -2426.6, -2350, -2466.6, -2350, -2546.6, -2430, -2566.6, -2430, -2626.6, -2530, -2666.6];
      dispatchLocal("map3d:area", { id: "op77_lightrp:lightrp.dogtown", pts: dogtown, fill: "#FF2E3C", fillOpacity: Number(q.get("fo") ?? 0.22), stroke: "#FF2E3C", strokeWidth: 2.5,
        pattern: "hatch", label: "DOGTOWN · DANGER ZONE", lx: Number(q.get("lx") ?? -1420), ly: Number(q.get("ly") ?? -2560), map: true, minimap: true, pulse: q.get("areas") === "pulse" });
      dispatchLocal("map3d:area", { id: "demo:solid", pts: [-1250, 250, -1120, 250, -1120, 380, -1250, 380], fill: "#3FE0D0", fillOpacity: 0.18, pattern: "solid", label: "SOLID AREA" });
    }
    // ?zones=1: influence zones at every density level, one of them filling up and emptying
    if (q.has("zones")) {
      const levels = [{ min: 5, id: "active", label: "ACTIVE" }, { min: 10, id: "busy", label: "BUSY" }, { min: 18, id: "crowded", label: "CROWDED" }, { min: 30, id: "hotspot", label: "HOTSPOT" }];
      const level = (n: number) => levels.reduce((k, l, i) => (n >= l.min ? i + 1 : k), 0);
      let crowd = 5;
      const send = () => dispatchLocal("map3d:influence", { enabled: true, levels, zones: [
        { id: "z1", x: -1420, y: 160, z: 20, radius: 260, count: 34, level: level(34) },
        { id: "z2", x: -1150, y: 330, z: 18, radius: 160, count: crowd, level: level(crowd) },
        { id: "z3", x: -1700, y: -120, z: 12, radius: 110, count: 6, level: level(6) },
        { id: "z4", x: -980, y: -60, z: 22, radius: 200, count: 19, level: level(19) },
        { id: "z5", x: -760, y: 900, z: 30, radius: 140, count: 11, level: level(11) },
      ] });
      send();
      if (!q.has("still")) setInterval(() => { crowd = crowd >= 32 ? 5 : crowd + 3; send(); }, 3000);
    }
    if (q.has("open")) dispatchLocal("map3d:open", {});
    if (q.has("dist")) setTimeout(() => dispatchLocal("map3d:focus", { x: Number(q.get("fx") ?? -1450), y: Number(q.get("fy") ?? 150), distance: Number(q.get("dist")) }), 300);
    if (q.has("route")) dispatchLocal("map3d:route", { x: -747.8, y: 914.6, z: 30 });
  }, 50);
  player();
  setInterval(player, 100);
}

void app.start();
