import { useEffect, useState } from "react";
import { sendAction } from "@/bridge/open77";
import type { MissionSquadMember, PartyMember, PartyState } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Icon, cx } from "@/design/components";
import "./crew.css";
import "@/features/dailies/rarity.css";

/* The crew on the HUD (server/modules/parties.lua "party" state), bottom-left above
   the weapon and the vitals: one frame, always there while you are in a crew.
   Outside a mission each member shows the leader crown, YOU, down/dead, what keeps
   them (mission, board, activity) and FAR when out of reach. During a mission the
   same frame shows every operator's health and armor (missions.lua squadView),
   strangers matched in included. Above it, the invite prompt with its keys.
   Only the server's words are shown; nothing is assumed. */

/* eight rows fit between the notices and the vitals at 1080p; short screens (720p)
   keep five and send the rest to F1 > Crew */
const SHORT_SCREEN = "(max-height: 800px)";
function useMaxRows(): number {
  const [short, setShort] = useState(() => typeof window !== "undefined" && !!window.matchMedia?.(SHORT_SCREEN).matches);
  useEffect(() => {
    const media = window.matchMedia?.(SHORT_SCREEN);
    if (!media) return;
    const change = () => setShort(media.matches);
    media.addEventListener("change", change);
    return () => media.removeEventListener("change", change);
  }, []);
  return short ? 5 : 8;
}
const BUSY: Record<string, { icon: string; label: string }> = {
  mission: { icon: "crosshair", label: "MISSION" },
  lobby: { icon: "timer", label: "BOARD" },
  activity: { icon: "swords", label: "ACTIVITY" },
};
const MISSION_STATE: Record<string, string> = { down: "DOWN", dead: "DEAD", recovering: "UP SOON" };

export function CrewHud() {
  const party = useStore((s) => s.state.party);
  const q = useStore((s) => s.state.missionQueue);
  const me = useStore((s) => s.state.character?.playerId);
  const running = q && q.running ? q : undefined;
  const operators = running?.squad ?? [];
  // a solo run (only you) leaves your own vitals alone
  const missionFrame = operators.length > 1 || (operators.length === 1 && operators[0]!.id !== me);
  return <>
    {!!party?.invites?.length && <CrewInvitePrompt party={party} />}
    {missionFrame ? <MissionCrew operators={operators} party={party} me={me} title={running!.title} />
      : party?.id && party.members?.length ? <CrewFrame party={party} me={me} /> : null}
  </>;
}

function Header({ title, count, extra }: { title: string; count: string; extra?: string }) {
  return <header className="crew-frame__head">
    <Icon name="users" size={12} /><b>{title}</b>{extra && <span className="crew-frame__extra">{extra}</span>}<span className="crew-frame__count">{count}</span>
  </header>;
}

function CrewFrame({ party, me }: { party: PartyState; me?: number }) {
  const members = party.members ?? [];
  const you = party.you ?? me;
  const rows = useMaxRows();
  // over the cap your own row still shows, in place of the last one
  const shown = members.length > rows && members.findIndex((m) => m.id === you) >= rows
    ? [...members.slice(0, rows - 1), members.find((m) => m.id === you)!] : members.slice(0, rows);
  const pending = party.pending ?? [];
  return <aside className="crew-frame" aria-label="Crew">
    <Header title="CREW" count={`${members.length}/${party.maxSize}`} extra={party.matchmaking ? "MATCHMAKING" : undefined} />
    {shown.map((m) => <MemberRow key={m.id} m={m} you={m.id === you} />)}
    {members.length > shown.length && <div className="crew-row is-more">+{members.length - shown.length} MORE · F1 &gt; CREW</div>}
    {members.length <= 1 && pending.slice(0, 3).map((p) => <div key={p.id} className="crew-row is-pending">
      <span className="crew-row__mark"><Icon name="loader" size={10} /></span><strong>{p.name.toUpperCase()}</strong><span className="crew-row__chip">INVITED</span>
    </div>)}
  </aside>;
}

