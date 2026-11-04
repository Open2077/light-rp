/* Large messages from client/main.lua. The WebUI bridge refuses a message of more than
   1024 values without a word, and the clinic's open (the whole catalogue) is about 1600:
   the page never got rd:open (LightRP Testing, 2026-11-04). The client sends such a
   payload as JSON text, { __json } in one message or { __part: { id, i, n, text } } in
   several; this wraps Open77.on so every handler still receives the plain object.
   Loaded before app.js (a classic script runs before the module). Not part of the
   ripperdoc-ui build: keep it in index.html when the page is rebuilt. */
(function () {
  "use strict";
  function wrap(bridge) {
  if (!bridge || typeof bridge.on !== "function" || bridge.__partsWrapped) return;
  var on = bridge.on.bind(bridge);
  var pending = {}; // event name -> { id, parts, got }
  function decode(name, payload) {
    if (!payload || typeof payload !== "object") return { ready: true, value: payload };
    if (typeof payload.__json === "string") return { ready: true, value: JSON.parse(payload.__json) };
    var part = payload.__part;
    if (!part || typeof part.text !== "string") return { ready: true, value: payload };
    var n = Number(part.n), i = Number(part.i);
    if (!(n >= 1 && n <= 512 && i >= 1 && i <= n)) return { ready: false };
    var entry = pending[name];
    if (!entry || entry.id !== part.id) { entry = { id: part.id, parts: new Array(n), got: 0 }; pending[name] = entry; }
    if (entry.parts[i - 1] === undefined) { entry.parts[i - 1] = part.text; entry.got += 1; }
    if (entry.got < n) return { ready: false };
    delete pending[name];
    return { ready: true, value: JSON.parse(entry.parts.join("")) };
  }
  bridge.on = function (name, handler) {
    return on(name, function (payload) {
      var out;
      try { out = decode(name, payload); }
      catch (e) { console.error("[ripperdoc] " + name + " did not decode", e); return; }
      if (out.ready) return handler(out.value);
    });
  };
  bridge.__partsWrapped = true;
  }
  if (window.Open77) { wrap(window.Open77); return; }
  // The bridge not injected yet: wrap it the moment it is.
  var held;
  try {
    Object.defineProperty(window, "Open77", { configurable: true, enumerable: true,
      get: function () { return held; },
      set: function (value) { held = value; wrap(value); } });
  } catch (e) { console.error("[ripperdoc] bridge hook unavailable", e); }
})();
