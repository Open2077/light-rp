import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, on, sendAction } from "@/bridge/open77";
import { formatMoney } from "@/bridge/money";
import { PAGE_EVENTS, type InventoryDialogPayload, type InventoryItem, type InventorySnapshot, type UiAction, type WornSlot, type WornState } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { emptySlot, itemAt, itemIdentity, itemAmount, kg, matchesToggleKey, quantity, transferSlot, type SlotRef } from "./model";
import { ItemArt, ItemEffects } from "./ItemArt";
import { WARDROBE_ROOT, WORN_SLOTS, garmentIcon, garmentTitle } from "./garment";
import "./inventory.css";

/* The inventory: Worn (what the character wears) on the left, Pockets in the
   middle with the quick slots 1–5 below, the other side (ground, trunk,
   storage) on the right. Compact tiles; details on hover, actions on the right
   button, double-click uses (puts a garment on, takes a worn one off), Shift +
   click sends to the other side. Items only change on server snapshots. */

type Drag = { from: SlotRef; item: InventoryItem; count: number; x: number; y: number; active: boolean };
type Menu = { x: number; y: number };
type Confirmation = "drop" | "give";
type Hover = { ref: SlotRef; x: number; y: number };
const QUICK = 5;

export function InventoryDialog() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "inventory";
  const close = useCallback(() => { sendAction({ type: "inventory.close" }); closeDialog(); }, [closeDialog]);
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "inventory", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    // the server pushes `worn` with the dialog; this is a late fallback (actions are throttled)
    const refresh = window.setTimeout(() => sendAction({ type: "clothing.refresh" }), 600);
    const offClose = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "inventory") close(); });
    return () => { window.clearTimeout(refresh); offClose(); emit(PAGE_EVENTS.focus, { active: false }); };
  }, [visible, close]);
  if (!visible || !dialog) return null;
  return <InventoryBody payload={dialog as InventoryDialogPayload} onClose={close} />;
}

/** Category → the thin line under a tile (signal colours, state only). */
const TONE: Record<string, string> = { food: "food", drink: "drink", medical: "health", currency: "accent", clothing: "steel", tool: "accent", material: "dim", document: "steel" };
const tone = (item: InventoryItem) => TONE[(item.category ?? "").toLowerCase()] ?? "dim";
const isGarment = (item: InventoryItem) => item.name === "clothing" || item.name === "outfit";

