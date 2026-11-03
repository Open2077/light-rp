import { useEffect, useRef, useState } from "react";
import { on } from "@/bridge/open77";
import { FRAGMENT, VERTEX } from "./signalShader";
import "./announce.css";

/* Staff voice announcements (server/modules/announce.lua, client/core/announce.lua):
   while someone is on air for us, a pixelated cyber signal hangs at the top of the screen
   (signalShader.ts: an oscilloscope trace, a LED equalizer, radar rings) and follows their
   live voice level. The speaker sees their own. */
export const ANNOUNCE_PAGE = "lightrp:ui:announce";

interface Cast { speaker: number; name: string; mode: "server" | "radius"; radius?: number | null; self: boolean; audience: number }
type AnnounceEvent =
  | ({ kind: "cast" } & Cast)
  | { kind: "end"; speaker: number }
  | { kind: "level"; speaker: number; level: number; talking: boolean };

interface Live { level: number; talking: boolean; at: number }

function compile(gl: WebGLRenderingContext): WebGLProgram | null {
  const shader = (type: number, src: string) => {
    const s = gl.createShader(type);
    if (!s) return null;
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) { console.warn("[announce] shader:", gl.getShaderInfoLog(s)); return null; }
    return s;
  };
  const vs = shader(gl.VERTEX_SHADER, VERTEX), fs = shader(gl.FRAGMENT_SHADER, FRAGMENT);
  if (!vs || !fs) return null;
  const prog = gl.createProgram();
  if (!prog) return null;
  gl.attachShader(prog, vs); gl.attachShader(prog, fs); gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) { console.warn("[announce] link:", gl.getProgramInfoLog(prog)); return null; }
  return prog;
}

