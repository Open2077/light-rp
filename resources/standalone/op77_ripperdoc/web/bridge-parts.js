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
  // What the page received and every error it hit go to the server log (rd:diag, relayed by
  // client/main.lua): a blank page with the cursor alone said nothing (2026-11-05).
  function diag(text) { try { bridge.emit("rd:diag", { text: String(text).slice(0, 300) }); } catch (e) { /* no bridge */ } }
  window.addEventListener("error", function (e) {
    diag("error: " + (e && e.message) + " @" + (e && e.filename ? String(e.filename).split("/").pop() : "?") + ":" + (e && e.lineno));
  });
  window.addEventListener("unhandledrejection", function (e) { diag("rejection: " + (e && e.reason)); });
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
  // Some clients hand the page a frozen Open77 ("Cannot assign to read only property 'on'",
  // 2026-11-05): nothing to wrap there; the app decodes the parts itself (src/bridge.ts).
  var wrapped = function (name, handler) {
    return on(name, function (payload) {
      var out;
      try { out = decode(name, payload); }
      catch (e) { console.error("[ripperdoc] " + name + " did not decode", e); diag(name + " did not decode: " + e); return; }
      if (!out.ready) return;
      try { return handler(out.value); }
      catch (e) { diag(name + " handler threw: " + e); throw e; }
    });
  };
  try { bridge.on = wrapped; bridge.__partsWrapped = true; }
  catch (e) { diag("bridge is read-only: the app decodes large messages itself"); }
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
