import { SECTION, SECTIONS, roman, type Body } from "./data";
import { isStored } from "./model";
import { iconImage, type Manifest } from "./media";
import { anchorPoint, bodyBox } from "./Stage";
import { play } from "./sfx";
import type { Phase, Session } from "./App";

/* The paperdoll overview: the twelve sections in two columns around the body, like the game's
   ripperdoc screen. Hover lights the system on the body and draws a lead from the group to its
   anchor; a click dives into the close-up. */

const ROW0 = 168, ROW_H = 142, SLOT = 84, GAP = 10, MARGIN = 74;

function groupGeometry(manifest: Manifest, body: Body, index: number, side: "left" | "right") {
  const box = bodyBox(manifest, body);
  const row = side === "left" ? index : index - 6;
  const y = ROW0 + row * ROW_H;
  const inner = side === "left" ? box.left - MARGIN : box.left + box.width + MARGIN;
  return { y, inner, slotsY: y + 34 };
}

interface Props {
  body: Body; manifest: Manifest; phase: Phase; hovered: string | null; session: Session;
  onHover(id: string | null): void; onDive(id: string): void;
}

export function Overview({ body, manifest, phase, hovered, session, onHover, onDive }: Props) {
  const installed = session.installed;
  return (
    <div className={`rd-overview ${phase === "diving" ? "is-diving" : ""} ${phase === "surfacing" ? "is-surfacing" : ""}`}>
      <svg className="rd-leads" width="1920" height="1080" viewBox="0 0 1920 1080">
        {SECTIONS.map((s, i) => {
          const g = groupGeometry(manifest, body, i, s.side);
          const a = anchorPoint(manifest, body, s.id);
          const sx = g.inner + (s.side === "left" ? 14 : -14);
          const sy = g.slotsY + SLOT / 2;
          const knee = s.side === "left" ? sx + 34 : sx - 34;
          const on = hovered === s.id;
          return (
            <g key={s.id} className={`rd-lead ${on ? "on" : ""}`}>
              <path d={`M ${sx} ${sy} L ${knee} ${sy} L ${a.x} ${a.y}`} />
              <circle cx={sx} cy={sy} r={3} />
              {on && <circle cx={a.x} cy={a.y} r={5} className="tip" />}
            </g>
          );
        })}
      </svg>
      {hovered && phase === "overview" && <Peek body={body} manifest={manifest} id={hovered} installed={installed[hovered] ?? []} session={session} />}
      {SECTIONS.map((s, i) => {
        const g = groupGeometry(manifest, body, i, s.side);
        const list = installed[s.id] ?? [];
        const slots0 = Math.max(s.slots, list.length);
        const total = slots0 + s.locked;
        const width = total * SLOT + (total - 1) * GAP;
        const left = s.side === "left" ? g.inner - width : g.inner;
        const on = hovered === s.id;
        const slots = Array.from({ length: total }, (_, k) => k);
        return (
          <div key={s.id} className={`rd-group rd-${s.side} ${on ? "on" : ""} ${hovered && !on ? "dim" : ""}`}
            style={{ left, top: g.y, width, ["--i" as string]: i }}
            onPointerEnter={() => { onHover(s.id); play("hover"); }} onPointerLeave={() => onHover(null)}
            onClick={() => { play("press"); onDive(s.id); }}>
            <div className="rd-group-label">
              <span className="code">{s.code}</span>
              <span className="name">{s.label}</span>
              <span className="count">{list.length}/{slots0}</span>
            </div>
            <div className="rd-group-slots">
              {slots.map((k) => {
                const id = list[k];
                const item = id ? session.items[id] : undefined;
                const locked = k >= slots0;
                return (
                  <div key={k} className={`rd-slot ${item ? `filled r-${item.rarity}` : locked ? "locked" : "empty"}`}>
                    {item && <img src={iconImage(item.icon)} alt="" />}
                    {!item && !locked && <span className="plus" />}
                    {locked && <span className="lock">LOCKED</span>}
                    {item && <span className="tier">{roman(item.tier)}</span>}
                  </div>
                );
              })}
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* A holographic card floating in front of the body, next to the hovered system's anchor. */
function Peek({ body, manifest, id, installed, session }: { body: Body; manifest: Manifest; id: string; installed: string[]; session: Session }) {
  const s = SECTION[id]!;
  const a = anchorPoint(manifest, body, id);
  const stockCount = session.stock.filter((x) => x.section === id).length;
  const stored = session.stock.filter((x) => x.section === id && isStored(session, x.id));
  const left = s.side === "left" ? a.x + 46 : a.x - 46 - 270;
  const top = Math.min(860, Math.max(110, a.y - 30));
  return (
    <div key={id} className={`rd-peek rd-peek-${s.side}`} style={{ left, top }}>
      <div className="rd-peek-code">{s.code} // SCAN</div>
      <div className="rd-peek-name">{s.label}</div>
      <ul>
        {installed.length === 0 && <li className="none">No implant</li>}
        {installed.map((x) => <li key={x}><i style={{ background: `var(--r-${session.items[x]?.rarity ?? "common"})` }} />{session.items[x]?.name ?? x}</li>)}
        {stored.map((x) => <li key={x.id} className="stored"><i style={{ background: `var(--r-${x.rarity})` }} />{x.name} · storage</li>)}
        {stockCount === 0 && <li className="none">Nothing in stock for this system</li>}
      </ul>
      <div className="rd-peek-foot"><kbd>LMB</kbd> OPEN SYSTEM</div>
    </div>
  );
}
