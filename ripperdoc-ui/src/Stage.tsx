import { useEffect, useRef, useState, type ReactNode } from "react";
import { SECTION, type Body } from "./data";
import { bodyVideo, stillImage, uiImage, type Manifest } from "./media";
import type { Phase } from "./App";

/* The holographic body: the game's idle paperdoll loop, graded to the DA, standing on a ring
   pedestal in a perspective room. The mouse tilts the room (parallax); hovering a section lights
   its system (the game's full-body overlay when there is one, a lens on the region otherwise);
   diving flies the camera into the anchor before the close-up takes over. */

export const STAGE = { top: 92, height: 960, centerX: 960 };

export function bodyBox(manifest: Manifest, body: Body) {
  const info = manifest.videos?.[`${body}_body`];
  const aspect = info ? info.width / info.height : 0.5625;
  const width = STAGE.height * aspect;
  return { left: STAGE.centerX - width / 2, top: STAGE.top, width, height: STAGE.height };
}

export function anchorPoint(manifest: Manifest, body: Body, section: string) {
  const box = bodyBox(manifest, body);
  const anchor = SECTION[section]!.anchor[body];
  return { x: box.left + anchor.x * box.width, y: box.top + anchor.y * box.height };
}

/** Pointer parallax, smoothed: writes --rx/--ry/--px/--py on the element. */
export function useParallax<T extends HTMLElement>(strength = 1) {
  const ref = useRef<T>(null);
  useEffect(() => {
    let tx = 0, ty = 0, x = 0, y = 0, frame = 0;
    const move = (e: PointerEvent) => {
      tx = (e.clientX / window.innerWidth) * 2 - 1;
      ty = (e.clientY / window.innerHeight) * 2 - 1;
    };
    const tick = () => {
      x += (tx - x) * 0.06;
      y += (ty - y) * 0.06;
      const el = ref.current;
      if (el) {
        el.style.setProperty("--ry", `${(x * 7 * strength).toFixed(3)}deg`);
        el.style.setProperty("--rx", `${(-y * 4 * strength).toFixed(3)}deg`);
        el.style.setProperty("--px", x.toFixed(4));
        el.style.setProperty("--py", y.toFixed(4));
      }
      frame = requestAnimationFrame(tick);
    };
    window.addEventListener("pointermove", move);
    frame = requestAnimationFrame(tick);
    return () => { window.removeEventListener("pointermove", move); cancelAnimationFrame(frame); };
  }, [strength]);
  return ref;
}

interface Props { body: Body; manifest: Manifest; phase: Phase; focus: string | null; children?: ReactNode }

export function Stage({ body, manifest, phase, focus, children }: Props) {
  const room = useParallax<HTMLDivElement>(0.55);
  const box = bodyBox(manifest, body);
  const stillBoxes = manifest.stills ?? {};
  const [shown, setShown] = useState<string | null>(null);
  useEffect(() => { setShown(focus); }, [focus]);

  // The dive: scale about the anchor and slide it to where the close-up's subject sits.
  let transform = "none";
  if (focus && (phase === "diving" || phase === "section")) {
    const anchor = SECTION[focus]!.anchor[body];
    const ox = box.left + anchor.x * box.width;
    const oy = box.top + anchor.y * box.height;
    const s = 3.4;
    transform = `translate(${(1240 - ox)}px, ${(560 - oy)}px) translate(${ox}px, ${oy}px) scale(${s}) translate(${-ox}px, ${-oy}px)`;
  }
  const lens = focus ? SECTION[focus]!.anchor[body] : null;
  const still = focus && SECTION[focus]!.still ? stillBoxes[`${body}_${focus}`] : undefined;

  return (
    <div className="rd-room" ref={room}>
      <div className="rd-floor" />
      <div className="rd-stage" style={{ transform }}>
        <div className="rd-halo" style={{ left: STAGE.centerX - 520, top: STAGE.top + 40 }}>
          <img src={uiImage("circle_1")} alt="" className="rd-halo-ring a" />
          <img src={uiImage("circle_2")} alt="" className="rd-halo-ring b" />
        </div>
        <img className="rd-cables" src={uiImage(body === "male" ? "man_cables" : "woman_cables")} alt=""
          style={{ left: box.left - box.width * 0.9, top: box.top - 40, width: box.width * 2.8 }} />
        <div className="rd-pedestal" style={{ left: STAGE.centerX - 260, top: box.top + box.height - 150 }}>
          <img src={uiImage("circle_1")} alt="" />
          <img src={uiImage("circle_2")} alt="" className="slow" />
        </div>
        <div className={`rd-body ${focus ? "is-focus" : ""}`} style={{ left: box.left, top: box.top, width: box.width, height: box.height }}>
          <video className="rd-body-video" src={bodyVideo(body)} autoPlay loop muted playsInline />
          {SECTIONS_WITH_STILL.map((id) => {
            const b = stillBoxes[`${body}_${id}`];
            if (!b) return null;
            return (
              <img key={id} className={`rd-still ${shown === id && still ? "on" : ""}`} src={stillImage(body, id)} alt=""
                style={{ left: `${b.left * 100}%`, top: `${b.top * 100}%`, width: `${b.width * 100}%`, height: `${b.height * 100}%` }} />
            );
          })}
          {lens && (
            <div className={`rd-lens ${still ? "soft" : ""}`} style={{ left: `${lens.x * 100}%`, top: `${lens.y * 100}%` }}>
              <img src={uiImage("circle_2")} alt="" />
              <i /><b />
            </div>
          )}
          <div className="rd-body-scan" />
        </div>
      </div>
      <div className="rd-layer">{children}</div>
    </div>
  );
}

const SECTIONS_WITH_STILL = ["circulatory", "immune", "nervous", "integumentary", "skeleton"];
