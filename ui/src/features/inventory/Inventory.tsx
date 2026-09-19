import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type InventoryDialogPayload, type InventoryItem, type InventorySnapshot } from "@/bridge/protocol";
import { Button, Icon, Keycap } from "@/design/components";
import "./inventory.css";

/* Two inventories side by side (ox_inventory layout): the player's on the
   left, whatever is in reach on the right (a trunk, a pile, a stash, or the
   bare ground). Drag a stack between slots or across; right-click a slot for
   the actions; the middle column carries the amount and the buttons for the
   selected slot. Every operation is an action the server validates; the
   server pushes fresh snapshots back. */

const COLUMNS = 5;

type SlotRef = { inventory: string; slot: number };
interface Drag { from: SlotRef; item: InventoryItem; count: number; x: number; y: number }
interface Menu { at: SlotRef; item: InventoryItem; x: number; y: number }

const formatKg = (kg: number) => `${kg.toFixed(kg < 10 ? 2 : 1)}`;

export function InventoryDialog() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "inventory";

  const close = useCallback(() => { sendAction({ type: "inventory.close" }); closeDialog(); }, [closeDialog]);

  useEffect(() => {
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const onKey = (e: KeyboardEvent) => {
      if ((e.key === "Escape" || e.key === "i" || e.key === "I") && !e.repeat) {
        const target = e.target as HTMLElement | null;
        if (e.key !== "Escape" && target && target.tagName === "INPUT") return;
        e.preventDefault(); close();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => { window.removeEventListener("keydown", onKey); emit(PAGE_EVENTS.focus, { active: false }); };
  }, [visible, close]);

  if (!visible || !dialog) return null;
  return <InventoryBody payload={dialog as InventoryDialogPayload} onClose={close} />;
}

function InventoryBody({ payload, onClose }: { payload: InventoryDialogPayload; onClose: () => void }) {
  const [drag, setDrag] = useState<Drag | null>(null);
  const [menu, setMenu] = useState<Menu | null>(null);
  const [selected, setSelected] = useState<SlotRef | null>(null);
  const [amount, setAmount] = useState<string>("");
  const [hover, setHover] = useState<{ item: InventoryItem; x: number; y: number } | null>(null);
  const [search, setSearch] = useState<{ left: string; right: string }>({ left: "", right: "" });
  const dragRef = useRef<Drag | null>(null);
  const ghost = useRef<HTMLDivElement>(null);

  const left = payload.left;
  const right = payload.right;
  const findItem = (ref: SlotRef | null): InventoryItem | undefined => {
    if (!ref) return undefined;
    const inv = ref.inventory === left.id ? left : ref.inventory === right.id ? right : undefined;
    return inv?.items.find((i) => i.slot === ref.slot);
  };
  const selectedItem = findItem(selected);
  const wanted = (max: number) => { const n = Math.floor(Number(amount)); return Number.isFinite(n) && n > 0 ? Math.min(n, max) : max; };

  // ---- drag & drop (pointer events, one ghost element moved without re-renders)
  const onSlotPointerDown = (inv: InventorySnapshot, slot: number, item: InventoryItem | undefined, e: React.PointerEvent) => {
    if (e.button !== 0) return;
    setMenu(null);
    setSelected({ inventory: inv.id, slot });
    if (!item) return;
    const count = e.shiftKey ? Math.max(1, Math.floor(item.count / 2)) : wanted(item.count);
    const d: Drag = { from: { inventory: inv.id, slot }, item, count, x: e.clientX, y: e.clientY };
    dragRef.current = d; setDrag(d);
    e.preventDefault();
  };
  useEffect(() => {
    if (!drag) return;
    const move = (e: PointerEvent) => {
      if (ghost.current) ghost.current.style.transform = `translate(${e.clientX + 12}px, ${e.clientY + 12}px)`;
    };
    const up = (e: PointerEvent) => {
      const d = dragRef.current; dragRef.current = null; setDrag(null);
      if (!d) return;
      const el = document.elementFromPoint(e.clientX, e.clientY)?.closest<HTMLElement>("[data-inv]");
      if (!el) return;
      const to: SlotRef = { inventory: el.dataset.inv!, slot: Number(el.dataset.slot) };
      if (to.inventory === d.from.inventory && to.slot === d.from.slot) return;
      sendAction({ type: "inventory.move", from: d.from, to, count: d.count });
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up, { once: true });
    return () => { window.removeEventListener("pointermove", move); window.removeEventListener("pointerup", up); };
  }, [drag]);

  // ---- context menu
  const onContext = (inv: InventorySnapshot, slot: number, item: InventoryItem | undefined, e: React.MouseEvent) => {
    e.preventDefault();
    if (!item) { setMenu(null); return; }
    setSelected({ inventory: inv.id, slot });
    setMenu({ at: { inventory: inv.id, slot }, item, x: e.clientX, y: e.clientY });
  };
  useEffect(() => {
    if (!menu) return;
    const dismiss = (e: PointerEvent) => { if (!(e.target as HTMLElement).closest(".inv-menu")) setMenu(null); };
    window.addEventListener("pointerdown", dismiss);
    return () => window.removeEventListener("pointerdown", dismiss);
  }, [menu]);

  const isPlayerSlot = (ref: SlotRef | null) => !!ref && ref.inventory === left.id;
  const act = {
    use: (ref: SlotRef) => { if (isPlayerSlot(ref)) sendAction({ type: "inventory.use", slot: ref.slot }); setMenu(null); },
    give: (ref: SlotRef, item: InventoryItem) => { if (isPlayerSlot(ref)) sendAction({ type: "inventory.give", slot: ref.slot, count: wanted(item.count) }); setMenu(null); },
    drop: (ref: SlotRef, item: InventoryItem) => { if (isPlayerSlot(ref)) sendAction({ type: "inventory.drop", slot: ref.slot, count: wanted(item.count) }); setMenu(null); },
    split: (ref: SlotRef, item: InventoryItem) => {
      const inv = ref.inventory === left.id ? left : right;
      const used = new Set(inv.items.map((i) => i.slot));
      let free = 0; for (let s = 1; s <= inv.slots; s++) if (!used.has(s)) { free = s; break; }
      if (!free) { setMenu(null); return; }
      const half = Math.max(1, Math.floor(item.count / 2));
      const n = Math.floor(Number(amount));
      const count = Number.isFinite(n) && n > 0 && n < item.count ? n : half;
      sendAction({ type: "inventory.move", from: ref, to: { inventory: inv.id, slot: free }, count });
      setMenu(null);
    },
  };

  return (
    <div className="inv o77-interactive" role="dialog" aria-modal="true" aria-label="Inventory">
      <Panel inv={left} side="left" search={search.left} onSearch={(v) => setSearch((s) => ({ ...s, left: v }))}
        selected={selected} drag={drag} onPointerDown={onSlotPointerDown} onContext={onContext} onHover={setHover} hotbar />

      <div className="inv__middle">
        <div className="inv__amount">
          <span className="o77-readout o77-dim">AMOUNT</span>
          <input className="inv__amount-input" type="number" min={1} inputMode="numeric" placeholder="all" value={amount}
            onChange={(e) => setAmount(e.target.value)} onKeyDown={(e) => e.stopPropagation()} />
        </div>
        <Button size="sm" icon="hand" disabled={!selectedItem || !selectedItem.usable || !isPlayerSlot(selected)} onClick={() => selected && act.use(selected)}>Use</Button>
        <Button size="sm" variant="secondary" icon="users" disabled={!selectedItem || !isPlayerSlot(selected)} onClick={() => selected && selectedItem && act.give(selected, selectedItem)}>Give</Button>
        <Button size="sm" variant="secondary" icon="package-open" disabled={!selectedItem || !isPlayerSlot(selected)} onClick={() => selected && selectedItem && act.drop(selected, selectedItem)}>Drop</Button>
        <Button size="sm" variant="ghost" icon="x" onClick={onClose}>Close</Button>
        <span className="inv__hint o77-readout o77-disabled">DRAG TO MOVE · SHIFT+DRAG HALF · RIGHT CLICK FOR ACTIONS · <Keycap size="sm">I</Keycap> CLOSE</span>
      </div>

      <Panel inv={right} side="right" search={search.right} onSearch={(v) => setSearch((s) => ({ ...s, right: v }))}
        selected={selected} drag={drag} onPointerDown={onSlotPointerDown} onContext={onContext} onHover={setHover} />

      {drag && (
        <div ref={ghost} className="inv__ghost" style={{ transform: `translate(${drag.x + 12}px, ${drag.y + 12}px)` }}>
          <Icon name={drag.item.icon} size={22} />
          <span className="inv__ghost-count">{drag.count}x</span>
        </div>
      )}

      {menu && (
        <div className="inv-menu" style={{ left: Math.min(menu.x, window.innerWidth - 190), top: Math.min(menu.y, window.innerHeight - 200) }}>
          <div className="inv-menu__title">{menu.item.label}</div>
          {menu.item.usable && isPlayerSlot(menu.at) && <button type="button" className="inv-menu__row" onClick={() => act.use(menu.at)}><Icon name="hand" size={13} />Use</button>}
          {isPlayerSlot(menu.at) && <button type="button" className="inv-menu__row" onClick={() => act.give(menu.at, menu.item)}><Icon name="users" size={13} />Give</button>}
          {menu.item.count > 1 && <button type="button" className="inv-menu__row" onClick={() => act.split(menu.at, menu.item)}><Icon name="arrow-left-right" size={13} />Split</button>}
          {isPlayerSlot(menu.at) && <button type="button" className="inv-menu__row inv-menu__row--danger" onClick={() => act.drop(menu.at, menu.item)}><Icon name="package-open" size={13} />Drop</button>}
          <button type="button" className="inv-menu__row" onClick={() => setMenu(null)}><Icon name="x" size={13} />Close</button>
        </div>
      )}

      {hover && !drag && !menu && (
        <div className="inv-tip" style={{ left: Math.min(hover.x + 14, window.innerWidth - 280), top: Math.min(hover.y + 14, window.innerHeight - 140) }}>
          <div className="inv-tip__head"><Icon name={hover.item.icon} size={14} /><span>{hover.item.label}</span><span className="inv-tip__w">{formatKg(hover.item.weight)} KG</span></div>
          {hover.item.description && <p className="inv-tip__desc">{hover.item.description}</p>}
          <div className="inv-tip__meta">
            <span>{hover.item.count}x · {formatKg(hover.item.weight * hover.item.count)} KG TOTAL</span>
            {hover.item.stack > 1 && <span>STACK {hover.item.stack}</span>}
            {hover.item.usable && <span className="o77-accent">USABLE</span>}
          </div>
        </div>
      )}
    </div>
  );
}

function Panel({ inv, side, search, onSearch, selected, drag, onPointerDown, onContext, onHover, hotbar }: {
  inv: InventorySnapshot; side: "left" | "right"; search: string; onSearch: (v: string) => void; selected: SlotRef | null; drag: Drag | null;
  onPointerDown: (inv: InventorySnapshot, slot: number, item: InventoryItem | undefined, e: React.PointerEvent) => void;
  onContext: (inv: InventorySnapshot, slot: number, item: InventoryItem | undefined, e: React.MouseEvent) => void;
  onHover: (h: { item: InventoryItem; x: number; y: number } | null) => void; hotbar?: boolean;
}) {
  const bySlot = useMemo(() => new Map(inv.items.map((i) => [i.slot, i])), [inv.items]);
  const ground = inv.kind === "ground";
  const rows = Math.max(Math.ceil(inv.slots / COLUMNS), 5);
  const q = search.trim().toLowerCase();
  const pct = inv.maxWeight > 0 ? Math.min(1, inv.weight / inv.maxWeight) : 0;
  return (
    <section className={`inv__panel inv__panel--${side}${ground ? " inv__panel--ground" : ""}`}>
      <header className="inv__head">
        <div className="inv__head-row">
          <span className="inv__title">{inv.label}</span>
          <span className="inv__weight"><Icon name="package" size={13} /> {formatKg(inv.weight)} / {formatKg(inv.maxWeight)} KG</span>
        </div>
        <div className="inv__bar"><div className={"inv__bar-fill" + (pct > 0.9 ? " inv__bar-fill--full" : "")} style={{ transform: `scaleX(${pct})` }} /></div>
        <div className="inv__tools">
          <label className="inv__search"><Icon name="terminal" size={12} /><input value={search} placeholder="Search" onChange={(e) => onSearch(e.target.value)} onKeyDown={(e) => e.stopPropagation()} /></label>
          <span className="o77-readout o77-disabled">{inv.items.length} / {inv.slots} SLOTS</span>
        </div>
      </header>
      <div className="inv__grid" style={{ gridTemplateColumns: `repeat(${COLUMNS}, 1fr)`, gridTemplateRows: `repeat(${rows}, 1fr)` }}>
        {ground && inv.items.length === 0 && <div className="inv__ground-hint" data-inv={inv.id} data-slot={1}><Icon name="package-open" size={22} /><span>DROP HERE</span></div>}
        {Array.from({ length: inv.slots }, (_, i) => i + 1).map((slot) => {
          const item = bySlot.get(slot);
          const dim = !!q && !!item && !item.label.toLowerCase().includes(q);
          const isSel = selected?.inventory === inv.id && selected.slot === slot;
          const isDragSrc = drag?.from.inventory === inv.id && drag.from.slot === slot;
          return (
            <div key={slot} className={"inv__slot" + (item ? " inv__slot--filled" : "") + (isSel ? " inv__slot--selected" : "") + (dim ? " inv__slot--dim" : "") + (isDragSrc ? " inv__slot--source" : "")}
              data-inv={inv.id} data-slot={slot}
              onPointerDown={(e) => onPointerDown(inv, slot, item, e)} onContextMenu={(e) => onContext(inv, slot, item, e)}
              onPointerEnter={(e) => item && onHover({ item, x: e.clientX, y: e.clientY })} onPointerMove={(e) => item && onHover({ item, x: e.clientX, y: e.clientY })} onPointerLeave={() => onHover(null)}>
              {hotbar && slot <= 5 && <span className="inv__hotkey">{slot}</span>}
              {item && (
                <>
                  <span className="inv__label">{item.label}</span>
                  <span className="inv__icon"><Icon name={item.icon} size={30} /></span>
                  <span className="inv__count">{item.count}x</span>
                  <span className="inv__kg">{formatKg(item.weight * item.count)}</span>
                  {item.usable && <span className="inv__usable" />}
                </>
              )}
            </div>
          );
        })}
      </div>
    </section>
  );
}
