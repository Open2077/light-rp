import { useEffect, useState, type ReactNode } from "react";
import { eddies, roman, type Guide as GuideData } from "./data";
import type { Session } from "./App";
import { play } from "./sfx";

/* The clinic guide: what capacity is, how street cred opens implant ranks and more capacity, how it
   is earned, how buying / storage / swaps work and which keys the active implants use. Opens by itself
   on a first visit (guide.auto), and from the GUIDE button or H at any time. Every number comes from
   the server's guide payload (its live configuration) and the patient's own state. */

interface Step { kicker: string; title: string; body: ReactNode }

const ranks = (rank: number) => (rank <= 0 ? "—" : rank === 1 ? "I" : `I – ${roman(Math.min(rank, 6))}`);

function steps(guide: GuideData, session: Session): Step[] {
  const cap = session.capacity;
  const rep = session.reputation;
  const tiers = guide.tiers ?? [];
  const current = tiers.find((t) => t.tier === rep?.tier);
  const top = tiers[tiers.length - 1];
  const fee = guide.fittingFee ?? session.fittingFee;
  const account = guide.payFrom === "cash" ? "cash" : "bank account";
  const toNext = rep?.next !== undefined && rep.points !== undefined ? Math.max(0, rep.next - rep.points) : undefined;
  return [
    {
      kicker: "WELCOME",
      title: "THE CLINIC",
      body: (
        <>
          <p>Your body is split into <b>twelve systems</b>. Click one to dive in: you see what is fitted there, the
            implants in your storage and the clinic's stock for that system.</p>
          <ul className="rd-guide-keys">
            <li><kbd>LMB</kbd><span>Open a body system</span></li>
            <li><kbd>A</kbd><kbd>D</kbd><span>Cycle the systems in the close-up</span></li>
            <li><kbd>E</kbd><span>Hold to operate (install, fit from storage, take out)</span></li>
            <li><kbd>ESC</kbd><span>Back to the full body, then leave the chair</span></li>
            <li><kbd>H</kbd><span>This guide, any time</span></li>
          </ul>
        </>
      ),
    },
    {
      kicker: "THE LIMIT",
      title: "CAPACITY",
      body: (
        <>
          <p>Every implant takes <b>capacity points</b> (the number on its card). Your body only holds so many.</p>
          {cap && (
            <div className="rd-guide-stat">
              <div><span>YOUR BODY</span><b>{cap.used}<i> / {cap.total}</i></b><em>{Math.max(0, cap.total - cap.used)} {cap.total - cap.used === 1 ? "POINT" : "POINTS"} FREE</em></div>
              <div className="rd-guide-capbar">
                {Array.from({ length: Math.max(cap.total, cap.used) }, (_, k) =>
                  <i key={k} className={k < cap.used ? (k >= cap.total ? "x" : "on") : ""} />)}
              </div>
            </div>
          )}
          <p>Body full? <b>Take an implant out</b> (it goes to your storage, you keep it) or <b>raise your street cred</b>:
            every tier gives more room{top?.capacity ? <>, up to <b>{top.capacity} points</b> at {top.name}</> : null}.</p>
          <p className="dim">The best implant of every family adds up to far more than that: a build is a choice (tank,
            mobility, support, brawler...). A body already over its limit keeps everything fitted, but only a lighter
            swap fits until it is back under it.</p>
        </>
      ),
    },
    {
      kicker: "PROGRESSION",
      title: "STREET CRED",
      body: (
        <>
          <p>Your <b>street cred</b> tier decides two things: your <b>capacity</b> and the <b>implant ranks</b> you may
            buy (I to V+). A card you cannot buy yet shows the tier it needs (<span className="rd-guide-lock">REP III</span>).</p>
          <table className="rd-guide-table">
            <thead><tr><th>TIER</th><th>STREET CRED</th><th>CAPACITY</th><th>IMPLANT RANKS</th></tr></thead>
            <tbody>
              {tiers.map((t) => (
                <tr key={t.tier} className={t.tier === rep?.tier ? "is-you" : t.tier < (rep?.tier ?? 0) ? "is-done" : ""}>
                  <td><b>{roman(t.tier)}</b> {t.name.toUpperCase()}{t.tier === rep?.tier ? <em> · YOU</em> : null}</td>
                  <td>{t.points === 0 ? "START" : `${eddies(t.points)} PTS`}</td>
                  <td>{t.capacity ?? "—"}</td>
                  <td>{ranks(t.rank)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {rep && (
            <p className="rd-guide-you">You are <b>{(rep.name ?? current?.name ?? roman(rep.tier)).toUpperCase()}</b>
              {rep.points !== undefined && <> with <b>{eddies(rep.points)}</b> points</>}
              {toNext !== undefined && rep.nextName ? <>: <b>{eddies(toNext)}</b> more to reach {rep.nextName}.</> : "."}</p>
          )}
          <p className="dim">An implant you already own (fitted or in storage) is never locked.</p>
        </>
      ),
    },
    {
      kicker: "PROGRESSION",
      title: "EARNING STREET CRED",
      body: (
        <>
          <p>Street cred comes from <b>PvE only</b>: missions, the Chimera raid, fixer gigs and the PvE activities of the
            activities board.{guide.pvpGivesNone !== false && <> <b>PvP gives none.</b></>}</p>
          {guide.gains && guide.gains.length > 0 && (
            <table className="rd-guide-table">
              <thead><tr><th>A FINISHED MISSION</th><th>STREET CRED</th><th>NEEDS</th></tr></thead>
              <tbody>
                {guide.gains.map((g) => (
                  <tr key={g.label}>
                    <td><b>{g.label.toUpperCase()}</b></td>
                    <td className="accent">+{g.points}</td>
                    <td>{g.tier <= 1 ? "EVERYONE" : `${roman(g.tier)} ${(g.tierName ?? "").toUpperCase()}`}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <p className="dim">Harder difficulties pay more but open with your tier (and clearing the one before). The
            same job repeated too soon pays less street cred for a while: vary your work.</p>
          {guide.drops && guide.drops.length > 0 && (
            <p><b>Iconic implants</b> are never sold: they drop from {guide.drops.join(", ")} and go to your storage.</p>
          )}
        </>
      ),
    },
    {
      kicker: "THE RULES",
      title: "BUYING, STORAGE & SWAPS",
      body: (
        <ul className="rd-guide-points">
          <li>You pay from your <b>{account}</b>. Buying an implant <b>includes the surgery</b>.</li>
          <li><b>One implant per family</b> (one native slot: arms, legs, operating system...). A new one replaces the
            fitted one, which goes to your <b>storage for free</b>.</li>
          <li>An implant you bought is <b>yours for good</b>. Fitting one from storage, or taking one out to storage,
            costs <b>€$ {eddies(fee)}</b>, never its price again.</li>
          <li>No resale, no trade: choose your build.</li>
        </ul>
      ),
    },
    {
      kicker: "IN THE STREET",
      title: "USING YOUR IMPLANTS",
      body: (
        <>
          <p><b>Passive implants</b> (health, armor, regeneration, stamina...) work as soon as they are fitted. Active
            ones have a key:</p>
          <ul className="rd-guide-keys">
            {(guide.keys ?? []).filter((k) => k.key).map((k) => (
              <li key={k.label}>{k.key!.split(" + ").map((x) => <kbd key={x}>{x}</kbd>)}<span>{k.label}</span></li>
            ))}
          </ul>
          <p className="dim">Rebind them in Pause › Settings › Key bindings. Reopen this guide any time with
            <b> GUIDE</b> (top right) or <kbd>H</kbd>.</p>
        </>
      ),
    },
  ];
}

export function GuideLayer({ guide, session, onClose }: { guide: GuideData; session: Session; onClose: () => void }) {
  const list = steps(guide, session);
  const [index, setIndex] = useState(0);
  const last = index === list.length - 1;
  const go = (to: number) => {
    const next = Math.max(0, Math.min(list.length - 1, to));
    if (next === index) return;
    setIndex(next);
    play("tick_up");
  };
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      // The guide owns the keyboard while it is open (the page's own keys wait).
      e.stopImmediatePropagation();
      if (e.key === "Escape" || e.key === "h" || e.key === "H") { e.preventDefault(); onClose(); }
      else if (e.key === "ArrowRight" || e.key === "d" || e.key === "D" || e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        if (last) onClose(); else go(index + 1);
      } else if (e.key === "ArrowLeft" || e.key === "a" || e.key === "A" || e.key === "Backspace") { e.preventDefault(); go(index - 1); }
    };
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  });
  const step = list[index]!;
  return (
    <div className="rd-guide" role="dialog" aria-label="Clinic guide">
      <div className="rd-guide-panel" key={index}>
        <div className="rd-guide-head">
          <span className="rd-guide-kicker">CLINIC GUIDE // {step.kicker}</span>
          <span className="rd-guide-count">{index + 1} / {list.length}</span>
        </div>
        <div className="rd-guide-title" data-text={step.title}>{step.title}</div>
        <div className="rd-guide-body">{step.body}</div>
        <div className="rd-guide-foot">
          <div className="rd-guide-dots">
            {list.map((s, k) => <button key={s.title} className={k === index ? "on" : k < index ? "done" : ""}
              onClick={() => go(k)} aria-label={s.title} />)}
          </div>
          <button className="rd-guide-btn ghost" onClick={onClose}>{last ? "CLOSE" : "SKIP GUIDE"}</button>
          <button className="rd-guide-btn ghost" disabled={index === 0} onClick={() => go(index - 1)}><kbd>A</kbd> BACK</button>
          <button className="rd-guide-btn" onClick={() => (last ? onClose() : go(index + 1))}>{last ? "GOT IT" : "NEXT"} <kbd>D</kbd></button>
        </div>
      </div>
    </div>
  );
}
