"use strict";

// The Titan HUD's drawing page. render.lua sends one frame per game frame, as ONE string, with the event "hud:frame";
// the page keeps the newest and paints it on the next animation frame, so a slow paint never queues old frames.
//
// A frame is text. Its first line is "W H": the space the controller drew in (the integer pixels of the game's
// picture); the canvas maps that space onto the whole surface. Every other line is one primitive. All numbers are
// integers: coordinates, radii, rounding, thickness and text sizes are in tenths of a pixel; a colour is ImGui's packed
// ABGR (0xAABBGGRR) in hex.
//
//   L x1 y1 x2 y2 col thickness
//   R x1 y1 x2 y2 col rounding thickness filled       filled is 0 or 1
//   C x y radius col segments thickness filled        segments 0 is a smooth circle, 3 and up a polygon
//   P x1 y1 x2 y2 x3 y3 col thickness filled
//   T x y col size text                               text is the rest of the line, "\" and newline escaped
//
// A frame with no primitive clears the canvas. The shapes follow ImGui's draw list (butt-capped lines, a 0.5 px
// offset for lines and outlines, the rounding clamp), because the controller's layout was made against it.
(() => {
  const FONT = HUD_FONT;
  const canvas = document.getElementById("hud");
  const ctx = canvas.getContext("2d", { alpha: true });

  // The line box is ascent - descent font units tall and is what the "size" of a text means (ImGui sizes a TTF the
  // same way). ui/hud_font.lua holds the same table, so render.lua's textSize is exactly what is laid out here.
  const LINE_UNITS = FONT.ascent - FONT.descent;
  const ADVANCE = new Map(Object.entries(FONT.advance).map(([cp, units]) => [Number(cp), units]));
  const QUESTION = 0x3f;
  const TAU = Math.PI * 2;

  let frame = null;
  let pending = false;
  let currentFont = "";

  // ---- the canvas ----------------------------------------------------------------------------------------------

  // Resizing a canvas resets its state, so this runs again after every resize.
  function configure() {
    ctx.textRendering = "geometricPrecision";
    ctx.fontKerning = "none";
    currentFont = "";
  }

  // The backing store is the surface's own device pixels, so a line one pixel wide is one pixel wide on the screen.
  function fit() {
    const ratio = window.devicePixelRatio || 1;
    const width = Math.max(1, Math.round(window.innerWidth * ratio));
    const height = Math.max(1, Math.round(window.innerHeight * ratio));
    if (canvas.width === width && canvas.height === height) return false;
    canvas.width = width;
    canvas.height = height;
    configure();
    return true;
  }

  const styles = new Map();
  function css(color) {
    let style = styles.get(color);
    if (style === undefined) {
      if (styles.size >= 1024) styles.clear();
      style = `rgba(${color & 255},${(color >>> 8) & 255},${(color >>> 16) & 255},${((color >>> 24) / 255).toFixed(4)})`;
      styles.set(color, style);
    }
    return style;
  }

  // ---- primitives ----------------------------------------------------------------------------------------------

  function stroke(color, thickness) {
    ctx.strokeStyle = css(color);
    ctx.lineWidth = thickness;
    ctx.stroke();
  }

  function drawLine(f) {
    ctx.beginPath();
    ctx.moveTo(f[0] / 10 + 0.5, f[1] / 10 + 0.5);
    ctx.lineTo(f[2] / 10 + 0.5, f[3] / 10 + 0.5);
    stroke(parseInt(f[4], 16), f[5] / 10);
  }

  function drawRect(f) {
    const color = parseInt(f[4], 16);
    const a = f[0] / 10, b = f[1] / 10, c = f[2] / 10, d = f[3] / 10;
    const rounding = f[5] / 10;
    let x = Math.min(a, c), y = Math.min(b, d);
    let w = Math.abs(c - a), h = Math.abs(d - b);
    const filled = f[7] === "1";
    if (!filled) {
      // ImGui strokes the outline half a pixel inside the box, so a one pixel outline is the box's own pixels.
      x += 0.5; y += 0.5;
      w = Math.max(0, w - 1); h = Math.max(0, h - 1);
    }
    ctx.beginPath();
    if (rounding > 0) ctx.roundRect(x, y, w, h, Math.min(rounding, w / 2, h / 2));
    else ctx.rect(x, y, w, h);
    if (filled) {
      ctx.fillStyle = css(color);
      ctx.fill();
    } else {
      stroke(color, f[6] / 10);
    }
  }

  function drawCircle(f) {
    const color = parseInt(f[3], 16);
    const segments = Number(f[4]);
    const filled = f[6] === "1";
    const x = f[0] / 10, y = f[1] / 10;
    const radius = f[2] / 10 - (filled ? 0 : 0.5);
    ctx.beginPath();
    if (segments === 0) {
      ctx.arc(x, y, radius, 0, TAU);
    } else {
      for (let i = 0; i < segments; i++) {
        const angle = (TAU * i) / segments;
        const px = x + Math.cos(angle) * radius, py = y + Math.sin(angle) * radius;
        if (i === 0) ctx.moveTo(px, py);
        else ctx.lineTo(px, py);
      }
    }
    ctx.closePath();
    if (filled) {
      ctx.fillStyle = css(color);
      ctx.fill();
    } else {
      stroke(color, f[5] / 10);
    }
  }

  function drawTriangle(f) {
    const color = parseInt(f[6], 16);
    ctx.beginPath();
    ctx.moveTo(f[0] / 10, f[1] / 10);
    ctx.lineTo(f[2] / 10, f[3] / 10);
    ctx.lineTo(f[4] / 10, f[5] / 10);
    ctx.closePath();
    if (f[8] === "1") {
      ctx.fillStyle = css(color);
      ctx.fill();
    } else {
      stroke(color, f[7] / 10);
    }
  }

  // One glyph at a time, each at the pen position the advance table gives: the layout is then render.lua's
  // textSize by construction, whatever kerning, hinting or subpixel positioning the browser would have applied to a
  // whole run. The top-left of the first line's box is (x, y); a newline starts a line `size` lower.
  function drawText(x, y, color, size, text) {
    const face = `500 ${(size * FONT.unitsPerEm) / LINE_UNITS}px ${FONT.family}`;
    if (face !== currentFont) {
      ctx.font = face;
      ctx.textBaseline = "alphabetic";
      currentFont = face;
    }
    ctx.fillStyle = css(color);
    const k = size / LINE_UNITS;
    const baseline = (size * FONT.ascent) / LINE_UNITS;
    let pen = x;
    let top = y;
    for (const ch of text) {
      const cp = ch.codePointAt(0);
      if (cp === 10) {
        pen = x;
        top += size;
        continue;
      }
      if (cp < 0x20 || (cp >= 0x7f && cp <= 0x9f)) continue;
      let units = ADVANCE.get(cp);
      let glyph = ch;
      if (units === undefined) {
        units = ADVANCE.get(QUESTION);
        glyph = "?";
      }
      if (cp !== 0x20 && cp !== 0xa0) ctx.fillText(glyph, pen, top + baseline);
      pen += units * k;
    }
  }

  function textLine(line) {
    const rest = line.slice(1);
    const f = [];
    let from = 0;
    for (let i = 0; i < 4; i++) {
      const to = rest.indexOf(" ", from);
      if (to < 0) return;
      f.push(rest.slice(from, to));
      from = to + 1;
    }
    let text = rest.slice(from);
    if (text.indexOf("\\") >= 0) text = text.replace(/\\(.)/g, (_, c) => (c === "n" ? "\n" : c));
    drawText(f[0] / 10, f[1] / 10, parseInt(f[2], 16), f[3] / 10, text);
  }

  function primitive(line) {
    switch (line.charCodeAt(0)) {
      case 0x4c: drawLine(line.slice(1).split(" ")); break;      // L
      case 0x52: drawRect(line.slice(1).split(" ")); break;      // R
      case 0x43: drawCircle(line.slice(1).split(" ")); break;    // C
      case 0x50: drawTriangle(line.slice(1).split(" ")); break;  // P
      case 0x54: textLine(line); break;                          // T
      default: break;
    }
  }

  // ---- frames --------------------------------------------------------------------------------------------------

  function paint() {
    pending = false;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (frame === null) return;
    const lines = frame.split("\n");
    if (lines.length < 2) return;
    const space = lines[0].split(" ");
    const width = Number(space[0]);
    const height = Number(space[1]);
    if (!(width > 0 && height > 0)) return;
    // The controller's space is the game's picture; the canvas is the same picture, so this is 1 to 1 up to rounding.
    ctx.setTransform(canvas.width / width, 0, 0, canvas.height / height, 0, 0);
    for (let i = 1; i < lines.length; i++) primitive(lines[i]);
  }

  function schedule() {
    if (pending) return;
    pending = true;
    window.requestAnimationFrame(paint);
  }

  Open77.on("hud:frame", (text) => {
    if (typeof text !== "string") return;
    frame = text;
    schedule();
  });

  window.addEventListener("resize", () => {
    if (fit()) schedule();
  });
  configure();
  fit();

  // The Lua side sends nothing before this: a frame needs the font, or its glyphs would be some other font's.
  let announced = false;
  function announce(font) {
    if (announced) return;
    announced = true;
    Open77.emit("ui:ready", { version: 1, font });
  }
  const timeout = new Promise((_, reject) => window.setTimeout(() => reject(new Error("font load timed out")), 3000));
  Promise.race([document.fonts.load(`500 16px ${FONT.family}`, "?"), timeout])
    .then((faces) => announce(faces.length > 0))
    .catch(() => announce(false));
})();
