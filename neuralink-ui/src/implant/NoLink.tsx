/* "No Neural-Link detected": a wireframe head swept by a scan line, the
   cortical port probe turning into the warning, and the way forward (install,
   or see a ripperdoc). The same red/amber alert frames an installation failure.
   Rare glitch bursts shake it, a few with a sound. */
import { useEffect, useState, type ReactNode } from "react";
import { RotateCcw, Syringe, X } from "lucide-react";
import { play } from "@/fx/sound";
import { errorText } from "@/bridge/errors";
import { userClose } from "@/store/actions";
import { reducedMotion } from "@/shell/Stage";
import { IrisGlyph } from "./Kiroshi";
import { SOUND_MS } from "./timeline";

const SCAN_MS = 1900;

const OUTLINE = "M200 38 C292 38 332 110 332 200 C332 262 318 302 300 332 C284 362 262 400 230 418 C214 428 186 428 170 418 C138 400 116 362 100 332 C82 302 68 262 68 200 C68 110 108 38 200 38 Z";

function WireHead({ detected, failed }: { detected: boolean; failed?: boolean }) {
  return (
    <svg className={`nlhead ${detected ? "is-detected" : ""} ${failed ? "is-failed" : ""}`} viewBox="0 0 400 500" width={380} height={475} aria-hidden>
      <defs>
        <clipPath id="nlhead-clip"><path d={OUTLINE} /></clipPath>
        <linearGradient id="nlhead-scan" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" className="nlhead__s0" />
          <stop offset="0.85" className="nlhead__s1" />
          <stop offset="1" className="nlhead__s2" />
        </linearGradient>
      </defs>
      <g className="nlhead__wire" clipPath="url(#nlhead-clip)">
        {Array.from({ length: 11 }, (_, i) => {
          const y = 66 + i * 34;
          return <path key={`la${i}`} d={`M50 ${y} Q200 ${y + 26} 350 ${y}`} />;
        })}
        {Array.from({ length: 9 }, (_, i) => {
          const k = i - 4;
          return <path key={`me${i}`} d={`M200 30 Q${200 + k * 74} 230 ${200 + k * 9} 430`} />;
        })}
      </g>
      <path className="nlhead__outline" d={OUTLINE} />
      <path className="nlhead__neck" d="M166 420 L158 488 M234 420 L242 488 M120 488 L280 488" />
      <path className="nlhead__eye" d="M126 214 Q152 194 178 214 Q152 230 126 214 Z" />
      <path className="nlhead__eye nlhead__eye--port" d="M222 214 Q248 194 274 214 Q248 230 222 214 Z" />
      <path className="nlhead__brow" d="M120 190 Q150 176 180 186 M220 186 Q250 176 280 190" />
      {/* the probe on the optic nerve */}
      <g className="nlhead__probe">
        <circle cx="248" cy="214" r="26" />
        <circle cx="248" cy="214" r="38" strokeDasharray="6 6" />
        <path d="M248 168 L248 182 M248 246 L248 260 M202 214 L216 214 M280 214 L294 214" />
      </g>
      <g clipPath="url(#nlhead-clip)">
        <rect className="nlhead__scan" x="40" y="0" width="320" height="70" fill="url(#nlhead-scan)" />
      </g>
      <g className="nlhead__tag">
        <path d="M282 196 L330 150 L392 150" />
        <text x="334" y="142">{failed ? "NOT SEATED" : detected ? "NO LINK" : "PROBING"}</text>
      </g>
    </svg>
  );
}

interface AlertProps {
  detected: boolean;
  failed?: boolean;
  kicker: string;
  title: string;
  sub: string;
  rows: [string, string][];
  children: ReactNode;
}