function InventoryBody({ payload, onClose }: { payload: InventoryDialogPayload; onClose: () => void }) {
  const { left, right } = payload;
  const root = useRef<HTMLDivElement>(null);
  const ghost = useRef<HTMLDivElement>(null);
  const dragRef = useRef<Drag | null>(null);
  const closeKeyPressed = useRef<string | null>(null);
  const latest = useRef(payload);
  latest.current = payload;
  const [drag, setDrag] = useState<Drag | null>(null);
  const [menu, setMenu] = useState<Menu | null>(null);
  const [hover, setHover] = useState<Hover | null>(null);
  const [wornMenu, setWornMenu] = useState<{ slot: WornSlot; x: number; y: number } | null>(null);
  const [selected, setSelected] = useState<SlotRef | null>(null);
  const [amount, setAmount] = useState("");
  const [search, setSearch] = useState("");
  const [confirmation, setConfirmation] = useState<Confirmation | null>(null);
  const [busy, setBusy] = useState(false);
  const pending = useRef(false);
  const [status, setStatus] = useState<{ text: string; error?: boolean } | null>(null);
  const result = useStore((s) => s.lastResult);
  const character = useStore((s) => s.state.character);
  const money = useStore((s) => s.state.money);
  const worn = useStore((s) => s.state.worn);
  const lastHandledResult = useRef(result);
  const selectedItem = itemAt(selected, [left, right]);
  const mine = selected?.inventory === left.id;
  const count = selectedItem ? quantity(amount, selectedItem.count) : 0;
  const destination = mine ? right : left;
  const moveSlot = selectedItem ? transferSlot(destination, selectedItem, count) : undefined;
  const canTransfer = !!selectedItem && count > 0 && destination.kind !== "ground" && moveSlot !== undefined;
  const source = selected?.inventory === left.id ? left : right;
  const freeSlot = emptySlot(source);
  const family = worn?.family ?? (character.bodyFamily === "male" ? "m" : "f");
  const name = `${character.firstName ?? ""} ${character.lastName ?? ""}`.trim() || character.accountName || "Inventory";

  const cancelDrag = useCallback(() => {
    dragRef.current = null; setDrag(null);
    root.current?.querySelectorAll("[data-drop-active]").forEach((element) => element.removeAttribute("data-drop-active"));
  }, []);
  const issue = useCallback((action: UiAction) => {
    if (pending.current) return;
    pending.current = true; setBusy(true); setMenu(null); setWornMenu(null); setConfirmation(null); setHover(null);
    setStatus({ text: "Updating inventory…" });
    sendAction(action);
  }, []);

  useEffect(() => {
    cancelDrag(); setMenu(null); setConfirmation(null);
    if (pending.current) { pending.current = false; setBusy(false); setStatus(null); }
  }, [left, right, cancelDrag]);
  useEffect(() => {
    if (result === lastHandledResult.current) return;
    lastHandledResult.current = result;
    if (!result?.action?.startsWith("inventory.")) return;
    pending.current = false; setBusy(false); setStatus({ text: result.text, error: !result.ok });
  }, [result]);
  useEffect(() => {
    if (!busy) return;
    const timer = window.setTimeout(() => {
      pending.current = false; setBusy(false);
      setStatus({ text: "No response yet. Close and reopen to refresh before trying again.", error: true });
    }, 5000);
    return () => window.clearTimeout(timer);
  }, [busy]);
  useEffect(() => {
    if (!status || status.error || busy) return;
    const timer = window.setTimeout(() => setStatus(null), 4500);
    return () => window.clearTimeout(timer);
  }, [status, busy]);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    root.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, []);

  const select = (ref: SlotRef) => {
    if (ref.inventory !== selected?.inventory || ref.slot !== selected.slot) setAmount("");
    setSelected(ref); setConfirmation(null); setMenu(null);
  };
  /** Shift + click: the whole stack to the other side, without selecting first. */
  const quickTransfer = (ref: SlotRef) => {
    const item = itemAt(ref, [left, right]);
    if (!item || busy) return;
    const to = ref.inventory === left.id ? right : left;
    if (to.kind === "ground") { issue({ type: "inventory.move", from: ref, to: { inventory: "ground", slot: 1 }, count: item.count }); return; }
    const slot = transferSlot(to, item, item.count);
    if (slot === undefined) { setStatus({ text: "No room for it on the other side.", error: true }); return; }
    issue({ type: "inventory.move", from: ref, to: { inventory: to.id, slot }, count: item.count });
  };
  const useAt = (ref: SlotRef) => {
    const item = itemAt(ref, [left, right]);
    if (!item || busy || ref.inventory !== left.id || !item.usable) return;
    issue({ type: "inventory.use", slot: ref.slot });
  };
  /** Double-click / menu on a Worn slot: take off, hide an outfit piece, show a hidden one, take the outfit off. */
  const wornAction = (slot: WornSlot) => {
    if (busy || !worn) return;
    if (worn.sources?.[slot] === "hidden") { issue({ type: "clothing.show", slot }); return; }
    if (slot === "Outfit" && worn.outfit) { issue({ type: "clothing.takeOff", slot }); return; }
    if (typeof worn.slots?.[slot] === "string") issue({ type: "clothing.takeOff", slot });
  };
  const perform = (action: "use" | "transfer" | "split") => {
    if (!selected || !selectedItem || busy) return;
    if (action === "use" && mine && selectedItem.usable) issue({ type: "inventory.use", slot: selected.slot });
    if (action === "transfer" && canTransfer && moveSlot !== undefined) issue({ type: "inventory.move", from: selected, to: { inventory: destination.id, slot: moveSlot }, count });
    if (action === "split" && selectedItem.count > 1 && freeSlot !== undefined && count > 0) {
      const splitCount = amount.trim() && count < selectedItem.count ? count : Math.floor(selectedItem.count / 2);
      issue({ type: "inventory.move", from: selected, to: { inventory: source.id, slot: freeSlot }, count: splitCount });
    }
  };
  const confirm = () => {
    if (!confirmation || !selected || !selectedItem || !mine || !count) return;
    issue({ type: confirmation === "give" ? "inventory.give" : "inventory.drop", slot: selected.slot, count });
  };

  useEffect(() => {
    const move = (event: PointerEvent) => {
      const current = dragRef.current;
      if (!current || (!current.active && Math.hypot(event.clientX - current.x, event.clientY - current.y) < 6)) return;
      if (!current.active) { current.active = true; setDrag({ ...current }); setHover(null); }
      if (ghost.current) ghost.current.style.transform = `translate(${event.clientX - 41}px, ${event.clientY - 41}px)`;
      root.current?.querySelectorAll("[data-drop-active]").forEach((element) => element.removeAttribute("data-drop-active"));
      const element = document.elementFromPoint(event.clientX, event.clientY);
      element?.closest("[data-inv], [data-worn]")?.setAttribute("data-drop-active", "true");
      const grid = element?.closest(".inv-grid");
      if (grid) {
        const bounds = grid.getBoundingClientRect();
        if (event.clientY > bounds.bottom - 32) grid.scrollTop += 15;
        else if (event.clientY < bounds.top + 32) grid.scrollTop -= 15;
      }
    };
    const up = (event: PointerEvent) => {
      const current = dragRef.current;
      cancelDrag();
      if (!current?.active || pending.current) return;
      const actual = itemAt(current.from, [latest.current.left, latest.current.right]);
      if (!actual || itemIdentity(actual) !== itemIdentity(current.item)) return;
      const hit = document.elementFromPoint(event.clientX, event.clientY);
      // a garment dropped on the Worn column: put it on
      const wornCell = hit?.closest<HTMLElement>("[data-worn]");
      if (wornCell) {
        if (current.from.inventory === latest.current.left.id && isGarment(actual) && actual.usable) issue({ type: "inventory.use", slot: current.from.slot });
        else setStatus({ text: "Only clothes from your pockets can be worn.", error: true });
        return;
      }
      const element = hit?.closest<HTMLElement>("[data-inv]");
      if (!element) return;
      const to = { inventory: element.dataset.inv!, slot: Number(element.dataset.slot) };
      if (to.inventory === current.from.inventory && to.slot === current.from.slot) return;
      if (to.inventory === "ground" && current.from.inventory !== latest.current.left.id) return;
      if (!Number.isInteger(to.slot) || to.slot < 1) return;
      issue({ type: "inventory.move", from: current.from, to, count: Math.min(current.count, actual.count) });
    };
    window.addEventListener("pointermove", move); window.addEventListener("pointerup", up);
    window.addEventListener("pointercancel", cancelDrag); window.addEventListener("blur", cancelDrag);
    return () => {
      window.removeEventListener("pointermove", move); window.removeEventListener("pointerup", up);
      window.removeEventListener("pointercancel", cancelDrag); window.removeEventListener("blur", cancelDrag);
    };
  }, [cancelDrag, issue]);
  useEffect(() => {
    if (!menu && !wornMenu) return;
    const dismiss = (event: PointerEvent) => { if (!(event.target as HTMLElement).closest(".inv-menu")) { setMenu(null); setWornMenu(null); setConfirmation(null); } };
    window.addEventListener("pointerdown", dismiss);
    return () => window.removeEventListener("pointerdown", dismiss);
  }, [menu, wornMenu]);

  const keyDown = (event: KeyboardEvent) => {
    if (event.key === "Escape") {
      event.preventDefault(); event.stopPropagation();
      if (menu || wornMenu) { setMenu(null); setWornMenu(null); setConfirmation(null); }
      else if (dragRef.current) cancelDrag();
      else onClose();
      return;
    }
    if (event.key === "Tab") {
      const focusable = Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled)') ?? []).filter((element) => element.getClientRects().length);
      const first = focusable[0], last = focusable.at(-1);
      if (event.shiftKey && (document.activeElement === first || document.activeElement === root.current)) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && (document.activeElement === last || document.activeElement === root.current)) { event.preventDefault(); first?.focus(); }
    }
    if ((event.target as HTMLElement).closest("input, textarea, select, [contenteditable=true]") || event.repeat) return;
    if (matchesToggleKey(event, payload.toggleKey)) {
      event.preventDefault(); event.stopPropagation();
      closeKeyPressed.current = event.code || event.key.toUpperCase();
      return;
    }
    if (busy) return;
    // the physical key: on AZERTY the 1–5 row types & é " ' ( without Shift
    const quick = /^(?:Digit|Numpad)([1-5])$/.exec(event.code)?.[1] ?? (/^[1-5]$/.test(event.key) ? event.key : undefined);
    if (quick) { event.preventDefault(); select({ inventory: left.id, slot: Number(quick) }); }
    if (event.key === "Enter" && selected) { event.preventDefault(); useAt(selected); }
  };
  const pointerDown = (inventory: InventorySnapshot, slot: number, item: InventoryItem | undefined, event: React.PointerEvent) => {
    if (event.button !== 0 || busy) return;
    select({ inventory: inventory.id, slot });
    if (!item || event.shiftKey) return; // Shift + click transfers (on click)
    const picked = event.ctrlKey ? Math.max(1, Math.floor(item.count / 2))
      : quantity(selected?.inventory === inventory.id && selected.slot === slot ? amount : "", item.count);
    if (picked) dragRef.current = { from: { inventory: inventory.id, slot }, item, count: picked, x: event.clientX, y: event.clientY, active: false };
  };
  const context = (inventory: InventorySnapshot, slot: number, event: React.MouseEvent) => {
    event.preventDefault();
    if (busy || !itemAt({ inventory: inventory.id, slot }, [left, right])) return;
    select({ inventory: inventory.id, slot }); setHover(null); setMenu({ x: event.clientX, y: event.clientY });
  };

  useEffect(() => {
    const keyUp = (event: KeyboardEvent) => {
      if (closeKeyPressed.current === null || (event.code || event.key.toUpperCase()) !== closeKeyPressed.current) return;
      closeKeyPressed.current = null;
      event.preventDefault(); event.stopPropagation(); onClose();
    };
    const blur = () => { closeKeyPressed.current = null; };
    window.addEventListener("keydown", keyDown);
    window.addEventListener("keyup", keyUp);
    window.addEventListener("blur", blur);
    return () => { window.removeEventListener("keydown", keyDown); window.removeEventListener("keyup", keyUp); window.removeEventListener("blur", blur); };
  });

  const tileProps = { selected, busy, drag, onSelect: select, onPointerDown: pointerDown, onContext: context, onUse: useAt, onTransfer: quickTransfer,
    onHover: (h: Hover | null) => { if (!dragRef.current?.active && !menu) setHover(h); } };
  const pct = left.maxWeight > 0 ? Math.min(100, Math.max(0, left.weight / left.maxWeight * 100)) : 0;
  const cash = money?.cash ?? 0;
  const hovered = hover ? itemAt(hover.ref, [left, right]) : undefined;

  return <div ref={root} className={`inventory o77-interactive${drag ? " inventory--dragging" : ""}`} role="dialog" aria-modal="true" aria-labelledby="inventory-title" tabIndex={-1} onContextMenu={(event) => event.preventDefault()}>
    <div className="inv-shell">
      <header className="inv-head">
        <span className="inv-head__badge"><Icon name="backpack" size={20} /></span>
        <div className="inv-head__who"><span>INVENTORY</span><h1 id="inventory-title">{name}</h1></div>
        <div className="inv-head__stat"><Icon name="wallet" size={16} /><b>{formatMoney(cash, money?.currency)}</b></div>
        <div className={`inv-head__weight${pct > 90 ? " is-heavy" : ""}`}><Icon name="scale" size={16} />
          <div><span><b>{kg(left.weight)}</b> / {kg(left.maxWeight)} kg</span><i><em style={{ width: `${pct}%` }} /></i></div></div>
        <button className="inv-head__close" aria-label="Close inventory" onClick={onClose}><Icon name="x" size={18} /></button>
      </header>

      <div className="inv-body">
        <WornColumn worn={worn} family={family} busy={busy} onAction={wornAction} dragging={!!drag && isGarment(drag.item)}
          onMakeOutfit={(name) => issue({ type: "clothing.makeOutfit", name })}
          onMenu={(slot, x, y) => { setMenu(null); setHover(null); setWornMenu({ slot, x, y }); }} />

        <section className="inv-panel inv-panel--pockets" aria-label="Pockets">
          <header className="inv-panel__head"><h2>Pockets</h2><span className="inv-count">{left.items.length} / {left.slots}</span>
            <label className="inv-search"><Icon name="search" size={14} /><input aria-label="Search items" placeholder="Search items" value={search} onChange={(e) => setSearch(e.target.value)} />{search && <button aria-label="Clear search" onClick={() => setSearch("")}><Icon name="x" size={12} /></button>}</label></header>
          <SlotGrid inv={left} from={QUICK + 1} search={search} {...tileProps} />
          <div className="inv-quick">
            <h3>Quick slots <span>1 – {QUICK}</span></h3>
            <div className="inv-quick__row">{Array.from({ length: Math.min(QUICK, left.slots) }, (_, i) => i + 1).map((slot) =>
              <Tile key={slot} inv={left} slot={slot} item={left.items.find((it) => it.slot === slot)} wide keyLabel={String(slot)} {...tileProps} />)}</div>
          </div>
        </section>

        <SidePanel inv={right} {...tileProps} />
      </div>

      <footer className="inv-keys">
        {status ? <span className={`inv-keys__status${status.error ? " is-error" : ""}`} role="status"><Icon name={busy ? "loader" : status.error ? "triangle-alert" : "check"} size={13} />{status.text}</span> : null}
        <span><kbd>DRAG</kbd>Move / swap</span><span><kbd>DOUBLE-CLICK</kbd>Use · wear · take off</span><span><kbd>RMB</kbd>Actions</span>
        <span><kbd>SHIFT + CLICK</kbd>Transfer</span><span><kbd>CTRL + DRAG</kbd>Half</span><span><kbd>1-5</kbd>Quick slots</span><span><kbd>{payload.toggleKey ?? "I"}</kbd>Close</span>
      </footer>
    </div>

    {hovered && hover && !menu && <ItemCard item={hovered} x={hover.x} y={hover.y} />}
    {drag && <div ref={ghost} className="inv-ghost" style={{ transform: `translate(${drag.x - 41}px, ${drag.y - 41}px)` }}><ItemArt item={drag.item} size="drag" />{drag.count > 1 && <b>×{drag.count}</b>}</div>}
    {wornMenu && worn && <WornMenu worn={worn} slot={wornMenu.slot} x={wornMenu.x} y={wornMenu.y} onAction={wornAction} />}
    {menu && selectedItem && <div className="inv-menu" role="menu" aria-label={`${selectedItem.label} actions`} style={{ left: Math.max(8, Math.min(menu.x, innerWidth - 268)), top: Math.max(8, Math.min(menu.y, innerHeight - 360)) }}>
      <header><b>{selectedItem.label}</b><span>{itemAmount(selectedItem)}</span></header>
      {confirmation ? <div className="inv-menu__confirm" role="alert"><strong>{confirmation === "drop" ? "Drop on the ground?" : "Give to the nearest player?"}</strong>
        <p>{itemAmount(selectedItem, count)} {selectedItem.label}{confirmation === "give" ? ". The server checks who is close enough." : ". Other players can pick it up."}</p>
        <div><button className="inv-btn inv-btn--primary" disabled={busy || !count} onClick={confirm}>Confirm</button><button className="inv-btn" onClick={() => setConfirmation(null)}>Back</button></div></div> : <>
        {selectedItem.count > 1 && <div className="inv-menu__qty"><input aria-label="Quantity" inputMode="numeric" placeholder={String(selectedItem.count)} value={amount} onChange={(e) => setAmount(e.target.value.replace(/[^0-9]/g, "").slice(0, 10))} />
          <button onClick={() => setAmount("1")}>1</button><button onClick={() => setAmount(String(Math.floor(selectedItem.count / 2)))}>½</button><button onClick={() => setAmount("")}>All</button></div>}
        {mine && selectedItem.usable && <button role="menuitem" onClick={() => perform("use")}><Icon name={isGarment(selectedItem) ? "shirt" : "hand"} size={14} />{isGarment(selectedItem) ? "Wear" : "Use one"}<kbd>2×CLICK</kbd></button>}
        {destination.kind !== "ground" && <button role="menuitem" disabled={!canTransfer} onClick={() => perform("transfer")}><Icon name="arrow-left-right" size={14} />{mine ? "Move to storage" : "Take"}<kbd>SHIFT</kbd></button>}
        <button role="menuitem" disabled={selectedItem.count < 2 || freeSlot === undefined || !count} onClick={() => perform("split")}><Icon name="split" size={14} />Split stack</button>
        {mine && <><button role="menuitem" disabled={!count} onClick={() => setConfirmation("give")}><Icon name="users" size={14} />Give to nearby player</button>
          <button role="menuitem" className="is-danger" disabled={!count} onClick={() => setConfirmation("drop")}><Icon name="arrow-down" size={14} />Drop on ground</button></>}
      </>}
    </div>}
  </div>;
}

