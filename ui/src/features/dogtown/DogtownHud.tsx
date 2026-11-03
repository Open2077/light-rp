import { useEffect, useRef, useState } from "react";
import { Crosshair, Flame, ShieldCheck, Skull, Timer, Wallet } from "lucide-react";
import { useStore } from "@/state/store";
import { formatMoney } from "@/bridge/money";
import { cashAtRisk, clock, normalizeDogtown, percent, stakeMissing } from "./model";
import "./dogtown.css";

const BANNER_MS = 6500;

/* Dogtown on screen: the red banner when the player walks in (or connects inside),
   and a persistent tile top-left while inside or combat-tagged: the cash at risk,
   the combat tag, the streak and a bounty, or, without the stake, what is missing
   and the escort countdown. The server decides who is inside, tagged, attackable
   and escorted; this only shows it. */
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

  // The tag and the escort count down from the push that carried them.
  const receivedAt = useRef(Date.now());
  useEffect(() => { receivedAt.current = Date.now(); }, [raw]);
  const [, tick] = useState(0);
  const counting = !!d?.tagged || !!d?.stake.short || !!d?.protected;
  useEffect(() => {
    if (!counting) return;
    const timer = setInterval(() => tick((n) => n + 1), 250);
    return () => clearInterval(timer);
  }, [counting]);

  if (!d || !d.enabled || !ready || character.status !== "active") return null;
  if (tutorial?.active && (tutorial.step === "intro" || tutorial.dialogue)) return null;
  const elapsed = Date.now() - receivedAt.current;
  const tagLeft = d.tagged ? Math.max(0, d.tagEndsInMs - elapsed) : 0;
  const tagged = tagLeft > 0;
  if (!inside && !tagged) return null;
  const cash = money?.cash ?? 0;
  const fmt = (n: number) => formatMoney(n, money?.currency);
  const risk = cashAtRisk(cash, d.rules);
  // The server's verdict (short) with the live pocket for the amount.
  const short = inside && d.stake.short;
  const missing = stakeMissing(cash, d.rules) || d.stake.missing;
  const escortLeft = short ? Math.max(0, d.stake.evictInMs - elapsed) : 0;
  // Entry protection: out of the PvP grant until it runs out (the server ends it).
  const safeLeft = d.protected ? Math.max(0, d.protectedInMs - elapsed) : 0;
  const safe = safeLeft > 0 && !short;

  return (
    <div className="dogtown" aria-hidden="true">
      {bannerAt !== null && inside && (
        <div className={`dogtown-banner${short ? " dogtown-banner--short" : ""}`} key={bannerAt}>
          <div className="dogtown-banner__bar"><Skull size={18} strokeWidth={2} aria-hidden="true" /><span>DANGER ZONE</span></div>
          <strong className="dogtown-banner__title">{d.label.toUpperCase()}</strong>
          {short
            ? <span className="dogtown-banner__law">NO STAKE <b>·</b> YOU CAN'T FIGHT HERE</span>
            : safe
              ? <span className="dogtown-banner__law dogtown-banner__law--safe">ENTRY PROTECTION <b>·</b> {clock(safeLeft / 1000)} TO GET CLEAR</span>
              : <span className="dogtown-banner__law">NO LAW <b>·</b> ANYONE CAN KILL YOU</span>}
          <span className="dogtown-banner__cash">You carry <em>{fmt(cash)}</em> in cash</span>
          {short ? (
            <span className="dogtown-banner__stake">
              The stake is {fmt(d.rules.stake)} in cash: {fmt(missing)} missing. Leave within {d.rules.graceSeconds} s or you are escorted out.
            </span>
          ) : (
            <span className="dogtown-banner__rule">
              A killer takes {fmt(risk)} ({percent(d.rules.share)}, {fmt(d.rules.min)} to {fmt(d.rules.max)}) plus a {percent(d.rules.bonus)} bonus. Your bank is safe.
            </span>
          )}
        </div>
      )}
      <div className={`dogtown-tile${tagged ? " dogtown-tile--tagged" : ""}${inside ? "" : " dogtown-tile--outside"}${short ? " dogtown-tile--short" : ""}${safe ? " dogtown-tile--safe" : ""}${d.bounty ? " dogtown-tile--bounty" : ""}`}>
        {short
          ? <Wallet className="dogtown-tile__glyph" size={20} strokeWidth={2} aria-hidden="true" />
          : safe
            ? <ShieldCheck className="dogtown-tile__glyph" size={20} strokeWidth={2} aria-hidden="true" />
            : <Skull className="dogtown-tile__glyph" size={20} strokeWidth={2} aria-hidden="true" />}
        <div className="dogtown-tile__body">
          <span className="dogtown-tile__label">
            {short ? <>NO STAKE <b>·</b> NO PVP FOR YOU</> : safe ? <>PVP ZONE <b>·</b> YOU ARE PROTECTED</> : inside ? <>PVP ZONE <b>·</b> NO LAW</> : <>LEFT {d.label.toUpperCase()} <b>·</b> STILL ATTACKABLE</>}
          </span>
          <strong>{short ? `${fmt(missing)} missing` : inside ? d.label : "Combat tag"}</strong>
          <div className="dogtown-tile__rows">
            {safe && <span className="dogtown-tile__safe"><ShieldCheck size={11} strokeWidth={2} aria-hidden="true" />SAFE FOR {clock(safeLeft / 1000)}</span>}
            {short && <span className="dogtown-tile__escort"><Timer size={11} strokeWidth={2} aria-hidden="true" />ESCORTED OUT IN {Math.ceil(escortLeft / 1000)} S</span>}
            {tagged && <span className="dogtown-tile__tag"><Timer size={11} strokeWidth={2} aria-hidden="true" />IN COMBAT {Math.ceil(tagLeft / 1000)} S</span>}
            {d.bounty && <span className="dogtown-tile__bounty"><Crosshair size={11} strokeWidth={2} aria-hidden="true" />BOUNTY · ON EVERYONE'S MAP</span>}
            {!d.bounty && d.streak > 0 && <span><Flame size={11} strokeWidth={2} aria-hidden="true" />{d.streak} in a row</span>}
            {!short && <span><Crosshair size={11} strokeWidth={2} aria-hidden="true" />{risk > 0 ? `${fmt(risk)} at risk` : "Nothing to take"}</span>}
          </div>
        </div>
      </div>
    </div>
  );
}
