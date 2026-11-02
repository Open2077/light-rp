import { useState } from "react";
import { Button, Panel } from "@/design/components";
import { emit } from "@/bridge/open77";
import { useStore } from "@/state/store";
import { asList, type ExtraControlsProps } from "./registry";

/* Blackjack panel. Everything here is a view of the server's public table
   state (the client adds clientNow, mySeat and legal); the page only sends
   requests: bet, deal, hit, stand, double. */
interface Card { c?: string; h?: boolean; t?: number; f?: number }
interface Hand {
  bet?: number; stake?: number; cards?: Card[]; total?: number; soft?: boolean; done?: boolean;
  doubled?: boolean; natural?: boolean; timedOut?: boolean; result?: string; payout?: number;
}
interface BlackjackState {
  phase?: "betting" | "playing" | "result"; round?: number;
  hands?: Record<string, Hand>; dealer?: { cards?: Card[]; total?: number; soft?: boolean };
  seatTurn?: string; closesAt?: number; actAt?: number; turnEndsAt?: number; resultAt?: number;
  clientNow?: number; mySeat?: string; legal?: { hit?: boolean; stand?: boolean; double?: boolean };
  shoe?: { left?: number; total?: number; cut?: boolean };
}
const SEAT_ORDER = ["white", "black", "white2", "black2"];
const SUITS: Record<string, string> = { S: "♠", H: "♥", D: "♦", C: "♣" };
const RESULTS: Record<string, string> = {
  blackjack: "Blackjack! Paid 3 to 2", win: "You win", push: "Push: stake returned", lose: "Dealer wins", bust: "Bust",
};
function cardText(card: Card, now: number): string {
  if (!card.c || (card.f ?? 0) > now) return "▒";
  const rank = card.c.charAt(0) === "T" ? "10" : card.c.charAt(0);
  return rank + (SUITS[card.c.charAt(1)] ?? "");
}
function shown(cards: Card[] | undefined, now: number) {
  return asList<Card>(cards).filter(card => (card.t ?? 0) <= now);
}
function totalText(total: number | undefined, soft: boolean | undefined) {
  return total === undefined ? "–" : soft && total < 21 ? `soft ${total}` : String(total);
}
function seconds(at: number | undefined, now: number) {
  return at === undefined ? 0 : Math.max(0, Math.ceil((at - now) / 1000));
}
export function BlackjackControls({ game: state, ready }: ExtraControlsProps) {
  const game = state as BlackjackState;
  const [amount, setAmount] = useState(25);
  const cash = useStore(s => s.state.money.cash);
  const action = (operation: string, data: Record<string, unknown> = {}) => emit("lightrp:tabletop:action", { operation, data });
  const now = game.clientNow ?? 0;
  const seat = game.mySeat;
  const hand = seat ? game.hands?.[seat] : undefined;
  const legal = game.legal ?? {};
  const dealerCards = shown(game.dealer?.cards, now);
  const revealing = game.phase === "result" && (game.resultAt ?? 0) > now;
  const dealing = game.phase === "playing" && (game.actAt ?? 0) > now;
  const dealerVisible = dealerCards.filter(card => card.c && (card.f ?? 0) <= now);
  const seatNumber = seat ? SEAT_ORDER.indexOf(seat) + 1 : 0;
  const stakeOk = Number.isInteger(amount) && amount >= 1 && amount <= 5000 && amount <= cash && (hand?.bet ?? 0) + amount >= 5 && (hand?.bet ?? 0) + amount <= 5000;
  const turnSeat = game.seatTurn ? SEAT_ORDER.indexOf(game.seatTurn) + 1 : 0;
  return <Panel title="BLACKJACK · CASH TABLE" chamfer="sm">
    <p className="board-games__meta">Round {game.round ?? 1} · Seat {seatNumber || "–"} · Cash €$ {cash.toLocaleString("en-US")}</p>
    <p className="board-games__meta">Dealer: {dealerCards.map(card => cardText(card, now)).join(" ") || "–"}
      {dealerVisible.length > 0 && <> · {revealing && dealerCards.length > dealerVisible.length ? "…" : totalText(game.dealer?.total, game.dealer?.soft)}</>}</p>
    {hand && <p className="board-games__status">
      Your hand: {shown(hand.cards, now).map(card => cardText(card, now)).join(" ") || "–"}
      {asList<Card>(hand.cards).length > 0 && !dealing && <> · {totalText(hand.total, hand.soft)}</>}
      {" "}· stake €$ {(hand.stake ?? hand.bet ?? 0).toLocaleString("en-US")}{hand.doubled ? " (doubled)" : ""}
    </p>}
    {game.phase === "betting" && <>
      <p role="status" className="board-games__turn">{game.closesAt ? `Dealing in ${seconds(game.closesAt, now)} s` : "Place a bet to start the hand."}</p>
      <label className="board-games__field">Bet (5 – 5,000)<input aria-label="Bet amount" type="number" min={5} max={5000} step={5} value={amount} onChange={e => setAmount(Number(e.target.value))} /></label>
      <div className="board-games__modes">
        <Button size="sm" disabled={!ready || !seat || !stakeOk} onClick={() => action("bet", { amount })}>{hand ? "Add to bet" : "Place bet"}</Button>
        <Button variant="secondary" size="sm" disabled={!ready || !hand} onClick={() => action("deal")}>Deal now</Button>
      </div>
    </>}
    {game.phase === "playing" && <>
      <p role="status" className="board-games__turn">{dealing ? "Dealing…" : game.seatTurn === seat ? `Your turn · ${seconds(game.turnEndsAt, now)} s` : `Seat ${turnSeat} to play`}</p>
      {game.seatTurn === seat && hand && !dealing && <div className="board-games__modes">
        <Button size="sm" disabled={!legal.hit} onClick={() => action("hit")}>Hit</Button>
        <Button variant="secondary" size="sm" disabled={!legal.stand} onClick={() => action("stand")}>Stand</Button>
        <Button variant="secondary" size="sm" disabled={!legal.double || (hand.bet ?? 0) > cash} onClick={() => action("double")}>Double</Button>
      </div>}
    </>}
    {game.phase === "result" && <p role="status" className="board-games__turn">
      {revealing ? "Dealer plays…" : hand?.result ? `${RESULTS[hand.result] ?? hand.result}${(hand.payout ?? 0) > 0 ? ` · €$ ${(hand.payout ?? 0).toLocaleString("en-US")} returned` : ""}` : "Next hand shortly."}
    </p>}
    {game.shoe?.cut && <p className="board-games__meta">Cut card is out: fresh shoe after this hand.</p>}
    <p className="board-games__description">Blackjack pays 3 to 2 · dealer stands on soft 17 · double on any first two cards. Stakes use your RP cash; returns include the stake and arrive when the dealer has finished.</p>
  </Panel>;
}