type TileHandlers = {
  selected: SlotRef | null; busy: boolean; drag: Drag | null;
  onSelect: (ref: SlotRef) => void;
  onPointerDown: (inv: InventorySnapshot, slot: number, item: InventoryItem | undefined, event: React.PointerEvent) => void;
  onContext: (inv: InventorySnapshot, slot: number, event: React.MouseEvent) => void;
  onUse: (ref: SlotRef) => void; onTransfer: (ref: SlotRef) => void; onHover: (h: Hover | null) => void;
};

function Tile({ inv, slot, item, wide, keyLabel, selected, busy, drag, onSelect, onPointerDown, onContext, onUse, onTransfer, onHover }: TileHandlers & {
  inv: InventorySnapshot; slot: number; item?: InventoryItem; wide?: boolean; keyLabel?: string;
}) {
  const ref = { inventory: inv.id, slot };
  const isSelected = selected?.inventory === inv.id && selected.slot === slot;
  const isSource = drag?.from.inventory === inv.id && drag.from.slot === slot;
  return <button type="button" className={`inv-tile${wide ? " inv-tile--wide" : ""}${item ? ` is-filled tone-${tone(item)}` : ""}${isSelected ? " is-selected" : ""}${isSource ? " is-source" : ""}`}
    data-inv={inv.id} data-slot={slot} disabled={busy} aria-label={item ? `${item.label}, ${item.count}, slot ${slot}` : `Empty slot ${slot}`} aria-pressed={isSelected}
    onClick={(e) => { if (e.shiftKey) onTransfer(ref); else onSelect(ref); }} onDoubleClick={() => onUse(ref)}
    onPointerDown={(e) => onPointerDown(inv, slot, item, e)} onContextMenu={(e) => onContext(inv, slot, e)}
    onPointerEnter={(e) => item && onHover({ ref, x: e.currentTarget.getBoundingClientRect().right, y: e.currentTarget.getBoundingClientRect().top })}
    onPointerLeave={() => onHover(null)}>
    {keyLabel && <span className="inv-tile__key">{keyLabel}</span>}
    {item && <>
      {item.count > 1 && <span className="inv-tile__count" key={`${item.name}:${item.count}`}>{item.name === "cash" ? itemAmount(item, item.count, true) : `×${item.count}`}</span>}
      {item.weight > 0 && <span className="inv-tile__weight">{kg(item.weight * item.count)} kg</span>}
      <span className="inv-tile__art"><ItemArt item={item} /></span>
      <span className="inv-tile__label">{item.label}</span>
    </>}
  </button>;
}

