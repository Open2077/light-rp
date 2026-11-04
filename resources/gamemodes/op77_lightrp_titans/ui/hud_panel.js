"use strict";

// The Titan HUD's DOM panels. open77_titan_hud.lua builds the state while V pilots BT and render.lua sends it, as ONE table, with
// the event "hud:state"; a state with `on` false (or none) clears every panel. Updates change only what differs: the page is
// drawn at the game's rate, the state arrives at most ten times a second.
//
//   { on = true, hints = true, top = 0.13,
//     className = "Vanguard", held = false,
//     allowed = { missiles, vortex, smoke, dash, jets, sentry, flight, designator, core },
//     hull = { segments, segment, hull, shield (0..1), doomed (0..1), doomedText, low, name, flash },
//     core = { share (0..1), state = "charging" | "ready" | "active", key, need (0..1, a mark) },
//     weapon = { id, name, melee, ammo, capacity, reload = { left, done (0..1) }, notes = { text, ... } },
//     abilities = { { id, name, key, state = "ready" | "empty" | "active", fill (0..1), count, left (seconds), tone }, ... },
//     protocols = { link (0..3), lamps = { { name, have, on, left (0..1), color }, x3 } },
//     controls = { { key, label }, ... },
//     notice = "eject" | "leave",
//     grab = { phase = "ready" | "held" | "charging", key, label, target = "person" | "vehicle", charge (0..1) } }
//
// This page draws the notice, the carry's prompt, the protocol lamps and the control hints. The rest of the state (the class and
// the hold, the hull, the core, the weapon, the abilities) is LightRP's HUD's: it reads the same table from the resource's
// `hudState` export and shows it on its vitals, its weapon readout and its ability bar. Of that rest the page reads only
// `allowed`, `abilities` and `core`, to drop a control hint whose key LightRP's bar already shows. Every field but `on` is
// optional; a panel whose field is missing is hidden. Nothing in the state is trusted for markup: text goes in through
// textContent, numbers are clamped. `top` (the old hull placement) is not used.
(() => {
  const byId = (id) => document.getElementById(id);
  const body = document.body;
  const refs = {
    notice: byId("notice"),
    grab: byId("grab"), grabKey: byId("grab-key"), grabLabel: byId("grab-label"), grabSub: byId("grab-sub"),
    grabTarget: byId("grab-target"), grabCharge: byId("grab-charge"),
    controls: byId("controls"), protocols: byId("protocols"), protocolsLink: byId("protocols-link"),
    lamps: byId("protocols-lamps"),
  };
  const noticeText = refs.notice.firstElementChild;
  const grabChargeFill = refs.grabCharge.querySelector("i");

  const GRAB_SUB = { ready: "", held: "HOLD TO CHARGE", charging: "RELEASE TO THROW" };

  // The controller's control hints (open77_titan_hud.lua CONTROLS) that name an ability, by their label: a hint is dropped when
  // the class may not use that ability, and when LightRP's ability bar already shows its key.
  const HINT_ABILITY = { "Jump / jets": "jets", "Dash": "dash", "Burst core": "core", "Flight strike": "flight" };

  const num = (v, fallback = 0) => (typeof v === "number" && Number.isFinite(v) ? v : fallback);
  const clamp01 = (v) => Math.min(1, Math.max(0, num(v)));
  const percent = (v) => `${(clamp01(v) * 100).toFixed(1)}%`;
  const text = (v, limit = 32) => (typeof v === "string" ? v.slice(0, limit) : "");

  // Setting a property to the value it has costs a style recalculation: every write goes through one of these.
  function setText(node, value) {
    const next = String(value);
    if (node.textContent !== next) node.textContent = next;
  }
  function setAttr(node, name, value) {
    const next = String(value);
    if (node.getAttribute(name) !== next) node.setAttribute(name, next);
  }
  function setData(node, name, value) {
    if (node.dataset[name] !== String(value)) node.dataset[name] = String(value);
  }
  function show(node, on) {
    if (node.hidden === on) node.hidden = !on;
  }
  function setWidth(node, share) {
    const next = percent(share);
    if (node.style.width !== next) node.style.width = next;
  }

  // ---- the class's ability lock ----------------------------------------------------------------------------------------

  function lockOf(allowed) {
    if (!allowed || typeof allowed !== "object") return () => true;
    return (id) => allowed[id] === true;
  }

  // The abilities LightRP's bar shows a key for: a cell for each ability the class may use, and the core's.
  function barIds(state, lock) {
    const ids = new Set();
    if (Array.isArray(state.abilities)) {
      for (const a of state.abilities) if (a && typeof a.id === "string" && lock(a.id)) ids.add(a.id);
    }
    if (state.core && typeof state.core === "object" && lock("core")) ids.add("core");
    return ids;
  }

  // ---- notices ---------------------------------------------------------------------------------------------------------

  const NOTICES = { eject: "EJECTING", leave: "BT STOPS - V CLIMBS OUT" };

  function renderNotice(kind) {
    const label = typeof kind === "string" ? NOTICES[kind] : undefined;
    show(refs.notice, label !== undefined);
    if (label === undefined) return;
    setData(refs.notice, "kind", kind);
    setText(noticeText, label);
  }

  // ---- the carry's prompt ----------------------------------------------------------------------------------------------

  function renderGrab(g) {
    const phase = g && (g.phase === "held" || g.phase === "charging" || g.phase === "ready") ? g.phase : null;
    show(refs.grab, phase !== null);
    if (phase === null) return;
    setData(refs.grab, "phase", phase);
    setData(refs.grab, "target", g.target === "vehicle" ? "vehicle" : "person");
    setText(refs.grabKey, text(g.key, 8) || "E");
    setText(refs.grabLabel, text(g.label, 24).toUpperCase());
    setText(refs.grabSub, GRAB_SUB[phase]);
    setText(refs.grabTarget, g.target === "vehicle" ? "VEHICLE" : "PERSON");
    show(refs.grabCharge, phase === "charging");
    if (phase === "charging") setWidth(grabChargeFill, g.charge);
  }

  // ---- protocols -------------------------------------------------------------------------------------------------------

  function renderProtocols(p) {
    const lamps = p && Array.isArray(p.lamps) ? p.lamps.slice(0, 3) : [];
    show(refs.protocols, lamps.length > 0);
    if (lamps.length === 0) return;
    if (refs.lamps.children.length !== lamps.length) {
      refs.lamps.replaceChildren(...lamps.map(() => {
        const lamp = document.createElement("div");
        lamp.className = "lamp";
        lamp.append(document.createElement("b"));
        return lamp;
      }));
    }
    lamps.forEach((lamp, index) => {
      const node = refs.lamps.children[index];
      const color = typeof lamp.color === "string" && /^#[0-9a-f]{6}$/i.test(lamp.color) ? lamp.color : "#ffffff";
      if (node.style.getPropertyValue("--c") !== color) node.style.setProperty("--c", color);
      setAttr(node, "title", text(lamp.name, 32));
      setData(node, "have", lamp.have === true);
      setData(node, "on", lamp.on === true);
      setWidth(node.firstElementChild, lamp.on === true ? lamp.left : 0);
    });
    const link = num(p.link);
    setText(refs.protocolsLink, link >= 3 ? "FULL LINK" : link >= 2 ? "LINK" : "");
  }

  // ---- control hints ---------------------------------------------------------------------------------------------------

  let hintsSignature = "";

  // `shown` holds the abilities whose key LightRP's bar already shows (the core counts as "core").
  function renderControls(list, wanted, lock, shown) {
    const items = wanted && Array.isArray(list)
      ? list.filter((c) => c && typeof c.key === "string" && typeof c.label === "string")
        .filter((c) => {
          const ability = HINT_ABILITY[c.label];
          return ability === undefined || (lock(ability) && !shown.has(ability));
        })
        .slice(0, 12)
      : [];
    show(refs.controls, items.length > 0);
    const signature = items.map((c) => `${c.key}\u0000${c.label}`).join("\u0001");
    if (signature === hintsSignature) return;
    hintsSignature = signature;
    refs.controls.replaceChildren(...items.map((c) => {
      const hint = document.createElement("span");
      hint.className = "hint";
      const key = document.createElement("kbd");
      key.className = "keycap keycap--sm";
      key.textContent = text(c.key, 10);
      const label = document.createElement("span");
      label.textContent = text(c.label, 28);
      hint.append(key, label);
      return hint;
    }));
  }

  // ---- the state -------------------------------------------------------------------------------------------------------

  const noLock = () => true;

  function clear() {
    setData(body, "on", false);
    renderNotice(null);
    renderGrab(null);
    renderProtocols(null);
    renderControls([], false, noLock, new Set());
  }

  const object = (v) => (v && typeof v === "object" ? v : null);

  function render(state) {
    if (!state || typeof state !== "object" || state.on !== true) {
      clear();
      return;
    }
    const lock = lockOf(state.allowed);
    setData(body, "on", true);
    renderNotice(state.notice);
    renderGrab(object(state.grab));
    renderProtocols(object(state.protocols));
    renderControls(state.controls, state.hints !== false, lock, barIds(state, lock));
  }

  // The DOM faces load on first use, which would show a fallback face in the first state's first frame: ask for them now.
  if (document.fonts && typeof document.fonts.load === "function") {
    for (const face of ["600 12px 'Chakra Petch'", "400 12px 'Share Tech Mono'"]) {
      document.fonts.load(face, "A0").catch(() => {});
    }
  }

  if (window.Open77 && typeof window.Open77.on === "function") {
    Open77.on("hud:state", render);
  } else if (new URLSearchParams(location.search).has("preview")) {
    // Design preview in a plain browser: ?preview[=carry|charging|eject|leave|melee|northstar]
    const mode = new URLSearchParams(location.search).get("preview");
    const grab = { carry: { phase: "ready", key: "E", label: "Grab", target: "person" },
      charging: { phase: "charging", key: "E", label: "Throw", target: "person", charge: 0.62 } }[mode] || null;
    const everything = { missiles: true, vortex: true, smoke: true, dash: true, jets: true, sentry: true, flight: true, designator: true, core: true };
    const lockedAll = Object.fromEntries(Object.keys(everything).map((id) => [id, false]));
    const only = (...ids) => ({ ...lockedAll, ...Object.fromEntries(ids.map((id) => [id, true])) });
    render({
      on: true, hints: true,
      allowed: mode === "melee" ? only("dash", "smoke", "core") : mode === "northstar" ? only("jets", "flight", "designator", "core") : only("missiles", "vortex", "jets", "core"),
      core: { share: 0.62, state: "charging" },
      abilities: [{ id: "missiles", state: "ready" }, { id: "vortex", state: "empty" }, { id: "jets", state: "ready" }],
      protocols: { link: 2, lamps: [{ name: "Protocol 1", have: true, on: true, left: 0.6, color: "#ffcc00" },
        { name: "Protocol 2", have: true, on: true, left: 0.3, color: "#7fb4d6" }, { name: "Protocol 3", have: false, color: "#ff2e3c" }] },
      controls: [{ key: "SPACE", label: "Jump / jets" }, { key: "L-CTRL", label: "Dash" }, { key: "V", label: "Melee" },
        { key: "X", label: "Burst core" }, { key: "T", label: "View" }, { key: "Z", label: "Shoulder" },
        { key: "E", label: "Disembark (hold)" }],
      notice: mode === "eject" || mode === "leave" ? mode : undefined,
      grab,
    });
  }
})();
