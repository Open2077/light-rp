/* An original stylised Kiroshi mark for the installer: an optic iris built from
   concentric SVG circles (aperture ring, dashed lens ring, pupil) and a
   letter-spaced wordmark whose O is a small iris. Not the real logo artwork. */
import type { CSSProperties } from "react";

export function IrisGlyph({ size = 240, className }: { size?: number; className?: string }) {
  return (
    <svg className={["kiris", className].filter(Boolean).join(" ")} width={size} height={size} viewBox="-120 -120 240 240" aria-hidden>
      <g className="kiris__ring kiris__ring--outer">
        <circle r="112" fill="none" strokeWidth="1.5" strokeDasharray="2 6" />
        <circle r="104" fill="none" strokeWidth="3" strokeDasharray="120 43.4" />
      </g>
      <g className="kiris__ring kiris__ring--blades">
        {/* twelve aperture blades: short arcs of one ring */}
        <circle r="82" fill="none" strokeWidth="14" strokeDasharray="36 6.94" />
      </g>
      <g className="kiris__ring kiris__ring--lens">
        <circle r="62" fill="none" strokeWidth="1.5" />
        <circle r="56" fill="none" strokeWidth="5" strokeDasharray="1.5 4.36" />
      </g>
      <g className="kiris__ring kiris__ring--inner">
        <circle r="40" fill="none" strokeWidth="2" strokeDasharray="62.8 62.8" />
      </g>
      <circle className="kiris__pupil" r="22" />
      <circle className="kiris__glint" cx="-8" cy="-9" r="5" />
    </svg>
  );
}

/** "KIROSHI" with the O as an iris; letters reveal one by one when `reveal`. */
export function Wordmark({ reveal = false, size = 72 }: { reveal?: boolean; size?: number }) {
  const letters = ["K", "I", "R", "O", "S", "H", "I"];
  return (
    <span className={`kword ${reveal ? "is-reveal" : ""}`} style={{ fontSize: size } as CSSProperties} aria-label="Kiroshi">
      {letters.map((l, i) => (
        <span key={i} className="kword__l" style={{ ["--i" as string]: i }} aria-hidden>
          {l === "O" ? (
            <svg className="kword__o" viewBox="-12 -12 24 24" aria-hidden>
              <circle r="10.5" fill="none" strokeWidth="2.2" />
              <circle r="6.2" fill="none" strokeWidth="1.2" strokeDasharray="2.2 1.05" />
              <circle r="2.6" />
            </svg>
          ) : l}
        </span>
      ))}
    </span>
  );
}
