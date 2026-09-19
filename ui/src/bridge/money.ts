import type { MoneyState, MoneyTransaction } from "./protocol";

/** "€$ 1,250" — whole eddies, thousands grouped, sign kept for ledger lines. */
export function formatMoney(amount: number, currency = "€$", signed = false): string {
  const n = Math.trunc(Number.isFinite(amount) ? amount : 0);
  const digits = Math.abs(n).toLocaleString("en-US");
  const sign = n < 0 ? "-" : signed && n > 0 ? "+" : "";
  return `${sign}${currency} ${digits}`;
}

const KIND_LABEL: Record<string, string> = {
  opening: "Account opened", deposit: "Deposit", withdraw: "Withdrawal", transfer_in: "Transfer in", transfer_out: "Transfer out",
  pay_in: "Cash received", pay_out: "Cash handed", fee: "Fee", refund: "Refund", staff: "Staff", salary: "Salary", credit: "Credit", debit: "Debit",
};
export function transactionLabel(t: MoneyTransaction): string {
  return KIND_LABEL[t.kind] ?? t.kind.replace(/_/g, " ");
}

/** The wire may hand an empty Lua table as `{}`: always read the ledger as an array. */
export function ledger(money: MoneyState): MoneyTransaction[] {
  return Array.isArray(money.history) ? money.history : [];
}