function SlotGrid({ inv, from, search, ...handlers }: TileHandlers & { inv: InventorySnapshot; from: number; search: string }) {
  const bySlot = useMemo(() => new Map(inv.items.map((item) => [item.slot, item])), [inv.items]);
  const query = search.trim().toLocaleLowerCase();
  const matches = (item: InventoryItem | undefined) => !!item && `${item.label} ${item.name} ${item.category ?? ""}`.toLocaleLowerCase().includes(query);
  const slots = Array.from({ length: Math.max(0, inv.slots - from + 1) }, (_, i) => i + from).filter((slot) => !query || matches(bySlot.get(slot)));
  return <div className="inv-grid" aria-label="Slots">
    {slots.map((slot) => <Tile key={slot} inv={inv} slot={slot} item={bySlot.get(slot)} {...handlers} />)}
    {query && slots.length === 0 && <p className="inv-grid__none">No item matches “{search}”.</p>}
  </div>;
}

function SidePanel({ inv, ...handlers }: TileHandlers & { inv: InventorySnapshot }) {
  const ground = inv.kind === "ground";
  const title = ground ? "Ground" : inv.kind === "trunk" ? "Trunk" : inv.kind === "drop" ? "On the ground" : inv.kind === "housing" ? "Home storage" : "Storage";
  const pct = inv.maxWeight > 0 ? Math.min(100, Math.max(0, inv.weight / inv.maxWeight * 100)) : 0;
  return <section className="inv-panel inv-panel--side" aria-label={title}>
    <header className="inv-panel__head inv-panel__head--side"><div><span>{ground ? "Nearby" : inv.label}</span><h2>{title}</h2></div>
      {ground ? <span className="inv-count">0 / 20</span> : <div className="inv-side__weight"><span className="inv-count">{inv.items.length} / {inv.slots}</span><span>{kg(inv.weight)} / {kg(inv.maxWeight)} kg</span><i><em style={{ width: `${pct}%` }} /></i></div>}</header>
    {ground
      ? <div className="inv-grid inv-grid--ground" data-inv="ground" data-slot="1">{Array.from({ length: 20 }, (_, i) => <span key={i} className="inv-tile inv-tile--ghost" />)}</div>
      : <SlotGrid inv={inv} from={1} search="" {...handlers} />}
    <p className="inv-panel__hint"><Icon name={ground ? "arrow-down" : "arrow-left-right"} size={13} />{ground ? "Drag items here to leave them on the ground." : "Drag between both sides, or Shift + click to send a stack across."}</p>
  </section>;
}

