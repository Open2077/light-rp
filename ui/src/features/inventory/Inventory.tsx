import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type InventoryDialogPayload, type InventoryItem, type InventorySnapshot, type UiAction } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { emptySlot, itemAt, itemIdentity, kg, matchesToggleKey, quantity, transferSlot, type SlotRef } from "./model";
import { ItemArt, ItemEffects } from "./ItemArt";
import "./inventory.css";

type Drag = { from: SlotRef; item: InventoryItem; count: number; x: number; y: number; active: boolean };
type Menu = { x: number; y: number };
type Confirmation = "drop" | "give";

export function InventoryDialog() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "inventory";
  const close = useCallback(() => { sendAction({ type: "inventory.close" }); closeDialog(); }, [closeDialog]);
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "inventory", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const offClose = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "inventory") close(); });
    return () => { offClose(); emit(PAGE_EVENTS.focus, { active: false }); };
  }, [visible, close]);
  if (!visible || !dialog) return null;
  return <InventoryBody payload={dialog as InventoryDialogPayload} onClose={close} />;
}

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
  const [selected, setSelected] = useState<SlotRef | null>(null);
  const [amount, setAmount] = useState("");
  const [search, setSearch] = useState({ left: "", right: "" });
  const [confirmation, setConfirmation] = useState<Confirmation | null>(null);
  const [busy, setBusy] = useState(false);
  const pending = useRef(false);
  const [status, setStatus] = useState<{ text: string; error?: boolean }>({ text: "Select an item to see its details." });
  const result = useStore((s) => s.lastResult);
  const lastHandledResult = useRef(result);
  const selectedItem = itemAt(selected, [left, right]);
  const mine = selected?.inventory === left.id;
  const count = selectedItem ? quantity(amount, selectedItem.count) : 0;
  const destination = mine ? right : left;
  const moveSlot = selectedItem ? transferSlot(destination, selectedItem, count) : undefined;
  const canTransfer = !!selectedItem && count > 0 && destination.kind !== "ground" && moveSlot !== undefined;
  const source = selected?.inventory === left.id ? left : right;
  const freeSlot = emptySlot(source);

  const cancelDrag = useCallback(() => {
    dragRef.current = null; setDrag(null);
    root.current?.querySelectorAll("[data-drop-active]").forEach((element) => element.removeAttribute("data-drop-active"));
  }, []);
  const issue = useCallback((action: UiAction) => {
    if (pending.current) return;
    pending.current = true; setBusy(true); setMenu(null); setConfirmation(null);
    setStatus({ text: "Updating inventory…" });
    sendAction(action);
  }, []);

  // Items only change on server snapshots, never on optimistic browser mutations.
  useEffect(() => {
    cancelDrag(); setMenu(null); setConfirmation(null);
    if (pending.current) { pending.current = false; setBusy(false); setStatus({ text: "Inventory updated." }); }
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
    const previous = document.activeElement as HTMLElement | null;
    root.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, []);

  const select = (ref: SlotRef) => {
    if (ref.inventory !== selected?.inventory || ref.slot !== selected.slot) setAmount("");
    setSelected(ref); setConfirmation(null); setMenu(null);
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
      if (!current.active) { current.active = true; setDrag({ ...current }); }
      if (ghost.current) ghost.current.style.transform = `translate(${Math.min(event.clientX + 15, innerWidth - 140)}px, ${Math.min(event.clientY + 15, innerHeight - 54)}px)`;
      root.current?.querySelectorAll("[data-drop-active]").forEach((element) => element.removeAttribute("data-drop-active"));
      const element = document.elementFromPoint(event.clientX, event.clientY);
      element?.closest("[data-inv]")?.setAttribute("data-drop-active", "true");
      const grid = element?.closest(".inventory-grid");
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
      const element = document.elementFromPoint(event.clientX, event.clientY)?.closest<HTMLElement>("[data-inv]");
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
    if (!menu) return;
    const dismiss = (event: PointerEvent) => { if (!(event.target as HTMLElement).closest(".inventory-menu")) setMenu(null); };
    window.addEventListener("pointerdown", dismiss);
    return () => window.removeEventListener("pointerdown", dismiss);
  }, [menu]);

  const keyDown = (event: KeyboardEvent) => {
    if (event.key === "Escape") {
      event.preventDefault(); event.stopPropagation();
      if (menu) setMenu(null);
      else if (confirmation) setConfirmation(null);
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
      // Embedded Chromium can omit the physical code; retain the logical key
      // so its release still closes the inventory in the in-game WebUI.
      closeKeyPressed.current = event.code || event.key.toUpperCase();
      return;
    }
    if (busy) return;
    if (/^[1-5]$/.test(event.key)) { event.preventDefault(); select({ inventory: left.id, slot: Number(event.key) }); }
  };
  const pointerDown = (inventory: InventorySnapshot, slot: number, item: InventoryItem | undefined, event: React.PointerEvent) => {
    if (event.button !== 0 || busy) return;
    select({ inventory: inventory.id, slot });
    if (!item) return;
    const picked = event.shiftKey ? Math.max(1, Math.floor(item.count / 2))
      : quantity(selected?.inventory === inventory.id && selected.slot === slot ? amount : "", item.count);
    if (picked) dragRef.current = { from: { inventory: inventory.id, slot }, item, count: picked, x: event.clientX, y: event.clientY, active: false };
  };
  const context = (inventory: InventorySnapshot, slot: number, event: React.MouseEvent) => {
    event.preventDefault();
    if (busy || !itemAt({ inventory: inventory.id, slot }, [left, right])) return;
    select({ inventory: inventory.id, slot }); setMenu({ x: event.clientX, y: event.clientY });
  };

  // A disabled action can send focus back to body while waiting for the server.
  // Keep Escape/Tab working there too, including inside a search/quantity input.
  useEffect(() => {
    // Close on release: the opening key-up alone is ignored, and the native
    // mapping cannot see a still-held I after the page releases gameplay focus.
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

  return <div ref={root} className={`inventory o77-interactive${drag ? " inventory--dragging" : ""}`} role="dialog" aria-modal="true" aria-labelledby="inventory-title" tabIndex={-1} onContextMenu={(event) => event.preventDefault()}>
    <div className="inventory__workspace">
      <header className="inventory__header"><div><span className="inventory__eyebrow"><b>Light RP /</b> Personal belongings</span><h1 id="inventory-title">Inventory<span>.</span></h1></div>
        <button className="inventory__close" aria-label="Close inventory" onClick={onClose}><span>Close</span><kbd>{payload.toggleKey ?? "I"}</kbd><kbd>Esc</kbd><Icon name="x" size={18} /></button></header>
      <div className="inventory__layout">
        {(["left", "right"] as const).map((side) => <InventoryPanel key={side} inventory={payload[side]} side={side} search={search[side]}
          onSearch={(value) => setSearch((old) => ({ ...old, [side]: value }))} selected={selected} busy={busy} drag={drag} select={select} onPointerDown={pointerDown} onContext={context} />)}
        <aside className="inventory-detail" aria-label="Item details"><span className="inventory__eyebrow">{selectedItem ? "Selected item" : "Item details"}</span>
          {selectedItem ? <>
            <div className="inventory-detail__item" key={`${selected?.inventory}:${selected?.slot}:${selectedItem.name}`}>
              <div className="inventory-detail__art"><ItemArt item={selectedItem} size="detail" /></div>
              <span className="inventory-detail__category">{selectedItem.category ?? "Personal item"}</span><h2>{selectedItem.label}</h2>
              <p>{selectedItem.description || "Keep it in your pockets or move it to storage."}</p>
              <ItemEffects item={selectedItem} />
              <dl><div><dt>Weight each</dt><dd>{kg(selectedItem.weight)} kg</dd></div><div><dt>In this stack</dt><dd>{selectedItem.count} <span>· {kg(selectedItem.weight * selectedItem.count)} kg</span></dd></div></dl>
            </div>
            <div className="inventory-quantity"><label htmlFor="inventory-amount">Quantity <span>{amount.trim() === "" ? "All items" : `${count} selected`}</span></label>
              <div className="inventory-quantity__row"><input id="inventory-amount" aria-label="Quantity" inputMode="numeric" type="text" placeholder={String(selectedItem.count)} value={amount} disabled={busy} aria-invalid={count === 0} onChange={(event) => { setAmount(event.target.value.replace(/[^0-9]/g, "").slice(0, 7)); setConfirmation(null); }} />
                <button disabled={busy} onClick={() => { setAmount("1"); setConfirmation(null); }}>1</button><button disabled={busy || selectedItem.count < 2} onClick={() => { setAmount(String(Math.floor(selectedItem.count / 2))); setConfirmation(null); }}>Half</button><button disabled={busy} onClick={() => { setAmount(""); setConfirmation(null); }}>All</button></div>
            </div>
            {confirmation ? <div className="inventory-confirm" role="alert"><strong>{confirmation === "drop" ? "Drop on the ground?" : "Give to the nearest player?"}</strong>
              <p>{count} × {selectedItem.label}{confirmation === "give" ? ". The server checks who is close enough." : ". Other players can pick this up."}</p>
              <div><button className="inventory-button inventory-button--primary" disabled={busy || !count} onClick={confirm}>Confirm {confirmation}</button><button className="inventory-button" onClick={() => setConfirmation(null)}>Cancel</button></div></div>
              : <div className="inventory-detail__actions">
                {mine && selectedItem.usable && <button className="inventory-button inventory-button--primary" disabled={busy} onClick={() => perform("use")}><Icon name="hand" size={16} />Use one<Icon name="arrow-right" size={15} /></button>}
                {destination.kind !== "ground" && <button className={`inventory-button${!mine || !selectedItem.usable ? " inventory-button--primary" : ""}`} disabled={busy || !canTransfer} onClick={() => perform("transfer")}><Icon name="arrow-left-right" size={16} />{mine ? "Move to storage" : "Take item"}</button>}
                <button className="inventory-button" disabled={busy || selectedItem.count < 2 || freeSlot === undefined || !count} onClick={() => perform("split")}><Icon name="split" size={16} />Split stack</button>
                {mine && <><button className="inventory-button" disabled={busy || !count} onClick={() => setConfirmation("give")}><Icon name="users" size={16} />Give to nearby player</button><button className="inventory-button inventory-button--subtle" disabled={busy || !count} onClick={() => setConfirmation("drop")}><Icon name="arrow-down" size={16} />Drop on ground</button></>}
              </div>}
          </> : <div className="inventory-detail__empty"><Icon name="hand" size={36} /><h2>Select an item</h2><p>Its details and available actions will appear here.</p><span>Drag items between slots.<br />Right-click for quick actions.</span></div>}
        </aside>
      </div>
      <footer className="inventory__footer"><span className={status.error ? "inventory__feedback is-error" : "inventory__feedback"} role="status"><Icon name={busy ? "loader" : status.error ? "triangle-alert" : "info"} size={14} />{status.text}</span><span><kbd>Shift</kbd> + drag half <i /> <kbd>1–5</kbd> select <i /> Right-click actions</span></footer>
    </div>
    {drag && <div ref={ghost} className="inventory-ghost" style={{ transform: `translate(${drag.x + 15}px, ${drag.y + 15}px)` }}><ItemArt item={drag.item} size="drag" /><div>{drag.item.label}<small>{drag.count} items</small></div></div>}
    {menu && selectedItem && <div className="inventory-menu" role="menu" aria-label={`${selectedItem.label} actions`} style={{ left: Math.max(8, Math.min(menu.x, innerWidth - 244)), top: Math.max(8, Math.min(menu.y, innerHeight - 280)) }}>
      <span>{selectedItem.label}</span>
      {mine && selectedItem.usable && <button role="menuitem" onClick={() => perform("use")}><Icon name="hand" size={14} />Use one</button>}
      {destination.kind !== "ground" && <button role="menuitem" disabled={!canTransfer} onClick={() => perform("transfer")}><Icon name="arrow-left-right" size={14} />{mine ? "Move to storage" : "Take item"}</button>}
      <button role="menuitem" disabled={selectedItem.count < 2 || freeSlot === undefined || !count} onClick={() => perform("split")}><Icon name="split" size={14} />Split stack</button>
      {mine && <><button role="menuitem" disabled={!count} onClick={() => { setMenu(null); setConfirmation("give"); }}><Icon name="users" size={14} />Give to nearby player</button><button role="menuitem" disabled={!count} onClick={() => { setMenu(null); setConfirmation("drop"); }}><Icon name="arrow-down" size={14} />Drop on ground</button></>}
    </div>}
  </div>;
}

function InventoryPanel({ inventory: inv, side, search, onSearch, selected, busy, drag, select, onPointerDown, onContext }: {
  inventory: InventorySnapshot; side: "left" | "right"; search: string; onSearch: (value: string) => void;
  selected: SlotRef | null; busy: boolean; drag: Drag | null; select: (ref: SlotRef) => void;
  onPointerDown: (inv: InventorySnapshot, slot: number, item: InventoryItem | undefined, event: React.PointerEvent) => void;
  onContext: (inv: InventorySnapshot, slot: number, event: React.MouseEvent) => void;
}) {
  const bySlot = useMemo(() => new Map(inv.items.map((item) => [item.slot, item])), [inv.items]);
  const ground = inv.kind === "ground";
  const query = search.trim().toLocaleLowerCase();
  const matches = (item: InventoryItem | undefined) => !!item && (!query || `${item.label} ${item.name} ${item.category ?? ""}`.toLocaleLowerCase().includes(query));
  const slots = Array.from({ length: inv.slots }, (_, index) => index + 1).filter((slot) => !query || matches(bySlot.get(slot)));
  const pct = inv.maxWeight > 0 ? Math.min(100, Math.max(0, inv.weight / inv.maxWeight * 100)) : 0;
  const title = side === "left" ? "Pockets" : ground ? "Nearby" : inv.kind === "trunk" ? "Vehicle storage" : inv.kind === "drop" ? "On the ground" : "Storage";
  return <section className={`inventory-panel inventory-panel--${side}`} aria-label={title}>
    <header className="inventory-panel__head"><div className="inventory-panel__title"><Icon name={side === "left" ? "backpack" : inv.kind === "trunk" ? "car" : "package-open"} size={20} /><div><h2>{title}</h2><p>{ground ? "Items you leave here are visible to others." : inv.label}</p></div></div>
      {!ground && <div className={`inventory-weight${pct > 90 ? " is-heavy" : ""}`}><span><strong>{kg(inv.weight)}</strong> / {kg(inv.maxWeight)} kg</span><div><i style={{ width: `${pct}%` }} /></div></div>}
    </header>
    {ground ? <div className="inventory-ground" data-inv="ground" data-slot="1"><Icon name="arrow-down" size={25} /><h3>Leave something here</h3><p>Drag an item from your pockets<br />to place it on the ground.</p><span>Or select an item and choose Drop.</span></div> : <>
      <div className="inventory-panel__tools"><label className="inventory-search"><Icon name="search" size={16} /><input aria-label={`Search ${title.toLowerCase()}`} placeholder="Find an item…" value={search} onChange={(event) => onSearch(event.target.value)} />{search && <button aria-label={`Clear ${title.toLowerCase()} search`} onClick={() => onSearch("")}><Icon name="x" size={14} /></button>}</label><span>{inv.items.length} / {inv.slots} slots</span></div>
      <div className="inventory-grid" aria-label={`${title} slots`}>
        {slots.map((slot) => {
          const item = bySlot.get(slot);
          const isSelected = selected?.inventory === inv.id && selected.slot === slot;
          const isSource = drag?.from.inventory === inv.id && drag.from.slot === slot;
          return <button key={slot} type="button" className={`inventory-slot${item ? " is-filled" : ""}${isSelected ? " is-selected" : ""}${isSource ? " is-source" : ""}`} data-inv={inv.id} data-slot={slot} disabled={busy}
            aria-label={item ? `${item.label}, ${item.count}, slot ${slot}` : `Empty slot ${slot}`} aria-pressed={isSelected}
            onClick={() => select({ inventory: inv.id, slot })} onPointerDown={(event) => onPointerDown(inv, slot, item, event)} onContextMenu={(event) => onContext(inv, slot, event)}
            onKeyDown={(event) => {
              const offset = ({ ArrowRight: 1, ArrowLeft: -1, ArrowDown: 5, ArrowUp: -5 } as Record<string, number>)[event.key];
              if (offset === undefined) return;
              event.preventDefault();
              const buttons = Array.from(event.currentTarget.parentElement!.querySelectorAll<HTMLButtonElement>("button"));
              const target = buttons[buttons.indexOf(event.currentTarget) + offset];
              if (target) { target.focus(); select({ inventory: inv.id, slot: Number(target.dataset.slot) }); }
            }}>
            <span className="inventory-slot__index">{side === "left" && slot <= 5 ? slot : String(slot).padStart(2, "0")}</span>
            {item ? <><span className="inventory-slot__count" key={`${item.name}:${item.count}`}>×{item.count}</span><span className="inventory-slot__icon"><ItemArt item={item} /></span><span className="inventory-slot__label">{item.label}</span></> : <span className="inventory-slot__empty">·</span>}
          </button>;
        })}
        {slots.length === 0 && <div className="inventory-no-results"><Icon name="search" size={25} /><h3>No matching items</h3><p>Try another name or clear your search.</p><button className="inventory-button" onClick={() => onSearch("")}>Clear search</button></div>}
      </div>
    </>}
  </section>;
}
