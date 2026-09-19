import { useEffect, useMemo, useState } from "react";
import { useStore } from "@/state/store";
import { requestClose } from "@/bridge/open77";
import { RageMenu, type RageMenuItem } from "@/design/components";
import { formatMoney, ledger, transactionLabel } from "@/bridge/money";
import type { CharacterState, MoneyState } from "@/bridge/protocol";
import "./menu.css";

/* The player menu (F1): a RageUI-style list menu, keyboard only, top-left. The
   tree is built from the server state on every render, so a row is never stale.
   Submenus are entries of the tree keyed by `item.target`; the navigation stack
   holds one { key, index } per level. */

interface MenuNode { title: string; subtitle?: string; tag: string; items: RageMenuItem[] }

const ROOT_INDEX = 1; // first pickable row under the CHARACTER caption

function formatDuration(ms: number): string {
  const minutes = Math.floor(ms / 60000);
  return `${String(Math.floor(minutes / 60)).padStart(2, "0")}H${String(minutes % 60).padStart(2, "0")}`;
}

function buildTree(character: CharacterState, money: MoneyState): Record<string, MenuNode> {
  const name = `${character.firstName ?? ""} ${character.lastName ?? ""}`.trim() || character.accountName;
  const id = String(character.playerId).padStart(3, "0");
  const origin = character.origins.find((o) => o.key === character.origin)?.label;
  const age = character.birthDate ? character.currentYear - Number(character.birthDate.slice(0, 4)) : null;
  return {
    root: {
      title: "OPEN//77", subtitle: "PLAYER MENU", tag: "PLAYER",
      items: [
        { label: "CHARACTER" },
        { id: "identity", type: "submenu", text: "Identity", icon: "id-card", meta: `ID ${id}`, target: "identity",
          description: "Your citizen record: ID, name, birth date, origin and bank account." },
        { id: "bank", type: "submenu", text: "Bank", icon: "landmark", meta: money.bank ? formatMoney(money.bank.balance, money.currency) : "—", target: "bank",
          description: "Cash, account balance, account number and your last operations." },
        { separator: true },
        { label: "SERVER" },
        { id: "briefing", type: "item", text: "Server briefing", icon: "info", description: "Read the welcome briefing again: what Light Roleplay means here." },
        { separator: true },
        { id: "close", type: "item", text: "Close", icon: "x", description: "Close the menu. Backspace or Escape does the same." },
      ],
    },
    bank: {
      title: "BANK", subtitle: money.bank ? `NIGHT CITY BANK // ${money.bank.number}` : "NO ACCOUNT YET", tag: "BANK",
      items: [
        { id: "cash", type: "item", text: "Cash", icon: "banknote", meta: formatMoney(money.cash, money.currency), description: "What you carry. /pay <id> <amount> hands it to someone next to you." },
        { id: "balance", type: "item", text: "Account", icon: "landmark", meta: money.bank ? formatMoney(money.bank.balance, money.currency) : "—", description: "Your balance at Night City Bank." },
        { id: "number", type: "item", text: "Account number", icon: "credit-card", meta: money.bank?.number ?? "—", description: "Give it to whoever has to wire you money: /transfer <number> <amount>." },
        { id: "total", type: "item", text: "Total", icon: "wallet", meta: formatMoney(money.cash + (money.bank?.balance ?? 0), money.currency) },
        ...(ledger(money).length > 0 ? [{ separator: true } as RageMenuItem, { label: "LAST OPERATIONS" } as RageMenuItem] : []),
        ...ledger(money).slice(0, 6).map((t, i): RageMenuItem => ({
          id: `tx${i}`, type: "item", text: transactionLabel(t), icon: t.wallet === "bank" ? "landmark" : "banknote",
          meta: formatMoney(t.amount, money.currency, true), danger: t.amount < 0 && t.kind !== "deposit" && t.kind !== "withdraw",
          description: [t.counterparty, t.note, t.at?.slice(0, 16)].filter(Boolean).join(" · ") || undefined,
        })),
      ],
    },
    identity: {
      title: "IDENTITY", subtitle: `${name.toUpperCase()} // ID ${id}`, tag: "IDENTITY",
      items: [
        { id: "id", type: "item", text: "Citizen ID", icon: "id-card", meta: id, description: "Your number on this server, the one other players use in commands." },
        { id: "first", type: "item", text: "First name", icon: "user", meta: character.firstName ?? "—", description: "The name the others read in the chat." },
        { id: "last", type: "item", text: "Last name", icon: "user", meta: character.lastName ?? "—" },
        { id: "born", type: "item", text: "Born", icon: "calendar", meta: character.birthDate ? `${character.birthDate} · ${age}Y` : "—",
          description: "Night City calendar, year " + character.currentYear + "." },
        { id: "origin", type: "item", text: "Origin", icon: "map-pin", meta: origin ?? "—" },
        { separator: true },
        { id: "account", type: "item", text: "Bank account", icon: "landmark", meta: money.bank?.number ?? "—",
          description: money.bank ? `Night City Bank. Balance ${formatMoney(money.bank.balance, money.currency)}, ${formatMoney(money.cash, money.currency)} in your pocket.` : "No account yet." },
        { id: "playtime", type: "item", text: "Time in the city", icon: "clock", meta: formatDuration(character.playtimeMs ?? 0) },
        { id: "status", type: "item", text: "Record", icon: "badge-check", meta: character.status === "active" ? "ACTIVE" : "DRAFT",
          description: character.story ? character.story : "No backstory written." },
      ],
    },
  };
}

export function PlayerMenu() {
  const open = useStore((s) => s.menuOpen);
  const character = useStore((s) => s.state.character);
  const money = useStore((s) => s.state.money);
  const setWelcomeReplay = useStore((s) => s.setWelcomeReplay);
  const [stack, setStack] = useState<Array<{ key: string; index: number }>>([{ key: "root", index: ROOT_INDEX }]);

  // Every open starts at the root, on the first row.
  useEffect(() => { if (open) setStack([{ key: "root", index: ROOT_INDEX }]); }, [open]);

  // F1 closes the menu too, the key that opened it.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "F1" && !e.repeat) { e.preventDefault(); requestClose(); } };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  const tree = useMemo(() => buildTree(character, money), [character, money]);
  if (!open || character.status !== "active") return null;

  const root = tree.root!;
  const top = stack[stack.length - 1] ?? { key: "root", index: ROOT_INDEX };
  const node = tree[top.key] ?? root;
  const path = stack.map((s) => (tree[s.key] ?? root).tag);
  const setIndex = (i: number) => setStack((s) => s.map((e, n) => (n === s.length - 1 ? { ...e, index: i } : e)));
  const back = () => { if (stack.length > 1) setStack((s) => s.slice(0, -1)); else requestClose(); };
  const select = (item: RageMenuItem) => {
    if (item.type === "submenu" && item.target && tree[item.target]) return setStack((s) => [...s, { key: item.target!, index: 0 }]);
    if (item.id === "briefing") { setWelcomeReplay(true); requestClose(); return; }
    if (item.id === "close") requestClose();
  };

  return (
    <div className="player-menu">
      <RageMenu title={node.title} subtitle={node.subtitle} tag={node.tag} items={node.items} index={top.index} path={path}
        width={340} onIndexChange={setIndex} onSelect={select} onBack={back}
        footer={<><span>[↑↓] MOVE</span><span>[ENTER] SELECT</span><span>[BKSP] BACK</span><span>[F1] CLOSE</span></>} />
    </div>
  );
}