export function AnnounceHalo() {
  const [casts, setCasts] = useState<Record<number, Cast>>({});
  const [focus, setFocus] = useState<number | null>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const fallbackRef = useRef<HTMLDivElement>(null);
  const labelRef = useRef<HTMLDivElement>(null);
  const live = useRef<Record<number, Live>>({});
  const castsRef = useRef(casts);
  castsRef.current = casts;

  useEffect(() => on<AnnounceEvent>(ANNOUNCE_PAGE, e => {
    if (!e || typeof e !== "object") return;
    if (e.kind === "cast") {
      setCasts(c => ({ ...c, [e.speaker]: { speaker: e.speaker, name: e.name, mode: e.mode, radius: e.radius, self: e.self, audience: e.audience } }));
    } else if (e.kind === "end") {
      delete live.current[e.speaker];
      setCasts(c => { const n = { ...c }; delete n[e.speaker]; return n; });
    } else if (e.kind === "level") {
      live.current[e.speaker] = { level: Math.max(0, Math.min(1, e.level || 0)), talking: !!e.talking, at: performance.now() };
    }
  }), []);

  // the render loop: springs toward the live voice, one shader pass per frame
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const gl = canvas.getContext("webgl", { alpha: true, premultipliedAlpha: true, antialias: false, depth: false, stencil: false });
    const prog = gl ? compile(gl) : null;
    const u: Record<string, WebGLUniformLocation | null> = {};
    if (gl && prog) {
      gl.useProgram(prog);
      const buf = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
      const loc = gl.getAttribLocation(prog, "aPos");
      gl.enableVertexAttribArray(loc);
      gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
      for (const n of ["uRes", "uTime", "uLevel", "uEnergy", "uTalk", "uPresence", "uCell"]) u[n] = gl.getUniformLocation(prog, n);
      gl.clearColor(0, 0, 0, 0);
    }
    canvas.dataset.renderer = gl && prog ? "webgl" : "css";

    let raf = 0, lastT = performance.now(), start = lastT;
    let level = 0, energy = 0, talk = 0, presence = 0, shown: number | null = null;
    const frame = (now: number) => {
      const dt = Math.min(0.05, (now - lastT) / 1000);
      lastT = now;
      const list = Object.values(castsRef.current);
      // who is shown: whoever talks, else the latest cast
      let pick: Cast | undefined = list.find(c => live.current[c.speaker]?.talking) ?? list[list.length - 1];
      if (pick && shown !== pick.speaker) { shown = pick.speaker; setFocus(pick.speaker); }
      const l = pick ? live.current[pick.speaker] : undefined;
      // a level older than 400 ms is silence (a dropped update)
      const fresh = l && now - l.at < 400;
      const targetLevel = fresh && l!.talking ? l!.level : 0;
      const targetTalk = fresh && l!.talking ? 1 : 0;
      // fast attack, softer release: it breathes, never twitches
      level += (targetLevel - level) * (1 - Math.exp(-dt * (targetLevel > level ? 8 : 3.5)));
      energy += (level - energy) * (1 - Math.exp(-dt * (level > energy ? 2.5 : 1.0)));
      talk += (targetTalk - talk) * (1 - Math.exp(-dt * (targetTalk > talk ? 5 : 2)));
      presence += ((pick ? 1 : 0) - presence) * (1 - Math.exp(-dt * (pick ? 3.2 : 4.5)));

      const w = canvas.clientWidth, h = canvas.clientHeight;
      if (gl && prog) {
        const dpr = Math.min(1, window.devicePixelRatio || 1); // the WebUI copies every frame to the game: keep it light
        const cw = Math.round(w * dpr), ch = Math.round(h * dpr);
        if (canvas.width !== cw || canvas.height !== ch) { canvas.width = cw; canvas.height = ch; gl.viewport(0, 0, cw, ch); }
        gl.uniform2f(u.uRes!, cw, ch);
        gl.uniform1f(u.uTime!, (now - start) / 1000);
        gl.uniform1f(u.uLevel!, level);
        gl.uniform1f(u.uEnergy!, energy);
        gl.uniform1f(u.uTalk!, talk);
        gl.uniform1f(u.uPresence!, presence);
        gl.uniform1f(u.uCell!, Math.max(3, Math.round(ch / 75))); // ~4 px cells at 300 px
        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      } else if (fallbackRef.current) {
        const f = fallbackRef.current;
        f.style.opacity = String(presence);
        f.style.top = `${Math.round(0.42 * h)}px`;
        f.style.transform = `translateX(-50%) scaleY(${1 + 6 * level})`;
      }
      // the label sits under the signal and slides in with it
      if (labelRef.current) {
        const y = (0.62 + 0.12 * presence) * h;
        labelRef.current.style.transform = `translate(-50%, ${Math.round(y)}px)`;
        labelRef.current.style.opacity = String(Math.max(0, presence * 1.15 - 0.15));
      }
      if (!pick && presence < 0.002) {
        // off air and fully retracted: clear once, then look again 4 times a second
        if (gl) gl.clear(gl.COLOR_BUFFER_BIT);
        presence = 0;
        if (shown !== null) { shown = null; setFocus(null); }
        idle = window.setTimeout(() => { lastT = performance.now(); raf = requestAnimationFrame(frame); }, 250);
        return;
      }
      raf = requestAnimationFrame(frame);
    };
    let idle = 0;
    raf = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(raf); window.clearTimeout(idle); };
  }, []);

  const c = focus != null ? casts[focus] : undefined;
  const reach = c ? (c.mode === "server" ? "SERVER-WIDE" : `WITHIN ${c.radius ?? 0} M`) : "";
  return <div className="announce" aria-hidden={!c}>
    <canvas ref={canvasRef} className="announce__canvas" />
    <div ref={fallbackRef} className="announce__fallback" />
    <div ref={labelRef} className="announce__label" role="status">
      {c && <>
        <span className="announce__tag">{c.self ? "ON AIR" : "ANNOUNCEMENT"}</span>
        <b className="announce__name">{c.self ? "YOU" : c.name.toUpperCase()}</b>
        <span className="announce__reach">{reach}{c.self ? ` · ${c.audience} LISTENING` : " · STAFF"}</span>
      </>}
    </div>
  </div>;
}
