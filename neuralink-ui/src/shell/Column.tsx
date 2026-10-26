/* The SAO main column: round buttons cascading in from the top. */
import { Power } from "lucide-react";
import { useStore } from "@/store/store";
import { RoundButton } from "@/components/RoundButton";
import { act, userClose } from "@/store/actions";
import { play } from "@/fx/sound";
import { selectColumn } from "./keys";
import type { ColumnItem } from "./menu";

export const COL = { x: 560, btn: 80, gap: 16, closeBtn: 54, closeGap: 34 };

export interface ColumnLayout { top: number; centers: number[]; height: number }

export function columnLayout(n: number): ColumnLayout {
  const step = COL.btn + COL.gap;
  const height = n * step - COL.gap + COL.closeGap + COL.closeBtn;
  const top = Math.round(540 - height / 2);
  return { top, height, centers: Array.from({ length: n }, (_, i) => top + i * step + COL.btn / 2) };
}

export function Column({ items, layout }: { items: ColumnItem[]; layout: ColumnLayout }) {
  const menu = useStore((s) => s.menu);
  const callView = useStore((s) => s.callView);
  const cursor = useStore((s) => s.cursor);
  const call = useStore((s) => s.state?.call ?? null);

  const launch = async (appId: string) => {
    play("select");
    useStore.getState().setMenu(null);
    await act("apps.launch", { id: appId });
  };

  return (
    <nav className="column nl-hit" style={{ top: layout.top, left: COL.x }} aria-label="Neural-Link menu">
      <span className="column__spine" aria-hidden style={{ height: layout.height }} />
      {items.map((it, i) => {
        const selected = it.id === "call" ? callView : it.id === menu;
        const isCall = it.id === "call";
        return (
          <div key={it.id} className="column__slot" style={{ ["--i" as string]: i }}>
            <RoundButton
              icon={it.icon}
              label={isCall ? (call?.phase === "incoming" ? "Incoming" : "In call") : it.label}
              selected={selected}
              cursor={cursor === i}
              badge={it.badge}
              tone={isCall ? "ok" : "glass"}
              pulse={isCall}
              color={it.color}
              className={isCall ? "rb--call" : undefined}
              onClick={() => {
                useStore.getState().setCursor(i);
                if (it.appId) void launch(it.appId);
                else selectColumn(it.id);
              }}
              dataCol={it.id}
            />
          </div>
        );
      })}
      <div className="column__slot column__slot--close" style={{ ["--i" as string]: items.length, marginTop: COL.closeGap - COL.gap }}>
        <RoundButton icon={<Power size={22} strokeWidth={2.2} />} label="Disconnect" size={COL.closeBtn} tone="danger" onClick={userClose} />
      </div>
    </nav>
  );
}
