(() => {
  "use strict";

  // MicIndicator, fed by the Lua side (client/main.lua) with one payload:
  // { visible, configured, available, captureEnabled, transmitting,
  //   microphoneDetected, inputLevel, state, mode (label), modeName, distance,
  //   color, key, modeIndex, modeCount, modes, activation, activeTalkers, error }.
  // Everything here is presentation; nothing is decided from the page.
  const STATES = ["idle", "detected", "talking", "muted", "offline"];
  const STATE_LABELS = { idle: "OPEN", detected: "SIGNAL", talking: "TRANSMIT", muted: "MUTED", offline: "VOICE OFF" };
  const STATE_SENTENCES = { idle: "Listening", detected: "Signal detected", talking: "Transmitting", muted: "Mic disabled", offline: "Voice offline" };
  // Reach presets on the design system's voice palette; unknown presets keep the server's colour.
  const REACH_COLORS = { whisper: "var(--voice-whisper)", normal: "var(--voice-live)", shout: "var(--voice-shout)" };
  const BARS = 14;

  const root = document.getElementById("voice");
  const stateLabel = document.getElementById("stateLabel");
  const modeLabel = document.getElementById("modeLabel");
  const distance = document.getElementById("distance");
  const cycleKey = document.getElementById("cycleKey");
  const talkers = document.getElementById("talkers");
  const talkerCount = document.getElementById("talkerCount");
  const meter = document.getElementById("meter");
  const ranges = document.getElementById("ranges");
  const reach = document.querySelector(".mic__reach");
  const error = document.getElementById("error");
  const micOn = document.getElementById("micOn");
  const micOff = document.getElementById("micOff");

  const meterBars = Array.from({ length: BARS }, (_, i) => {
    const bar = document.createElement("i");
    bar.style.height = (5 + (i / BARS) * 11).toFixed(1) + "px";
    if (i >= BARS - 3) bar.classList.add("peak");
    meter.append(bar);
    return bar;
  });
  meter.setAttribute("aria-valuemin", "0");
  meter.setAttribute("aria-valuemax", "100");

  let previousMode = "";
  let modeAnimationTimer = 0;
  let rangesKey = "";

  const setText = (element, value) => { if (element.textContent !== value) element.textContent = value; };
  const setAttribute = (element, name, value) => { if (element.getAttribute(name) !== value) element.setAttribute(name, value); };
  const toggle = (element, name, enabled) => { if (element.classList.contains(name) !== enabled) element.classList.toggle(name, enabled); };
  const bounded = (value, max) => String(value ?? "").slice(0, max);
  const clamp = (value, minimum, maximum) => Math.max(minimum, Math.min(maximum, Number(value) || 0));
  const safeColor = value => (/^#[0-9a-f]{6}$/i.test(String(value || "")) ? String(value) : null);
  const reachColor = (name, fallback) => REACH_COLORS[name] || safeColor(fallback) || "var(--voice-live)";

  function resolveState(value, inputLevel) {
    const supplied = bounded(value.state, 16).toLowerCase();
    if (STATES.includes(supplied)) return supplied;
    if (!value.configured || value.available === false) return "offline";
    if (!value.captureEnabled) return "muted";
    if (value.transmitting) return "talking";
    if (value.microphoneDetected || inputLevel > 0.025) return "detected";
    return "idle";
  }

  function animateModeChange(mode) {
    if (!previousMode) { previousMode = mode; return; }
    if (mode === previousMode) return;
    previousMode = mode;
    clearTimeout(modeAnimationTimer);
    root.classList.remove("mode-changing");
    void root.offsetWidth;
    root.classList.add("mode-changing");
    modeAnimationTimer = setTimeout(() => root.classList.remove("mode-changing"), 340);
  }

  function renderMeter(level, state) {
    const enabled = state !== "muted" && state !== "offline";
    const lit = enabled ? Math.round(clamp(level, 0, 1) * BARS) : 0;
    meterBars.forEach((bar, index) => toggle(bar, "lit", index < lit));
    setAttribute(meter, "aria-valuenow", String(Math.round(lit * 100 / BARS)));
  }

  // The reach presets, rebuilt only when the list itself changes.
  function renderRanges(modes, activeMode) {
    const list = Array.isArray(modes) ? modes.slice(0, 8) : [];
    const key = list.map(m => `${m?.name}|${m?.label}|${m?.color}`).join(";");
    if (key !== rangesKey) {
      rangesKey = key;
      ranges.replaceChildren();
      for (const m of list) {
        if (!m || typeof m !== "object") continue;
        const tag = document.createElement("span");
        tag.className = "mic__range";
        tag.dataset.name = bounded(m.name, 24).toLowerCase();
        tag.textContent = bounded(m.label || m.name || "", 12).toUpperCase();
        const metres = Number(m.distance);
        if (Number.isFinite(metres) && metres > 0) {
          const m2 = document.createElement("span");
          m2.className = "mic__range-m";
          m2.textContent = formatDistance(metres) + "M";
          tag.append(m2);
        }
        tag.style.setProperty("--range-color", reachColor(tag.dataset.name, m.color));
        ranges.append(tag);
      }
    }
    for (const tag of ranges.children) toggle(tag, "mic__range--on", tag.dataset.name === activeMode);
    ranges.hidden = ranges.children.length < 2;
    // With the tags on screen the separate readout would say the same thing twice.
    reach.hidden = !ranges.hidden;
  }

  function formatDistance(value) {
    const metres = Math.max(0, Number(value) || 0);
    if (metres > 0 && metres < 10 && !Number.isInteger(metres)) return metres.toFixed(1);
    return String(Math.round(metres));
  }

  function render(value = {}) {
    const inputLevel = clamp(value.inputLevel, 0, 1);
    const state = resolveState(value, inputLevel);
    const activeMode = bounded(value.modeName || value.mode || "normal", 24).toLowerCase();
    const label = bounded(value.mode || value.modeName || "Voice", 24).toUpperCase();
    const key = bounded(value.key || "F11", 12).toUpperCase();
    const heard = Math.max(0, Math.round(Number(value.activeTalkers) || 0));

    toggle(root, "visible", value.visible !== false);
    for (const name of STATES) toggle(root, `state-${name}`, name === state);
    const color = reachColor(activeMode, value.color);
    if (root.style.getPropertyValue("--mode-color") !== color) root.style.setProperty("--mode-color", color);

    const off = state === "muted" || state === "offline";
    if (micOn.hidden !== off) micOn.hidden = off;
    if (micOff.hidden !== !off) micOff.hidden = !off;

    setText(stateLabel, STATE_LABELS[state]);
    setText(modeLabel, label);
    setText(distance, formatDistance(value.distance));
    setText(cycleKey, key);
    setText(talkerCount, String(heard));
    if (talkers.hidden !== (heard === 0)) talkers.hidden = heard === 0;

    renderMeter(inputLevel, state);
    renderRanges(value.modes, activeMode);
    animateModeChange(activeMode);

    const errorText = bounded(value.error, 80);
    setText(error, errorText);
    toggle(error, "active", errorText.length > 0);

    setAttribute(root, "aria-label", `Voice ${STATE_SENTENCES[state]}, ${label}, ${formatDistance(value.distance)} metres`);
    setAttribute(root, "title", `${STATE_SENTENCES[state]} · ${label} · ${formatDistance(value.distance)} m · ${key}`);
  }

  Open77.on("open-voice:update", render);
  Open77.ready();
  Open77.emit("open-voice:ready", {});
})();
