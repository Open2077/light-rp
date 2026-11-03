import { useEffect, useRef, useState } from "react";
import { Crosshair, Skull, Timer } from "lucide-react";
import { useStore } from "@/state/store";
import { formatMoney } from "@/bridge/money";
import { cashAtRisk, normalizeDogtown, percent } from "./model";
import "./dogtown.css";

const BANNER_MS = 6500;

/* Dogtown on screen: the red banner when the player walks in (or connects inside),
   and a persistent tile top-left while inside or combat-tagged. The server decides
   who is inside, tagged and attackable; this only shows it. */
export function DogtownHud() {
  const raw = useStore((s) => s.state.dogtown);
  const money = useStore((s) => s.state.money);
  const ready = useStore((s) => s.hud.ready);
  const character = useStore((s) => s.state.character);
  const tutorial = useStore((s) => s.state.tutorial);
  const d = normalizeDogtown(raw);
  const inside = !!d?.enabled && !!d?.inside;

  // The banner, once per entry.
  const [bannerAt, setBannerAt] = useState<number | null>(null);
  const wasInside = useRef(false);
  useEffect(() => {
    if (inside && !wasInside.current) setBannerAt(Date.now());
    if (!inside) setBannerAt(null);
    wasInside.current = inside;
  }, [inside]);
  useEffect(() => {
    if (bannerAt === null) return;
    const timer = setTimeout(() => setBannerAt(null), BANNER_MS);
    return () => clearTimeout(timer);
  }, [bannerAt]);

  // The tag counts down from the push that carried it.
  const receivedAt = useRef(Date.now());
  useEffect(() => { receivedAt.current = Date.now(); }, [raw]);
  const [, tick] = useState(0);
  useEffect(() => {
    if (!d?.tagged) return;
    const timer = setInterval(() => tick((n) => n + 1), 250);
    return () => clearInterval(timer);
  }, [d?.tagged]);

  if (!d || !d.enabled || !ready || character.status !== "active") return null;
  if (tutorial?.active && (tutorial.step === "intro" || tutorial.dialogue)) return null;
  const tagLeft = d.tagged ? Math.max(0, d.tagEndsInMs - (Date.now() - receivedAt.current)) : 0;
  const tagged = tagLeft > 0;
  if (!inside && !tagged) return null;
  const cash = money?.cash ?? 0;
  const fmt = (n: number) => formatMoney(n, money?.currency);
  const risk = cashAtRisk(cash, d.rules);

  return (
    <div className="dogtown" aria-hidden="true">
      {bannerAt !== null && inside && (
        <div className="dogtown-banner" key={bannerAt}>
          <div className="dogtown-banner__bar"><Skull size={18} strokeWidth={2} aria-hidden="true" /><span>DANGER ZONE</span></div>
          <strong className="dogtown-banner__title">{d.label.toUpperCase()}</strong>
          <span className="dogtown-banner__law">NO LAW <b>·</b> ANYONE CAN KILL YOU</span>
          <span className="dogtown-banner__cash">You carry <em>{fmt(cash)}</em> in cash</span>
          <span className="dogtown-banner__rule">
            {risk > 0 ? `A killer takes ${fmt(risk)} (${percent(d.rules.share)}, max ${fmt(d.rules.max)}).` : `Under ${fmt(d.rules.minCash)}, a killer takes nothing.`} Your bank is safe.
          </span>
        </div>
      )}
      <div className={`dogtown-tile${tagged ? " dogtown-tile--tagged" : ""}${inside ? "" : " dogtown-tile--outside"}`}>
        <Skull className="dogtown-tile__glyph" size={20} strokeWidth={2} aria-hidden="true" />
        <div className="dogtown-tile__body">
          <span className="dogtown-tile__label">{inside ? <>PVP ZONE <b>·</b> NO LAW</> : <>LEFT {d.label.toUpperCase()} <b>·</b> STILL ATTACKABLE</>}</span>
          <strong>{inside ? d.label : "Combat tag"}</strong>
          <div className="dogtown-tile__rows">
            {tagged && <span className="dogtown-tile__tag"><Timer size={11} strokeWidth={2} aria-hidden="true" />IN COMBAT {Math.ceil(tagLeft / 1000)} S</span>}
            <span><Crosshair size={11} strokeWidth={2} aria-hidden="true" />{risk > 0 ? `${fmt(risk)} at risk` : "Nothing to take"}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