function MemberRow({ m, you }: { m: PartyMember; you: boolean }) {
  const state = m.state ?? "alive";
  const busy = m.busy ? BUSY[m.busy] : undefined;
  return <div className={cx("crew-row", `is-${state}`, you && "is-me", m.far && !you && "is-far")} title={m.busyLabel}>
    <span className="crew-row__mark">{m.leader ? <Icon name="crown" size={11} /> : <i className="crew-row__dot" />}</span>
    <strong>{m.name.toUpperCase()}</strong>
    {m.title && <span className={cx("crew-row__title title-rarity", m.titleRarity && `is-${m.titleRarity}`)} title={m.title}>{m.title.toUpperCase()}</span>}
    {you && <em>YOU</em>}
    {state !== "alive" ? <span className="crew-row__chip is-alert">{state === "down" ? "DOWN" : "DEAD"}</span>
      : busy ? <span className="crew-row__chip"><Icon name={busy.icon} size={10} />{busy.label}</span>
      : m.far && !you ? <span className="crew-row__chip is-dim"><Icon name="navigation" size={10} />FAR</span> : null}
  </div>;
}

/* During a mission: the operators with health and armor (the old squad frame). */
function MissionCrew({ operators, party, me, title }: { operators: MissionSquadMember[]; party?: PartyState; me?: number; title: string }) {
  const crewIds = new Set((party?.id ? party.members ?? [] : []).map((m) => m.id));
  const leader = party?.id ? party.leader : undefined;
  const shown = operators.slice(0, useMaxRows());
  return <aside className="crew-frame is-mission" aria-label="Crew">
    <Header title={crewIds.size > 1 ? "CREW" : "OPERATORS"} count={`${operators.length}`} extra={title.toUpperCase()} />
    {shown.map((m) => {
      const hp = m.maxHealth > 0 ? Math.max(0, Math.min(1, m.health / m.maxHealth)) : 0;
      const armor = Math.max(0, Math.min(1, m.armor / 100));
      const low = m.state === "alive" && hp < 0.3;
      const crown = leader != null ? m.id === leader : m.host;
      return <div key={m.id} className={cx("crew-op", `is-${m.state}`, low && "is-low", m.id === me && "is-me", crewIds.size > 1 && !crewIds.has(m.id) && "is-stranger")}>
        <div className="crew-op__line">
          <span className="crew-row__mark">{crown ? <Icon name="crown" size={11} /> : <i className="crew-row__dot" />}</span>
          <strong>{m.name.toUpperCase()}</strong>
          {m.id === me && <em>YOU</em>}
          {MISSION_STATE[m.state] ? <span className="crew-row__chip is-alert">{MISSION_STATE[m.state]}</span> : <span className="crew-op__hp">{m.health}</span>}
        </div>
        <div className="crew-op__bar is-health"><i style={{ width: `${hp * 100}%` }} /></div>
        <div className="crew-op__bar is-armor"><i style={{ width: `${armor * 100}%` }} /></div>
      </div>;
    })}
    {operators.length > shown.length && <div className="crew-row is-more">+{operators.length - shown.length} MORE</div>}
  </aside>;
}

/* The newest invite: who, the keys (client/core/crew.lua adds the effective ones), the time left.
   The buttons answer too, whenever the cursor is out (F1, a dialog, ALT). */
function CrewInvitePrompt({ party }: { party: PartyState }) {
  const invite = party.invites[0]!;
  const [received, setReceived] = useState(() => performance.now());
  const [, tick] = useState(0);
  useEffect(() => { setReceived(performance.now()); }, [invite.party, invite.expiresInMs]);
  useEffect(() => { const t = window.setInterval(() => tick((n) => n + 1), 500); return () => window.clearInterval(t); }, []);
  const total = (party.inviteSeconds ?? 60) * 1000;
  const left = Math.max(0, invite.expiresInMs - (performance.now() - received));
  const accept = party.keys?.accept ?? "Y", decline = party.keys?.decline ?? "N";
  const more = party.invites.length - 1;
  return <section className="crew-invite o77-interactive" role="alert" aria-label="Crew invite">
    <header className="crew-invite__head"><Icon name="user-plus" size={12} /><b>CREW INVITE</b><span>{Math.ceil(left / 1000)}s</span></header>
    <p className="crew-invite__body"><strong>{invite.fromName}</strong> invites you to their crew.{more > 0 ? ` +${more} more in F1 > Crew.` : ""}</p>
    <div className="crew-invite__actions">
      <button className="crew-invite__btn is-yes" onClick={() => sendAction({ type: "party.accept", party: invite.party })}><kbd>{accept}</kbd>ACCEPT</button>
      <button className="crew-invite__btn" onClick={() => sendAction({ type: "party.decline", party: invite.party })}><kbd>{decline}</kbd>DECLINE</button>
    </div>
    <i className="crew-invite__time" style={{ width: `${Math.min(100, (left / total) * 100)}%` }} />
  </section>;
}
