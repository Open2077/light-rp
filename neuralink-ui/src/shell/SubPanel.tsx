/* Sub-panel: stacked glass slabs to the right of the column, joined to the
   selected button by the triangular pointer. */
import { useStore, topView } from "@/store/store";
import { Slab } from "@/components/Slab";
import { Holo3D } from "@/components/Holo3D";
import { Pointer } from "@/components/HoloPanel";
import { clamp } from "@/lib/format";
import { MENU_TITLES, panelRows, rowMatches } from "./menu";
import { play } from "@/fx/sound";

export const PANEL = { x: 690, w: 340, head: 64, row: 62, foot: 34 };

export function SubPanel({ anchorY, missed }: { anchorY: number; missed: number }) {
  const menu = useStore((s) => s.menu);
  const state = useStore((s) => s.state);
  const row = useStore((s) => s.row);
  const base = useStore((s) => s.stack[0] ?? null);
  const top = useStore(topView);
  const rows = panelRows(menu, state, missed);
  if (!menu || rows.length === 0) return null;

  const meta = MENU_TITLES[menu] ?? { title: menu, icon: null };
  const height = PANEL.head + rows.length * PANEL.row + PANEL.foot;
  const y = clamp(Math.round(anchorY - PANEL.head - PANEL.row / 2 + 6), 70, 1080 - 70 - height);
  const pointerY = clamp(anchorY - y - 11, 18, height - 30);
  const idx = String(["status", "phone", "messages", "contacts", "settings", "social"].indexOf(menu) + 1).padStart(2, "0");

  return (
    <div className="tilt tilt--panel" style={{ left: PANEL.x, top: y, width: PANEL.w }}>
      <Holo3D cut={12} depth={3} className="nl3d--board">
      <section className="subpanel nl-hit" aria-label={meta.title}>
        <Pointer y={pointerY} />
        <header className="subpanel__head">
          <span className="subpanel__icon">{meta.icon}</span>
          <span className="subpanel__title label">{meta.title}</span>
          <span className="subpanel__tag mono">NL//{idx}</span>
        </header>
        <div className="subpanel__rows">
          {rows.map((r, i) => (
            <Slab
              key={r.id}
              index={i}
              icon={r.icon}
              label={r.label}
              hint={r.hint}
              badge={r.badge}
              active={rowMatches(r, base) && !!top}
              cursor={row === i}
              onClick={() => {
                const st = useStore.getState();
                st.setRow(i);
                if (rowMatches(r, base) && st.stack.length === 1) { st.resetView(null); play("back"); return; }
                st.resetView(r.view);
                play("select");
              }}
            />
          ))}
        </div>
        <footer className="subpanel__foot mono" aria-hidden>
          <span>↑↓ select</span><span>⏎ open</span><span>esc back</span>
        </footer>
      </section>
      </Holo3D>
    </div>
  );
}