/** Shared frame: backdrop, head, glass panel, glitch bursts. */
function Alert({ detected, failed, kicker, title, sub, rows, children }: AlertProps) {
  const [glitch, setGlitch] = useState(false);

  // Glitch bursts every few seconds; a sound on some of them, never over another slot A sound.
  useEffect(() => {
    if (reducedMotion()) return;
    let timer = 0, off = 0;
    let quietUntil = performance.now() + SCAN_MS + (SOUND_MS.implant_denied ?? 1240) + 200;
    let lastSound = 0;
    const burst = () => {
      setGlitch(true);
      const now = performance.now();
      if (now > quietUntil && now - lastSound > 9000 && Math.random() < 0.45) {
        lastSound = now;
        quietUntil = now + (SOUND_MS.implant_glitch ?? 550);
        play("implant_glitch");
      }
      off = window.setTimeout(() => setGlitch(false), 160 + Math.random() * 220);
      timer = window.setTimeout(burst, 2600 + Math.random() * 4200);
    };
    timer = window.setTimeout(burst, 2400 + Math.random() * 1800);
    return () => { window.clearTimeout(timer); window.clearTimeout(off); };
  }, []);

  return (
    <div className={`nolink nl-hit ${detected ? "is-detected" : "is-scanning"} ${glitch ? "is-glitch" : ""}`} role="alertdialog" aria-live="assertive" aria-label={title}>
      <div className="nolink__bg" aria-hidden />
      <div className="nolink__frame">
        <div className="nolink__head"><WireHead detected={detected} failed={failed} /></div>
        <div className="nolink__panel">
          <div className="nolink__kicker mono">{kicker}</div>
          <div className="nolink__title label" data-text={title}>{title}</div>
          <div className="nolink__sub">{sub}</div>
          <ul className="nolink__rows mono">
            {rows.map(([k, v], i) => (
              <li key={k} style={{ ["--i" as string]: i }}><span>{k}</span><b>{v}</b></li>
            ))}
          </ul>
          <div className="nolink__actions">{children}</div>
        </div>
      </div>
    </div>
  );
}

export function NoLink({ selfInstall, onInstall }: { selfInstall: boolean; onInstall(): void }) {
  const [detected, setDetected] = useState(false);
  useEffect(() => {
    // static as the dead interface tries to project, then the verdict
    play("implant_glitch");
    const t = window.setTimeout(() => { setDetected(true); play("implant_denied"); }, reducedMotion() ? 600 : SCAN_MS);
    return () => window.clearTimeout(t);
  }, []);

  const rows: [string, string][] = detected
    ? [["Cortical port C7", "EMPTY"], ["Optic nerve bus", "NO HANDSHAKE"], ["Synaptic interface", "OFFLINE"]]
    : [["Cortical port C7", "PROBING"], ["Optic nerve bus", "LISTENING"], ["Synaptic interface", "…"]];

  return (
    <Alert
      detected={detected}
      kicker="KIROSHI DIAGNOSTIC · CORTICAL BUS"
      title={detected ? "No Neural-Link detected" : "Scanning cortical port…"}
      sub={detected ? "No compatible implant on the optic nerve." : "Looking for a neural implant on this body."}
      rows={rows}
    >
      {detected && (selfInstall ? (
        <>
          <button type="button" className="btn btn--sel nolink__install" onClick={onInstall} autoFocus>
            <IrisGlyph size={22} className="nolink__iris" /> <span>Install Kiroshi Neural-Link</span>
          </button>
          <button type="button" className="btn btn--ghost" onClick={userClose}><span>Cancel</span></button>
        </>
      ) : (
        <>
          <div className="nolink__ripper"><Syringe size={20} /> <span>Visit a ripperdoc to have a Neural-Link installed</span></div>
          <button type="button" className="btn btn--ghost" onClick={userClose} autoFocus><X size={16} /> <span>Close</span></button>
        </>
      ))}
    </Alert>
  );
}

export function InstallError({ slug, onRetry }: { slug: string; onRetry(): void }) {
  const ripper = slug === "ripperdoc_required";
  useEffect(() => { play("implant_denied"); }, []);
  return (
    <Alert
      detected
      failed
      kicker="KIROSHI INSTALLER · FAULT"
      title="Installation failed"
      sub={errorText(slug)}
      rows={[["Error code", slug.toUpperCase()], ["Implant", "NOT SEATED"], ["Cortical port C7", "SEALED · SAFE"]]}
    >
      {ripper
        ? <div className="nolink__ripper"><Syringe size={20} /> <span>Visit a ripperdoc to have a Neural-Link installed</span></div>
        : <button type="button" className="btn btn--sel" onClick={onRetry} autoFocus><RotateCcw size={16} /> <span>Retry</span></button>}
      <button type="button" className="btn btn--ghost" onClick={userClose} autoFocus={ripper}><X size={16} /> <span>Close</span></button>
    </Alert>
  );
}