/** What a Worn slot shows: the outfit (Outfit slot), a worn record, or a hidden outfit piece. */
function wornView(worn: WornState | undefined, slot: WornSlot) {
  const source = worn?.sources?.[slot];
  if (slot === "Outfit" && worn?.outfit) return { kind: "outfit" as const, title: worn.outfit.label, image: worn.outfit.image, source };
  const record = worn?.slots?.[slot];
  if (typeof record === "string") return { kind: "worn" as const, title: garmentTitle(record), record, source };
  const hidden = worn?.hidden?.[slot];
  if (source === "hidden" && hidden) return { kind: "hidden" as const, title: garmentTitle(hidden), record: hidden, source };
  return null;
}
const SOURCE_TAG: Record<string, string> = { outfit: "OUTFIT", over: "OVER OUTFIT", hidden: "HIDDEN" };
const OUTFIT_ART = /^open77:\/\/open77_wardrobe_ui\/web\/icons\/[mf]\/[0-9a-f]{16}\.webp$/;

function WornColumn({ worn, family, busy, onAction, onMenu, onMakeOutfit, dragging }: { worn: WornState | undefined; family: "m" | "f"; busy: boolean; onAction: (slot: WornSlot) => void; onMenu: (slot: WornSlot, x: number, y: number) => void; onMakeOutfit: (name: string) => void; dragging: boolean }) {
  // The outfit's own pieces belong to the Outfit slot: their slots read as free (only pieces worn over it count).
  const count = WORN_SLOTS.filter((s) => { const v = wornView(worn, s.slot); return v && v.kind !== "hidden" && v.source !== "outfit"; }).length;
  const [naming, setNaming] = useState<string | null>(null);
  const canMake = !!worn?.ready && !worn.outfit && count > 0;
  const ghost = (v: ReturnType<typeof wornView>) => !!v && v.kind === "worn" && v.source === "outfit";
  useEffect(() => { if (!canMake) setNaming(null); }, [canMake]);
  return <aside className={`inv-worn${dragging ? " is-target" : ""}${worn?.outfit ? " has-outfit" : ""}`} aria-label="Worn">
    <header className="inv-panel__head"><h2>Worn</h2><span className="inv-count">{worn?.ready === false ? "…" : `${count} / ${WORN_SLOTS.length}`}</span></header>
    <div className="inv-worn__list">{WORN_SLOTS.map(({ slot, label, icon }) => {
      const view = wornView(worn, slot);
      const tag = view?.kind === "outfit" ? "OUTFIT" : ghost(view) ? "IN OUTFIT" : view?.source ? SOURCE_TAG[view.source] : undefined;
      const hint = !view ? `${label}: nothing worn` : view.kind === "hidden" ? `${view.title} · hidden · double-click to show`
        : view.source === "outfit" ? `${view.title} · part of your outfit · double-click to hide`
        : `${view.title} · double-click or right-click to take off`;
      return <button key={slot} type="button" className={`inv-worn__slot${view ? ` is-on is-${view.kind}` : ""}${view?.source ? ` from-${view.source}` : ""}`} data-worn={slot} disabled={busy || !view}
        title={hint} onDoubleClick={() => onAction(slot)}
        onContextMenu={(e) => { e.preventDefault(); if (view && !busy) onMenu(slot, e.clientX, e.clientY); }}>
        {tag && <em className="inv-worn__tag">{tag}</em>}
        {!view || ghost(view) ? <Icon name={icon} size={26} />
          : view.kind === "outfit" ? (view.image && OUTFIT_ART.test(view.image) ? <img className="inv-worn__art" alt="" draggable={false} src={view.image} /> : <Icon name="users" size={26} />)
          : <WornArt record={view.record} family={family} fallback={icon} />}
        <span>{view && !ghost(view) ? view.title : label}</span><small>{ghost(view) ? view!.title : label}</small>
      </button>;
    })}</div>
    {canMake && (naming === null
      ? <button type="button" className="inv-worn__make" disabled={busy} onClick={() => setNaming("")} title="Everything you wear becomes one outfit. Take it off from the Outfit slot to fold it into your bag.">
          <Icon name="users" size={14} />Make an outfit</button>
      : <form className="inv-worn__name" onSubmit={(e) => { e.preventDefault(); onMakeOutfit(naming.trim() || "My outfit"); setNaming(null); }}>
          <input autoFocus maxLength={40} placeholder="My outfit" value={naming} aria-label="Outfit name" onChange={(e) => setNaming(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Escape") { e.stopPropagation(); setNaming(null); } }} />
          <div><button type="submit" className="inv-btn inv-btn--primary" disabled={busy}>Save</button><button type="button" className="inv-btn" onClick={() => setNaming(null)}>Cancel</button></div>
        </form>)}
  </aside>;
}

function WornMenu({ worn, slot, x, y, onAction }: { worn: WornState; slot: WornSlot; x: number; y: number; onAction: (slot: WornSlot) => void }) {
  const view = wornView(worn, slot);
  if (!view) return null;
  const label = WORN_SLOTS.find((s) => s.slot === slot)?.label;
  const text = view.kind === "outfit" ? "Take the outfit off · to pockets" : view.kind === "hidden" ? "Show the outfit's piece"
    : view.source === "outfit" ? "Hide this outfit piece" : view.source === "over" ? "Take off · the outfit's shows again" : "Take off · to pockets";
  return <div className="inv-menu" role="menu" style={{ left: Math.max(8, Math.min(x, innerWidth - 268)), top: Math.max(8, Math.min(y, innerHeight - 140)) }}>
    <header><b>{view.title}</b><span>{label}</span></header>
    <button role="menuitem" onClick={() => onAction(slot)}><Icon name={view.kind === "hidden" ? "eye" : "arrow-down"} size={14} />{text}<kbd>2×CLICK</kbd></button>
  </div>;
}

function WornArt({ record, family, fallback }: { record: string; family: "m" | "f"; fallback: string }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [record, family]);
  if (failed) return <Icon name={fallback} size={26} />;
  return <img className="inv-worn__art" alt="" draggable={false} src={WARDROBE_ROOT + garmentIcon(record, family)} onError={() => setFailed(true)} />;
}

function ItemCard({ item, x, y }: { item: InventoryItem; x: number; y: number }) {
  const left = x + 280 > innerWidth ? x - 296 : x + 10;
  return <div className={`inv-card tone-${tone(item)}`} style={{ left: Math.max(8, left), top: Math.max(8, Math.min(y, innerHeight - 260)) }} role="tooltip">
    <span className="inv-card__cat">{item.category ?? "Item"}{item.useAction && ` · ${item.useAction.durationMs / 1000}s`}</span>
    <b>{item.label}</b>
    {item.description && <p>{item.description}</p>}
    <ItemEffects item={item} />
    <dl><div><dt>Each</dt><dd>{item.weight === 0 ? "—" : `${kg(item.weight)} kg`}</dd></div><div><dt>Stack</dt><dd>{itemAmount(item)} · {kg(item.weight * item.count)} kg</dd></div></dl>
    {item.usable && <span className="inv-card__hint"><kbd>2×CLICK</kbd>{isGarment(item) ? "Wear" : "Use"}</span>}
  </div>;
}
